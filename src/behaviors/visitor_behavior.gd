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
const BROWSE_ARRIVAL_DISTANCE: float = 0.5
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
const BROWSE_VIEW_POS := &"browse_view_pos"  # Vector2 view-cell center (free-roam)
# Path cell this visitor is walking toward to view the current exhibit. Picked
# once per browse target so the visitor commits to a specific viewing spot
# instead of stopping at the first cell within engagement distance — that
# spread is what stops the whole crowd from clumping at one path tile.
const BROWSE_PATH_CELL := &"browse_path_cell"
const LINGER_UNTIL := &"linger_until"     # 0 = not currently lingering
# Satisfaction at the moment the visitor decided to leave. Reading
# agent.satisfaction in on_despawn isn't right — hunger keeps decaying
# during the walk to the exit, which would penalize otherwise-happy
# visitors. This captures the "review" they'd write on the way out.
const DEPARTURE_SATISFACTION := &"departure_satisfaction"
# Running mean of satisfaction across the whole visit — the visitor's overall
# "review", used for the reputation swing on despawn. Averaging beats a single
# end-of-visit snapshot, which was noisy (one decaying need at the exit tick
# could turn a great visit into a bad review).
# Recency-weighted mood (exponential moving average of satisfaction). It's the
# guest's "review" on the way out: it tracks how they felt *recently*, so a
# visit that ended badly (needs collapsed, couldn't be served) leaves a poor
# review even if it started fine — while smoothing the per-tick noise that a
# single end-of-visit snapshot suffered from.
const MOOD := &"mood"
const MOOD_RATE: float = 0.012
# Enjoyment — the "saw amazing animals" half of satisfaction. Decays slowly and
# is topped up each time the guest views an exhibit, by how good that exhibit
# is. This is what ties reputation to building great exhibits (the genre's
# core loop), not just to keeping the restrooms stocked.
const ENJOYMENT := &"enjoyment"
const ENJOY_DECAY: float = 0.0013     # per tick; a boring park bores guests
const VIEW_BOOST: float = 0.22        # added per exhibit view, scaled by appeal

const ST_BROWSING := &"browsing"
const ST_SEEKING := &"seeking"
const ST_LEAVING := &"leaving"

# Exit point. When zoo design grows a proper entrance/exit tile, point
# this at it. Bottom-left of the grid — matches the MapView gate.
const EXIT_POSITION := Vector2(0.0, 17.0)

# --- Path navigation (engine v0.6.1 WalkableNetwork) ------------------------
# Guests prefer to walk the player-built path network. When a usable route
# exists they stick to paths and "view" exhibits / use amenities from a path
# cell; when there's no network, the guest is off-network, or the goal isn't
# reachable by path, they fall back to the legacy free-roam movement so the
# game still works with zero paths (and the existing economic-loop tests stay
# green). This is the sanctioned rollout step — free-roam is the fallback
# until paths are proven, not a parallel system.
const GATE_CELL := Vector2i(0, 17)        # network root / exit (entrance gate)
const AMENITY_ENGAGE_D := 1               # must stand next to a stand to use it
# _path_move outcomes.
const PATH_MOVING := 0                     # stepping along the network
const PATH_ARRIVED := 1                    # within engagement distance of goal
const PATH_NONE := 2                       # no usable route → caller free-roams
# behavior_state key the engine navigator reads (plain String, not StringName).
const NAV_TARGET := "nav_target"

var _value_model := VisitorValueModel.new()


func on_spawn(agent: Agent) -> void:
	# The engine's auto-spawn lands agents at Vector2.ZERO; explicit zoo-side
	# spawns can pass any position. Either way, an auto-spawn at (0,0) puts the
	# guest at the top-left of the grid which is no longer where the gate is.
	# Snap auto-spawns onto the actual gate cell so guests visibly enter
	# through the ticket booth.
	if agent.position == Vector2.ZERO:
		agent.position = Vector2(GATE_CELL)
	var fee := _value_model.compute_entry_fee(agent)
	Ledger.post_income(fee, "Ticket", &"entry")
	ZooBootstrap.money_floated.emit(fee, agent.position)
	agent.behavior_state[SPAWN_TICK] = SimClock.current_tick
	agent.behavior_state[STATE] = ST_BROWSING
	agent.behavior_state[BROWSE_TARGET] = 0
	agent.behavior_state[MOOD] = 0.6
	agent.behavior_state[ENJOYMENT] = 0.5
	_pick_browse_target(agent)


func on_need_threshold_crossed(agent: Agent, need_id: StringName) -> void:
	if agent.behavior_state.get(STATE) == ST_LEAVING:
		return
	# If we're already seeking another amenity, only switch when the newly
	# crossed need is more urgent (lower current level) than the one we're
	# already chasing. Otherwise the next threshold crossing would abandon a
	# half-finished trip and the agent ends up cycling between amenities,
	# never actually satisfying any — which is what tanks the rep.
	if agent.behavior_state.get(STATE) == ST_SEEKING and agent.seeking_need != &"":
		var current_level: float = float(agent.need_levels.get(agent.seeking_need, 1.0))
		var new_level: float = float(agent.need_levels.get(need_id, 1.0))
		if new_level >= current_level:
			return
	var best_id := _pick_satisfier_with_noise(agent, need_id)
	if best_id == 0:
		return  # nothing satisfies — keep browsing until we leave from frustration
	agent.target_entity_id = best_id
	agent.seeking_need = need_id
	agent.behavior_state[STATE] = ST_SEEKING
	_clear_nav(agent)   # new intent → re-plan the route on the next tick


func on_tick(agent: Agent) -> void:
	var state: StringName = agent.behavior_state.get(STATE, ST_BROWSING)
	# Enjoyment ebbs over time (so a dull park bores guests); views top it up.
	agent.behavior_state[ENJOYMENT] = maxf(0.0,
		float(agent.behavior_state.get(ENJOYMENT, 0.5)) - ENJOY_DECAY)
	# Track the recency-weighted mood (the despawn review) only DURING the
	# visit — not on the long walk to the exit, where needs decay with no
	# refills and would poison an otherwise-good review.
	if state != ST_LEAVING:
		agent.behavior_state[MOOD] = float(agent.behavior_state.get(MOOD, 0.6)) * (1.0 - MOOD_RATE) \
			+ agent.satisfaction * MOOD_RATE

	if state == ST_LEAVING:
		_nav_leave(agent)
		return

	# Time-to-leave checks (don't interrupt an active food-seek mid-trip).
	if state != ST_SEEKING:
		var ticks_alive: int = SimClock.current_tick - int(agent.behavior_state.get(SPAWN_TICK, 0))
		var stay_duration: int = int(agent.traits.get(TRAIT_STAY, FALLBACK_STAY_DURATION))
		if ticks_alive >= stay_duration:
			agent.behavior_state[DEPARTURE_SATISFACTION] = agent.satisfaction
			agent.behavior_state[STATE] = ST_LEAVING
			_clear_nav(agent)
			return
		var impatience: float = agent.traits.get(TRAIT_IMPATIENCE, FALLBACK_IMPATIENCE)
		if agent.satisfaction <= impatience:
			# Frustrated departure — visitor gives up on the zoo.
			agent.behavior_state[DEPARTURE_SATISFACTION] = agent.satisfaction
			agent.behavior_state[STATE] = ST_LEAVING
			_clear_nav(agent)
			return

	if state == ST_SEEKING and agent.target_entity_id != 0:
		_nav_seek(agent)
		return

	_nav_browse(agent)


func on_despawn(agent: Agent) -> void:
	# Reputation impact: a happy visitor tells their friends (+1), a
	# frustrated one writes a bad review (-1), an in-between one is
	# forgettable (0). We use the satisfaction snapshot captured at
	# departure-decision time, not the moment of despawn, because hunger
	# decay during the walk to the exit would unfairly penalize visitors
	# who had a great visit but got peckish on the way home.
	# The guest's review is their recency-weighted mood on the way out.
	var rating: float = float(agent.behavior_state.get(MOOD, agent.satisfaction))
	if rating >= 0.68:
		ProgressionManager.add_reputation(1)
	elif rating < 0.42:
		ProgressionManager.add_reputation(-1)


# ---------------------------------------------------------------------------
# Path navigation — walk the network when one is usable, else free-roam.
# ---------------------------------------------------------------------------

# Leaving: head for the entrance gate on the path, then despawn.
func _nav_leave(agent: Agent) -> void:
	var anchors: Array[Vector2i] = [GATE_CELL]
	match _path_move(agent, anchors, 0):
		PATH_ARRIVED:
			AgentPool.despawn(agent.agent_id)
		PATH_MOVING:
			pass
		_:
			_step_toward_exit(agent)   # legacy free-roam to the exit


# Seeking a need-satisfier: walk to a path cell beside it, then transact.
func _nav_seek(agent: Agent) -> void:
	var inst: EntityInstance = EntityRegistry.get_instance(agent.target_entity_id)
	if inst == null:
		agent.target_entity_id = 0
		agent.seeking_need = &""
		agent.behavior_state[STATE] = ST_BROWSING
		_clear_nav(agent)
		return
	match _path_move(agent, _amenity_anchors(inst), AMENITY_ENGAGE_D):
		PATH_MOVING:
			return
		PATH_ARRIVED:
			_satisfy_need_at(agent, inst)
			agent.target_entity_id = 0
			agent.seeking_need = &""
			agent.behavior_state[STATE] = ST_BROWSING
			_clear_nav(agent)
			# If other needs are still below threshold, chain into the next
			# seek immediately. The engine only re-fires threshold_crossed when
			# a need goes ABOVE threshold and then crosses back below — so a
			# need that was already low before this trip would otherwise be
			# stranded until the visitor leaves frustrated.
			_seek_next_unmet_need(agent)
		_:
			_step_toward_target(agent)   # legacy free-roam (satisfies on reach)


# After satisfying one need, look at the agent's other needs and start seeking
# the most urgent one still below threshold. Mirrors on_need_threshold_crossed
# but driven by state inspection, not the engine signal.
func _seek_next_unmet_need(agent: Agent) -> void:
	var type: AgentType = ContentDB.get_agent_type(agent.agent_type_id)
	if type == null:
		return
	var lowest_id: StringName = &""
	var lowest_level: float = INF
	for ns: NeedSpec in type.needs:
		if ns.need == null:
			continue
		var nid: StringName = ns.need.id
		var lvl: float = float(agent.need_levels.get(nid, 1.0))
		if lvl < ns.threshold and lvl < lowest_level:
			lowest_id = nid
			lowest_level = lvl
	if lowest_id == &"":
		return
	var best_id := _pick_satisfier_with_noise(agent, lowest_id)
	if best_id == 0:
		return
	agent.target_entity_id = best_id
	agent.seeking_need = lowest_id
	agent.behavior_state[STATE] = ST_SEEKING
	_clear_nav(agent)


# Browsing: walk to a path cell within viewing distance of the target exhibit,
# then linger and maybe tip.
func _nav_browse(agent: Agent) -> void:
	var rid: int = agent.behavior_state.get(BROWSE_TARGET, 0)
	var region: Region = RegionRegistry.get_region(rid) if rid > 0 else null
	if region == null or region.cells.is_empty() or region.placements.is_empty():
		_pick_browse_target(agent)
		return
	# Pick a *specific* path cell to view from. Each visitor commits to one
	# spot so a crowd disperses along the fence instead of all stopping at
	# the same engagement-distance threshold cell.
	var path_cell: Vector2i = agent.behavior_state.get(BROWSE_PATH_CELL, Vector2i.MAX)
	if path_cell == Vector2i.MAX:
		path_cell = _random_view_path_cell(region, agent)
		if path_cell == INetworkNavigator.NO_STEP:
			_step_browsing(agent)   # no usable viewing cell — free-roam fallback
			return
		agent.behavior_state[BROWSE_PATH_CELL] = path_cell
		_clear_nav(agent)
	match _path_move(agent, [path_cell] as Array[Vector2i], 0):
		PATH_MOVING:
			return
		PATH_ARRIVED:
			_linger_and_donate(agent, region)
		_:
			_step_browsing(agent)   # legacy free-roam fallback


# Pick a random path cell near the region's fence. Each visitor commits to one
# spot so a crowd disperses along the perimeter instead of all stopping at the
# first cell within engagement distance.
#
# The candidate set is path cells within engagement-distance of any region cell.
# We expand outward from the fence rather than iterating the whole network
# (WalkableNetwork doesn't expose its cell list — engine seam, see CLAUDE.md §1).
func _random_view_path_cell(region: Region, _agent: Agent) -> Vector2i:
	var net: WalkableNetwork = NavigationRegistry.get_network()
	if net == null or net.cell_count() == 0:
		return INetworkNavigator.NO_STEP
	var engage_d := _view_engage_d()
	var region_set := {}
	for rc in region.cells:
		region_set[rc] = true
	var seen := {}
	var candidates: Array[Vector2i] = []
	var weights: Array[float] = []
	var total: float = 0.0
	# Manhattan-ring expansion from each region cell up to engage_d.
	for rc in region.cells:
		for dy in range(-engage_d, engage_d + 1):
			var span: int = engage_d - absi(dy)
			for dx in range(-span, span + 1):
				var c := rc + Vector2i(dx, dy)
				if seen.has(c) or region_set.has(c):
					continue
				seen[c] = true
				if not net.has_cell(c):
					continue
				var d: int = absi(dx) + absi(dy)
				# Inverse-distance: cells right against the fence dominate
				# but every viewable cell keeps a non-zero chance.
				var w: float = 1.0 / float(d + 1)
				candidates.append(c)
				weights.append(w)
				total += w
	if candidates.is_empty():
		return INetworkNavigator.NO_STEP
	var pick := SimClock.rng.randf() * total
	var accum: float = 0.0
	for i in candidates.size():
		accum += weights[i]
		if pick <= accum:
			return candidates[i]
	return candidates[candidates.size() - 1]


# Once parked within viewing distance of an exhibit: tip on arrival, hold for
# the linger duration, then pick the next exhibit.
func _linger_and_donate(agent: Agent, region: Region) -> void:
	var linger_until: int = agent.behavior_state.get(LINGER_UNTIL, 0)
	if linger_until == 0:
		agent.behavior_state[LINGER_UNTIL] = SimClock.current_tick + \
			_linger_duration_for_region(agent, region)
		_apply_view_enjoyment(agent, region)
		_maybe_donate(agent, region)
	elif SimClock.current_tick >= linger_until:
		agent.behavior_state[LINGER_UNTIL] = 0
		_pick_browse_target(agent)


# Core network step. Returns PATH_MOVING / PATH_ARRIVED / PATH_NONE. The
# caller free-roams on PATH_NONE (no network, off-network, or unreachable).
func _path_move(agent: Agent, anchors: Array[Vector2i], engage_d: int) -> int:
	var net: WalkableNetwork = NavigationRegistry.get_network()
	if net == null or net.cell_count() == 0:
		return PATH_NONE
	var cur := Vector2i(agent.position.round())
	if not net.has_cell(cur):
		return PATH_NONE
	if net.within_engagement_distance(cur, anchors, engage_d):
		return PATH_ARRIVED
	if not agent.behavior_state.has(NAV_TARGET):
		var t := _nearest_viewing_cell(net, cur, anchors, engage_d)
		if t == INetworkNavigator.NO_STEP:
			return PATH_NONE
		agent.behavior_state[NAV_TARGET] = t
	var nxt: Vector2i = NavigationRegistry.navigator.step(agent, net)
	if nxt == INetworkNavigator.NO_STEP:
		return PATH_NONE   # route lost (e.g. path removed under us)
	_move_position_toward(agent, Vector2(nxt))
	return PATH_MOVING


# Nearest path cell from which `anchors` are within engagement distance.
func _nearest_viewing_cell(net: WalkableNetwork, origin: Vector2i,
		anchors: Array[Vector2i], engage_d: int) -> Vector2i:
	var pred := func(c: Vector2i) -> bool:
		return net.within_engagement_distance(c, anchors, engage_d)
	return NavigationRegistry.nearest(origin, pred)


func _move_position_toward(agent: Agent, dest: Vector2) -> void:
	var to := dest - agent.position
	var d := to.length()
	var step := _walking_speed(agent)
	if d <= step or d == 0.0:
		agent.position = dest
	else:
		agent.position += to / d * step


func _amenity_anchors(inst: EntityInstance) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var def := inst.get_def()
	if def == null:
		out.append(inst.position)
		return out
	for dx in def.footprint.x:
		for dy in def.footprint.y:
			out.append(inst.position + Vector2i(dx, dy))
	return out


func _view_engage_d() -> int:
	var bc: BalanceConfig = ContentDB.balance_config
	return bc.nav_default_engagement_distance if bc != null else 10


func _clear_nav(agent: Agent) -> void:
	agent.behavior_state.erase(NAV_TARGET)
	agent.behavior_state.erase("nav_route")


# ---------------------------------------------------------------------------
# Movement helpers (legacy free-roam — used as the fallback when no usable
# path route exists; see the path-navigation section above).
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
		_satisfy_need_at(agent, inst)
		agent.target_entity_id = 0
		agent.seeking_need = &""
		agent.behavior_state[STATE] = ST_BROWSING
		return
	agent.position += to_target.normalized() * _walking_speed(agent)


# Player-facing money-float label per need. Defaults to a capitalized need
# id so a new need without an entry still reads sensibly.
const NEED_LABELS := {
	&"hunger":   "Food",
	&"thirst":   "Drink",
	&"restroom": "Restroom",
	&"energy":   "Rest",
}


# A guest reached a satisfier for `agent.seeking_need`. Charge the service
# price(s), refill the need(s), and apply the eat→restroom spillover — the
# original Zoo Tycoon twist where meeting one need worsens another.
#
# A single-need stand (food / drink / restroom / bench) refills just its one
# need. A multi-need building — the Restaurant capstone, which satisfies all
# four — is a one-stop shop: the guest "has a meal" and every need it serves
# refills in one visit, charged only for the needs that were actually low.
# That convenience (vs. four separate trips) is what justifies the
# restaurant's cost and reputation gate. All pricing/spillover comes from
# design/tuning/services.md via ServiceConfig.
func _satisfy_need_at(agent: Agent, inst: EntityInstance) -> void:
	var sought: StringName = agent.seeking_need
	if sought == &"":
		return
	var def := inst.get_def()
	if def == null:
		return
	var services: ServiceConfig = ZooBootstrap.services

	# Needs this entity serves that the guest actually has. Always include the
	# sought need even if the entity's `satisfies` list somehow omits it.
	var to_refill: Array[StringName] = []
	for need in def.satisfies:
		if agent.need_levels.has(need) and need not in to_refill:
			to_refill.append(need)
	if sought not in to_refill and agent.need_levels.has(sought):
		to_refill.append(sought)

	var total_charge: int = 0
	for need in to_refill:
		var was_low: bool = float(agent.need_levels[need]) < 0.999
		# Apply this need's spillover before refilling (a refilled spillover
		# target below is then topped back up — the capstone benefit).
		if services != null and was_low:
			var spill: Array = services.spillover_for(need)
			var spill_need: StringName = spill[0]
			var spill_amt: float = spill[1]
			if spill_need != &"" and agent.need_levels.has(spill_need):
				agent.need_levels[spill_need] = maxf(
					0.0, float(agent.need_levels[spill_need]) - spill_amt)
			# Charge only for needs the guest actually needed topping up.
			total_charge += services.price_for(need)

	for need in to_refill:
		agent.need_levels[need] = 1.0

	if total_charge > 0:
		# Archetype spend (a Family party pays more than a lone Child).
		if services != null:
			total_charge = int(round(
				total_charge * services.spend_multiplier(agent.agent_type_id)))
		var label: String = NEED_LABELS.get(sought, String(sought).capitalize())
		if to_refill.size() > 1:
			label = "Meal"
		Ledger.post_income(total_charge, label,
			services.source_for(sought) if services != null else sought)
		ZooBootstrap.money_floated.emit(total_charge, agent.position)


# A guest views an exhibit: top up enjoyment by how good the exhibit is (its
# strongest appeal axis). Great exhibits delight; dull ones barely register.
func _apply_view_enjoyment(agent: Agent, region: Region) -> void:
	var appeal: Dictionary = EffectResolver.compute_region_appeal(region)
	var q: float = 0.0
	for v in appeal.values():
		if v > q:
			q = v
	var e: float = float(agent.behavior_state.get(ENJOYMENT, 0.5))
	agent.behavior_state[ENJOYMENT] = minf(1.0, e + VIEW_BOOST * q)


const DONATION_BOX_TAG := &"donation_box"


# Roll for a tip when a guest settles in to watch an exhibit that has a
# Donation Box. Amount scales with the guest's satisfaction and the exhibit's
# strongest appeal axis — a happy crowd at a great pen tips best. All knobs
# come from design/tuning/services.md via ServiceConfig.
func _maybe_donate(agent: Agent, region: Region) -> void:
	var services: ServiceConfig = ZooBootstrap.services
	if services == null:
		return
	if agent.satisfaction < services.donation_min_satisfaction:
		return
	if not _region_has_donation_box(region):
		return
	if SimClock.rng.randf() >= services.donation_view_chance:
		return
	var appeal: Dictionary = EffectResolver.compute_region_appeal(region)
	var appeal_max: float = 0.0
	for v in appeal.values():
		if v > appeal_max:
			appeal_max = v
	var amount: int = int(round(
		float(services.donation_amount_max) * agent.satisfaction * appeal_max
		* services.spend_multiplier(agent.agent_type_id)))
	amount = maxi(1, amount)
	ZooBootstrap.record_donation(region.region_id, amount)
	ZooBootstrap.money_floated.emit(amount, agent.position)


func _region_has_donation_box(region: Region) -> bool:
	for placement: Placement in region.placements:
		var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
		if def != null and DONATION_BOX_TAG in def.own_tags:
			return true
	return false


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
			# Settled in to watch — enjoy it, and maybe tip the box.
			_apply_view_enjoyment(agent, region)
			_maybe_donate(agent, region)
		elif SimClock.current_tick >= linger_until:
			_pick_browse_target(agent)
			agent.behavior_state[LINGER_UNTIL] = 0
			return
		# Gentle sway while lingering — deterministic so the visitor doesn't
		# vibrate. Each agent gets its own phase + axis so a crowd doesn't
		# move in lockstep. Amplitude is a tenth of a tile; the bob in the
		# renderer adds the visual "alive" feel.
		var phase := float(SimClock.current_tick) * 0.06 + float(agent.agent_id) * 0.73
		agent.position += Vector2(cos(phase) * 0.004, sin(phase * 1.13) * 0.004)
		return
	var step := to_target.normalized() * _walking_speed(agent) * BROWSE_SPEED_FACTOR
	agent.position = _avoid_regions(agent.position, step)


# If `pos + step` would land inside a Region, slide along it instead — try
# the two perpendicular directions and pick whichever brings us closer to
# the original step direction without entering a region. If both still
# overlap, take the straight step anyway (visitor will be inside briefly,
# but the next tick they'll be pushed out again by the same logic).
func _avoid_regions(pos: Vector2, step: Vector2) -> Vector2:
	var direct := pos + step
	if RegionRegistry.region_at_cell(Vector2i(floor(direct.x), floor(direct.y))) == null:
		return direct
	# Side-step options: ±90° perpendicular at same speed.
	var perp := Vector2(-step.y, step.x)
	var option_a := pos + perp
	var option_b := pos - perp
	var a_blocked := RegionRegistry.region_at_cell(
		Vector2i(floor(option_a.x), floor(option_a.y))) != null
	var b_blocked := RegionRegistry.region_at_cell(
		Vector2i(floor(option_b.x), floor(option_b.y))) != null
	if not a_blocked and b_blocked:
		return option_a
	if a_blocked and not b_blocked:
		return option_b
	if not a_blocked and not b_blocked:
		# Pick the one whose resulting position is closer to the original
		# target heading. We don't know the target here, but the dot
		# product of (perp choice) with (step) is zero — so prefer the
		# side that keeps us moving in the same general world quadrant.
		# Cheap proxy: pick option_a; deterministic tie-break.
		return option_a
	# Both blocked — go direct and rely on the next tick to recover.
	return direct


# A viewing cell is a tile adjacent (4-neighbor) to the region but NOT in it.
# We weight candidates by inverse-distance from the visitor so each visitor
# walks to the *closest* fence side rather than potentially cutting straight
# across the exhibit to reach a far-side cell. Some randomness stays so a
# crowd doesn't all stack on one slot.
func _pick_viewing_point(region: Region, agent: Agent) -> Vector2:
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
	var weights: Array[float] = []
	var total: float = 0.0
	for c in candidates:
		var center := Vector2(c) + Vector2(0.5, 0.5)
		var d := center.distance_to(agent.position)
		# Inverse-square falloff: a cell at distance 1 is 5× as likely as
		# one at distance 5. Keeps a small chance of "far side" choices.
		var w: float = 1.0 / (1.0 + d * d * 0.4)
		weights.append(w)
		total += w
	var pick := SimClock.rng.randf() * total
	var picked: Vector2i = candidates[candidates.size() - 1]
	var accum: float = 0.0
	for i in candidates.size():
		accum += weights[i]
		if pick <= accum:
			picked = candidates[i]
			break
	# A bit of noise inside the chosen cell so two visitors landing on the
	# same viewing slot don't pixel-stack.
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
	_clear_nav(agent)   # new exhibit → re-plan the path route next tick
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
		agent.behavior_state.erase(BROWSE_PATH_CELL)
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
	# Clear last exhibit's viewing spots so _nav_browse picks a fresh one for
	# the new target; otherwise the visitor would try to walk to the previous
	# exhibit's fence.
	agent.behavior_state.erase(BROWSE_PATH_CELL)
	var region := RegionRegistry.get_region(picked_region_id)
	if region != null:
		agent.behavior_state[BROWSE_VIEW_POS] = _pick_viewing_point(region, agent)
	else:
		agent.behavior_state[BROWSE_VIEW_POS] = Vector2.INF
