extends IAgentBehavior
class_name AnimalBehavior
## Free-roam behavior for the `animal` AgentType (roadmap 6.6 — animals as
## agents). An animal is a persistent, region-bound Agent: it roams its
## enclosure, walks to a food/water trough when that need runs low, drifts
## toward or away from conspecifics to satisfy its herd preference, and
## otherwise ambles. Its movement is now a *consequence of the model* instead
## of the renderer's old sine-wander lie (North Star principle 2).
##
## Wander randomness comes from a dedicated, fixed-seed RNG (see `rng` below)
## so it stays reproducible without perturbing the visitor/weather/breeding
## sequence. No pathfinding: enclosures are tiny and convex-ish,
## so "step toward target, stay inside the cells, turn back at the bound" reads
## correct and costs nothing (spec §5). State lives in `agent.behavior_state`:
##   species (StringName), home_region_id (int), hx/hy (current heading).
## The spawner (ZooBootstrap) sets species/home_region_id right after spawn.

const SEEK_THRESHOLD := 0.45   # need level below which the animal heads to a trough
const ARRIVE := 0.7            # within this of a trough cell-centre = "fed"
const REFILL_PER_TICK := 0.5   # how much of the need a tick at the trough restores
const TURN_LERP := 0.18        # heading smoothing — animals turn, they don't snap
const RETARGET_CHANCE := 0.02  # idle: chance per tick to pick a fresh heading

# Dedicated deterministic RNG for idle wander. Reproducible (fixed seed), but
# DELIBERATELY separate from SimClock.rng so per-tick animal jitter never
# perturbs the visitor/weather/breeding sequence the economy is tuned against.
# Save/load restores the persisted position, not a replayed wander, so a
# separate stream costs us nothing in fidelity.
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 0x5EEDA11


func on_need_threshold_crossed(agent: Agent, need_id: StringName) -> void:
	# React on the transition tick: start heading for the matching trough.
	if need_id == &"food" or need_id == &"water":
		agent.seeking_need = need_id


func on_tick(agent: Agent) -> void:
	var rid := int(agent.behavior_state.get("home_region_id", -1))
	if rid < 0:
		return
	var region: Region = RegionRegistry.get_region(rid)
	if region == null or region.cells.is_empty():
		return  # enclosure gone — the lifecycle reconcile will despawn us
	var heading := _decide_heading(agent, region)
	_step(agent, region, heading)
	_maybe_refill(agent, region)


# --- Decision ------------------------------------------------------------

func _decide_heading(agent: Agent, region: Region) -> Vector2:
	# 1. Seek the lowest unmet need if a provider exists in the enclosure.
	var need := _lowest_unmet_need(agent)
	if need != &"":
		var tag := &"provides_food" if need == &"food" else &"provides_water"
		var cell = _nearest_provider_cell(agent, region, tag)
		if cell != null:
			agent.seeking_need = need
			return (cell - agent.position)
	agent.seeking_need = &""

	# 2. Social drift — toward conspecifics if under herd minimum, away if over.
	var social := _social_drift(agent, region)
	if social != Vector2.ZERO:
		return social

	# 3. Idle amble — keep heading, occasionally pick a new one.
	var h := Vector2(agent.behavior_state.get("hx", 0.0), agent.behavior_state.get("hy", 0.0))
	if h == Vector2.ZERO or rng.randf() < RETARGET_CHANCE:
		h = Vector2.from_angle(rng.randf() * TAU)
	return h


func _lowest_unmet_need(agent: Agent) -> StringName:
	var f := float(agent.need_levels.get(&"food", 1.0))
	var w := float(agent.need_levels.get(&"water", 1.0))
	if f < SEEK_THRESHOLD and f <= w:
		return &"food"
	if w < SEEK_THRESHOLD:
		return &"water"
	return &""


func _social_drift(agent: Agent, region: Region) -> Vector2:
	var species: StringName = agent.behavior_state.get("species", &"")
	var def: PlaceableDef = ContentDB.placeable_defs.get(species)
	if def == null:
		return Vector2.ZERO
	var count := 0
	var nearest_pos = null
	var nearest_d := INF
	for aid in AgentPool.get_agents_by_type(&"animal"):
		if aid == agent.agent_id:
			continue
		var other: Agent = AgentPool.get_agent(aid)
		if other == null:
			continue
		if int(other.behavior_state.get("home_region_id", -1)) != region.region_id:
			continue
		if other.behavior_state.get("species", &"") != species:
			continue
		count += 1
		var d := agent.position.distance_to(other.position)
		if d < nearest_d:
			nearest_d = d
			nearest_pos = other.position
	if nearest_pos == null:
		return Vector2.ZERO
	var herd := count + 1  # include self
	if herd < def.social_min:
		return nearest_pos - agent.position          # cluster up
	if herd > def.social_max and nearest_d < 1.5:
		return agent.position - nearest_pos          # too crowded — peel off
	return Vector2.ZERO


# --- Movement ------------------------------------------------------------

func _step(agent: Agent, region: Region, goal_dir: Vector2) -> void:
	var speed := float(agent.traits.get("wander_speed", 0.03))
	var cur := Vector2(agent.behavior_state.get("hx", 0.0), agent.behavior_state.get("hy", 0.0))
	var desired := goal_dir.normalized() if goal_dir.length() > 0.0001 else cur
	if desired == Vector2.ZERO:
		desired = Vector2.from_angle(rng.randf() * TAU)
	var newh := desired if cur == Vector2.ZERO else cur.lerp(desired, TURN_LERP)
	if newh.length() < 0.0001:
		newh = desired
	newh = newh.normalized()

	var np := agent.position + newh * speed
	if _inside(np, region):
		agent.position = np
		agent.behavior_state["hx"] = newh.x
		agent.behavior_state["hy"] = newh.y
		return
	# Hit the enclosure bound: turn back toward the centre with a little jitter,
	# and rescue the rare case where we ended up outside the cells entirely.
	var centre := _centroid(region)
	var back := centre - agent.position
	var bh := back.normalized() if back.length() > 0.001 else Vector2.from_angle(rng.randf() * TAU)
	bh = bh.rotated(rng.randf_range(-0.6, 0.6)).normalized()
	agent.behavior_state["hx"] = bh.x
	agent.behavior_state["hy"] = bh.y
	if not _inside(agent.position, region):
		agent.position = centre


func _maybe_refill(agent: Agent, region: Region) -> void:
	if agent.seeking_need == &"":
		return
	var tag := &"provides_food" if agent.seeking_need == &"food" else &"provides_water"
	var cell = _nearest_provider_cell(agent, region, tag)
	if cell != null and agent.position.distance_to(cell) <= ARRIVE:
		var lvl := float(agent.need_levels.get(agent.seeking_need, 0.0))
		agent.need_levels[agent.seeking_need] = minf(1.0, lvl + REFILL_PER_TICK)
		if agent.need_levels[agent.seeking_need] >= 0.99:
			agent.seeking_need = &""


# --- Helpers -------------------------------------------------------------

# Cell-centre of the nearest in-region placement whose own_tags carry `tag`,
# or null if the enclosure has no such provider.
func _nearest_provider_cell(agent: Agent, region: Region, tag: StringName):
	var best = null
	var best_d := INF
	for p: Placement in region.placements:
		var def: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
		if def == null or not (tag in def.own_tags):
			continue
		var cell := p.primary_cell
		if not (cell in region.cells):
			cell = region.cells[0]
		var centre := Vector2(cell) + Vector2(0.5, 0.5)
		var d := agent.position.distance_to(centre)
		if d < best_d:
			best_d = d
			best = centre
	return best


func _inside(pos: Vector2, region: Region) -> bool:
	return Vector2i(floori(pos.x), floori(pos.y)) in region.cells


func _centroid(region: Region) -> Vector2:
	var sum := Vector2.ZERO
	for c in region.cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	return sum / float(region.cells.size())
