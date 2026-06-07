extends RefCounted
class_name StaffConfig
# Zookeeper tuning from design/tuning/staff.md (roadmap 3.3). Game-side like the
# other zoo configs; the daily wage + welfare effect live in src/bootstrap.gd.

const TUNING_PATH := "res://design/tuning/staff.md"

var keeper_wage_per_day: int = 25
var keeper_welfare_bonus: float = 0.12
var max_keepers: int = 12


static func load_from_tuning() -> StaffConfig:
	var s := StaffConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[staff] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Settings", {}).get("scalars", {})
	if scalars.is_empty():
		push_error("[staff] missing ## Settings in %s" % TUNING_PATH)
		return s
	s.keeper_wage_per_day = int(_f(scalars, "keeper_wage_per_day", s.keeper_wage_per_day))
	s.keeper_welfare_bonus = _f(scalars, "keeper_welfare_bonus", s.keeper_welfare_bonus)
	s.max_keepers = int(_f(scalars, "max_keepers", s.max_keepers))
	return s


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback
