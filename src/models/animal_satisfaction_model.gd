extends ISatisfactionModel
class_name AnimalSatisfactionModel
## Welfare for the `animal` AgentType (roadmap 6.6). `Agent.satisfaction`
## becomes the animal's continuous welfare: a weakest-link blend of how well
## its needs (food, water), its herd (social), and its room (space) are met —
## the same shape as the visitor model, so one screaming axis drags the whole
## score down.
##
## This is what makes welfare *watchable*: a starving or lonely or cramped
## animal reads as low-satisfaction (and the behavior paces it toward a trough
## or a herd-mate). It is deliberately kept OUT of the visitor spawn curve by
## the `animal` type's `drives_spawn_balance = false` flag (engine v0.7.0), so a
## miserable lion never suppresses guest arrivals.
##
## Note on the survival pipeline: the slow day-end care model in
## ZooBootstrap._on_day_ending_for_welfare (habitat fit + keepers) remains the
## authority for illness/death/breeding via placement state — see the spec's
## §3d. This model is the continuous, behaviour-driving welfare; unifying the
## two into a single number is a tunable follow-up, not a launch blocker.

const NEEDS_WEIGHT := 0.6   # weakest-link share vs mean


func update_satisfaction(agent: Agent) -> void:
	var rid := int(agent.behavior_state.get("home_region_id", -1))
	var region: Region = RegionRegistry.get_region(rid) if rid >= 0 else null
	if region == null or region.cells.is_empty():
		return  # keep the spawn-neutral 0.5 until the animal is homed

	var species: StringName = agent.behavior_state.get("species", &"")
	var def: PlaceableDef = ContentDB.placeable_defs.get(species)

	var food := float(agent.need_levels.get(&"food", 1.0))
	var water := float(agent.need_levels.get(&"water", 1.0))
	var social := _social_score(agent, region, def)
	var space := _space_score(region, def)

	var axes: Array[float] = [food, water, social, space]
	var lowest := axes[0]
	var total := 0.0
	for a in axes:
		lowest = minf(lowest, a)
		total += a
	var mean := total / float(axes.size())
	agent.satisfaction = clampf(NEEDS_WEIGHT * lowest + (1.0 - NEEDS_WEIGHT) * mean, 0.0, 1.0)


# Herd satisfaction: 1.0 inside [social_min, social_max], falling off when the
# enclosure is under-stocked (lonely) or over-stocked (crowded).
func _social_score(agent: Agent, region: Region, def: PlaceableDef) -> float:
	if def == null:
		return 1.0
	var herd := _conspecifics(agent, region) + 1  # include self
	if herd < def.social_min:
		return clampf(float(herd) / float(maxi(def.social_min, 1)), 0.0, 1.0)
	if herd > def.social_max:
		return clampf(float(def.social_max) / float(herd), 0.0, 1.0)
	return 1.0


# Room to roam: enclosure cells vs the space the resident animals need.
func _space_score(region: Region, def: PlaceableDef) -> float:
	if def == null:
		return 1.0
	var need := 0
	for p: Placement in region.placements:
		var pdef: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
		if pdef != null and not pdef.appeal_contribution.is_empty():
			need += maxi(pdef.space_required, 1)
	if need <= 0:
		return 1.0
	return clampf(float(region.cells.size()) / float(need), 0.0, 1.0)


func _conspecifics(agent: Agent, region: Region) -> int:
	var species: StringName = agent.behavior_state.get("species", &"")
	var count := 0
	for aid in AgentPool.get_agents_by_type(&"animal"):
		if aid == agent.agent_id:
			continue
		var other: Agent = AgentPool.get_agent(aid)
		if other == null:
			continue
		if int(other.behavior_state.get("home_region_id", -1)) != region.region_id:
			continue
		if other.behavior_state.get("species", &"") == species:
			count += 1
	return count
