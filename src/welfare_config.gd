extends RefCounted
class_name WelfareConfig
# Animal-welfare tuning loaded from design/tuning/welfare.md (roadmap 3.1).
# Game-side, like Scenario / ServiceConfig — the engine doesn't read it. The
# daily welfare update lives in src/bootstrap.gd; the appeal effect lives in
# src/models/zoo_animal_happiness.gd.

const TUNING_PATH := "res://design/tuning/welfare.md"

var happiness_threshold: float = 0.5
var recovery_per_day: float = 0.15
var decline_per_day: float = 0.20
var illness_threshold: float = 0.35
var death_reputation_penalty: int = 3


static func load_from_tuning() -> WelfareConfig:
	var w := WelfareConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[welfare] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Settings", {}).get("scalars", {})
	if scalars.is_empty():
		push_error("[welfare] missing ## Settings in %s" % TUNING_PATH)
		return w
	w.happiness_threshold = _f(scalars, "happiness_threshold", w.happiness_threshold)
	w.recovery_per_day = _f(scalars, "recovery_per_day", w.recovery_per_day)
	w.decline_per_day = _f(scalars, "decline_per_day", w.decline_per_day)
	w.illness_threshold = _f(scalars, "illness_threshold", w.illness_threshold)
	w.death_reputation_penalty = int(_f(scalars, "death_reputation_penalty",
		w.death_reputation_penalty))
	return w


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback
