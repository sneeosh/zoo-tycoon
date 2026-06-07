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

const SPACE_WEIGHT: float = 0.5
const SOCIAL_DEFICIT_WEIGHT: float = 0.1
const SOCIAL_EXCESS_WEIGHT: float = 0.05
const NEEDS_DEFICIT_WEIGHT: float = 0.2


func compute_happiness(region: Region, index: int) -> float:
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
	var n: int = region.placements.size()
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

	var penalty: float = space_penalty + social_penalty + needs_penalty
	var base_happiness: float = clampf(1.0 - penalty, 0.0, 1.0)
	var attitude: float = clampf(float(placement.state.get("attitude", 1.0)), 0.0, 1.0)

	return {
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
