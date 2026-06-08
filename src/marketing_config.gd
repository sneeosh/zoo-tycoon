extends RefCounted
class_name MarketingConfig
# Marketing-campaign tuning from design/tuning/marketing.md (roadmap 4.2).
# Game-side; the campaign logic lives in src/bootstrap.gd.

const TUNING_PATH := "res://design/tuning/marketing.md"

var campaign_cost: int = 800
var campaign_days: int = 5
var campaign_boost: float = 3.0


static func load_from_tuning() -> MarketingConfig:
	var m := MarketingConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[marketing] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Settings", {}).get("scalars", {})
	if scalars.is_empty():
		push_error("[marketing] missing ## Settings in %s" % TUNING_PATH)
		return m
	m.campaign_cost = int(_f(scalars, "campaign_cost", m.campaign_cost))
	m.campaign_days = int(_f(scalars, "campaign_days", m.campaign_days))
	m.campaign_boost = _f(scalars, "campaign_boost", m.campaign_boost)
	return m


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback
