extends IAgentBehavior
class_name VisitorBehavior
# Zoo's IAgentBehavior — Prompt 10.
#
# Trivial visitor: pays a ticket on spawn, wanders gently, and when hunger
# crosses threshold seeks the nearest entity whose `satisfies` covers
# hunger. On arrival, pays for food and refills the need. Engine's
# EffectResolver handles the per-day proximity revenue separately — these
# IValueModel posts are the "explicit" purchases.

const SPEED_PER_TICK: float = 0.15
const REACH_DISTANCE: float = 0.6

var _value_model := VisitorValueModel.new()


func on_spawn(agent: Agent) -> void:
	# Entry ticket — IValueModel decides the price, behavior books the income.
	Ledger.post_income(_value_model.compute_entry_fee(agent), "Ticket", &"entry")


func on_need_threshold_crossed(agent: Agent, need_id: StringName) -> void:
	# Find nearest entity that satisfies this need.
	var best_id: int = 0
	var best_dist_sq: float = INF
	for entity_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.get_instance(entity_id)
		var def := inst.get_def()
		if def == null:
			continue
		if not (need_id in def.satisfies):
			continue
		var center := Vector2(inst.position) + Vector2(def.footprint) * 0.5
		var d := center.distance_squared_to(agent.position)
		if d < best_dist_sq:
			best_dist_sq = d
			best_id = entity_id
	if best_id != 0:
		agent.target_entity_id = best_id
		agent.seeking_need = need_id


func on_tick(agent: Agent) -> void:
	if agent.target_entity_id == 0:
		_wander(agent)
		return
	var inst: EntityInstance = EntityRegistry.get_instance(agent.target_entity_id)
	if inst == null:
		# Target was removed mid-trip.
		agent.target_entity_id = 0
		agent.seeking_need = &""
		return
	var def := inst.get_def()
	var target_pos := Vector2(inst.position) + Vector2(def.footprint) * 0.5
	var to_target := target_pos - agent.position
	var dist := to_target.length()
	if dist <= REACH_DISTANCE:
		# Arrived. If this satisfies a need, refill it AND pay for the service.
		if agent.seeking_need == &"hunger":
			Ledger.post_income(
				_value_model.compute_food_purchase(agent),
				"Food",
				inst.entity_def_id)
			agent.need_levels[agent.seeking_need] = 1.0
		agent.target_entity_id = 0
		agent.seeking_need = &""
		return
	agent.position += to_target.normalized() * SPEED_PER_TICK


func _wander(agent: Agent) -> void:
	# Gentle random drift through the sim RNG — keeps determinism.
	var dx := SimClock.rng.randf_range(-0.05, 0.05)
	var dy := SimClock.rng.randf_range(-0.05, 0.05)
	agent.position += Vector2(dx, dy)


func on_despawn(_agent: Agent) -> void:
	pass
