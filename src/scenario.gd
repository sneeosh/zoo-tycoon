extends RefCounted
class_name Scenario
# Win + lose parameters loaded from design/tuning/scenario.md.
#
# This sits *outside* the engine's ContentDB on purpose. The engine cares
# about economy (starting cash, recurring expenses) but not about scenarios
# — that's a game-side concept. We use the engine's MarkdownTuningParser
# to read the file, but compile it ourselves.

const TUNING_PATH := "res://design/tuning/scenario.md"

var target_cash: int = 20000
var target_reputation: int = 50
var days_limit: int = 30
var bankruptcy_threshold: int = 0

# Difficulty (roadmap 2.6). The ## Goal values above are the Standard default;
# a difficulty overlay overrides the win bar + sets starting cash + a global
# guest-demand multiplier. Filled from the ## Difficulties table.
var difficulty: StringName = &"standard"
var starting_cash: int = 10000
var demand_multiplier: float = 1.0
# Ordered list of {id, label, starting_cash, target_cash, target_reputation,
# days_limit, demand_multiplier}.
var difficulties: Array = []


static func load_from_tuning() -> Scenario:
	var s := Scenario.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[scenario] %s" % err)
	var section: Dictionary = parsed["sections"].get("Goal", {})
	if section.is_empty():
		push_error("[scenario] missing ## Goal section in %s" % TUNING_PATH)
		return s
	s.target_cash = _read_int(section, "target_cash", s.target_cash)
	s.target_reputation = _read_int(section, "target_reputation", s.target_reputation)
	s.days_limit = _read_int(section, "days_limit", s.days_limit)
	s.bankruptcy_threshold = _read_int(section, "bankruptcy_threshold", s.bankruptcy_threshold)
	s._load_difficulties(parsed)
	return s


func _load_difficulties(parsed: Dictionary) -> void:
	var tables: Array = parsed["sections"].get("Difficulties", {}).get("tables", [])
	if tables.is_empty():
		return
	for row: Dictionary in tables[0]["rows"]:
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		difficulties.append({
			"id": id,
			"label": String(row.get("label", String(id))).strip_edges(),
			"starting_cash": _cell_int(row, "starting_cash", 10000),
			"target_cash": _cell_int(row, "target_cash", target_cash),
			"target_reputation": _cell_int(row, "target_reputation", target_reputation),
			"days_limit": _cell_int(row, "days_limit", days_limit),
			"demand_multiplier": _cell_float(row, "demand_multiplier", 1.0),
		})


# Look up a difficulty preset by id, or {} if absent.
func difficulty_preset(id: StringName) -> Dictionary:
	for d in difficulties:
		if d["id"] == id:
			return d
	return {}


# Overlay a difficulty: override the win bar, starting cash, and demand.
# Unknown ids are ignored.
func apply_difficulty(id: StringName) -> bool:
	var d := difficulty_preset(id)
	if d.is_empty():
		return false
	difficulty = id
	starting_cash = int(d["starting_cash"])
	target_cash = int(d["target_cash"])
	target_reputation = int(d["target_reputation"])
	days_limit = int(d["days_limit"])
	demand_multiplier = float(d["demand_multiplier"])
	return true


static func _cell_int(row: Dictionary, key: String, fallback: int) -> int:
	var raw := String(row.get(key, "")).strip_edges()
	return raw.to_int() if raw.is_valid_int() else fallback


static func _cell_float(row: Dictionary, key: String, fallback: float) -> float:
	var raw := String(row.get(key, "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback


static func _read_int(section: Dictionary, key: String, fallback: int) -> int:
	var entry: Dictionary = section["scalars"].get(key, {})
	if entry.is_empty():
		push_error("[scenario] missing key '%s'" % key)
		return fallback
	var raw: String = entry["raw"]
	if not raw.is_valid_int():
		push_error("[scenario] '%s' is not an integer: '%s'" % [key, raw])
		return fallback
	return raw.to_int()
