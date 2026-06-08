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

# Ordered list of ticket brackets, cheapest first. Each entry:
#   {id:StringName, label:String, price:int, demand_multiplier:float}
var ticket_brackets: Array = []
# id of the bracket a new park starts on (the row marked default = true).
var default_bracket: StringName = &""

# Donation parameters (## Donations scalar section).
var donation_view_chance: float = 0.35
var donation_amount_max: int = 6
var donation_min_satisfaction: float = 0.55

# Per-archetype spend multiplier (## Guest types). agent_type id -> float.
var spend_by_type: Dictionary = {}

# Opening hours as a fraction of the day [0,1) (## Day cycle).
var open_start: float = 0.0
var open_end: float = 0.80


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

	sc._load_ticket_brackets(parsed)
	sc._load_donations(parsed)
	sc._load_guest_types(parsed)
	sc._load_day_cycle(parsed)
	return sc


func _load_day_cycle(parsed: Dictionary) -> void:
	var scalars: Dictionary = parsed["sections"].get("Day cycle", {}).get("scalars", {})
	if scalars.is_empty():
		return   # optional — defaults leave the park open all day
	open_start = _scalar_float(scalars, "open_start", open_start)
	open_end = _scalar_float(scalars, "open_end", open_end)


func _load_guest_types(parsed: Dictionary) -> void:
	var section: Dictionary = parsed["sections"].get("Guest types", {})
	var tables: Array = section.get("tables", [])
	if tables.is_empty():
		return   # optional — every type defaults to 1.0
	for row: Dictionary in tables[0]["rows"]:
		var id := StringName(String(row.get("agent_id", "")).strip_edges())
		if id == &"":
			continue
		spend_by_type[id] = _to_float(row.get("spend_multiplier", "1"))


# Spend multiplier for an agent type (gate, purchases, tips). Default 1.0.
func spend_multiplier(agent_type_id: StringName) -> float:
	return float(spend_by_type.get(agent_type_id, 1.0))


func _load_donations(parsed: Dictionary) -> void:
	var section: Dictionary = parsed["sections"].get("Donations", {})
	var scalars: Dictionary = section.get("scalars", {})
	if scalars.is_empty():
		push_error("[services] missing ## Donations scalars in %s" % TUNING_PATH)
		return
	donation_view_chance = _scalar_float(scalars, "donation_view_chance", donation_view_chance)
	donation_amount_max = int(_scalar_float(scalars, "donation_amount_max", donation_amount_max))
	donation_min_satisfaction = _scalar_float(
		scalars, "donation_min_satisfaction", donation_min_satisfaction)


static func _scalar_float(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	return _to_float(entry.get("raw", ""))


func _load_ticket_brackets(parsed: Dictionary) -> void:
	var section: Dictionary = parsed["sections"].get("Ticket brackets", {})
	var tables: Array = section.get("tables", [])
	if tables.is_empty():
		push_error("[services] missing ## Ticket brackets table in %s" % TUNING_PATH)
		return
	var table: Dictionary = tables[0]
	for row: Dictionary in table["rows"]:
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		ticket_brackets.append({
			"id": id,
			"label": String(row.get("label", String(id))).strip_edges(),
			"price": _to_int(row.get("price", "0")),
			"demand_multiplier": _to_float(row.get("demand_multiplier", "1")),
		})
		if String(row.get("default", "")).strip_edges().to_lower() == "true":
			default_bracket = id
	if default_bracket == &"" and not ticket_brackets.is_empty():
		default_bracket = ticket_brackets[0]["id"]


# Look up a bracket dict by id, or {} if absent.
func bracket(id: StringName) -> Dictionary:
	for b in ticket_brackets:
		if b["id"] == id:
			return b
	return {}


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
