extends RefCounted
class_name ServiceConfig
# Per-need service pricing + spillover, loaded from design/tuning/services.md.
#
# Like Scenario, this sits *outside* the engine's ContentDB: pricing and the
# eat→restroom spillover are game-side concepts. We use the engine's
# MarkdownTuningParser to read the file but compile it ourselves.
#
# Consumed by VisitorBehavior (charges the price + applies spillover when a
# guest satisfies a need at a satisfier entity) and VisitorValueModel.

const TUNING_PATH := "res://design/tuning/services.md"

# need_id (StringName) -> {price:int, revenue_source:StringName,
#                          spillover_need:StringName, spillover_amount:float}
var by_need: Dictionary = {}


static func load_from_tuning() -> ServiceConfig:
	var sc := ServiceConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[services] %s" % err)
	var section: Dictionary = parsed["sections"].get("Need satisfiers", {})
	var tables: Array = section.get("tables", [])
	if tables.is_empty():
		push_error("[services] missing ## Need satisfiers table in %s" % TUNING_PATH)
		return sc
	var table: Dictionary = tables[0]
	for row: Dictionary in table["rows"]:
		var need_id := StringName(String(row.get("need_id", "")).strip_edges())
		if need_id == &"":
			continue
		sc.by_need[need_id] = {
			"price": _to_int(row.get("price", "0")),
			"revenue_source": StringName(String(row.get("revenue_source", "")).strip_edges()),
			"spillover_need": StringName(String(row.get("spillover_need", "")).strip_edges()),
			"spillover_amount": _to_float(row.get("spillover_amount", "0")),
		}
	return sc


# Cash charged when a guest satisfies `need_id`. Unknown need → 0 (free).
func price_for(need_id: StringName) -> int:
	var entry: Dictionary = by_need.get(need_id, {})
	return int(entry.get("price", 0))


# Ledger source id income for `need_id` is booked under. Falls back to the
# need id itself so the books still balance for un-configured needs.
func source_for(need_id: StringName) -> StringName:
	var entry: Dictionary = by_need.get(need_id, {})
	var src: StringName = entry.get("revenue_source", &"")
	return src if src != &"" else need_id


# (spillover_need, amount) for `need_id`, or (&"", 0.0) when none.
func spillover_for(need_id: StringName) -> Array:
	var entry: Dictionary = by_need.get(need_id, {})
	return [entry.get("spillover_need", &""), float(entry.get("spillover_amount", 0.0))]


static func _to_int(raw: Variant) -> int:
	var s := String(raw).strip_edges()
	return s.to_int() if s.is_valid_int() else 0


static func _to_float(raw: Variant) -> float:
	var s := String(raw).strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0
