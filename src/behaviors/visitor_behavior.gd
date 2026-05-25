extends IAgentBehavior
class_name VisitorBehavior
# Zoo's IAgentBehavior — visitor lifecycle.
#
# A visitor's life:
#
#   spawn → BROWSING → (hunger fires) → SEEKING → satisfy need → BROWSING
#         → (timer expires OR satisfaction drops) → LEAVING → despawn
#
# Compared to the v0.1 implementation this:
#   * picks the LEAST-CROWDED of nearby food stands rather than nearest,
#     using engine v0.3's AgentPool.count_targeting() to break swarms;
#   * actually moves between exhibits when not hungry instead of standing
#     still in spawn position;
#   * leaves after STAY_DURATION_TICKS so the park breathes and new
#     visitors aren't stacked on top of departing ones;
#   * leaves early if satisfaction tanks (no food found / sad zoo).

const WANDER_SPEED: float = 0.18           # moving with intent
const BROWSE_SPEED: float = 0.10           # strolling between exhibits
const REACH_DISTANCE: float = 0.6          # close enough to "arrive"
const BROWSE_ARRIVAL_DISTANCE: float = 1.5 # how close to count an exhibit visited
const STAY_DURATION_TICKS: int = 320       # ~16s at 20tps × 1×
const EARLY_LEAVE_SATISFACTION: float = 0.25
const CROWD_PENALTY_TILES: float = 1.5     # adds N tiles of "distance" per other targeter

# behavior_state keys
const STATE := &"state"
const SPAWN_TICK := &"spawn_tick"
const BROWSE_TARGET := &"browse_target"

const ST_BROWSING := &"browsing"
const ST_SEEKING := &"seeking"
const ST_LEAVING := &"leaving"

# Exit point. Park-level concept — when there's a proper entrance/exit
# tile in zoo design, point this at it. Top-left for now.
const EXIT_POSITION := Vector2(0.0, 0.0)

var _value_model := VisitorValueModel.new()


func on_spawn(agent: Agent) -> void:
	Ledger.post_income(_value_model.compute_entry_fee(agent), "Ticket", &"entry")
	agent.behavior_state[SPAWN_TICK] = SimClock.current_tick
	agent.behavior_state[STATE] = ST_BROWSING
	agent.behavior_state[BROWSE_TARGET] = 0
	_pick_browse_target(agent)


func on_need_threshold_crossed(agent: Agent, need_id: StringName) -> void:
	if agent.behavior_state.get(STATE) == ST_LEAVING:
		return
	var best_id := _pick_least_crowded_satisfier(agent, need_id)
	if best_id == 0:
		return  # nothing can satisfy — stay browsing until we leave from frustration
	agent.target_entity_id = best_id
	agent.seeking_need = need_id
	agent.behavior_state[STATE] = ST_SEEKING


func on_tick(agent: Agent) -> void:
	var state: StringName = agent.behavior_state.get(STATE, ST_BROWSING)

	if state == ST_LEAVING:
		_step_toward_exit(agent)
		return

	# Time-to-leave checks (don't interrupt an active food-seek mid-trip).
	if state != ST_SEEKING:
		var ticks_alive: int = SimClock.current_tick - int(agent.behavior_state.get(SPAWN_TICK, 0))
		if ticks_alive >= STAY_DURATION_TICKS:
			agent.behavior_state[STATE] = ST_LEAVING
			return
		if agent.satisfaction <= EARLY_LEAVE_SATISFACTION:
			# Visitor gives up on the zoo — counts as a bad-experience departure.
			agent.behavior_state[STATE] = ST_LEAVING
			return

	if state == ST_SEEKING and agent.target_entity_id != 0:
		_step_toward_target(agent)
		return

	_step_browsing(agent)


func on_despawn(_agent: Agent) -> void:
	pass


# ---------------------------------------------------------------------------
# Movement helpers
# ---------------------------------------------------------------------------

func _step_toward_target(agent: Agent) -> void:
	var inst: EntityInstance = EntityRegistry.get_instance(agent.target_entity_id)
	if inst == null:
		# Target was removed mid-trip — fall back to browsing.
		agent.target_entity_id = 0
		agent.seeking_need = &""
		agent.behavior_state[STATE] = ST_BROWSING
		return
	var def := inst.get_def()
	var target_pos := Vector2(inst.position) + Vector2(def.footprint) * 0.5
	var to_target := target_pos - agent.position
	var dist := to_target.length()
	if dist <= REACH_DISTANCE:
		if agent.seeking_need == &"hunger":
			Ledger.post_income(
				_value_model.compute_food_purchase(agent),
				"Food", inst.entity_def_id)
			agent.need_levels[agent.seeking_need] = 1.0
		agent.target_entity_id = 0
		agent.seeking_need = &""
		agent.behavior_state[STATE] = ST_BROWSING
		return
	agent.position += to_target.normalized() * WANDER_SPEED


func _step_browsing(agent: Agent) -> void:
	var target_id: int = agent.behavior_state.get(BROWSE_TARGET, 0)
	var inst: EntityInstance = null
	if target_id != 0:
		inst = EntityRegistry.get_instance(target_id)
	if inst == null:
		_pick_browse_target(agent)
		# Mild drift while we figure out where to go next.
		agent.position += Vector2(
			SimClock.rng.randf_range(-0.05, 0.05),
			SimClock.rng.randf_range(-0.05, 0.05))
		return
	var def := inst.get_def()
	var center := Vector2(inst.position) + Vector2(def.footprint) * 0.5
	var to_target := center - agent.position
	if to_target.length() <= BROWSE_ARRIVAL_DISTANCE:
		# Arrived at an exhibit — soak in the appeal, then pick a new one.
		_pick_browse_target(agent)
		return
	agent.position += to_target.normalized() * BROWSE_SPEED


func _step_toward_exit(agent: Agent) -> void:
	var to_exit := EXIT_POSITION - agent.position
	if to_exit.length() <= REACH_DISTANCE:
		AgentPool.despawn(agent.agent_id)
		return
	agent.position += to_exit.normalized() * WANDER_SPEED


# ---------------------------------------------------------------------------
# Target selection
# ---------------------------------------------------------------------------

# Picks an entity satisfying `need_id` minimizing (distance + crowd_penalty).
# Returns 0 if no entity can satisfy. Uses engine v0.3's count_targeting() so
# the second visitor to get hungry naturally picks a less crowded option.
func _pick_least_crowded_satisfier(agent: Agent, need_id: StringName) -> int:
	var best_id: int = 0
	var best_score: float = INF
	for entity_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[entity_id]
		var def := inst.get_def()
		if def == null:
			continue
		if not (need_id in def.satisfies):
			continue
		var center := Vector2(inst.position) + Vector2(def.footprint) * 0.5
		var dist := center.distance_to(agent.position)
		var crowding := AgentPool.count_targeting(entity_id)
		var score := dist + crowding * CROWD_PENALTY_TILES
		if score < best_score:
			best_score = score
			best_id = entity_id
	return best_id


# Browse target = a random thrill-bearing exhibit. Falls back to ANY entity
# if no thrill-bearing one exists (small zoos).
func _pick_browse_target(agent: Agent) -> void:
	var candidates: Array[int] = []
	var fallback: Array[int] = []
	for entity_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[entity_id]
		var def := inst.get_def()
		if def == null:
			continue
		fallback.append(entity_id)
		if def.appeal_profile.has(&"thrill"):
			candidates.append(entity_id)
	if candidates.is_empty():
		candidates = fallback
	if candidates.is_empty():
		agent.behavior_state[BROWSE_TARGET] = 0
		return
	agent.behavior_state[BROWSE_TARGET] = candidates[SimClock.rng.randi() % candidates.size()]
