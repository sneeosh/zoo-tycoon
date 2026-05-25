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
const BROWSE_VIEW_POS := &"browse_view_pos"  # Vector2 view-cell center
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
	var fee := _value_model.compute_entry_fee(agent)
	Ledger.post_income(fee, "Ticket", &"entry")
	ZooBootstrap.money_floated.emit(fee, agent.position)
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
			var price := _value_model.compute_food_purchase(agent)
			Ledger.post_income(price, "Food", inst.entity_def_id)
			ZooBootstrap.money_floated.emit(price, agent.position)
			agent.need_levels[agent.seeking_need] = 1.0
		agent.target_entity_id = 0
		agent.seeking_need = &""
		agent.behavior_state[STATE] = ST_BROWSING
		return
	agent.position += to_target.normalized() * _walking_speed(agent)


func _step_browsing(agent: Agent) -> void:
	# Visitors walk to a *viewing cell* adjacent to the region (outside it),
	# not the region's centroid. Standing inside the exhibit on top of the
	# animals reads as a bug; gathering at the fence line reads as a crowd.
	var target_region_id: int = agent.behavior_state.get(BROWSE_TARGET, 0)
	var region: Region = null
	if target_region_id > 0:
		region = RegionRegistry.get_region(target_region_id)
	if region == null or region.cells.is_empty():
		_pick_browse_target(agent)
		agent.position += Vector2(
			SimClock.rng.randf_range(-0.05, 0.05),
			SimClock.rng.randf_range(-0.05, 0.05))
		return
	var view_pos: Vector2 = agent.behavior_state.get(BROWSE_VIEW_POS, Vector2.INF)
	if view_pos == Vector2.INF:
		# Region was picked but no view point yet (loaded save, edge case).
		view_pos = _pick_viewing_point(region, agent)
		agent.behavior_state[BROWSE_VIEW_POS] = view_pos
	var to_target := view_pos - agent.position
	if to_target.length() <= BROWSE_ARRIVAL_DISTANCE:
		var linger_until: int = agent.behavior_state.get(LINGER_UNTIL, 0)
		if linger_until == 0:
			agent.behavior_state[LINGER_UNTIL] = SimClock.current_tick + \
				_linger_duration_for_region(agent, region)
		elif SimClock.current_tick >= linger_until:
			_pick_browse_target(agent)
			agent.behavior_state[LINGER_UNTIL] = 0
			return
		# Drift while lingering — gives the impression of looking around
		# without overlapping with other visitors at the same fence spot.
		agent.position += Vector2(
			SimClock.rng.randf_range(-0.04, 0.04),
			SimClock.rng.randf_range(-0.04, 0.04))
		return
	agent.position += to_target.normalized() * _walking_speed(agent) * BROWSE_SPEED_FACTOR


# A viewing cell is a tile adjacent (4-neighbor) to the region but NOT in it.
# Picking randomly among the candidates spreads visitors around the perimeter
# instead of stacking them on one spot. Returns the world-space center of the
# chosen cell. Falls back to the region centroid if the region has no
# exterior neighbors (fully surrounded — shouldn't happen in practice).
func _pick_viewing_point(region: Region, _agent: Agent) -> Vector2:
	var cell_set := {}
	for c in region.cells:
		cell_set[c] = true
	var candidates: Array[Vector2i] = []
	var neighbors: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)]
	for c in region.cells:
		for n in neighbors:
			var ext := c + n
			if cell_set.has(ext):
				continue
			# Skip cells inside another region — those are someone else's
			# exhibit, not a viewing platform.
			if RegionRegistry.region_at_cell(ext) != null:
				continue
			candidates.append(ext)
	if candidates.is_empty():
		return _region_centroid(region)
	# A bit of noise inside the chosen cell so two visitors landing on the
	# same viewing slot don't pixel-stack.
	var picked: Vector2i = candidates[SimClock.rng.randi_range(0, candidates.size() - 1)]
	var jitter := Vector2(
		SimClock.rng.randf_range(0.2, 0.8),
		SimClock.rng.randf_range(0.2, 0.8))
	return Vector2(picked) + jitter


func _region_centroid(region: Region) -> Vector2:
	var sum := Vector2.ZERO
	for c in region.cells:
		sum += Vector2(c)
	return sum / float(region.cells.size()) + Vector2(0.5, 0.5)


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


# Linger duration at a region, in ticks. Scales with appeal_match_region:
#   appeal ≤ FLOOR → BASE (visitor glances and moves on)
#   appeal = 1     → MAX (a region full of perfect-match exhibits holds them)
# A small random jitter (±15%) prevents identical-trait visitors arriving
# together from departing in unison.
func _linger_duration_for_region(_agent: Agent, region: Region) -> int:
	var agent_type: AgentType = ContentDB.get_agent_type(_agent.agent_type_id)
	if agent_type == null:
		return LINGER_TICKS_MIN
	var appeal := EffectResolver.appeal_match_region(agent_type, region)
	var base: float
	if appeal <= LINGER_APPEAL_FLOOR:
		base = LINGER_TICKS_BASE
	else:
		var t := (appeal - LINGER_APPEAL_FLOOR) / (1.0 - LINGER_APPEAL_FLOOR)
		base = lerpf(LINGER_TICKS_MIN, LINGER_TICKS_MAX, clampf(t, 0.0, 1.0))
	var jitter := SimClock.rng.randf_range(0.85, 1.15)
	return int(base * jitter)


# Browse target picked from populated Regions, weighted by
# appeal_match_region against the agent type's preferences. Plain-
# roulette pick — higher-match regions are more likely but not
# certain, so the same agent visits varied regions over its stay.
func _pick_browse_target(agent: Agent) -> void:
	var agent_type: AgentType = ContentDB.get_agent_type(agent.agent_type_id)
	if agent_type == null:
		agent.behavior_state[BROWSE_TARGET] = 0
		return
	var candidates: Array[int] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for region in RegionRegistry.all_regions():
		# Empty regions don't have appeal — skip.
		if region.placements.is_empty():
			continue
		var score := EffectResolver.appeal_match_region(agent_type, region)
		if score <= 0.0:
			continue
		candidates.append(region.region_id)
		weights.append(score)
		total_weight += score
	if candidates.is_empty():
		agent.behavior_state[BROWSE_TARGET] = 0
		agent.behavior_state[BROWSE_VIEW_POS] = Vector2.INF
		return
	var picked_region_id: int = candidates[candidates.size() - 1]
	var pick := SimClock.rng.randf() * total_weight
	var accum: float = 0.0
	for i in candidates.size():
		accum += weights[i]
		if pick <= accum:
			picked_region_id = candidates[i]
			break
	agent.behavior_state[BROWSE_TARGET] = picked_region_id
	var region := RegionRegistry.get_region(picked_region_id)
	if region != null:
		agent.behavior_state[BROWSE_VIEW_POS] = _pick_viewing_point(region, agent)
	else:
		agent.behavior_state[BROWSE_VIEW_POS] = Vector2.INF
