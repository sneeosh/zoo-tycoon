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

const SPACE_WEIGHT: float = 0.5
const SOCIAL_DEFICIT_WEIGHT: float = 0.1
const SOCIAL_EXCESS_WEIGHT: float = 0.05
const NEEDS_DEFICIT_WEIGHT: float = 0.2


func compute_happiness(region: Region, index: int) -> float:
	if index < 0 or index >= region.placements.size():
		return 1.0
	var placement: Placement = region.placements[index]
	var self_def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
	if self_def == null:
		return 1.0

	var penalty: float = 0.0

	# --- Space ---
	var n: int = region.placements.size()
	var actual_space: float = float(region.area) / float(max(n, 1))
	if actual_space < float(self_def.space_ideal):
		var deficit: float = 1.0 - actual_space / float(self_def.space_ideal)
		penalty += deficit * SPACE_WEIGHT

	# --- Social — same-species companions, excluding self ---
	var companions: int = 0
	for i in region.placements.size():
		if i == index:
			continue
		if region.placements[i].placeable_def_id == self_def.id:
			companions += 1
	if companions < self_def.social_min:
		penalty += float(self_def.social_min - companions) * SOCIAL_DEFICIT_WEIGHT
	if companions > self_def.social_max:
		penalty += float(companions - self_def.social_max) * SOCIAL_EXCESS_WEIGHT

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
	for required_tag in self_def.needs_provided_tags:
		if not provided.has(required_tag):
			penalty += NEEDS_DEFICIT_WEIGHT

	var base_happiness: float = clampf(1.0 - penalty, 0.0, 1.0)

	# --- Attitude ---
	var attitude: float = clampf(float(placement.state.get("attitude", 1.0)), 0.0, 1.0)
	return base_happiness * attitude
