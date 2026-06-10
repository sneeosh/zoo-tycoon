extends GutTest
# Habitat axes — the ZT1 exhibit-authoring layer.
# Data: design/tuning/habitat.md (+ the habitat/enrichment placeables in
# placeables.md). Model: the habitat extension in
# src/models/zoo_animal_happiness.gd. The legacy space/social/needs rows in
# design/algorithms/animal_happiness.md are untouched by these axes (they
# only fire for species with a habitat entry, which all shipped animals
# have — these tests pin down both the penalties and the payoff).


func before_each() -> void:
	SaveService.autosave_enabled = false
	Ledger.reset(50000)
	EntityRegistry.reset()
	RegionRegistry.reset()
	NavigationRegistry.reset()
	AgentPool.reset()
	ZooBootstrap.get_happiness_model().clear_terrain_cache()


# A 20-cell pen matching the lion's terrain mix: 17 grass (0.85 ≥ 0.75
# wanted) + 3 rock (0.15 ≥ 0.15 wanted), so the terrain axis scores clean
# and the dressing axes can be tested in isolation.
func _build_lion_pen() -> Region:
	for y in range(4):
		for x in range(5):
			if y == 3 and x >= 2:
				EntityRegistry.place(&"rock_patch", Vector2i(x, y))
			else:
				EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	var region := RegionRegistry.region_at_cell(Vector2i(0, 0))
	assert_not_null(region, "zone tiles form a region")
	# Two lions (social_min 1 satisfied) + both troughs (needs satisfied).
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	return region


func test_habitat_config_loaded() -> void:
	assert_not_null(ZooBootstrap.habitat, "habitat tuning loads at bootstrap")
	assert_true(ZooBootstrap.habitat.has_prefs(&"lion"), "lion has habitat prefs")
	assert_true(ZooBootstrap.habitat.has_prefs(&"polar_bear"))
	var lion: Dictionary = ZooBootstrap.habitat.prefs(&"lion")
	assert_almost_eq(float(lion["terrain_mix"][&"grass"]), 0.75, 0.001)
	assert_true(bool(lion["wants_shelter"]))


func test_bare_pen_pays_habitat_penalties() -> void:
	var region := _build_lion_pen()
	var b: Dictionary = ZooBootstrap.get_happiness_model().compute_breakdown(region, 0)
	assert_almost_eq(float(b["terrain"]), 0.0, 0.001,
		"terrain mix matches the species — no terrain penalty")
	assert_almost_eq(float(b["space"]), 0.0, 0.001, "20 cells / 4 occupants is ample")
	assert_almost_eq(float(b["social"]), 0.0, 0.001)
	assert_almost_eq(float(b["needs"]), 0.0, 0.001)
	# But the pen is bare: no foliage, no rocks placed, no shelter.
	assert_gt(float(b["foliage"]), 0.0, "bare pen: foliage shortfall")
	assert_gt(float(b["rocks"]), 0.0, "bare pen: rock shortfall")
	assert_almost_eq(float(b["shelter"]), ZooBootstrap.habitat.shelter_weight, 0.001,
		"lion wants a shelter")
	assert_almost_eq(float(b["enrichment"]), 0.0, 0.001, "lions don't need toys")


func test_dressing_the_pen_raises_happiness() -> void:
	var region := _build_lion_pen()
	var model := ZooBootstrap.get_happiness_model()
	var bare: float = model.compute_breakdown(region, 0)["happiness"]
	# Author the exhibit the ZT1 way: preferred foliage, a rock, a shelter.
	RegionRegistry.add_placement(region.region_id, &"acacia_tree")
	RegionRegistry.add_placement(region.region_id, &"acacia_tree")
	RegionRegistry.add_placement(region.region_id, &"rock_small")
	RegionRegistry.add_placement(region.region_id, &"wood_shelter")
	var b: Dictionary = model.compute_breakdown(region, 0)
	assert_almost_eq(float(b["foliage"]), 0.0, 0.001, "2 acacias hit the 10% target")
	assert_almost_eq(float(b["rocks"]), 0.0, 0.001, "one rock hits the 4% target")
	assert_almost_eq(float(b["shelter"]), 0.0, 0.001, "shelter present")
	assert_gt(float(b["happiness"]), bare, "a dressed pen beats a bare one")


func test_offtype_foliage_counts_partially() -> void:
	var region := _build_lion_pen()
	var model := ZooBootstrap.get_happiness_model()
	# Lion prefers plant_savannah; pines are conifers → half credit each.
	RegionRegistry.add_placement(region.region_id, &"pine_tree")
	RegionRegistry.add_placement(region.region_id, &"pine_tree")
	var b: Dictionary = model.compute_breakdown(region, 0)
	assert_almost_eq(float(b["foliage_have"]), 1.0, 0.001,
		"2 off-type plants at 0.5 credit = 1.0 of the 2 needed")
	assert_gt(float(b["foliage"]), 0.0, "still short of the target")


func test_dressing_never_crowds_the_animals() -> void:
	var region := _build_lion_pen()
	var model := ZooBootstrap.get_happiness_model()
	var before: float = model.compute_breakdown(region, 0)["space"]
	for i in range(5):
		RegionRegistry.add_placement(region.region_id, &"shrub")
	var after: float = model.compute_breakdown(region, 0)["space"]
	assert_almost_eq(after, before, 0.0001,
		"space_required-0 dressing must not raise the space penalty")


func test_playful_species_want_a_toy() -> void:
	for y in range(4):
		for x in range(5):
			if x < 4:
				EntityRegistry.place(&"grass_patch", Vector2i(x + 10, y))
			else:
				EntityRegistry.place(&"water_patch", Vector2i(x + 10, y))
	var region := RegionRegistry.region_at_cell(Vector2i(10, 0))
	assert_not_null(region)
	RegionRegistry.add_placement(region.region_id, &"elephant")
	RegionRegistry.add_placement(region.region_id, &"elephant")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	var model := ZooBootstrap.get_happiness_model()
	var b: Dictionary = model.compute_breakdown(region, 0)
	assert_almost_eq(float(b["enrichment"]), ZooBootstrap.habitat.enrichment_weight,
		0.001, "bored elephant pays the enrichment penalty")
	RegionRegistry.add_placement(region.region_id, &"toy_ball")
	b = model.compute_breakdown(region, 0)
	assert_almost_eq(float(b["enrichment"]), 0.0, 0.001, "toy fixes it")
	assert_true(bool(b["has_toy"]))


func test_terrain_cache_invalidates_on_world_change() -> void:
	var region := _build_lion_pen()
	var model := ZooBootstrap.get_happiness_model()
	var b1: Dictionary = model.compute_breakdown(region, 0)
	assert_almost_eq(float(b1["terrain"]), 0.0, 0.001)
	# Extend the pen with 8 more grass cells — rocks fraction drops below
	# the lion's 15% want; the cached composition must not mask it.
	for x in range(5, 9):
		for y in range(2):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	var grown := RegionRegistry.region_at_cell(Vector2i(0, 0))
	var b2: Dictionary = model.compute_breakdown(grown, 0)
	assert_gt(float(b2["terrain"]), 0.0,
		"diluted rock fraction is picked up after the region changes")
