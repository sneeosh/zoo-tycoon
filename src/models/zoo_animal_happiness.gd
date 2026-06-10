extends IPlaceableHappiness
class_name ZooAnimalHappiness
# Zoo's IPlaceableHappiness implementation.
# Spec: design/algorithms/animal_happiness.md
#
# Each animal placement scores [0, 1]. Start at 1.0 and subtract:
#   * SPACE penalty when actual space per individual < ideal
#   * SOCIAL penalty when same-species companions outside [min, max]
#   * NEEDS penalty for each required_provided_tag missing from the
#     region's "provided pool" (union of other placements' own_tags)
# Then multiply by the per-placement attitude (from state["attitude"],
# default 1.0).
#
# compute_breakdown() exposes the same math as a labelled dict so the UI can
# render a 0–100 suitability rating with a per-factor breakdown and an
# always-on "next most impactful" recommendation (adaptation plan §2 item 1,
# §5 divergence #2). compute_happiness() — the engine's IPlaceableHappiness
# entry point — is a thin wrapper over it.
#
# HABITAT AXES (the ZT1 exhibit-authoring layer): when `habitat` is injected
# (bootstrap loads design/tuning/habitat.md via HabitatConfig), species with
# preferences additionally score terrain mix, foliage, rocks, shelter, and
# enrichment. With habitat == null (or a species with no entry) the model is
# exactly the original space/social/needs math — which is what the worked
# examples in design/algorithms/animal_happiness.md and their mirror tests
# exercise.

const SPACE_WEIGHT: float = 0.5
const SOCIAL_DEFICIT_WEIGHT: float = 0.1
const SOCIAL_EXCESS_WEIGHT: float = 0.05
const NEEDS_DEFICIT_WEIGHT: float = 0.2

# Injected by bootstrap; null disables the habitat axes.
var habitat: HabitatConfig = null

# region_id -> {area:int, fracs:Dictionary[zone_tag -> float]} — terrain
# composition is O(all entities) to compute, so cache it; bootstrap clears
# the cache on entity/region change events.
var _terrain_cache: Dictionary = {}


func clear_terrain_cache(_a = null, _b = null, _c = null) -> void:
	_terrain_cache.clear()


func compute_happiness(region: Region, index: int) -> float:
	# The engine consumes this for guest appeal / quality. It's the exhibit's
	# care quality (the breakdown happiness) scaled by the animal's welfare —
	# a neglected, sick animal draws fewer guests. welfare defaults to 1.0
	# (state set by the daily welfare update in bootstrap), so an exhibit with
	# no welfare history behaves exactly as before.
	var b := compute_breakdown(region, index)
	var care: float = b.get("happiness", 1.0)
	if not b.get("valid", false):
		return care
	var welfare: float = clampf(
		float(region.placements[index].state.get("welfare", 1.0)), 0.0, 1.0)
	return care * welfare


# The care quality an exhibit provides one animal (space / social / needs /
# attitude), WITHOUT the welfare discount — this is what *drives* welfare each
# day, so welfare can't spiral by feeding back into itself.
func care_quality(region: Region, index: int) -> float:
	return compute_breakdown(region, index).get("happiness", 1.0)


# Returns a labelled breakdown for one placement:
#   {
#     valid:    bool,                 # false for out-of-range / unknown def
#     space:    float,  # space penalty   (≥0)
#     social:   float,  # social penalty  (≥0)
#     social_kind: "deficit"|"excess"|"" ,
#     companions: int, social_min: int, social_max: int,
#     missing_needs: Array[StringName],  # required tags not provided
#     needs:    float,  # needs penalty   (≥0)
#     attitude: float,  # 0..1 multiplier (show fatigue, etc.)
#     base:     float,  # 1 - penalties, clamped 0..1
#     happiness:float,  # base * attitude (what the engine consumes)
#   }
func compute_breakdown(region: Region, index: int) -> Dictionary:
	if index < 0 or index >= region.placements.size():
		return {"valid": false, "happiness": 1.0}
	var placement: Placement = region.placements[index]
	var self_def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
	if self_def == null:
		return {"valid": false, "happiness": 1.0}

	# --- Space ---
	# Even-split across the placements that actually occupy floor space.
	# Habitat dressing (foliage / rocks / shelters / toys) has
	# space_required 0 and shares tiles — decorating a pen must never make
	# the animals feel more cramped.
	var n: int = 0
	for p in region.placements:
		var pdef: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
		if pdef != null and pdef.space_required > 0:
			n += 1
	var actual_space: float = float(region.area) / float(max(n, 1))
	var space_penalty: float = 0.0
	if actual_space < float(self_def.space_ideal):
		var deficit: float = 1.0 - actual_space / float(self_def.space_ideal)
		space_penalty = deficit * SPACE_WEIGHT

	# --- Social — same-species companions, excluding self ---
	var companions: int = 0
	for i in region.placements.size():
		if i == index:
			continue
		if region.placements[i].placeable_def_id == self_def.id:
			companions += 1
	var social_penalty: float = 0.0
	var social_kind: String = ""
	if companions < self_def.social_min:
		social_penalty = float(self_def.social_min - companions) * SOCIAL_DEFICIT_WEIGHT
		social_kind = "deficit"
	elif companions > self_def.social_max:
		social_penalty = float(companions - self_def.social_max) * SOCIAL_EXCESS_WEIGHT
		social_kind = "excess"

	# --- Needs — provided pool from OTHER placements ---
	var provided: Dictionary = {}
	for i in region.placements.size():
		if i == index:
			continue
		var other_def: PlaceableDef = ContentDB.placeable_defs.get(region.placements[i].placeable_def_id)
		if other_def == null:
			continue
		for tag in other_def.own_tags:
			provided[tag] = true
	var missing_needs: Array[StringName] = []
	for required_tag in self_def.needs_provided_tags:
		if not provided.has(required_tag):
			missing_needs.append(required_tag)
	var needs_penalty: float = float(missing_needs.size()) * NEEDS_DEFICIT_WEIGHT

	# --- Habitat axes (terrain / foliage / rocks / shelter / enrichment) ---
	var hb := _habitat_breakdown(region, self_def)

	var penalty: float = space_penalty + social_penalty + needs_penalty \
		+ float(hb["terrain"]) + float(hb["foliage"]) + float(hb["rocks"]) \
		+ float(hb["shelter"]) + float(hb["enrichment"])
	var base_happiness: float = clampf(1.0 - penalty, 0.0, 1.0)
	var attitude: float = clampf(float(placement.state.get("attitude", 1.0)), 0.0, 1.0)

	var out := {
		"valid": true,
		"space": space_penalty,
		"social": social_penalty,
		"social_kind": social_kind,
		"companions": companions,
		"social_min": self_def.social_min,
		"social_max": self_def.social_max,
		"missing_needs": missing_needs,
		"needs": needs_penalty,
		"attitude": attitude,
		"base": base_happiness,
		"happiness": base_happiness * attitude,
	}
	out.merge(hb)
	return out


# The ZT1 habitat axes for one species in one region. All zeros (and empty
# detail fields) when the config is absent or the species has no entry, so
# the legacy space/social/needs model is unchanged.
func _habitat_breakdown(region: Region, self_def: PlaceableDef) -> Dictionary:
	var out := {
		"terrain": 0.0, "foliage": 0.0, "rocks": 0.0,
		"shelter": 0.0, "enrichment": 0.0,
		"terrain_detail": {}, "foliage_have": 0.0, "foliage_target": 0,
		"foliage_pref": &"", "rocks_have": 0.0, "rocks_target": 0,
		"has_shelter": false, "has_toy": false,
		"wants_shelter": false, "wants_enrichment": false,
	}
	if habitat == null or not habitat.has_prefs(self_def.id):
		return out
	var pref: Dictionary = habitat.prefs(self_def.id)

	# Terrain mix — deficit-only against the pen's actual zone-tile fractions.
	var mix: Dictionary = pref["terrain_mix"]
	if not mix.is_empty():
		var fracs := _terrain_fractions(region)
		var deficit := 0.0
		var detail := {}
		for tag in mix.keys():
			var want: float = mix[tag]
			var have: float = float(fracs.get(tag, 0.0))
			detail[tag] = {"want": want, "have": have}
			deficit += maxf(0.0, want - have)
		out["terrain"] = deficit * habitat.terrain_weight
		out["terrain_detail"] = detail

	# Count the dressing in this pen.
	var foliage_have := 0.0
	var rocks_have := 0.0
	var has_shelter := false
	var has_toy := false
	var want_plant: StringName = pref["foliage_pref"]
	for p in region.placements:
		var pdef: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
		if pdef == null:
			continue
		if &"foliage" in pdef.own_tags:
			var on_type: bool = want_plant == &"" or want_plant in pdef.own_tags
			foliage_have += 1.0 if on_type else habitat.offtype_foliage_credit
		if &"rock_item" in pdef.own_tags:
			rocks_have += habitat.rock_big_value if &"rock_big" in pdef.own_tags else 1.0
		if &"shelter" in pdef.own_tags:
			has_shelter = true
		if &"enrichment" in pdef.own_tags:
			has_toy = true

	# Foliage / rocks — score the shortfall against an area-scaled target.
	var foliage_target := int(ceil(float(pref["foliage_frac"]) * float(region.area)))
	if foliage_target > 0:
		out["foliage"] = clampf(1.0 - foliage_have / float(foliage_target), 0.0, 1.0) \
			* habitat.foliage_weight
	var rocks_target := int(ceil(float(pref["rocks_frac"]) * float(region.area)))
	if rocks_target > 0:
		out["rocks"] = clampf(1.0 - rocks_have / float(rocks_target), 0.0, 1.0) \
			* habitat.rocks_weight

	if bool(pref["wants_shelter"]) and not has_shelter:
		out["shelter"] = habitat.shelter_weight
	if bool(pref["wants_enrichment"]) and not has_toy:
		out["enrichment"] = habitat.enrichment_weight

	out["foliage_have"] = foliage_have
	out["foliage_target"] = foliage_target
	out["foliage_pref"] = want_plant
	out["rocks_have"] = rocks_have
	out["rocks_target"] = rocks_target
	out["has_shelter"] = has_shelter
	out["has_toy"] = has_toy
	out["wants_shelter"] = bool(pref["wants_shelter"])
	out["wants_enrichment"] = bool(pref["wants_enrichment"])
	return out


# Fraction of the region's cells carrying each zone tag (a cell's zone-tile
# entity can provide several tags; each counts toward its own fraction).
# Cached per region — bootstrap clears the cache on world-change events.
func _terrain_fractions(region: Region) -> Dictionary:
	var cached: Dictionary = _terrain_cache.get(region.region_id, {})
	if not cached.is_empty() and int(cached["area"]) == region.area:
		return cached["fracs"]
	var cellset := {}
	for c in region.cells:
		cellset[c] = true
	var counts := {}
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null or def.zone_kind == &"" or not cellset.has(inst.position):
			continue
		for tag in def.zone_tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	var fracs := {}
	var area := float(max(region.area, 1))
	for tag in counts.keys():
		fracs[tag] = float(counts[tag]) / area
	_terrain_cache[region.region_id] = {"area": region.area, "fracs": fracs}
	return fracs
