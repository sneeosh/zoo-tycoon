extends GutTest
# End-to-end smoke tests — Prompt 10.
#
# These prove the engine runs a full economic loop with zoo content +
# zoo adapter scripts and ZERO modifications to addons/tycoon_core/.
# If any of these fail with a "seam leak" message, document it in the
# commit message — that's the experiment paying off.


func before_each() -> void:
	# Suppress autosave noise across the test session.
	SaveService.autosave_enabled = false
	Ledger.reset(5000)
	EntityRegistry.reset()
	RegionRegistry.reset()
	NavigationRegistry.reset()
	AgentPool.reset()
	SimClock.current_tick = 0
	SimClock.current_day = 0
	SimClock.current_period = 0
	SimClock.set_seed(1234)


# --- Content loaded from zoo/design/tuning/ -----------------------------

func test_zoo_tuning_loaded_clean() -> void:
	assert_eq(ContentDB.load_errors, [] as Array[String],
		"zoo design/tuning/*.md must parse with zero errors")
	assert_true(ContentDB.is_loaded)


func test_zoo_entities_loaded() -> void:
	# v0.4.0: exhibits are no longer EntityDefs — they're emergent Regions
	# built from zone-tile entities. Tuning ships four zone tile types
	# (grass / rock / water patches + cage panel) plus the food stand and
	# restroom amenities.
	assert_not_null(ContentDB.get_entity_def(&"grass_patch"))
	assert_not_null(ContentDB.get_entity_def(&"rock_patch"))
	assert_not_null(ContentDB.get_entity_def(&"cage_panel"))
	assert_not_null(ContentDB.get_entity_def(&"food_stand"))
	assert_not_null(ContentDB.get_entity_def(&"restroom"))
	# Animal placeables loaded too.
	assert_not_null(ContentDB.placeable_defs.get(&"lion"))
	assert_not_null(ContentDB.placeable_defs.get(&"feeding_trough"))


func test_visitor_agent_type_loaded() -> void:
	# v0.5.x — four-need guest model (hunger / thirst / restroom / energy).
	var visitor: AgentType = ContentDB.get_agent_type(&"visitor")
	assert_not_null(visitor)
	assert_eq(visitor.needs.size(), 4, "four guest needs")
	var need_ids := {}
	for ns: NeedSpec in visitor.needs:
		need_ids[ns.need.id] = true
	assert_true(need_ids.has(&"hunger"), "hunger need present")
	assert_true(need_ids.has(&"thirst"), "thirst need present")
	assert_true(need_ids.has(&"restroom"), "restroom need present")
	assert_true(need_ids.has(&"energy"), "energy need present")


func test_amenities_satisfy_each_need() -> void:
	# Every guest need must have at least one satisfier entity, or the need
	# is unmeetable and the four-need model just punishes the player.
	var satisfied := {}
	for def_id in ContentDB.entity_defs.keys():
		var ed: EntityDef = ContentDB.entity_defs[def_id]
		for need_id in ed.satisfies:
			satisfied[need_id] = true
	for need_id in [&"hunger", &"thirst", &"restroom", &"energy"]:
		assert_true(satisfied.has(need_id),
			"need '%s' has a satisfier entity" % need_id)


func test_services_config_loads() -> void:
	# ServiceConfig compiles design/tuning/services.md (game-side tuning).
	var sc := ServiceConfig.load_from_tuning()
	assert_eq(sc.price_for(&"hunger"), 5, "food costs $5")
	assert_eq(sc.price_for(&"thirst"), 3, "a drink costs $3")
	assert_eq(sc.price_for(&"restroom"), 0, "restrooms are free")
	# Eating fills the bladder — the original game's spillover twist.
	var spill := sc.spillover_for(&"hunger")
	assert_eq(spill[0], &"restroom", "eating spills into the restroom need")
	assert_gt(float(spill[1]), 0.0, "spillover amount is positive")


func test_ticket_brackets_loaded() -> void:
	var sc := ServiceConfig.load_from_tuning()
	assert_eq(sc.ticket_brackets.size(), 4, "four ticket brackets")
	assert_eq(sc.default_bracket, &"standard", "park starts on Standard")
	var standard := sc.bracket(&"standard")
	assert_eq(int(standard["price"]), 10, "standard ticket is $10")
	# Cheaper bracket pulls a bigger crowd; pricier one thins it.
	assert_gt(float(sc.bracket(&"budget")["demand_multiplier"]),
		float(sc.bracket(&"premium")["demand_multiplier"]),
		"budget demand > premium demand")


func test_ticket_bracket_drives_entry_fee_and_demand() -> void:
	# Switching brackets on the live bootstrap sets the entry fee and scales
	# the park's base spawn rate by the bracket's demand multiplier.
	var base := ZooBootstrap._default_base_spawn_rate
	ZooBootstrap.set_ticket_bracket(&"budget")
	assert_eq(ZooBootstrap.entry_fee, 5, "budget gate fee is $5")
	assert_almost_eq(AgentPool.base_spawn_rate, base * 1.35, 0.0001,
		"budget scales demand up")
	ZooBootstrap.set_ticket_bracket(&"premium")
	assert_eq(ZooBootstrap.entry_fee, 18, "premium gate fee is $18")
	assert_almost_eq(AgentPool.base_spawn_rate, base * 0.70, 0.0001,
		"premium scales demand down")
	# Restore the default so later tests start from a known gate.
	ZooBootstrap.set_ticket_bracket(&"standard")


# --- Adapter scripts registered with the engine -------------------------

func test_bootstrap_registered_visitor_behavior() -> void:
	# Spawn a visitor and verify behavior fires (on_spawn posts a ticket).
	var pre := Ledger.get_balance()
	var id := AgentPool.spawn(&"visitor")
	assert_ne(id, 0)
	# VisitorBehavior.on_spawn posts a ticket (5).
	assert_eq(Ledger.get_balance(), pre + VisitorValueModel.TICKET_PRICE)


func test_satisfaction_model_runs_per_tick() -> void:
	var id := AgentPool.spawn(&"visitor")
	# Advance a tick so the model fires.
	SimClock.advance_tick()
	var a := AgentPool.get_agent(id)
	# Baseline = mean of need levels. Visitor starts with hunger=1.0 so
	# satisfaction should be ~1.0 (minus tiny effect drift if any).
	assert_gt(a.satisfaction, 0.5)


# --- End-to-end economic loop -------------------------------------------

func test_visitor_seeks_and_buys_food_when_hungry() -> void:
	# Stage a food stand and a visitor; advance enough ticks for hunger
	# to cross threshold, behavior to walk over, and the food purchase
	# to post.
	EntityRegistry.place(&"food_stand", Vector2i(3, 3))
	var pre_balance := Ledger.get_balance()
	var aid := AgentPool.spawn(&"visitor", Vector2(0, 0))
	# Visitor entry ticket already posted on spawn.
	var post_entry := Ledger.get_balance()
	assert_eq(post_entry - pre_balance, VisitorValueModel.TICKET_PRICE)

	# Drive ticks. hunger threshold = 0.4, decay = 0.0015/tick → crosses
	# around tick ~400. Then behavior heads to food stand (~5 tiles
	# away, walking speed ~0.18/tick → ~30 ticks). After eating, hunger
	# decays again. We can't snapshot hunger==1.0 at an arbitrary
	# end-tick — check the transaction log for the food purchase.
	for i in range(600):
		SimClock.advance_tick()

	var has_food_purchase := false
	for tx: Dictionary in Ledger.transactions:
		if tx["label"] == "Food":
			has_food_purchase = true
			break
	assert_true(has_food_purchase, "visitor reached food stand and posted a food purchase")
	assert_gt(Ledger.get_balance(), post_entry, "food purchase added income")


func test_donation_box_collects_tips() -> void:
	# A Donation Box inside a populated exhibit earns tips from happy guests
	# who stop to watch — per-exhibit income beyond the gate take.
	for x in range(0, 3):
		for y in range(0, 3):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 3))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(region)
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	RegionRegistry.add_placement(region.region_id, &"donation_box")
	ZooBootstrap.donations_by_region.clear()
	for i in range(6):
		AgentPool.spawn(&"visitor", Vector2(5, 5))
	for i in range(SimClock.ticks_per_day):
		SimClock.advance_tick()
	assert_gt(ZooBootstrap.donations_for_region(region.region_id), 0,
		"happy guests tipped at the donation box")


func test_happiness_breakdown_identifies_dominant_factor() -> void:
	# A lone lion in a tiny pen with no troughs should report its missing
	# needs (provides_food / provides_water) and a social deficit via the
	# labelled breakdown the suitability panel renders.
	# Pen of area 6 — room for the lion (space_required 3) plus two troughs
	# (1 each); can_add_placement sums space_required against area.
	EntityRegistry.place(&"grass_patch", Vector2i(0, 0))
	EntityRegistry.place(&"grass_patch", Vector2i(1, 0))
	EntityRegistry.place(&"grass_patch", Vector2i(2, 0))
	EntityRegistry.place(&"grass_patch", Vector2i(0, 1))
	EntityRegistry.place(&"grass_patch", Vector2i(1, 1))
	EntityRegistry.place(&"rock_patch", Vector2i(2, 1))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(region)
	var added := RegionRegistry.add_placement(region.region_id, &"lion")
	assert_not_null(added, "lion fits a 4-cell grass+rock pen")
	var model := ZooBootstrap.get_happiness_model()
	var b := model.compute_breakdown(region, 0)
	assert_true(b["valid"])
	# Lion needs provides_food + provides_water; neither is present.
	assert_eq((b["missing_needs"] as Array).size(), 2, "two unmet needs")
	assert_gt(float(b["needs"]), 0.0, "needs penalty registered")
	assert_eq(b["social_kind"], "deficit", "lone lion is under social_min")
	# happiness == compute_happiness (the engine's entry point) — same math.
	assert_almost_eq(float(b["happiness"]),
		model.compute_happiness(region, 0), 0.0001,
		"breakdown happiness matches compute_happiness")
	# Adding the troughs clears the needs penalty.
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	var b2 := model.compute_breakdown(region, 0)
	assert_eq((b2["missing_needs"] as Array).size(), 0, "troughs meet the needs")


func test_restaurant_satisfies_all_four_needs() -> void:
	var rest: EntityDef = ContentDB.get_entity_def(&"restaurant")
	assert_not_null(rest, "restaurant capstone loaded")
	for need_id in [&"hunger", &"thirst", &"restroom", &"energy"]:
		assert_true(need_id in rest.satisfies,
			"restaurant satisfies '%s'" % need_id)


func test_restaurant_is_a_one_stop_meal() -> void:
	# A guest who gets hungry near a Restaurant (and nothing else) walks there
	# and buys a "Meal" — the multi-need one-stop refill, not a single "Food".
	EntityRegistry.place(&"restaurant", Vector2i(3, 3))
	AgentPool.spawn(&"visitor", Vector2(0, 0))
	for i in range(600):
		SimClock.advance_tick()
	var has_meal := false
	for tx: Dictionary in Ledger.transactions:
		if tx["label"] == "Meal":
			has_meal = true
			break
	assert_true(has_meal, "guest bought a one-stop Meal at the restaurant")


func test_compost_has_revenue_and_stink_effects() -> void:
	var compost: EntityDef = ContentDB.get_entity_def(&"compost")
	assert_not_null(compost, "compost building loaded")
	assert_eq(compost.maintenance_cost, 0, "compost is zero-upkeep")
	var has_revenue := false
	var has_stink := false
	for eff: Effect in compost.effects:
		if eff.target == Effect.TARGET_REVENUE and eff.magnitude > 0.0:
			has_revenue = true
		if eff.target == Effect.TARGET_SATISFACTION and eff.magnitude < 0.0:
			has_stink = true
	assert_true(has_revenue, "compost earns revenue from the crowd")
	assert_true(has_stink, "compost carries a stink satisfaction penalty")


func test_path_tiles_build_a_walkable_network() -> void:
	# Placing `path` tiles must reactively build a WalkableNetwork (proves the
	# engine bump is wired: walkable column parsed, NavigationRegistry autoload
	# live, routing works).
	for x in range(0, 5):
		EntityRegistry.place(&"path", Vector2i(x, 0))
	var net := NavigationRegistry.get_network()
	assert_not_null(net, "a default network exists once path tiles are placed")
	assert_eq(net.cell_count(), 5, "five path cells in the network")
	assert_true(net.has_cell(Vector2i(0, 0)), "gate-end path cell present")
	var route := NavigationRegistry.path(Vector2i(0, 0), Vector2i(4, 0))
	assert_eq(route.size(), 5, "straight 5-cell route end to end")
	# A non-path cell is off-network.
	assert_false(net.has_cell(Vector2i(0, 1)), "non-path cell is not walkable")


func test_guest_walks_only_on_paths_to_reach_food() -> void:
	# With a path network present, a guest sticks to it: lay a straight path
	# from the gate to a food stand and assert the guest's cell is ALWAYS a
	# path cell across its whole visit, and that it still reaches and buys food.
	for x in range(0, 9):
		EntityRegistry.place(&"path", Vector2i(x, 0))
	EntityRegistry.place(&"food_stand", Vector2i(4, 1))   # path (4,0) sits beside it
	var net := NavigationRegistry.get_network()
	assert_not_null(net)
	var aid := AgentPool.spawn(&"visitor", Vector2(0, 0))
	var off_path_ticks := 0
	for i in range(700):
		SimClock.advance_tick()
		var a := AgentPool.get_agent(aid)
		if a == null:
			break   # left the park (still left via the path)
		if not net.has_cell(Vector2i(a.position.round())):
			off_path_ticks += 1
	assert_eq(off_path_ticks, 0, "guest never stepped off the path network")
	var bought := false
	for tx: Dictionary in Ledger.transactions:
		if tx["label"] == "Food":
			bought = true
			break
	assert_true(bought, "guest reached the food stand along the path and ate")


func test_full_day_runs_end_to_end() -> void:
	# Place a small park and spawn a few visitors, then advance a full
	# day. The build plan's success criterion: economic loop with
	# net positive income after settlement.
	EntityRegistry.place(&"lion_exhibit", Vector2i(0, 0))
	EntityRegistry.place(&"food_stand", Vector2i(10, 0))
	EntityRegistry.place(&"restroom", Vector2i(15, 0))
	var pre_balance := Ledger.get_balance()
	for i in range(8):
		AgentPool.spawn(&"visitor", Vector2(SimClock.rng.randf_range(0, 5), SimClock.rng.randf_range(0, 5)))

	# Run a full day. ticks_per_day = 240 per zoo balance.md.
	for i in range(SimClock.ticks_per_day):
		SimClock.advance_tick()

	# Daily settlement has run (Ledger handler on day_ended). Recurring
	# expenses cost 50/day. Tickets brought 8 * 5 = 40. Food purchases
	# fired for some visitors. Proximity revenue effect on food_stand
	# posted for visitors within 3 tiles. Net should easily clear costs.
	assert_gt(Ledger.get_balance(), pre_balance,
		"end-to-end loop nets positive over one day with %d starting balance" % pre_balance)
	assert_eq(SimClock.current_day, 1, "exactly one day elapsed")


func test_quality_rating_reflects_region_appeal() -> void:
	# v0.4.0: rating is mean of regions' max-axis appeal × 5.
	var initial := ZooBootstrap.get_quality_rating()
	assert_eq(initial, 0.0, "no populated regions → 0")
	# Build a small grass region and drop a lion in it.
	for x in range(0, 3):
		for y in range(0, 3):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 3))   # adds rocks tag
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(region)
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	# Lion contributes thrill 0.8 and danger 0.6; happiness will be near 1.0
	# (companions 0 < social_min 1 → small penalty). Max axis ≈ 0.8 × 0.x
	# → rating ≈ 3-4 stars, definitely > 1.
	var rating := ZooBootstrap.get_quality_rating()
	assert_gt(rating, 1.0, "populated region with a lion should rate > 1 star")


