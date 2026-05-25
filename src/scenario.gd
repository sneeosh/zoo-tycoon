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
	return s


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
