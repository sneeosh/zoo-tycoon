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
	ZooBootstrap.set_hired_keepers(0)
	# Game default is now closed-on-start (player opens after first exhibit);
	# tests presume an open park unless they explicitly close it.
	ZooBootstrap.set_park_open(true)


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


func test_difficulties_loaded_and_overlay() -> void:
	var s := Scenario.load_from_tuning()
	assert_eq(s.difficulties.size(), 3, "three difficulties")
	assert_true(s.apply_difficulty(&"hard"), "hard overlay applies")
	assert_eq(s.target_cash, 28000, "hard raises the cash bar")
	assert_eq(s.days_limit, 24, "hard shortens the window")
	assert_lt(s.demand_multiplier, 1.0, "hard thins the crowd")
	assert_true(s.apply_difficulty(&"easy"))
	assert_eq(s.starting_cash, 14000, "easy starts richer")
	assert_false(s.apply_difficulty(&"unknown"), "unknown ids are ignored")


func test_set_difficulty_resets_cash_and_targets() -> void:
	ZooBootstrap.set_difficulty(&"easy")
	assert_eq(ZooBootstrap.scenario.target_cash, 15000, "easy win bar applied")
	assert_eq(Ledger.get_balance(), 14000, "easy opening cash applied")
	# Restore Standard so later tests start from the default.
	ZooBootstrap.set_difficulty(&"standard")
	assert_eq(ZooBootstrap.scenario.target_cash, 20000)
	assert_almost_eq(ZooBootstrap.scenario.demand_multiplier, 1.0, 0.001)


func test_marketing_campaign_boosts_then_expires() -> void:
	var fam: AgentType = ContentDB.get_agent_type(&"family")
	var base := fam.spawn_weight
	assert_true(ZooBootstrap.start_campaign(&"family"), "campaign launches when affordable")
	assert_gt(fam.spawn_weight, base, "family arrivals are boosted during the campaign")
	assert_false(ZooBootstrap.start_campaign(&"child"), "only one campaign at a time")
	for d in range(ZooBootstrap.marketing.campaign_days):
		ZooBootstrap._tick_campaign(d)
	assert_eq(ZooBootstrap.campaign_days_left, 0, "campaign ends after its run")
	assert_almost_eq(fam.spawn_weight, base, 0.001, "spawn weight restored when it ends")


func test_guest_archetypes_loaded() -> void:
	# Four guest archetypes, each a full AgentType with the four needs and its
	# own appeal preferences.
	for tid in [&"visitor", &"child", &"family", &"enthusiast"]:
		var at: AgentType = ContentDB.get_agent_type(tid)
		assert_not_null(at, "archetype '%s' loaded" % tid)
		assert_eq(at.needs.size(), 4, "'%s' has four needs" % tid)
	assert_true(ContentDB.get_agent_type(&"child").preferences.has(&"cute"),
		"children prefer cute exhibits")
	assert_true(ContentDB.get_agent_type(&"enthusiast").preferences.has(&"exotic"),
		"enthusiasts prefer exotic exhibits")
	var sc := ServiceConfig.load_from_tuning()
	assert_almost_eq(sc.spend_multiplier(&"family"), 2.2, 0.001, "family parties spend more")
	assert_almost_eq(sc.spend_multiplier(&"visitor"), 1.0, 0.001, "adult is the spend baseline")


func test_archetype_spend_scales_gate_fee() -> void:
	# A guest's archetype scales what they pay at the gate (and inside).
	var fee := ZooBootstrap.entry_fee
	var pre := Ledger.get_balance()
	AgentPool.spawn(&"family")
	assert_eq(Ledger.get_balance() - pre, int(round(fee * 2.2)),
		"a family pays a party-sized gate fee")
	var pre2 := Ledger.get_balance()
	AgentPool.spawn(&"child")
	assert_eq(Ledger.get_balance() - pre2, int(round(fee * 0.5)),
		"a child pays half the gate fee")


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
	# the park's base spawn rate by the bracket's demand multiplier. Pin a
	# neutral environment (cloudy × spring = 1.0) so weather doesn't skew it.
	ZooBootstrap.current_weather = &"cloudy"
	SimClock.current_day = 0
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
	for i in range(1000):
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
	for i in range(1000):
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
	# Gate now lives at (0,17) (see GATE_TILE in main.gd); the path runs east
	# from there and the food stand sits one cell north of it.
	for x in range(0, 9):
		EntityRegistry.place(&"path", Vector2i(x, 17))
	EntityRegistry.place(&"food_stand", Vector2i(4, 15))   # path (4,17) sits beside it
	var net := NavigationRegistry.get_network()
	assert_not_null(net)
	var aid := AgentPool.spawn(&"visitor", Vector2(0, 17))
	var off_path_ticks := 0
	for i in range(1000):
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


func test_disconnected_exhibit_detection() -> void:
	# The HUD flags a populated exhibit when no gate-reachable path cell can
	# see it. This exercises that exact query (NavigationRegistry.nearest with
	# the engagement-distance predicate).
	for y in range(0, 4):
		EntityRegistry.place(&"path", Vector2i(0, y))
	var net := NavigationRegistry.get_network()
	# Exhibit beside the path → within viewing distance → connected.
	EntityRegistry.place(&"grass_patch", Vector2i(1, 1))
	EntityRegistry.place(&"grass_patch", Vector2i(1, 2))
	var near := RegionRegistry.region_at_cell(Vector2i(1, 1))
	# Exhibit far from any path → no path access.
	EntityRegistry.place(&"grass_patch", Vector2i(25, 25))
	EntityRegistry.place(&"grass_patch", Vector2i(25, 26))
	var far := RegionRegistry.region_at_cell(Vector2i(25, 25))
	var d := 10
	var near_cell := NavigationRegistry.nearest(Vector2i(0, 0), func(c: Vector2i) -> bool:
		return net.within_engagement_distance(c, near.cells, d))
	var far_cell := NavigationRegistry.nearest(Vector2i(0, 0), func(c: Vector2i) -> bool:
		return net.within_engagement_distance(c, far.cells, d))
	assert_ne(near_cell, INetworkNavigator.NO_STEP, "exhibit beside the path is reachable")
	assert_eq(far_cell, INetworkNavigator.NO_STEP, "far exhibit has no path access")


func test_welfare_kills_a_neglected_animal() -> void:
	# A cramped lion with no food/water troughs has poor care quality, so its
	# welfare declines day over day until it dies and is removed.
	EntityRegistry.place(&"grass_patch", Vector2i(0, 0))
	EntityRegistry.place(&"grass_patch", Vector2i(1, 0))
	EntityRegistry.place(&"rock_patch", Vector2i(2, 0))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(RegionRegistry.add_placement(region.region_id, &"lion"))
	var died := false
	for day in range(40):
		ZooBootstrap._on_day_ending_for_welfare(day)
		if region.placements.is_empty():
			died = true
			break
	assert_true(died, "a neglected animal eventually dies of poor welfare")


func test_welfare_recovers_under_good_care() -> void:
	# A genuinely well-kept lion recovers welfare and isn't sick. "Well-kept"
	# now includes the habitat axes (design/tuning/habitat.md): right terrain
	# mix, a companion, foliage, rocks, and a shelter — a bare cramped pen no
	# longer counts as good care (see tests/test_habitat.gd).
	for y in range(4):
		for x in range(5):
			if y == 3 and x >= 2:
				EntityRegistry.place(&"rock_patch", Vector2i(x, y))
			else:
				EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	RegionRegistry.add_placement(region.region_id, &"acacia_tree")
	RegionRegistry.add_placement(region.region_id, &"acacia_tree")
	RegionRegistry.add_placement(region.region_id, &"rock_small")
	RegionRegistry.add_placement(region.region_id, &"wood_shelter")
	region.placements[0].state["welfare"] = 0.4   # start ailing
	for day in range(8):
		ZooBootstrap._on_day_ending_for_welfare(day)
	assert_gt(float(region.placements[0].state["welfare"]), 0.9, "good care restores welfare")
	assert_false(bool(region.placements[0].state.get("sick", false)), "recovered animal isn't sick")


func test_welfare_scales_appeal() -> void:
	# A neglected animal draws fewer guests: welfare scales the appeal the
	# engine consumes, while care_quality (the welfare driver) does not.
	for x in range(0, 3):
		for y in range(0, 2):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 2))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	var model := ZooBootstrap.get_happiness_model()
	var care := model.care_quality(region, 0)
	region.placements[0].state["welfare"] = 0.5
	assert_almost_eq(model.compute_happiness(region, 0), care * 0.5, 0.001,
		"welfare halves the appeal the engine sees")


func _count_species(region: Region, species: StringName) -> int:
	var n := 0
	for p in region.placements:
		if p.placeable_def_id == species:
			n += 1
	return n


func test_breeding_produces_offspring() -> void:
	# A roomy exhibit with two well-kept adult lions produces offspring.
	for x in range(0, 4):
		for y in range(0, 4):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 4))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	for p in region.placements:
		if p.placeable_def_id == &"lion":
			p.state["age_days"] = 5
			p.state["welfare"] = 1.0
	var before := _count_species(region, &"lion")
	for day in range(40):
		ZooBootstrap._on_day_ending_for_breeding(day)
	assert_gt(_count_species(region, &"lion"), before, "well-kept lion pair breeds")


func test_no_breeding_with_a_single_animal() -> void:
	for x in range(0, 3):
		for y in range(0, 2):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 2))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	region.placements[0].state["age_days"] = 5
	region.placements[0].state["welfare"] = 1.0
	for day in range(40):
		ZooBootstrap._on_day_ending_for_breeding(day)
	assert_eq(_count_species(region, &"lion"), 1, "a lone animal can't breed")


func test_animal_dies_of_old_age() -> void:
	for x in range(0, 3):
		for y in range(0, 2):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 2))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	region.placements[0].state["age_days"] = ZooBootstrap.breeding.max_age_days
	ZooBootstrap._on_day_ending_for_breeding(0)
	assert_eq(_count_species(region, &"lion"), 0, "an animal past its lifespan dies")


func test_opening_hours_gate_arrivals() -> void:
	# Guests arrive during opening hours and stop arriving after closing.
	SimClock.current_tick = 0
	assert_true(ZooBootstrap.is_within_open_hours(), "open at the start of the day")
	ZooBootstrap._apply_spawn_rate()
	assert_gt(AgentPool.base_spawn_rate, 0.0, "guests arrive while open")
	SimClock.current_tick = int(SimClock.ticks_per_day * 0.9)   # past open_end 0.80
	assert_false(ZooBootstrap.is_within_open_hours(), "closed in the evening")
	ZooBootstrap._apply_spawn_rate()
	assert_eq(AgentPool.base_spawn_rate, 0.0, "no new arrivals after closing")
	# Restore a known clock + gate for later tests.
	SimClock.current_tick = 0
	ZooBootstrap.set_ticket_bracket(&"standard")


func test_keepers_maintain_welfare_and_cost_wages() -> void:
	# Hiring keepers keeps an otherwise-neglected animal alive (welfare bonus),
	# and charges wages each day.
	EntityRegistry.place(&"grass_patch", Vector2i(0, 0))
	EntityRegistry.place(&"grass_patch", Vector2i(1, 0))
	EntityRegistry.place(&"rock_patch", Vector2i(2, 0))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")   # cramped, no troughs
	ZooBootstrap.set_hired_keepers(3)
	var pre := Ledger.get_balance()
	# Run the same number of days that killed the unkept lion; with keepers it
	# survives.
	for day in range(40):
		ZooBootstrap._on_day_ending_for_welfare(day)
		if region.placements.is_empty():
			break
	assert_false(region.placements.is_empty(), "keepers keep a neglected animal alive")
	assert_lt(Ledger.get_balance(), pre, "keeper wages are charged daily")
	ZooBootstrap.set_hired_keepers(0)


func test_keeper_headcount_is_capped() -> void:
	ZooBootstrap.set_hired_keepers(9999)
	assert_eq(ZooBootstrap.hired_keepers, ZooBootstrap.staff.max_keepers,
		"headcount is capped at max_keepers")
	ZooBootstrap.set_hired_keepers(0)


func test_weather_and_seasons_loaded() -> void:
	var wc := WeatherConfig.load_from_tuning()
	assert_eq(wc.seasons.size(), 4, "four seasons")
	assert_eq(wc.weathers.size(), 3, "three weather states")
	# Seasons cycle by day.
	assert_eq(wc.season_for_day(0)["id"], &"spring", "day 0 is spring")
	assert_eq(wc.season_for_day(wc.days_per_season)["id"], &"summer", "next block is summer")
	# Rainy thins the crowd vs sunny.
	assert_lt(float(wc.weather_by_id(&"rainy")["mult"]),
		float(wc.weather_by_id(&"sunny")["mult"]), "rain < sun for demand")


func test_environment_multiplier_scales_spawn() -> void:
	# Weather × season feeds into the gate spawn rate.
	SimClock.current_tick = 0
	SimClock.current_day = 0   # spring (1.0)
	ZooBootstrap.current_weather = &"rainy"   # 0.7
	ZooBootstrap._apply_spawn_rate()
	var rainy_rate := AgentPool.base_spawn_rate
	ZooBootstrap.current_weather = &"sunny"   # 1.15
	ZooBootstrap._apply_spawn_rate()
	assert_gt(AgentPool.base_spawn_rate, rainy_rate, "sunny draws more than rainy")
	# Restore a neutral-ish state for later tests.
	ZooBootstrap.current_weather = &"cloudy"
	ZooBootstrap._apply_spawn_rate()


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


func test_playthrough_park_stays_solvent_and_profits() -> void:
	# A full multi-day playthrough of a sensibly-built park, exercising every
	# system at once (paths, needs, donations, welfare, breeding, day/night,
	# weather, staff). Guards against crashes and economic collapse before a
	# playtest. Starts from the real game's opening cash.
	Ledger.reset(ContentDB.balance_config.starting_cash)
	# Path spine: gate down to a concourse.
	for y in range(0, 6):
		EntityRegistry.place(&"path", Vector2i(0, y))
	for x in range(1, 9):
		EntityRegistry.place(&"path", Vector2i(x, 5))
	# A well-built lion exhibit with troughs + a donation box, in view of the path.
	for c in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 3), Vector2i(4, 3)]:
		EntityRegistry.place(&"grass_patch", c)
	EntityRegistry.place(&"rock_patch", Vector2i(5, 3))
	var region := RegionRegistry.region_at_cell(Vector2i(3, 2))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	RegionRegistry.add_placement(region.region_id, &"donation_box")
	# Amenities for all four needs, each beside the concourse.
	EntityRegistry.place(&"food_stand", Vector2i(6, 3))
	EntityRegistry.place(&"drink_stand", Vector2i(2, 4))
	EntityRegistry.place(&"restroom", Vector2i(4, 4))
	EntityRegistry.place(&"bench", Vector2i(1, 4))
	ZooBootstrap.set_hired_keepers(1)

	var pre_run := Ledger.get_balance()
	for i in range(12 * SimClock.ticks_per_day):
		SimClock.advance_tick()

	assert_eq(SimClock.current_day, 12, "twelve days elapsed without a crash")
	assert_gt(Ledger.get_balance(), 0, "park never went bankrupt")
	var revenue := int(Accounting.get_income_statement(0, SimClock.current_day).get("revenue", 0))
	assert_gt(revenue, 0, "the park earned revenue from guests")
	assert_gt(Ledger.get_balance(), pre_run,
		"a well-run park turns a profit over the run (winnability signal)")
	assert_false(region.placements.is_empty(), "the cared-for lion is still alive")
	ZooBootstrap.set_hired_keepers(0)


func test_saveload_round_trips_the_whole_zoo() -> void:
	# The engine doesn't persist region placements or zoo settings and doesn't
	# rebuild regions on load; the zoo's save-state provider fills both gaps.
	# Build a park with animal welfare/age state + zoo settings, save, wipe,
	# load, and assert it all came back — including the cash balance (no
	# double-charge).
	ZooBootstrap.set_difficulty(&"hard")            # opening cash 7000
	ZooBootstrap.set_ticket_bracket(&"premium")
	ZooBootstrap.set_hired_keepers(2)
	ZooBootstrap.set_park_open(false)
	for x in range(0, 3):
		for y in range(0, 2):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(0, 2))
	EntityRegistry.place(&"food_stand", Vector2i(8, 8))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	region.placements[0].state["welfare"] = 0.42
	region.placements[0].state["age_days"] = 7
	var bal_before := Ledger.get_balance()

	SaveService.save_to_slot("rt")
	# Wipe everything to a clean, different state.
	EntityRegistry.reset(); RegionRegistry.reset(); NavigationRegistry.reset(); AgentPool.reset()
	ZooBootstrap.set_hired_keepers(0); ZooBootstrap.set_park_open(true)
	ZooBootstrap.set_ticket_bracket(&"standard")
	Ledger.reset(123)
	SaveService.load_from_slot("rt")

	var r2 := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(r2, "exhibit was rebuilt on load")
	assert_eq(r2.placements.size(), 2, "lion + trough restored")
	var lion_i := -1
	for i in r2.placements.size():
		if r2.placements[i].placeable_def_id == &"lion":
			lion_i = i
	assert_gt(lion_i, -1, "the lion came back")
	assert_almost_eq(float(r2.placements[lion_i].state.get("welfare", 1.0)), 0.42, 0.001,
		"welfare state restored")
	assert_eq(int(r2.placements[lion_i].state.get("age_days", 0)), 7, "age restored")
	assert_eq(ZooBootstrap.hired_keepers, 2, "keepers restored")
	assert_eq(ZooBootstrap.ticket_bracket, &"premium", "ticket bracket restored")
	assert_false(ZooBootstrap.park_open, "park open/closed restored")
	assert_eq(ZooBootstrap.scenario.difficulty, &"hard", "difficulty restored")
	assert_eq(Ledger.get_balance(), bal_before, "cash balance preserved (no double-charge)")

	SaveService.delete_slot("rt")
	# Restore defaults for any later tests.
	ZooBootstrap.set_difficulty(&"standard")
	ZooBootstrap.set_park_open(true)
	ZooBootstrap.set_ticket_bracket(&"standard")
	ZooBootstrap.set_hired_keepers(0)


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


