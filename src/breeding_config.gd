extends RefCounted
class_name BreedingConfig
# Breeding/aging tuning from design/tuning/breeding.md (roadmap 3.5). Game-side
# like the other zoo configs; the daily logic lives in src/bootstrap.gd.

const TUNING_PATH := "res://design/tuning/breeding.md"

var welfare_threshold: float = 0.75
var chance_per_day: float = 0.15
var min_age_days: int = 2
var max_age_days: int = 60
var rare_chance: float = 0.05
var rare_reputation: int = 5


static func load_from_tuning() -> BreedingConfig:
	var b := BreedingConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[breeding] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Settings", {}).get("scalars", {})
	if scalars.is_empty():
		push_error("[breeding] missing ## Settings in %s" % TUNING_PATH)
		return b
	b.welfare_threshold = _f(scalars, "welfare_threshold", b.welfare_threshold)
	b.chance_per_day = _f(scalars, "chance_per_day", b.chance_per_day)
	b.min_age_days = int(_f(scalars, "min_age_days", b.min_age_days))
	b.max_age_days = int(_f(scalars, "max_age_days", b.max_age_days))
	b.rare_chance = _f(scalars, "rare_chance", b.rare_chance)
	b.rare_reputation = int(_f(scalars, "rare_reputation", b.rare_reputation))
	return b


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback
