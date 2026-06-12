extends RefCounted
class_name ZooTypeConfig
# Land plots + climates from design/tuning/zoo_types.md.
# Game-side; purchase/sale/relocation logic lives in src/bootstrap.gd.

const TUNING_PATH := "res://design/tuning/zoo_types.md"

# The starter park layout (src/starter_park.gd) and the gate column need at
# least this much grid; rows below these minimums are rejected at load.
const MIN_PLOT_W: int = 16
const MIN_PLOT_H: int = 18

var resale_fraction: float = 0.75
var min_cash_after_purchase: int = 5500
# Ordered list of {id, label, climate, size:Vector2i, cost:int, blurb}.
var plots: Array = []
# climate id -> {id, label, demand_multiplier:float,
#                weather_weights: {weather_id -> multiplier}}
var climates: Dictionary = {}
# First zero-cost plot (fallback: first plot) — what new games start on and
# what old saves without a zoo_type resolve to.
var default_plot: StringName = &""


static func load_from_tuning() -> ZooTypeConfig:
	var z := ZooTypeConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[zoo_types] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Land", {}).get("scalars", {})
	z.resale_fraction = clampf(_f(scalars, "resale_fraction", z.resale_fraction), 0.0, 1.0)
	z.min_cash_after_purchase = maxi(0, int(_f(scalars, "min_cash_after_purchase",
		float(z.min_cash_after_purchase))))

	for row: Dictionary in _rows(parsed, "Climates"):
		var cid := StringName(String(row.get("id", "")).strip_edges())
		if cid == &"":
			continue
		var weights := {}
		for key in row.keys():
			if key in ["id", "label", "demand_multiplier"]:
				continue
			weights[StringName(key)] = _to_f(row[key])
		z.climates[cid] = {
			"id": cid,
			"label": String(row.get("label", String(cid))).strip_edges(),
			"demand_multiplier": _to_f(row.get("demand_multiplier", "1")),
			"weather_weights": weights,
		}

	for row: Dictionary in _rows(parsed, "Plots"):
		var id := StringName(String(row.get("id", "")).strip_edges())
		if id == &"":
			continue
		var w := int(_to_f(row.get("plot_w", "0")))
		var h := int(_to_f(row.get("plot_h", "0")))
		var climate := StringName(String(row.get("climate", "")).strip_edges())
		if w < MIN_PLOT_W or h < MIN_PLOT_H:
			push_error("[zoo_types] plot '%s' is %dx%d — below the %dx%d minimum, skipping"
				% [id, w, h, MIN_PLOT_W, MIN_PLOT_H])
			continue
		if not z.climates.has(climate):
			push_error("[zoo_types] plot '%s' names unknown climate '%s', skipping"
				% [id, climate])
			continue
		z.plots.append({
			"id": id,
			"label": String(row.get("label", String(id))).strip_edges(),
			"climate": climate,
			"size": Vector2i(w, h),
			"cost": maxi(0, int(_to_f(row.get("cost", "0")))),
			"blurb": String(row.get("blurb", "")).strip_edges(),
		})
		if z.default_plot == &"" and int(_to_f(row.get("cost", "0"))) == 0:
			z.default_plot = id
	if z.plots.is_empty():
		push_error("[zoo_types] no valid plots in %s" % TUNING_PATH)
	elif z.default_plot == &"":
		z.default_plot = z.plots[0]["id"]
	return z


# Plot record by id, or {} if absent.
func plot(id: StringName) -> Dictionary:
	for p in plots:
		if p["id"] == id:
			return p
	return {}


# Climate record by id, or {} if absent.
func climate(id: StringName) -> Dictionary:
	return climates.get(id, {})


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
