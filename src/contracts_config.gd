extends RefCounted
class_name ContractsConfig
# Short-term contracts tuning from design/tuning/contracts.md (roadmap 6.9).
# Game-side; the slate management, evaluation, reward payout and save
# round-trip live in src/bootstrap.gd. This class only parses the pool.

const TUNING_PATH := "res://design/tuning/contracts.md"

var active_slots: int = 3
# Ordered pool. Each:
#   {id:StringName, label:String, metric:StringName, target:int,
#    reward_cash:int, reward_reputation:int, description:String}
var contracts: Array = []


static func load_from_tuning() -> ContractsConfig:
	var c := ContractsConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[contracts] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Globals", {}).get("scalars", {})
	c.active_slots = maxi(1, int(_f(scalars, "active_slots", float(c.active_slots))))
	for row: Dictionary in _rows(parsed, "Contracts"):
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		c.contracts.append({
			"id": id,
			"label": String(row.get("label", String(id))).strip_edges(),
			"metric": StringName(String(row.get("metric", "")).strip_edges()),
			"target": _to_i(row.get("target", "0")),
			"reward_cash": _to_i(row.get("reward_cash", "0")),
			"reward_reputation": _to_i(row.get("reward_reputation", "0")),
			"description": String(row.get("description", "")).strip_edges(),
		})
	return c


func by_id(id: StringName) -> Dictionary:
	for c in contracts:
		if c["id"] == id:
			return c
	return {}


func ids() -> Array:
	var out: Array = []
	for c in contracts:
		out.append(c["id"])
	return out


static func _rows(parsed: Dictionary, section: String) -> Array:
	var tables: Array = parsed["sections"].get(section, {}).get("tables", [])
	return tables[0]["rows"] if not tables.is_empty() else []


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback


static func _to_i(raw: Variant) -> int:
	var s := String(raw).strip_edges()
	return s.to_int() if s.is_valid_int() else 0
