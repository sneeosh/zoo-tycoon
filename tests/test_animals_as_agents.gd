extends GutTest
# Animals as agents (roadmap 6.6 / design/animals_as_agents_spec.md §8).
# An animal Placement is now bound 1:1 to a free-roaming `animal` Agent. These
# cover the lifecycle binding, enclosure containment, trough feeding, the
# spawn-curve isolation seam (drives_spawn_balance), and save/load round-trip.


func before_each() -> void:
	SaveService.autosave_enabled = false
	Ledger.reset(20000)
	# NOTE: deliberately NOT calling Accounting.reset() — it clears the global
	# REVENUE category registrations that ZooBootstrap sets once at _ready and
	# never re-registers, which would break later files' income-statement
	# assertions. These tests don't touch the income statement, so they don't
	# need it. (See the test_zoo_integration playthrough.)
	EntityRegistry.reset()
	RegionRegistry.reset()
	NavigationRegistry.reset()
	AgentPool.reset()
	SimClock.current_tick = 0
	SimClock.current_day = 0
	SimClock.set_seed(99)
	ZooBootstrap.set_park_open(false)
	ProgressionManager.set_reputation(0)
	ZooBootstrap.set_zoo_type(ZooBootstrap.zoo_types.default_plot, false)
	ZooBootstrap.reconcile_animals()   # clear any animals left from a prior test


# A 4-cell grass+rock enclosure: lion needs grass,rocks + 3 space, leaving
# room for a 1-space trough.
func _lion_enclosure() -> Region:
	EntityRegistry.place(&"grass_patch", Vector2i(2, 2))
	EntityRegistry.place(&"grass_patch", Vector2i(3, 2))
	EntityRegistry.place(&"rock_patch", Vector2i(4, 2))
	EntityRegistry.place(&"rock_patch", Vector2i(5, 2))
	return RegionRegistry.region_at_cell(Vector2i(2, 2))


func _animal_ids() -> Array:
	return AgentPool.get_agents_by_type(&"animal")


func test_animal_type_excluded_from_spawn_balance() -> void:
	var at: AgentType = ContentDB.get_agent_type(&"animal")
	assert_not_null(at, "the animal AgentType is defined")
	assert_eq(at.spawn_weight, 0.0, "animals are never auto-spawned by the visitor loop")
	assert_false(at.drives_spawn_balance, "animal welfare must not feed the spawn curve")


func test_placing_an_animal_spawns_exactly_one_agent() -> void:
	var region := _lion_enclosure()
	assert_eq(_animal_ids().size(), 0)
	var p := RegionRegistry.add_placement(region.region_id, &"lion")
	assert_not_null(p)
	assert_eq(_animal_ids().size(), 1, "one placement → one animal agent")
	# The placement is bound to that agent.
	var aid := int(p.state.get("agent_id", 0))
	assert_eq(aid, _animal_ids()[0])


func test_removing_an_animal_despawns_its_agent() -> void:
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	assert_eq(_animal_ids().size(), 1)
	RegionRegistry.remove_placement(region.region_id, 0)
	assert_eq(_animal_ids().size(), 0, "removing the placement despawns its agent")


func test_animal_stays_inside_its_enclosure() -> void:
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	var agent: Agent = AgentPool.get_agent(_animal_ids()[0])
	var cells := {}
	for c in region.cells:
		cells[c] = true
	for i in 400:
		ZooBootstrap._animal_behavior.on_tick(agent)
		var cell := Vector2i(floori(agent.position.x), floori(agent.position.y))
		assert_true(cells.has(cell), "tick %d: animal left its enclosure at %s" % [i, agent.position])


func test_hungry_animal_walks_to_the_trough_and_eats() -> void:
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	var agent: Agent = AgentPool.get_agent(_animal_ids()[0])
	agent.need_levels[&"food"] = 0.1
	agent.seeking_need = &"food"
	for i in 600:
		ZooBootstrap._animal_behavior.on_tick(agent)
	assert_gt(float(agent.need_levels[&"food"]), 0.5,
		"a hungry animal should reach the trough and refill food")


func test_hungry_animal_without_a_trough_stays_hungry() -> void:
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	var agent: Agent = AgentPool.get_agent(_animal_ids()[0])
	agent.need_levels[&"food"] = 0.1
	agent.seeking_need = &"food"
	for i in 300:
		ZooBootstrap._animal_behavior.on_tick(agent)
	assert_lt(float(agent.need_levels[&"food"]), 0.45,
		"no trough in the enclosure → food cannot recover")


func test_miserable_animal_does_not_drag_the_spawn_curve() -> void:
	# The seam end-to-end: a happy visitor and a miserable animal; the
	# aggregate that drives arrivals must reflect the visitor only.
	var vid := AgentPool.spawn(&"visitor", Vector2(1, 1))
	AgentPool.get_agent(vid).satisfaction = 0.8
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	AgentPool.get_agent(_animal_ids()[0]).satisfaction = 0.05
	assert_almost_eq(AgentPool.compute_aggregate_satisfaction(), 0.8, 0.001)


func test_save_load_round_trips_animal_roam_state() -> void:
	var region := _lion_enclosure()
	RegionRegistry.add_placement(region.region_id, &"lion")
	var agent: Agent = AgentPool.get_agent(_animal_ids()[0])
	agent.position = Vector2(3.3, 2.4)
	agent.need_levels[&"food"] = 0.42
	assert_true(SaveService.save_to_slot("test_animals"))
	# Scramble live state, then load.
	agent.position = Vector2(0, 0)
	assert_true(SaveService.load_from_slot("test_animals"))
	assert_eq(_animal_ids().size(), 1, "exactly one animal after load")
	var restored: Agent = AgentPool.get_agent(_animal_ids()[0])
	assert_almost_eq(restored.position.x, 3.3, 0.001)
	assert_almost_eq(restored.position.y, 2.4, 0.001)
	assert_almost_eq(float(restored.need_levels[&"food"]), 0.42, 0.001)
