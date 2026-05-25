extends ISatisfactionModel
class_name VisitorSatisfactionModel
# Zoo's ISatisfactionModel — Prompt 10.
#
# Baseline = mean of need levels. The engine's AgentPool then layers
# EffectResolver.compute_satisfaction_modifier_for(agent) on top, so
# proximity bonuses from nearby exhibits feed in automatically.


func update_satisfaction(agent: Agent) -> void:
	if agent.need_levels.is_empty():
		agent.satisfaction = 0.5
		return
	var sum: float = 0.0
	for level in agent.need_levels.values():
		sum += level
	agent.satisfaction = sum / agent.need_levels.size()
