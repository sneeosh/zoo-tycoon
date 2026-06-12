extends RefCounted
class_name WeatherConfig
# Weather + seasons tuning from design/tuning/weather.md (roadmap 3.6).
# Game-side; the daily roll + demand effect live in src/bootstrap.gd.

const TUNING_PATH := "res://design/tuning/weather.md"

var days_per_season: int = 8
# Ordered season cycle. Each: {id:StringName, label:String, mult:float}
var seasons: Array = []
# Weather states. Each: {id:StringName, label:String, mult:float, weight:float}
var weathers: Array = []


static func load_from_tuning() -> WeatherConfig:
	var w := WeatherConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[weather] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Seasons", {}).get("scalars", {})
	w.days_per_season = maxi(1, int(_f(scalars, "days_per_season", w.days_per_season)))
	for row: Dictionary in _rows(parsed, "Season effects"):
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		w.seasons.append({"id": id, "label": String(row.get("label", String(id))).strip_edges(),
			"mult": _to_f(row.get("demand_multiplier", "1"))})
	for row: Dictionary in _rows(parsed, "Weather"):
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		w.weathers.append({"id": id, "label": String(row.get("label", String(id))).strip_edges(),
			"mult": _to_f(row.get("demand_multiplier", "1")),
			"weight": _to_f(row.get("weight", "1"))})
	return w


# Season at a given (0-indexed) day, cycling through the season list.
func season_for_day(day: int) -> Dictionary:
	if seasons.is_empty():
		return {"id": &"", "label": "", "mult": 1.0}
	var idx := int(day / days_per_season) % seasons.size()
	return seasons[idx]


func weather_by_id(id: StringName) -> Dictionary:
	for wx in weathers:
		if wx["id"] == id:
			return wx
	return {"id": id, "label": String(id), "mult": 1.0, "weight": 1.0}


# Weighted pick of a weather id using the supplied (seeded) RNG.
# weight_mults (weather id -> multiplier) lets the zoo's climate bias the
# roll — desert plots barely see rain, tropical ones see plenty
# (design/tuning/zoo_types.md ## Climates).
func pick_weather(rng: RandomNumberGenerator, weight_mults: Dictionary = {}) -> StringName:
	if weathers.is_empty():
		return &""
	var total := 0.0
	for wx in weathers:
		total += float(wx["weight"]) * float(weight_mults.get(wx["id"], 1.0))
	if total <= 0.0:
		return weathers[0]["id"]
	var pick := rng.randf() * total
	var accum := 0.0
	for wx in weathers:
		accum += float(wx["weight"]) * float(weight_mults.get(wx["id"], 1.0))
		if pick <= accum:
			return wx["id"]
	return weathers[weathers.size() - 1]["id"]


static func _rows(parsed: Dictionary, section: String) -> Array:
	var tables: Array = parsed["sections"].get(section, {}).get("tables", [])
	return tables[0]["rows"] if not tables.is_empty() else []


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	return _to_f(entry.get("raw", ""))


static func _to_f(raw: Variant) -> float:
	var s := String(raw).strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0
