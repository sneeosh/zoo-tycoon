extends ISatisfactionModel
class_name VisitorSatisfactionModel
# Zoo's ISatisfactionModel.
#
# v0.5.x — four-need model (adaptation plan §2 item 3). Baseline blends the
# MEAN of all need levels with the single LOWEST need:
#
#   satisfaction = MEAN_WEIGHT * mean + MIN_WEIGHT * min
#
# The min term is what makes amenities matter: a guest whose bladder is
# empty isn't "mostly happy because three of four needs are fine" — one
# screaming need ruins the visit. Without this, the four-need system would
# average away into the same flat number the single-need model produced.
#
# The engine's AgentPool then layers
# EffectResolver.compute_satisfaction_modifier_for(agent) on top, so
# proximity bonuses (and the Compost Building's stink penalty) feed in
# automatically.

# With four needs, one is usually mid-decay at any moment, so a heavy MIN
# term kept satisfaction chronically low (guests left unhappy → reputation
# bled away even in a well-served park). The min term still rewards keeping
# every need covered, but it no longer dominates.
const MEAN_WEIGHT: float = 0.78
const MIN_WEIGHT: float = 0.22


# Satisfaction = how well the guest's NEEDS are met blended with how much
# they're ENJOYING the exhibits. Comfort keeps them from leaving; enjoyment is
# what earns the park its reputation — so a great zoo with stocked amenities
# sends guests home delighted, and a dull or neglected one doesn't.
const NEEDS_WEIGHT: float = 0.68
const ENJOY_WEIGHT: float = 0.32


func update_satisfaction(agent: Agent) -> void:
	if agent.need_levels.is_empty():
		agent.satisfaction = 0.5
		return
	var sum: float = 0.0
	var lowest: float = 1.0
	for level: float in agent.need_levels.values():
		sum += level
		if level < lowest:
			lowest = level
	var mean: float = sum / agent.need_levels.size()
	var needs_blend: float = MEAN_WEIGHT * mean + MIN_WEIGHT * lowest
	var enjoyment: float = float(agent.behavior_state.get(&"enjoyment", 0.5))
	agent.satisfaction = NEEDS_WEIGHT * needs_blend + ENJOY_WEIGHT * enjoyment
