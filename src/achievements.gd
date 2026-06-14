extends Node
## Achievements (roadmap 6.2) — genre table-stakes for retention, and the
## thing a playtester chases for "one more day".
##
## Definitions live in design/tuning/achievements.md (CLAUDE.md §3: numbers in
## tuning, never hardcoded). Each is a (metric, threshold) pair the autoload
## evaluates as the relevant signals fire; the unlocked set and the lifetime
## counters persist to user://achievements.json so progress is a *profile*,
## not a single save (you keep your badges across games and reloads — 5.4's
## persistence discipline applied to meta-progression).
##
## Engine-clean: every metric is read from existing engine/zoo signals and
## getters. No new engine surface.

signal achievement_unlocked(id: StringName, label: String, description: String)

const PATH := "user://achievements.json"
const TUNING_PATH := "res://design/tuning/achievements.md"

# id -> { label, description, metric, threshold }
var _defs: Dictionary = {}
# Stable display order, matching the tuning file.
var _order: Array[StringName] = []
# id -> true once earned.
var _unlocked: Dictionary = {}
# Lifetime counters that feed cumulative metrics.
var _counters := {
	&"guests": 0,
	&"happy_guests": 0,
	&"births": 0,
	&"rare_births": 0,
}
# Peak-seen state metrics, so a dip below threshold doesn't un-earn a badge.
var _peak := {&"balance": 0, &"reputation": 0, &"day": 0}


func _ready() -> void:
	_load_defs()
	_load_progress()
	ZooBootstrap.guest_departed.connect(_on_guest_departed)
	ZooBootstrap.animal_born.connect(_on_animal_born)
	EventBus.day_ended.connect(_on_day_ended)


# --- Queries (for the HUD list) -------------------------------------------

func all_ids() -> Array[StringName]:
	return _order.duplicate()


func definition(id: StringName) -> Dictionary:
	return _defs.get(id, {})


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func total_count() -> int:
	return _order.size()


# --- Signal handlers ------------------------------------------------------

func _on_guest_departed(verdict: int, _pos) -> void:
	_counters[&"guests"] += 1
	if verdict > 0:
		_counters[&"happy_guests"] += 1
	_evaluate()


func _on_animal_born(_rid, _species, _name, rare: bool) -> void:
	_counters[&"births"] += 1
	if rare:
		_counters[&"rare_births"] += 1
	_evaluate()


func _on_day_ended(day: int) -> void:
	_peak[&"day"] = maxi(_peak[&"day"], day + 1)
	_evaluate()


# --- Evaluation -----------------------------------------------------------

func _metric(name: StringName) -> int:
	match name:
		&"balance":
			_peak[&"balance"] = maxi(_peak[&"balance"], Ledger.get_balance())
			return _peak[&"balance"]
		&"reputation":
			_peak[&"reputation"] = maxi(_peak[&"reputation"], ProgressionManager.reputation)
			return _peak[&"reputation"]
		&"day":
			_peak[&"day"] = maxi(_peak[&"day"], SimClock.current_day + 1)
			return _peak[&"day"]
		_:
			return int(_counters.get(name, 0))


# Check every still-locked achievement; unlock + announce any that crossed.
func _evaluate() -> void:
	var newly := false
	for id in _order:
		if _unlocked.has(id):
			continue
		var d: Dictionary = _defs[id]
		if _metric(d["metric"]) >= int(d["threshold"]):
			_unlocked[id] = true
			newly = true
			achievement_unlocked.emit(id, d["label"], d["description"])
	if newly:
		_save_progress()


# --- Tuning + persistence -------------------------------------------------

func _load_defs() -> void:
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed.get("errors", []):
		push_error("[achievements] %s" % err)
	var tables: Array = parsed["sections"].get("Achievements", {}).get("tables", [])
	if tables.is_empty():
		push_error("[achievements] no ## Achievements table in %s" % TUNING_PATH)
		return
	for row: Dictionary in tables[0]["rows"]:
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		var threshold := int(String(row.get("threshold", "0")).strip_edges().to_int())
		_defs[id] = {
			"label": String(row.get("label", String(id))).strip_edges(),
			"description": String(row.get("description", "")).strip_edges(),
			"metric": StringName(String(row.get("metric", "")).strip_edges()),
			"threshold": threshold,
		}
		_order.append(id)


func _load_progress() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	for id_str in parsed.get("unlocked", []):
		_unlocked[StringName(id_str)] = true
	for key in _counters.keys():
		_counters[key] = int(parsed.get("counters", {}).get(String(key), _counters[key]))
	for key in _peak.keys():
		_peak[key] = int(parsed.get("peak", {}).get(String(key), _peak[key]))


func _save_progress() -> void:
	var ids: Array[String] = []
	for id in _unlocked.keys():
		ids.append(String(id))
	var counters := {}
	for key in _counters.keys():
		counters[String(key)] = _counters[key]
	var peak := {}
	for key in _peak.keys():
		peak[String(key)] = _peak[key]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[achievements] could not write %s" % PATH)
		return
	f.store_string(JSON.stringify({
		"unlocked": ids, "counters": counters, "peak": peak,
	}, "\t"))
