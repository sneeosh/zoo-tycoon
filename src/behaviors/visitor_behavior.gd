extends IAgentBehavior
class_name VisitorBehavior
# Zoo's IAgentBehavior — visitor lifecycle with per-agent trait variation.
#
# Lifecycle:
#
#   spawn → BROWSING → (hunger fires) → SEEKING → satisfy → BROWSING
#         → (timer expires OR satisfaction tanks) → LEAVING → despawn
#
# Variation comes from traits sampled at spawn (see design/tuning/agents.md).
# No explicit anti-swarm code: when two visitors get hungry, each adds their
# own `distance_fudge` noise to perceived food-stand distances, so they
# naturally route to different stands when the secondary option is close.
# This gives an alive-looking crowd from emergent variation, not a clever
# scoring formula every visitor runs identically.
#
# Browse target selection is weighted by EffectResolver.appeal_match so
# visitors gravitate toward exhibits that match the agent type's preferences.

const REACH_DISTANCE: float = 0.6
const BROWSE_ARRIVAL_DISTANCE: float = 1.5
const BROWSE_SPEED_FACTOR: float = 0.55   # browse pace = walking_speed * this
const HUNGRY_WEIGHT: int = 3              # weight bias when picking browse target
# Linger time at a browse target scales with how well the exhibit matches
# the visitor type's preferences (via EffectResolver.appeal_match). A
# perfect match → MAX; a mediocre one → MIN; below FLOOR → BASE so even
# unappealing exhibits get a quick look. This is what makes the cool
# exhibits actually feel cool in-game — visitors crowd them longer.
const LINGER_TICKS_BASE: int = 25
const LINGER_TICKS_MIN: int = 45
const LINGER_TICKS_MAX: int = 160
const LINGER_APPEAL_FLOOR: float = 0.2

# Fallback values if a trait is missing from tuning. Keeps the behavior
# robust to design churn — a missing trait shouldn't crash the sim.
const FALLBACK_WALKING_SPEED: float = 0.18
const FALLBACK_STAY_DURATION: float = 320.0
const FALLBACK_IMPATIENCE: float = 0.25
const FALLBACK_DISTANCE_FUDGE: float = 0.0

const TRAIT_WALKING := &"walking_speed"
const TRAIT_STAY := &"stay_duration"
const TRAIT_IMPATIENCE := &"impatience"
const TRAIT_FUDGE := &"distance_fudge"

# behavior_state keys
const STATE := &"state"
const SPAWN_TICK := &"spawn_tick"
const BROWSE_TARGET := &"browse_target"
const LINGER_UNTIL := &"linger_until"     # 0 = not currently lingering
# Satisfaction at the moment the visitor decided to leave. Reading
# agent.satisfaction in on_despawn isn't right — hunger keeps decaying
# during the walk to the exit, which would penalize otherwise-happy
# visitors. This captures the "review" they'd write on the way out.
const DEPARTURE_SATISFACTION := &"departure_satisfaction"

const ST_BROWSING := &"browsing"
const ST_SEEKING := &"seeking"
const ST_LEAVING := &"leaving"

# Exit point. When zoo design grows a proper entrance/exit tile, point
# this at it. Top-left of the grid for now — matches the MapView gate.
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
	var best_id := _pick_satisfier_with_noise(agent, need_id)
	if best_id == 0:
		return  # nothing satisfies — keep browsing until we leave from frustration
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
		var stay_duration: int = int(agent.traits.get(TRAIT_STAY, FALLBACK_STAY_DURATION))
		if ticks_alive >= stay_duration:
			agent.behavior_state[DEPARTURE_SATISFACTION] = agent.satisfaction
			agent.behavior_state[STATE] = ST_LEAVING
			return
		var impatience: float = agent.traits.get(TRAIT_IMPATIENCE, FALLBACK_IMPATIENCE)
		if agent.satisfaction <= impatience:
			# Frustrated departure — visitor gives up on the zoo.
			agent.behavior_state[DEPARTURE_SATISFACTION] = agent.satisfaction
			agent.behavior_state[STATE] = ST_LEAVING
			return

	if state == ST_SEEKING and agent.target_entity_id != 0:
		_step_toward_target(agent)
		return

	_step_browsing(agent)


func on_despawn(agent: Agent) -> void:
	# Reputation impact: a happy visitor tells their friends (+1), a
	# frustrated one writes a bad review (-1), an in-between one is
	# forgettable (0). We use the satisfaction snapshot captured at
	# departure-decision time, not the moment of despawn, because hunger
	# decay during the walk to the exit would unfairly penalize visitors
	# who had a great visit but got peckish on the way home.
	var rating: float = agent.behavior_state.get(
		DEPARTURE_SATISFACTION, agent.satisfaction)
	if rating >= 0.7:
		ProgressionManager.add_reputation(1)
	elif rating < 0.35:
		ProgressionManager.add_reputation(-1)


# ---------------------------------------------------------------------------
# Movement helpers
# ---------------------------------------------------------------------------

func _walking_speed(agent: Agent) -> float:
	return agent.traits.get(TRAIT_WALKING, FALLBACK_WALKING_SPEED)


func _step_toward_target(agent: Agent) -> void:
	var inst: EntityInstance = EntityRegistry.get_instance(agent.target_entity_id)
	if inst == null:
		# Target removed mid-trip — fall back to browsing.
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
	agent.position += to_target.normalized() * _walking_speed(agent)


func _step_browsing(agent: Agent) -> void:
	var target_id: int = agent.behavior_state.get(BROWSE_TARGET, 0)
	var inst: EntityInstance = null
	if target_id != 0:
		inst = EntityRegistry.get_instance(target_id)
	if inst == null:
		_pick_browse_target(agent)
		agent.position += Vector2(
			SimClock.rng.randf_range(-0.05, 0.05),
			SimClock.rng.randf_range(-0.05, 0.05))
		return
	var def := inst.get_def()
	var center := Vector2(inst.position) + Vector2(def.footprint) * 0.5
	var to_target := center - agent.position
	if to_target.length() <= BROWSE_ARRIVAL_DISTANCE:
		# Arrived. Linger so satisfaction can accrue from proximity effects
		# and the player sees visitors clustered AT the exhibit, not
		# bouncing through it. Linger duration sampled per-arrival.
		var linger_until: int = agent.behavior_state.get(LINGER_UNTIL, 0)
		if linger_until == 0:
			agent.behavior_state[LINGER_UNTIL] = SimClock.current_tick + \
				_linger_duration_for(agent, def)
		elif SimClock.current_tick >= linger_until:
			# Done lingering — move on.
			_pick_browse_target(agent)
			agent.behavior_state[LINGER_UNTIL] = 0
			return
		# Small drift while lingering so visitors at the same exhibit
		# don't perfectly overlap.
		agent.position += Vector2(
			SimClock.rng.randf_range(-0.03, 0.03),
			SimClock.rng.randf_range(-0.03, 0.03))
		return
	agent.position += to_target.normalized() * _walking_speed(agent) * BROWSE_SPEED_FACTOR


func _step_toward_exit(agent: Agent) -> void:
	var to_exit := EXIT_POSITION - agent.position
	if to_exit.length() <= REACH_DISTANCE:
		AgentPool.despawn(agent.agent_id)
		return
	agent.position += to_exit.normalized() * _walking_speed(agent)


# ---------------------------------------------------------------------------
# Target selection
# ---------------------------------------------------------------------------

# Picks an entity satisfying `need_id` minimizing perceived distance. Each
# entity's perceived distance has a per-pick random noise term scaled by the
# visitor's `distance_fudge` trait. Patient/focused visitors (low fudge) see
# distances clearly; distracted/wandering visitors (high fudge) may pick a
# further-but-still-reasonable option. Different visitors getting hungry at
# the same tick therefore pick different stands without any coordination.
func _pick_satisfier_with_noise(agent: Agent, need_id: StringName) -> int:
	var best_id: int = 0
	var best_score: float = INF
	var fudge: float = agent.traits.get(TRAIT_FUDGE, FALLBACK_DISTANCE_FUDGE)
	for entity_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[entity_id]
		var def := inst.get_def()
		if def == null:
			continue
		if not (need_id in def.satisfies):
			continue
		var center := Vector2(inst.position) + Vector2(def.footprint) * 0.5
		var dist := center.distance_to(agent.position)
		var noise := SimClock.rng.randf() * fudge
		var score := dist + noise
		if score < best_score:
			best_score = score
			best_id = entity_id
	return best_id


# Linger duration at a browse target, in ticks. Scales with appeal_match:
#   appeal ≤ FLOOR → BASE (visitor glances and moves on)
#   appeal = 1     → MAX (a perfect-match exhibit holds them)
# A small random jitter (±15%) prevents identical-trait visitors arriving
# together from departing in unison.
func _linger_duration_for(_agent: Agent, def: EntityDef) -> int:
	var agent_type: AgentType = ContentDB.get_agent_type(_agent.agent_type_id)
	if agent_type == null:
		return LINGER_TICKS_MIN
	var appeal := EffectResolver.appeal_match(agent_type, def)
	var base: float
	if appeal <= LINGER_APPEAL_FLOOR:
		base = LINGER_TICKS_BASE
	else:
		var t := (appeal - LINGER_APPEAL_FLOOR) / (1.0 - LINGER_APPEAL_FLOOR)
		base = lerpf(LINGER_TICKS_MIN, LINGER_TICKS_MAX, clampf(t, 0.0, 1.0))
	var jitter := SimClock.rng.randf_range(0.85, 1.15)
	return int(base * jitter)


# Browse target picked from entities with appeal_match > 0, weighted by
# match score. Plain-roulette pick — higher-match exhibits are more likely
# but not certain, so the same agent visits varied exhibits over its stay.
func _pick_browse_target(agent: Agent) -> void:
	var agent_type: AgentType = ContentDB.get_agent_type(agent.agent_type_id)
	if agent_type == null:
		agent.behavior_state[BROWSE_TARGET] = 0
		return
	var candidates: Array[int] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for entity_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[entity_id]
		var def := inst.get_def()
		if def == null:
			continue
		# Skip pure utilities (no appeal) — visitors don't stroll to the toilet.
		if def.appeal_profile.is_empty():
			continue
		var score := EffectResolver.appeal_match(agent_type, def)
		if score <= 0.0:
			continue
		candidates.append(entity_id)
		weights.append(score)
		total_weight += score
	if candidates.is_empty():
		agent.behavior_state[BROWSE_TARGET] = 0
		return
	var pick := SimClock.rng.randf() * total_weight
	var accum: float = 0.0
	for i in candidates.size():
		accum += weights[i]
		if pick <= accum:
			agent.behavior_state[BROWSE_TARGET] = candidates[i]
			return
	# Fallback (FP edge case): pick last candidate.
	agent.behavior_state[BROWSE_TARGET] = candidates[candidates.size() - 1]
