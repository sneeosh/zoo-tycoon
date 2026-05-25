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
	var visitor: AgentType = ContentDB.get_agent_type(&"visitor")
	assert_not_null(visitor)
	assert_eq(visitor.needs.size(), 1, "trivial: one hunger need")
	assert_eq(visitor.needs[0].need.id, &"hunger")


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

	# Drive ticks. hunger threshold = 0.4, decay = 0.005/tick → crosses
	# at tick ~121. Then behavior heads to food stand (~5 tiles away,
	# 0.15/tick → ~34 ticks). After eating, hunger decays again. We
	# can't snapshot hunger==1.0 at an arbitrary end-tick — check the
	# transaction log for the food purchase instead.
	for i in range(200):
		SimClock.advance_tick()

	var has_food_purchase := false
	for tx: Dictionary in Ledger.transactions:
		if tx["label"] == "Food":
			has_food_purchase = true
			break
	assert_true(has_food_purchase, "visitor reached food stand and posted a food purchase")
	assert_gt(Ledger.get_balance(), post_entry, "food purchase added income")


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


