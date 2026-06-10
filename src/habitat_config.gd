extends RefCounted
class_name HabitatConfig
# Per-species habitat preferences (terrain mix / foliage / rocks / shelter /
# enrichment), loaded from design/tuning/habitat.md — the ZT1 exhibit-
# authoring layer. Game-side, like ServiceConfig / WelfareConfig: the engine
# never reads this. Consumed by src/models/zoo_animal_happiness.gd.

const TUNING_PATH := "res://design/tuning/habitat.md"

# Axis weights (## Weights scalars).
var terrain_weight: float = 0.45
var foliage_weight: float = 0.18
var rocks_weight: float = 0.10
var shelter_weight: float = 0.12
var enrichment_weight: float = 0.10
var offtype_foliage_credit: float = 0.5
var rock_big_value: float = 2.0

# species id (StringName) -> {
#   terrain_mix: Dictionary[StringName, float],
#   foliage_frac: float, foliage_pref: StringName,
#   rocks_frac: float, wants_shelter: bool, wants_enrichment: bool }
var by_species: Dictionary = {}


static func load_from_tuning() -> HabitatConfig:
	var h := HabitatConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[habitat] %s" % err)
	var scalars: Dictionary = parsed["sections"].get("Weights", {}).get("scalars", {})
	if scalars.is_empty():
		push_error("[habitat] missing ## Weights in %s" % TUNING_PATH)
		return h
	h.terrain_weight = _scalar_float(scalars, "terrain_weight", h.terrain_weight)
	h.foliage_weight = _scalar_float(scalars, "foliage_weight", h.foliage_weight)
	h.rocks_weight = _scalar_float(scalars, "rocks_weight", h.rocks_weight)
	h.shelter_weight = _scalar_float(scalars, "shelter_weight", h.shelter_weight)
	h.enrichment_weight = _scalar_float(scalars, "enrichment_weight", h.enrichment_weight)
	h.offtype_foliage_credit = _scalar_float(
		scalars, "offtype_foliage_credit", h.offtype_foliage_credit)
	h.rock_big_value = _scalar_float(scalars, "rock_big_value", h.rock_big_value)

	var section: Dictionary = parsed["sections"].get("Species habitat", {})
	var tables: Array = section.get("tables", [])
	if tables.is_empty():
		push_error("[habitat] missing ## Species habitat table in %s" % TUNING_PATH)
		return h
	for row: Dictionary in tables[0]["rows"]:
		var id := StringName(String(row.get("species", "")).strip_edges())
		if id == &"":
			continue
		h.by_species[id] = {
			"terrain_mix": _parse_mix(String(row.get("terrain_mix", ""))),
			"foliage_frac": _to_float(row.get("foliage_frac", "0")),
			"foliage_pref": StringName(String(row.get("foliage_pref", "")).strip_edges()),
			"rocks_frac": _to_float(row.get("rocks_frac", "0")),
			"wants_shelter": _to_bool(row.get("wants_shelter", "false")),
			"wants_enrichment": _to_bool(row.get("wants_enrichment", "false")),
		}
	return h


func has_prefs(species_id: StringName) -> bool:
	return by_species.has(species_id)


func prefs(species_id: StringName) -> Dictionary:
	return by_species.get(species_id, {})


# "grass:0.75,rocks:0.15" -> {&"grass": 0.75, &"rocks": 0.15}
static func _parse_mix(raw: String) -> Dictionary:
	var out := {}
	for part in raw.split(",", false):
		var kv: PackedStringArray = part.split(":", false)
		if kv.size() != 2:
			continue
		var frac := kv[1].strip_edges().to_float()
		if frac > 0.0:
			out[StringName(kv[0].strip_edges())] = frac
	return out


static func _scalar_float(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback


static func _to_float(raw: Variant) -> float:
	var s := String(raw).strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0


static func _to_bool(raw: Variant) -> bool:
	return String(raw).strip_edges().to_lower() == "true"
