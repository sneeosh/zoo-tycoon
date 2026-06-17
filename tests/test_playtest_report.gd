extends GutTest
# Automated balance playtest (roadmap 5.2 is the *human* version — this is the
# Fable-style end-to-end run it complements). Drives full 30-day Standard games
# with every system live (paths, needs, donations, welfare, breeding, weather,
# AND the new 6.9 layer: events, contracts, finance, scenarios), opted into
# telemetry, and prints a report: the cash/reputation trajectory, win/lose
# verdict, and how often the 6.9 systems fired. Two parks — a minimal one and a
# well-built one — so balance findings can be told apart from setup artifacts.
# Asserts only "ran the scenario, never bankrupt"; the balance read is printed.


func before_each() -> void:
	SaveService.autosave_enabled = false
	_reset_world()


# Reset every stateful autoload to a clean new-game world (the engine ones the
# app's Replay does, plus the zoo-side 6.9 state), so each scenario runs in
# isolation and is reproducible.
# Note: deliberately does NOT call Accounting.reset() — that clears the
# REVENUE/EXPENSE category registrations ZooBootstrap._ready set up, which never
# re-runs in a test session, so wiping them would make every later test see
# revenue=0. The income statement carrying across the three runs only softens
# the (informational) revenue diag line; the headline metrics each reset.
func after_all() -> void:
	_reset_world()
	ZooBootstrap.set_park_open(false)


func _reset_world() -> void:
	Ledger.reset(ContentDB.balance_config.starting_cash)
	ProgressionManager.reset()
	EntityRegistry.reset()
	RegionRegistry.reset()
	NavigationRegistry.reset()
	AgentPool.reset()
	SimClock.current_tick = 0
	SimClock.current_day = 0
	SimClock.current_period = 0
	SimClock.rng.seed = SimClock.DEFAULT_SEED
	ProgressionManager.force_unlock(&"start")
	# Zoo-side 6.9 state that also persists on the ZooBootstrap autoload.
	ZooBootstrap.active_events.clear()
	ZooBootstrap.last_event_day = -9999
	ZooBootstrap._event_rng.seed = 0x2007E
	ZooBootstrap.completed_contracts.clear()
	ZooBootstrap.active_contracts.clear()
	ZooBootstrap._run_births = 0
	ZooBootstrap._refill_contracts()
	ZooBootstrap.loan_days_left = 0
	ZooBootstrap.sponsor_days_left = 0
	ZooBootstrap.donations_by_region.clear()
	ZooBootstrap.departures_happy = 0
	ZooBootstrap.departures_unhappy = 0
	ZooBootstrap.departures_total = 0


func test_minimal_park_playthrough_report() -> void:
	ZooBootstrap.set_difficulty(&"standard")
	# One small exhibit, one of each amenity — a thin starter build.
	for y in range(0, 6):
		EntityRegistry.place(&"path", Vector2i(0, y))
	for x in range(1, 9):
		EntityRegistry.place(&"path", Vector2i(x, 5))
	for c in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 3), Vector2i(4, 3)]:
		EntityRegistry.place(&"grass_patch", c)
	EntityRegistry.place(&"rock_patch", Vector2i(5, 3))
	var region := RegionRegistry.region_at_cell(Vector2i(3, 2))
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"lion")
	RegionRegistry.add_placement(region.region_id, &"feeding_trough")
	RegionRegistry.add_placement(region.region_id, &"water_trough")
	RegionRegistry.add_placement(region.region_id, &"donation_box")
	EntityRegistry.place(&"food_stand", Vector2i(6, 3))
	EntityRegistry.place(&"drink_stand", Vector2i(2, 4))
	EntityRegistry.place(&"restroom", Vector2i(4, 4))
	EntityRegistry.place(&"bench", Vector2i(1, 4))
	ZooBootstrap.set_hired_keepers(1)
	ZooBootstrap.set_park_open(true)
	_play_and_report("MINIMAL PARK (1 exhibit, 1/1/1/1 amenities, 1 keeper)")


func test_well_built_park_playthrough_report() -> void:
	ZooBootstrap.set_difficulty(&"standard")
	# Concourse.
	for x in range(0, 25):
		EntityRegistry.place(&"path", Vector2i(x, 4))
	# Four roomy grass exhibits (4x2, separated so each is its own region).
	# A lone lion gets its own pen (predator/prey can't share a region).
	var anchors := [Vector2i(1, 1), Vector2i(7, 1), Vector2i(13, 1), Vector2i(19, 1)]
	for a in anchors:
		for dx in range(0, 4):
			for dy in range(0, 2):
				EntityRegistry.place(&"grass_patch", a + Vector2i(dx, dy))
	var plans := [
		{"a": anchors[0], "species": [&"peacock", &"peacock"]},
		{"a": anchors[1], "species": [&"zebra", &"zebra"]},
		{"a": anchors[2], "species": [&"giraffe"]},
		{"a": anchors[3], "species": [&"lion"]},
	]
	for p in plans:
		var reg := RegionRegistry.region_at_cell(p["a"])
		for sp in p["species"]:
			RegionRegistry.add_placement(reg.region_id, sp)
		RegionRegistry.add_placement(reg.region_id, &"feeding_trough")
		RegionRegistry.add_placement(reg.region_id, &"water_trough")
		RegionRegistry.add_placement(reg.region_id, &"donation_box")
	# Heavy amenities along the concourse for the bigger crowd.
	for x in [3, 10, 17]:
		EntityRegistry.place(&"food_stand", Vector2i(x, 3))
	for x in [5, 12, 20]:
		EntityRegistry.place(&"drink_stand", Vector2i(x, 3))
	for x in [7, 15]:
		EntityRegistry.place(&"restroom", Vector2i(x, 3))
	for x in [2, 11, 22]:
		EntityRegistry.place(&"bench", Vector2i(x, 3))
	ZooBootstrap.set_hired_keepers(3)
	ZooBootstrap.set_park_open(true)
	_play_and_report("WELL-BUILT PARK (4 exhibits, 6 animals/4 species, 3/3/2/3 amenities, 3 keepers)")


func test_shipped_starter_park_playthrough_report() -> void:
	# The canonical, tuned starter park (src/starter_park.gd) — the layout the
	# winnability regression test locks. This is the control: if THIS can't win
	# on reputation, the 6.9 changes regressed balance; if it can, the hand-built
	# parks above just have bad path/amenity reachability.
	ZooBootstrap.set_difficulty(&"standard")
	StarterPark.stage()
	ZooBootstrap.set_hired_keepers(2)
	ZooBootstrap.set_park_open(true)
	_play_and_report("SHIPPED STARTER PARK (src/starter_park.gd, 2 keepers)")


# Shared driver: run the active scenario day by day with every 6.9 signal
# counted, then print the report.
func _play_and_report(setup: String) -> void:
	Settings.set_value(&"telemetry_opt_in", true)
	var s: Scenario = ZooBootstrap.scenario
	var ev := {"positive": 0, "negative": 0, "neutral": 0}
	var ev_ids: Array = []
	var contracts: Array = []
	var births := [0]
	var deaths := [0]
	var tele := {"n": 0}
	var on_event := func(_id: StringName, _label: String, category: String, _msg: String):
		ev[category] = int(ev.get(category, 0)) + 1
		ev_ids.append(String(_id))
	var on_contract := func(_id: StringName, label: String, _c: int, _r: int):
		contracts.append(label)
	var on_birth := func(_r, _sp, _nm, _rare): births[0] += 1
	var on_welfare := func(_r, _i, kind: String, _nm):
		if kind == "died":
			deaths[0] += 1
	var on_tele := func(_e: StringName, _p: Dictionary): tele["n"] += 1
	ZooBootstrap.park_event.connect(on_event)
	ZooBootstrap.contract_completed.connect(on_contract)
	ZooBootstrap.animal_born.connect(on_birth)
	ZooBootstrap.animal_welfare_alert.connect(on_welfare)
	Telemetry.event_recorded.connect(on_tele)

	var start_cash := Ledger.get_balance()
	var win_day := -1
	var peak_rep := -999
	var lines: Array = []
	for day in range(s.days_limit):
		for _t in range(SimClock.ticks_per_day):
			SimClock.advance_tick()
		var cash := Ledger.get_balance()
		var rep := ProgressionManager.reputation
		peak_rep = maxi(peak_rep, rep)
		var wx: Dictionary = ZooBootstrap.weather_cfg.weather_by_id(ZooBootstrap.current_weather)
		lines.append("Day %2d: $%6d  rep %3d  (%s)" % [day + 1, cash, rep, wx.get("label", "?")])
		if win_day < 0 and cash >= s.target_cash and rep >= s.target_reputation:
			win_day = day + 1

	print("\n========== AUTOMATED PLAYTEST — Standard, %d days ==========" % s.days_limit)
	print("Setup: " + setup)
	print("Target: $%d cash AND %d reputation.  Start cash $%d." % [
		s.target_cash, s.target_reputation, start_cash])
	for ln in lines:
		print("  " + ln)
	print("------------------------------------------------------------")
	if win_day > 0:
		print("RESULT: WON on day %d." % win_day)
	else:
		print("RESULT: did not meet the bar — cash $%d/%d, rep %d/%d (peak rep %d)." % [
			Ledger.get_balance(), s.target_cash, ProgressionManager.reputation,
			s.target_reputation, peak_rep])
	print("6.9 park events: %d pos / %d neg / %d neu (%d): %s" % [
		ev["positive"], ev["negative"], ev["neutral"],
		ev["positive"] + ev["negative"] + ev["neutral"], ", ".join(ev_ids)])
	print("6.9 contracts completed: %d  %s" % [contracts.size(), str(contracts)])
	print("   [diag] metrics now: animals=%d species=%d exhibits=%d revenue=%d balance=%d rep=%d" % [
		ZooBootstrap.contract_metric(&"animals"), ZooBootstrap.contract_metric(&"species"),
		ZooBootstrap.contract_metric(&"exhibits"), ZooBootstrap.contract_metric(&"revenue"),
		ZooBootstrap.contract_metric(&"balance"), ZooBootstrap.contract_metric(&"reputation")])
	var slate: Array = []
	for cid in ZooBootstrap.active_contracts:
		var cc := ZooBootstrap.contracts_cfg.by_id(cid)
		slate.append("%s(%s>=%d)" % [String(cid), String(cc.get("metric","?")), int(cc.get("target",0))])
	print("   [diag] active slate: %s" % str(slate))
	print("Animals: %d births, %d deaths.  Telemetry events: %d" % [
		births[0], deaths[0], tele["n"]])
	print("============================================================\n")

	ZooBootstrap.park_event.disconnect(on_event)
	ZooBootstrap.contract_completed.disconnect(on_contract)
	ZooBootstrap.animal_born.disconnect(on_birth)
	ZooBootstrap.animal_welfare_alert.disconnect(on_welfare)
	Telemetry.event_recorded.disconnect(on_tele)
	ZooBootstrap.set_hired_keepers(0)
	Settings.set_value(&"telemetry_opt_in", false)

	assert_eq(SimClock.current_day, s.days_limit, "ran the full scenario")
	assert_gt(Ledger.get_balance(), 0, "never went bankrupt")
