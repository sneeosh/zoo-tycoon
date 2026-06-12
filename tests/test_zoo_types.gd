extends GutTest
# Zoo types — land plots, climates, purchase and sell-to-relocate.
#
# Covers design/tuning/zoo_types.md (compiled by src/zoo_type_config.gd) and
# the ZooBootstrap land logic: buying a plot at game start, the climate's
# weather bias, and selling the whole zoo to fund a move to different land.


func before_each() -> void:
	SaveService.autosave_enabled = false
	Ledger.reset(10000)
	Accounting.reset()
	EntityRegistry.reset()
	RegionRegistry.reset()
	NavigationRegistry.reset()
	AgentPool.reset()
	SimClock.current_tick = 0
	SimClock.current_day = 0
	SimClock.current_period = 0
	SimClock.set_seed(1234)
	ZooBootstrap.set_park_open(false)
	ProgressionManager.set_reputation(0)
	ZooBootstrap.departures_happy = 0
	ZooBootstrap.departures_unhappy = 0
	ZooBootstrap.departures_total = 0
	ZooBootstrap.unhappy_need_counts.clear()
	# Land state is autoload-persistent — start every test on the default plot.
	ZooBootstrap.set_zoo_type(ZooBootstrap.zoo_types.default_plot, false)


func after_each() -> void:
	# Don't leak a relocated plot into the other suites (the integration arc
	# tests regression-test winnability on the default plot's climate).
	ZooBootstrap.set_zoo_type(ZooBootstrap.zoo_types.default_plot, false)


# --- Tuning loads -----------------------------------------------------------

func test_zoo_types_tuning_loaded() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	assert_not_null(zt)
	assert_true(zt.plots.size() >= 2, "need at least two plots to trade between")
	assert_ne(zt.default_plot, &"", "a default plot must exist")
	assert_eq(int(zt.plot(zt.default_plot)["cost"]), 0,
		"the default plot must be free — it's what old saves and the canonical Standard run sit on")
	for plot in zt.plots:
		var size: Vector2i = plot["size"]
		assert_true(size.x >= ZooTypeConfig.MIN_PLOT_W and size.y >= ZooTypeConfig.MIN_PLOT_H,
			"plot %s must fit the starter park" % plot["id"])
		assert_false(zt.climate(plot["climate"]).is_empty(),
			"plot %s must name a known climate" % plot["id"])


func test_plots_differ_in_climate_size_and_cost() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	var climates := {}
	var sizes := {}
	var costs := {}
	for plot in zt.plots:
		climates[plot["climate"]] = true
		sizes[plot["size"]] = true
		costs[int(plot["cost"])] = true
	assert_true(climates.size() >= 2, "plots should span multiple climates")
	assert_true(sizes.size() >= 2, "plots should span multiple land sizes")
	assert_true(costs.size() >= 2, "plots should span multiple prices")


# --- Selection, gate, and purchase -------------------------------------------

func test_set_zoo_type_charges_land_cost() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	var paid: Dictionary = {}
	for plot in zt.plots:
		if int(plot["cost"]) > 0:
			paid = plot
			break
	assert_false(paid.is_empty(), "need a non-free plot to test the purchase")
	var before := Ledger.get_balance()
	assert_true(ZooBootstrap.set_zoo_type(paid["id"], true))
	assert_eq(Ledger.get_balance(), before - int(paid["cost"]))
	assert_eq(ZooBootstrap.current_zoo_type, paid["id"])
	assert_eq(ZooBootstrap.plot_size(), paid["size"])


func test_gate_sits_on_bottom_row_of_plot() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	for plot in zt.plots:
		ZooBootstrap.set_zoo_type(plot["id"], false)
		assert_eq(ZooBootstrap.gate_cell(),
			Vector2i(0, (plot["size"] as Vector2i).y - 1),
			"gate must hug the bottom-left corner of %s" % plot["id"])


func test_unknown_zoo_type_rejected() -> void:
	var before := ZooBootstrap.current_zoo_type
	assert_false(ZooBootstrap.set_zoo_type(&"atlantis", true))
	assert_eq(ZooBootstrap.current_zoo_type, before)


# --- Climate biases the weather roll -----------------------------------------

func test_climate_weather_weights_bias_the_roll() -> void:
	var wc: WeatherConfig = ZooBootstrap.weather_cfg
	assert_false(wc.weathers.is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Zeroing every weight but one forces the roll deterministically.
	var only_rainy := {}
	for wx in wc.weathers:
		only_rainy[wx["id"]] = 1.0 if wx["id"] == &"rainy" else 0.0
	for _i in 20:
		assert_eq(wc.pick_weather(rng, only_rainy), &"rainy")


func test_starter_park_stages_on_every_plot() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	for plot in zt.plots:
		EntityRegistry.reset()
		RegionRegistry.reset()
		NavigationRegistry.reset()
		AgentPool.reset()
		Ledger.reset(10000)
		ZooBootstrap.set_zoo_type(plot["id"], false)
		StarterPark.stage()
		# Both exhibits must exist and the path spine must reach the gate.
		assert_true(RegionRegistry.all_regions().size() >= 2,
			"starter park staged short on %s" % plot["id"])
		var net: WalkableNetwork = NavigationRegistry.get_network()
		assert_true(net != null and net.has_cell(ZooBootstrap.gate_cell()),
			"path spine must reach the gate on %s" % plot["id"])


# --- Selling up & relocating --------------------------------------------------

func test_sale_value_counts_land_buildings_and_animals() -> void:
	EntityRegistry.place(&"grass_patch", Vector2i(2, 2))
	EntityRegistry.place(&"grass_patch", Vector2i(3, 2))
	var region := RegionRegistry.region_at_cell(Vector2i(2, 2))
	RegionRegistry.add_placement(region.region_id, &"lion")
	var sale := ZooBootstrap.zoo_sale_value()
	assert_eq(int(sale["land"]), 0, "default plot is free, so land resale is $0")
	# Two grass tiles at refund_fraction plus half a lion.
	var grass: EntityDef = ContentDB.get_entity_def(&"grass_patch")
	var lion: PlaceableDef = ContentDB.placeable_defs[&"lion"]
	var expected: int = 2 * int(grass.build_cost * EntityRegistry.refund_fraction) \
		+ int(lion.build_cost * 0.5)
	assert_eq(int(sale["assets"]), expected)
	assert_eq(int(sale["total"]), int(sale["land"]) + int(sale["assets"]))


func test_relocate_sells_everything_and_buys_new_land() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	var dest: Dictionary = {}
	for plot in zt.plots:
		if plot["id"] != ZooBootstrap.current_zoo_type:
			dest = plot
			break
	assert_false(dest.is_empty())
	# A small park to liquidate.
	EntityRegistry.place(&"grass_patch", Vector2i(2, 2))
	EntityRegistry.place(&"grass_patch", Vector2i(3, 2))
	EntityRegistry.place(&"path", Vector2i(2, 4))
	var region := RegionRegistry.region_at_cell(Vector2i(2, 2))
	RegionRegistry.add_placement(region.region_id, &"lion")
	AgentPool.spawn(&"visitor", Vector2(2, 4))
	var rep_before := ProgressionManager.reputation
	var happy_before := ZooBootstrap.departures_happy
	var unhappy_before := ZooBootstrap.departures_unhappy
	var total_before := ZooBootstrap.departures_total
	var balance_before := Ledger.get_balance()
	var sale := ZooBootstrap.zoo_sale_value()

	assert_true(ZooBootstrap.relocate_zoo(dest["id"]))

	# Books: old zoo liquidated at the estimate, new land paid for.
	assert_eq(Ledger.get_balance(),
		balance_before + int(sale["total"]) - int(dest["cost"]),
		"sale estimate must match the posted refunds exactly")
	# World: empty plot of the new size, crowd gone, park closed.
	assert_eq(EntityRegistry.instances.size(), 0)
	assert_eq(RegionRegistry.all_regions().size(), 0)
	assert_eq(AgentPool.alive_count(), 0)
	assert_eq(ZooBootstrap.current_zoo_type, dest["id"])
	assert_eq(ZooBootstrap.plot_size(), dest["size"])
	assert_false(ZooBootstrap.park_open)
	# Moving isn't a review event — reputation and the day's verdict untouched.
	assert_eq(ProgressionManager.reputation, rep_before)
	assert_eq(ZooBootstrap.departures_happy, happy_before)
	assert_eq(ZooBootstrap.departures_unhappy, unhappy_before)
	assert_eq(ZooBootstrap.departures_total, total_before)


func test_relocate_blocked_when_unaffordable() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	var priciest: Dictionary = {}
	for plot in zt.plots:
		if priciest.is_empty() or int(plot["cost"]) > int(priciest["cost"]):
			priciest = plot
	if int(priciest["cost"]) == 0:
		pass_test("no paid plots configured")
		return
	Ledger.reset(0)   # broke, empty zoo: sale proceeds are $0
	assert_false(ZooBootstrap.relocate_zoo(priciest["id"]))
	assert_eq(ZooBootstrap.current_zoo_type, zt.default_plot)


func test_relocate_to_current_plot_rejected() -> void:
	assert_false(ZooBootstrap.relocate_zoo(ZooBootstrap.current_zoo_type))


# --- Persistence ---------------------------------------------------------------

func test_save_payload_carries_zoo_type() -> void:
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	var paid: Dictionary = {}
	for plot in zt.plots:
		if int(plot["cost"]) > 0:
			paid = plot
			break
	ZooBootstrap.set_zoo_type(paid["id"], false)
	var payload: Dictionary = ZooBootstrap._save_game_state()
	assert_eq(payload["zoo_type"], String(paid["id"]))
	assert_eq(int(payload["version"]), ZooBootstrap.SAVE_VERSION)
	# An old (pre-v3) payload restores onto the default plot.
	ZooBootstrap._load_game_state({"version": 2, "exhibits": []})
	assert_eq(ZooBootstrap.current_zoo_type, zt.default_plot)
