extends GutTest
# Emergent "park stories" (roadmap 6.9). EventsConfig is pure (parses
# design/tuning/events.md and answers eligibility/pick), so most of this
# exercises it directly. A few cases poke ZooBootstrap's event hooks
# (demand multiplier, applying a known event, the save serializer), restoring
# any global state they touch.


func before_each() -> void:
	SaveService.autosave_enabled = false


# --- EventsConfig: loading -------------------------------------------------

func test_config_loads_globals_and_rows() -> void:
	var cfg := EventsConfig.load_from_tuning()
	assert_almost_eq(cfg.daily_chance, 0.45, 0.001)
	assert_eq(cfg.min_day, 3)
	assert_eq(cfg.cooldown_days, 2)
	assert_gt(cfg.events.size(), 5)


func test_config_event_fields() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var ev := cfg.event_by_id(&"animal_escape")
	assert_false(ev.is_empty(), "animal_escape row should parse")
	assert_eq(String(ev["requires"]), "sick_animal")
	assert_eq(int(ev["reputation"]), -4)
	assert_eq(int(ev["cash"]), -800)
	assert_lt(float(ev["demand_mult"]), 1.0)
	assert_eq(String(ev["category"]), "negative")


# --- EventsConfig: gating --------------------------------------------------

func test_gate_sick_animal_requires_a_sick_animal() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var healthy := {"reputation": 50, "animals": 4, "sick_animals": 0}
	var ailing := {"reputation": 50, "animals": 4, "sick_animals": 1}
	assert_false(_has(cfg.eligible(healthy), &"animal_escape"),
		"escape must not fire with no sick animal")
	assert_true(_has(cfg.eligible(ailing), &"animal_escape"),
		"escape becomes eligible once an animal is sick")


func test_gate_reputation_threshold() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var low := {"reputation": 10, "animals": 4, "sick_animals": 0}
	var high := {"reputation": 40, "animals": 4, "sick_animals": 0}
	assert_false(_has(cfg.eligible(low), &"celebrity_visit"),
		"a celebrity only visits a well-regarded zoo")
	assert_true(_has(cfg.eligible(high), &"celebrity_visit"))


func test_gate_animals_required() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var empty := {"reputation": 50, "animals": 0, "sick_animals": 0}
	# An animal-gated event is excluded, but an unconditional one survives.
	assert_false(_has(cfg.eligible(empty), &"school_trip"))
	assert_true(_has(cfg.eligible(empty), &"perfect_day"),
		"a 'requires: none' event is always eligible")


# --- EventsConfig: weighted pick -------------------------------------------

func test_pick_returns_an_eligible_event() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var world := {"reputation": 5, "animals": 0, "sick_animals": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Over many draws, every result must satisfy the gate for this world
	# (only unconditional events here, never an animal/sick/rep-gated one).
	for i in 50:
		var ev := cfg.pick(rng, world)
		assert_false(ev.is_empty())
		assert_true(String(ev["requires"]) in ["none", ""],
			"picked '%s' should be unconditional in an empty world" % ev.get("id"))


func test_pick_is_deterministic_for_a_seed() -> void:
	var cfg := EventsConfig.load_from_tuning()
	var world := {"reputation": 50, "animals": 4, "sick_animals": 1}
	var a := RandomNumberGenerator.new(); a.seed = 7
	var b := RandomNumberGenerator.new(); b.seed = 7
	assert_eq(cfg.pick(a, world)["id"], cfg.pick(b, world)["id"])


# --- ZooBootstrap hooks ----------------------------------------------------

func test_bootstrap_loaded_events_config() -> void:
	assert_not_null(ZooBootstrap.events_cfg)
	assert_eq(ZooBootstrap.event_demand_multiplier(), 1.0,
		"no event in flight → neutral demand")


func test_active_events_scale_demand() -> void:
	var saved := ZooBootstrap.active_events.duplicate(true)
	ZooBootstrap.active_events = [
		{"id": &"tv_feature", "label": "x", "days_left": 1, "demand_mult": 1.5},
		{"id": &"heatwave", "label": "y", "days_left": 2, "demand_mult": 0.7},
	]
	assert_almost_eq(ZooBootstrap.event_demand_multiplier(), 1.05, 0.0001)
	ZooBootstrap.active_events = saved


func test_apply_event_posts_cash_and_reputation() -> void:
	var bal0 := Ledger.get_balance()
	var rep0 := ProgressionManager.reputation
	var saved := ZooBootstrap.active_events.duplicate(true)
	var saved_last := ZooBootstrap.last_event_day
	ZooBootstrap._apply_event({
		"id": &"conservation_grant", "label": "Grant", "category": "positive",
		"requires": "none", "min_reputation": 0, "cash": 1500, "reputation": 1,
		"demand_mult": 1.0, "duration_days": 1, "message": "test",
	}, 5)
	assert_eq(Ledger.get_balance(), bal0 + 1500)
	assert_eq(ProgressionManager.reputation, rep0 + 1)
	# No lasting demand effect for a demand_mult of 1.0.
	assert_eq(ZooBootstrap.active_events.size(), saved.size())
	# Restore touched globals.
	ProgressionManager.set_reputation(rep0)
	ZooBootstrap.active_events = saved
	ZooBootstrap.last_event_day = saved_last


func test_active_events_serialize_for_save() -> void:
	var saved := ZooBootstrap.active_events.duplicate(true)
	ZooBootstrap.active_events = [
		{"id": &"heatwave", "label": "Heatwave", "days_left": 2, "demand_mult": 0.7},
	]
	var rows := ZooBootstrap._active_events_for_save()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["id"], "heatwave", "StringName id serializes to a String")
	assert_almost_eq(float(rows[0]["demand_mult"]), 0.7, 0.0001)
	ZooBootstrap.active_events = saved


# --- helpers ---------------------------------------------------------------

func _has(pool: Array, id: StringName) -> bool:
	for ev in pool:
		if ev["id"] == id:
			return true
	return false
