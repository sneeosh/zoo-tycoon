extends RefCounted
class_name EventsConfig
# Emergent "park stories" tuning from design/tuning/events.md (roadmap 6.9).
# Game-side; the daily roll, effect application, expiry and save round-trip
# live in src/bootstrap.gd. This class only parses the table and answers two
# questions: "which events are eligible right now?" and "pick one by weight".

const TUNING_PATH := "res://design/tuning/events.md"

var daily_chance: float = 0.45
var min_day: int = 3
var cooldown_days: int = 2
# Ordered list of event records. Each:
#   {id:StringName, label:String, weight:float, category:String,
#    requires:String, min_reputation:int, cash:int, reputation:int,
#    demand_mult:float, duration_days:int, message:String}
var events: Array = []


static func load_from_tuning() -> EventsConfig:
	var e := EventsConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[events] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Globals", {}).get("scalars", {})
	e.daily_chance = clampf(_f(scalars, "daily_chance", e.daily_chance), 0.0, 1.0)
	e.min_day = maxi(0, int(_f(scalars, "min_day", float(e.min_day))))
	e.cooldown_days = maxi(0, int(_f(scalars, "cooldown_days", float(e.cooldown_days))))
	for row: Dictionary in _rows(parsed, "Events"):
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		e.events.append({
			"id": id,
			"label": String(row.get("label", String(id))).strip_edges(),
			"weight": maxf(0.0, _to_f(row.get("weight", "1"))),
			"category": String(row.get("category", "neutral")).strip_edges(),
			"requires": String(row.get("requires", "none")).strip_edges(),
			"min_reputation": _to_i(row.get("min_reputation", "0")),
			"cash": _to_i(row.get("cash", "0")),
			"reputation": _to_i(row.get("reputation", "0")),
			"demand_mult": _to_f(row.get("demand_mult", "1")),
			"duration_days": maxi(0, _to_i(row.get("duration_days", "1"))),
			"message": String(row.get("message", "")).strip_edges(),
		})
	return e


func event_by_id(id: StringName) -> Dictionary:
	for ev in events:
		if ev["id"] == id:
			return ev
	return {}


# Events whose `requires` gate passes against the supplied world snapshot
# ({reputation:int, animals:int, sick_animals:int}). Zero-weight rows are
# dropped — a row weighted 0 is an author switching it off.
func eligible(world: Dictionary) -> Array:
	var out: Array = []
	for ev in events:
		if float(ev["weight"]) <= 0.0:
			continue
		if _gate_passes(ev, world):
			out.append(ev)
	return out


# Weighted pick among the currently-eligible events, or {} if none qualify.
func pick(rng: RandomNumberGenerator, world: Dictionary) -> Dictionary:
	var pool := eligible(world)
	if pool.is_empty():
		return {}
	var total := 0.0
	for ev in pool:
		total += float(ev["weight"])
	if total <= 0.0:
		return pool[0]
	var roll := rng.randf() * total
	var accum := 0.0
	for ev in pool:
		accum += float(ev["weight"])
		if roll <= accum:
			return ev
	return pool[pool.size() - 1]


func _gate_passes(ev: Dictionary, world: Dictionary) -> bool:
	match String(ev["requires"]):
		"", "none":
			return true
		"animals":
			return int(world.get("animals", 0)) >= 1
		"sick_animal":
			return int(world.get("sick_animals", 0)) >= 1
		"reputation":
			return int(world.get("reputation", 0)) >= int(ev["min_reputation"])
		_:
			push_warning("[events] unknown requires gate '%s' on '%s' — treating as always eligible"
				% [ev["requires"], ev["id"]])
			return true


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


static func _to_i(raw: Variant) -> int:
	var s := String(raw).strip_edges()
	return s.to_int() if s.is_valid_int() else 0
