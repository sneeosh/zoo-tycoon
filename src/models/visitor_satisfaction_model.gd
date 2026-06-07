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

const MEAN_WEIGHT: float = 0.6
const MIN_WEIGHT: float = 0.4


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
	agent.satisfaction = MEAN_WEIGHT * mean + MIN_WEIGHT * lowest
