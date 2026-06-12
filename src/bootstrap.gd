extends Node
# Zoo Tycoon — startup wiring. Autoloaded after all engine autoloads.

# Game-side event hub. Used for things the engine's generic EventBus doesn't
# emit because they'd require the engine to know what "money at a position"
# means. Currently: floating money toasts whenever a visitor pays for
# something at a location the UI wants to highlight.
signal money_floated(amount: int, world_pos: Vector2)
#
# By the time this _ready() runs, ContentDB has already loaded
# design/tuning/*.md. We just need to register the zoo's
# IAgentBehavior + ISatisfactionModel implementations against the
# visitor AgentType so the engine knows what to call.

# Keep the instances alive at module scope. AgentPool holds refs but
# storing here too means we can swap them at runtime if needed.
# Guest archetype agent-type ids (design/tuning/agents.md). All share the
# visitor behavior + satisfaction model.
const GUEST_TYPES: Array[StringName] = [&"visitor", &"child", &"family", &"enthusiast"]

var _visitor_behavior: VisitorBehavior
var _visitor_satisfaction: VisitorSatisfactionModel
var _zoo_quality: ZooQualityRating         # callable from game UI
var _animal_happiness: ZooAnimalHappiness  # engine reads via EffectResolver

# Scenario (win/lose params) loaded from design/tuning/scenario.md at startup.
# Exposed so the UI can show targets, evaluate end-game, etc.
var scenario: Scenario

# Today's departing-guest verdict, accumulated by VisitorBehavior.on_despawn
# and settled into reputation once per day (## Reputation in scenario.md —
# reputation is a rating that drifts toward the daily verdict, not a lifetime
# tally). need_counts tracks each unhappy departure's most-depleted need so
# the HUD can say *why* guests left sour ("12 left thirsty"), keyed by need id.
var departures_happy: int = 0
var departures_unhappy: int = 0
var departures_total: int = 0
var unhappy_need_counts: Dictionary = {}
# Emitted by record_departure for renderer feedback (verdict floats at the
# gate). verdict: +1 happy / 0 forgettable / -1 unhappy.
signal guest_departed(verdict: int, world_pos: Vector2)
# Emitted after the daily settlement so the HUD can narrate the day's verdict.
signal reputation_settled(day_score: int, happy: int, unhappy: int,
	total: int, old_rep: int, new_rep: int)

# Per-need service pricing + spillover (design/tuning/services.md). Read by
# VisitorBehavior when a guest satisfies a need at a satisfier entity.
var services: ServiceConfig

# Animal-welfare tuning (design/tuning/welfare.md). The daily update lives in
# _on_day_ending_for_welfare; welfare lives in each animal placement's
# state["welfare"] / state["sick"]. kind is "sick" / "recovered" / "died".
var welfare: WelfareConfig

# Per-species habitat preferences (terrain/foliage/rocks/shelter/toys) —
# the ZT1 exhibit-authoring layer. See design/tuning/habitat.md.
var habitat: HabitatConfig
signal animal_welfare_alert(region_id: int, index: int, kind: String, animal_name: String)

# Breeding/aging tuning (design/tuning/breeding.md). Daily logic in
# _on_day_ending_for_breeding, which runs after the welfare update.
var breeding: BreedingConfig
signal animal_born(region_id: int, species: StringName, animal_name: String, rare: bool)

# Staff (roadmap 3.3). Hired zookeepers tend exhibits (a daily welfare bonus)
# for a daily wage. Auto-distributed evenly across populated exhibits.
var staff: StaffConfig
var hired_keepers: int = 0
signal staff_changed(hired: int)

# Weather + seasons (roadmap 3.6). Re-rolled each day; scales guest demand.
var weather_cfg: WeatherConfig
var current_weather: StringName = &""
signal weather_changed(weather_id: StringName, season_id: StringName)

# Zoo land plots + climates (design/tuning/zoo_types.md). The selected plot
# sets the buildable grid size, the gate cell, and a climate that biases the
# daily weather roll and scales demand. Picked at the welcome screen; traded
# mid-run via relocate_zoo (Park Admin → Land & relocation).
var zoo_types: ZooTypeConfig
var current_zoo_type: StringName = &""
signal zoo_type_changed(id: StringName)
# Fallback when zoo_types fails to load — the historical hardcoded grid.
const DEFAULT_PLOT_SIZE := Vector2i(32, 18)

# Marketing campaigns (roadmap 4.2). Spend cash to bias arrivals toward an
# archetype for a few days by boosting its spawn weight. One at a time.
var marketing: MarketingConfig
var campaign_target: StringName = &""
var campaign_days_left: int = 0
var _base_spawn_weights: Dictionary = {}   # agent_type id -> base spawn_weight
signal campaign_changed(target: StringName, days_left: int)

# Per-exhibit donation totals — region_id (int) -> cumulative $ tipped at that
# exhibit's Donation Box. Display-only running stat; surfaced in the Manage
# Exhibit panel. Not persisted (resets on load — it's a session tally).
var donations_by_region: Dictionary = {}
signal donation_collected(region_id: int, amount: int)

# Park-admin state. Editable via the entrance-gate admin modal.
# entry_fee is what new visitors pay on arrival (derived from the selected
# ticket bracket); park_open gates the AgentPool spawn loop (sets
# base_spawn_rate to 0 when closed so the engine still runs but doesn't admit
# guests).
var entry_fee: int = 10
var ticket_bracket: StringName = &"standard"
var park_open: bool = false
var _default_base_spawn_rate: float = 0.5

# Day cycle (roadmap 3.4). Guests only arrive during opening hours; the gate
# spawn rate is gated by both the manual park_open toggle and the hours.
var _hours_open: bool = true
signal park_hours_changed(open: bool)

signal admin_changed

# Arena show bookings — arena_instance_id → {region_id, index, started_day}.
# Each arena can host at most one performance at a time. Fatigue drives
# the booked animal's attitude down each day; stopping the show lets it
# recover. Per ROADMAP §3 this is the game-side hook that proves the
# IPlaceableHappiness seam (attitude is engine-visible through placement
# state, set/read from here, never read by the engine itself).
var arena_bookings: Dictionary = {}

# Tuning knobs for the arena. Numbers here rather than scenario.md
# because we don't yet need designer-editable balance for it; promote
# to tuning once we have scenarios that vary them.
const SHOW_REVENUE_PER_APPEAL: int = 30
const SHOW_DAILY_FATIGUE: float = 0.08   # subtracted from attitude/day
const SHOW_REST_RECOVERY: float = 0.10   # restored when not performing
const SHOW_ATTITUDE_FLOOR: float = 0.30

signal arena_changed(arena_id: int)


func _ready() -> void:
	if not ContentDB.is_loaded:
		push_error("[Zoo] ContentDB failed to load — refusing to bootstrap. Errors above.")
		return

	_visitor_behavior = VisitorBehavior.new()
	_visitor_satisfaction = VisitorSatisfactionModel.new()
	_zoo_quality = ZooQualityRating.new()
	_animal_happiness = ZooAnimalHappiness.new()

	# All guest archetypes (Adult / Child / Family / Enthusiast — see
	# design/tuning/agents.md) share one behavior + satisfaction model; they
	# differ only in tuning (preferences, need decay, traits, spend). When a
	# non-guest population lands (e.g. staff in Phase 3) it registers its own.
	for guest_type in GUEST_TYPES:
		AgentPool.register_behavior(guest_type, _visitor_behavior)
		AgentPool.register_satisfaction_model(guest_type, _visitor_satisfaction)
	# v0.4.0 — engine multiplies placement appeal_contribution by the
	# happiness this returns when computing region appeal. Without this
	# registration, the engine's default returns 1.0 (no opinion) and
	# crowded / hungry / lonely animals contribute as much as happy ones.
	EffectResolver.register_happiness_model(_animal_happiness)

	# v0.5.0 — tell the engine's Accounting module which Ledger source_ids
	# are revenue vs operating expense. Sources we don't register fall
	# into Accounting's OTHER_* bucket so the books still balance, but
	# explicit categorization gives a cleaner Income Statement.
	Accounting.register_category(&"entry",       Accounting.Category.REVENUE)
	Accounting.register_category(&"food_stand",  Accounting.Category.REVENUE)
	Accounting.register_category(&"drink_stand", Accounting.Category.REVENUE)
	Accounting.register_category(&"donation",    Accounting.Category.REVENUE)
	Accounting.register_category(&"zoo_utilities", Accounting.Category.OPERATING_EXPENSE)
	Accounting.register_category(&"zoo_staff",     Accounting.Category.OPERATING_EXPENSE)

	# Grant the starting tier so starter content is immediately available
	# without the player having to unlock anything on day 1.
	ProgressionManager.force_unlock(&"start")

	scenario = Scenario.load_from_tuning()
	services = ServiceConfig.load_from_tuning()
	welfare = WelfareConfig.load_from_tuning()
	habitat = HabitatConfig.load_from_tuning()
	_animal_happiness.habitat = habitat
	# Terrain composition is cached per region inside the model; any world
	# change can repaint a pen's tiles, so drop the cache on those events.
	for sig in [EventBus.entity_placed, EventBus.entity_removed,
			EventBus.region_created, EventBus.region_destroyed, EventBus.region_changed]:
		sig.connect(_animal_happiness.clear_terrain_cache)
	breeding = BreedingConfig.load_from_tuning()
	staff = StaffConfig.load_from_tuning()
	weather_cfg = WeatherConfig.load_from_tuning()
	marketing = MarketingConfig.load_from_tuning()
	donations_by_region.clear()
	hired_keepers = 0
	# Snapshot each archetype's base spawn weight so a campaign boost can be
	# applied and cleanly restored.
	_base_spawn_weights.clear()
	for at_id in ContentDB.agent_types.keys():
		_base_spawn_weights[at_id] = (ContentDB.agent_types[at_id] as AgentType).spawn_weight
	Accounting.register_category(&"marketing", Accounting.Category.OPERATING_EXPENSE)
	EventBus.day_ended.connect(_tick_campaign)
	# Land plots — start on the default (free) plot; the welcome screen may
	# switch it (and charge for it) before play begins. Must load before the
	# weather seed so the climate biases the very first roll.
	zoo_types = ZooTypeConfig.load_from_tuning()
	if zoo_types != null:
		current_zoo_type = zoo_types.default_plot
	# Seed today's weather, then re-roll each new day.
	if weather_cfg != null and not weather_cfg.weathers.is_empty():
		current_weather = weather_cfg.pick_weather(SimClock.rng, climate_weather_weights())
	EventBus.day_ended.connect(_roll_weather)

	# Husbandry runs at day end: welfare first (care update + neglect deaths),
	# then aging/breeding — so the day's survivors age and breed. A death's
	# removal refund is negated in each handler so an animal lost to neglect or
	# old age never pays the player (see seam note).
	Accounting.register_category(&"animal_loss", Accounting.Category.OPERATING_EXPENSE)
	EventBus.day_ending.connect(_on_day_ending_for_welfare)
	EventBus.day_ending.connect(_on_day_ending_for_breeding)

	# Reputation settles from the day's departures after husbandry (so a
	# death's instant penalty lands first and the drift prices it in).
	EventBus.day_ending.connect(_on_day_ending_for_reputation)

	# Save/load completeness: the engine persists entities + ledger but NOT
	# region placements (animals + their welfare/age state) or any zoo-side
	# settings, and it doesn't rebuild regions on load. Register a provider
	# that fills both gaps so a saved zoo reloads intact.
	SaveService.register_game_state_provider("zoo", _save_game_state, _load_game_state)

	# Cache the engine's default spawn rate so the open/closed toggle and
	# ticket-bracket elasticity can scale from it. ContentDB has already
	# applied balance.md by now.
	_default_base_spawn_rate = AgentPool.base_spawn_rate

	# Start on the bracket marked default in services.md (Standard / $10).
	if services != null and services.default_bracket != &"":
		set_ticket_bracket(services.default_bracket)

	# Gate guest arrivals by opening hours; re-apply the spawn rate when the
	# park opens or closes for the day.
	_hours_open = is_within_open_hours()
	_apply_spawn_rate()
	EventBus.tick.connect(_on_tick_hours)

	Accounting.register_category(&"arena_show", Accounting.Category.REVENUE)

	# Daily hook: fatigue booked animals, post show revenue, drop bookings
	# whose arena got removed or whose animal got sold out from under us.
	EventBus.day_ending.connect(_on_day_ending_for_arena)
	EventBus.entity_removed.connect(_on_entity_removed_for_arena)

	print("[Zoo] Bootstrap complete. Starting balance: %d" % Ledger.get_balance())


# ---------------------------------------------------------------------------
# Arena show bookings
# ---------------------------------------------------------------------------

func book_animal(arena_id: int, region_id: int, index: int) -> bool:
	if not _is_arena(arena_id):
		push_warning("[arena] book: %d isn't an arena entity" % arena_id)
		return false
	var region: Region = RegionRegistry.get_region(region_id)
	if region == null or index < 0 or index >= region.placements.size():
		return false
	var placement: Placement = region.placements[index]
	var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
	if def == null or def.appeal_contribution.is_empty():
		return false   # only "animals" (placeables with appeal) can perform
	# Replace any existing booking on this arena.
	if arena_bookings.has(arena_id):
		stop_show(arena_id)
	arena_bookings[arena_id] = {
		"region_id": region_id,
		"index": index,
		"started_day": SimClock.current_day,
	}
	arena_changed.emit(arena_id)
	return true


func stop_show(arena_id: int) -> void:
	if not arena_bookings.has(arena_id):
		return
	arena_bookings.erase(arena_id)
	arena_changed.emit(arena_id)


func get_booking(arena_id: int) -> Dictionary:
	return arena_bookings.get(arena_id, {})


# Same arena id used by EntityRegistry — but we don't want to assert
# against engine internals here, just check the type via ContentDB.
func _is_arena(entity_instance_id: int) -> bool:
	var inst: EntityInstance = EntityRegistry.get_instance(entity_instance_id)
	if inst == null:
		return false
	return inst.entity_def_id == &"arena"


func _on_day_ending_for_arena(_day: int) -> void:
	# Walk a copy of the keys so we can mutate during iteration if a
	# booking's animal vanished.
	for arena_id in arena_bookings.keys():
		var booking: Dictionary = arena_bookings[arena_id]
		var region: Region = RegionRegistry.get_region(booking["region_id"])
		if region == null or booking["index"] >= region.placements.size():
			arena_bookings.erase(arena_id)
			arena_changed.emit(arena_id)
			continue
		var placement: Placement = region.placements[booking["index"]]
		var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
		if def == null:
			arena_bookings.erase(arena_id)
			continue
		# Revenue scales with the performer's total appeal axes.
		var appeal_sum: float = 0.0
		for v in def.appeal_contribution.values():
			appeal_sum += float(v)
		var revenue: int = int(round(appeal_sum * float(SHOW_REVENUE_PER_APPEAL)))
		if revenue > 0:
			Ledger.post_income(revenue, "Arena show — %s" % def.display_name,
				&"arena_show")
		# Fatigue: drop attitude per day, with a floor.
		var current: float = float(placement.state.get("attitude", 1.0))
		placement.state["attitude"] = maxf(SHOW_ATTITUDE_FLOOR,
			current - SHOW_DAILY_FATIGUE)

	# Resting animals (booked anywhere? no — just unbooked ones with
	# below-1.0 attitude) recover a little each day.
	for region: Region in RegionRegistry.all_regions():
		for i in region.placements.size():
			if _is_booked(region.region_id, i):
				continue
			var placement: Placement = region.placements[i]
			var att: float = float(placement.state.get("attitude", 1.0))
			if att < 1.0:
				placement.state["attitude"] = minf(1.0, att + SHOW_REST_RECOVERY)


func _is_booked(region_id: int, index: int) -> bool:
	for booking in arena_bookings.values():
		if booking["region_id"] == region_id and booking["index"] == index:
			return true
	return false


func _on_entity_removed_for_arena(instance_id: int) -> void:
	if arena_bookings.has(instance_id):
		arena_bookings.erase(instance_id)
		arena_changed.emit(instance_id)


func set_park_open(open: bool) -> void:
	park_open = open
	_apply_spawn_rate()
	admin_changed.emit()


# Switch the gate to a named bracket from services.md. Sets the entry fee and
# re-applies demand elasticity. Unknown ids are ignored (keeps current).
func set_ticket_bracket(id: StringName) -> void:
	if services == null:
		return
	var b: Dictionary = services.bracket(id)
	if b.is_empty():
		push_warning("[zoo] unknown ticket bracket '%s'" % id)
		return
	ticket_bracket = id
	entry_fee = int(b["price"])
	_apply_spawn_rate()
	admin_changed.emit()


# Demand multiplier of the currently-selected bracket (1.0 if unknown).
func current_demand_multiplier() -> float:
	if services == null:
		return 1.0
	var b: Dictionary = services.bracket(ticket_bracket)
	return float(b.get("demand_multiplier", 1.0)) if not b.is_empty() else 1.0


# base_spawn_rate = engine default × bracket demand elasticity, gated to 0
# when the park is closed (manually) or outside opening hours. Composes with
# the engine's per-day satisfaction→spawn multiplier.
func _apply_spawn_rate() -> void:
	var open := park_open and is_within_open_hours()
	var difficulty_demand: float = scenario.demand_multiplier if scenario != null else 1.0
	AgentPool.base_spawn_rate = (_default_base_spawn_rate
		* current_demand_multiplier() * environment_multiplier()
		* difficulty_demand) if open else 0.0


# Apply a difficulty overlay (roadmap 2.6) — overrides the win bar, resets the
# opening cash, and scales guest demand. Intended for a new game (called from
# the welcome screen); resetting cash mid-run would wipe the player's money.
signal difficulty_changed(id: StringName)

func set_difficulty(id: StringName) -> void:
	if scenario == null or not scenario.apply_difficulty(id):
		return
	Ledger.reset(scenario.starting_cash)
	_apply_spawn_rate()
	difficulty_changed.emit(id)


# Current season's record (id/label/mult) from the day count.
func current_season() -> Dictionary:
	if weather_cfg == null:
		return {"id": &"", "label": "", "mult": 1.0}
	return weather_cfg.season_for_day(SimClock.current_day)


# Combined weather × season × climate demand multiplier.
func environment_multiplier() -> float:
	var cm: float = float(current_climate().get("demand_multiplier", 1.0))
	if weather_cfg == null:
		return cm
	var wm: float = float(weather_cfg.weather_by_id(current_weather).get("mult", 1.0))
	var sm: float = float(current_season().get("mult", 1.0))
	return wm * sm * cm


# Re-roll the weather for the day that just started, then re-apply demand.
func _roll_weather(_day: int) -> void:
	if weather_cfg == null or weather_cfg.weathers.is_empty():
		return
	current_weather = weather_cfg.pick_weather(SimClock.rng, climate_weather_weights())
	_apply_spawn_rate()
	weather_changed.emit(current_weather, current_season().get("id", &""))


# ---------------------------------------------------------------------------
# Land plots — zoo type selection, purchase, sale & relocation
# ---------------------------------------------------------------------------

# The selected plot's record from zoo_types.md, or {} if config failed.
func current_plot() -> Dictionary:
	return zoo_types.plot(current_zoo_type) if zoo_types != null else {}


# Buildable grid of the current plot. Views, the gate, and main's placement
# bounds all read this — nothing else may hardcode the world size.
func plot_size() -> Vector2i:
	var p := current_plot()
	return p["size"] if not p.is_empty() else DEFAULT_PLOT_SIZE


# The entrance gate hugs the bottom-left corner of whatever plot we're on:
# guests spawn/exit here and the path network roots here.
func gate_cell() -> Vector2i:
	return Vector2i(0, plot_size().y - 1)


# Climate record of the current plot ({} when config is missing).
func current_climate() -> Dictionary:
	var p := current_plot()
	if zoo_types == null or p.is_empty():
		return {}
	return zoo_types.climate(p["climate"])


# Weather-weight multipliers of the current climate (for WeatherConfig).
func climate_weather_weights() -> Dictionary:
	return current_climate().get("weather_weights", {})


# Switch to plot `id`. charge_cost posts the land price as an expense (a new
# game buying its plot; relocation). Loading a save passes false — the
# restored ledger already reflects every purchase.
func set_zoo_type(id: StringName, charge_cost: bool = false) -> bool:
	if zoo_types == null:
		return false
	var p: Dictionary = zoo_types.plot(id)
	if p.is_empty():
		push_warning("[zoo] unknown zoo type '%s'" % id)
		return false
	current_zoo_type = id
	if charge_cost and int(p["cost"]) > 0:
		Ledger.post_expense(int(p["cost"]), "Land purchase — %s" % p["label"], &"land")
	_apply_spawn_rate()
	zoo_type_changed.emit(id)
	return true


# What selling up right now recovers, before any demolition happens:
#   land    — resale_fraction of the plot's purchase price
#   assets  — the engine's standard sell-back on every building
#             (refund_fraction of invested) and animal/infrastructure
#             placement (half build cost, mirroring remove_placement)
# The estimate matches relocate_zoo's actual postings exactly (same int
# truncation), so the admin UI can show it as a firm offer.
func zoo_sale_value() -> Dictionary:
	var land: int = 0
	if zoo_types != null:
		land = int(round(float(current_plot().get("cost", 0)) * zoo_types.resale_fraction))
	var assets: int = 0
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		assets += int(inst.get_total_invested() * EntityRegistry.refund_fraction)
	for region: Region in RegionRegistry.all_regions():
		for p: Placement in region.placements:
			var def: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if def != null:
				assets += int(def.build_cost * 0.5)
	return {"land": land, "assets": assets, "total": land + assets}


# Sell the whole zoo and move to plot `new_id`: liquidate every placement and
# entity through the engine's normal refund paths (so the books stay honest),
# post the land resale, send the crowd home, then buy the new plot. Fails
# (no-op) when the proceeds plus cash can't cover the new land.
func relocate_zoo(new_id: StringName) -> bool:
	if zoo_types == null or new_id == current_zoo_type:
		return false
	var dest: Dictionary = zoo_types.plot(new_id)
	if dest.is_empty():
		return false
	var sale := zoo_sale_value()
	if Ledger.get_balance() + int(sale["total"]) < int(dest["cost"]):
		return false
	var old_label: String = String(current_plot().get("label", "old grounds"))
	# Animals/infrastructure first (each posts its half-cost refund), then the
	# grid entities (each posts refund_fraction of invested; zone-tile removal
	# dissolves the regions and the nav network reacts via the normal events).
	for region: Region in RegionRegistry.all_regions():
		for i in range(region.placements.size() - 1, -1, -1):
			RegionRegistry.remove_placement(region.region_id, i)
	for inst_id in EntityRegistry.instances.keys():
		EntityRegistry.remove(inst_id)
	if int(sale["land"]) > 0:
		Ledger.post_income(int(sale["land"]), "Sold land — %s" % old_label, &"land")
	# Clear the crowd. Moving isn't a review event — despawn runs the normal
	# exit path (which files a verdict), so snapshot the day's counters and
	# restore them after.
	var snap_happy := departures_happy
	var snap_unhappy := departures_unhappy
	var snap_total := departures_total
	var snap_needs := unhappy_need_counts.duplicate()
	for guest_type in GUEST_TYPES:
		for agent_id in AgentPool.get_agents_by_type(guest_type):
			AgentPool.despawn(agent_id)
	departures_happy = snap_happy
	departures_unhappy = snap_unhappy
	departures_total = snap_total
	unhappy_need_counts = snap_needs
	donations_by_region.clear()
	arena_bookings.clear()
	park_open = false   # an empty plot has nothing to admit guests to
	set_zoo_type(new_id, true)
	admin_changed.emit()
	return true


# Fraction of the current day elapsed, in [0,1) — derived from SimClock.
func time_of_day_fraction() -> float:
	var tpd: int = maxi(SimClock.ticks_per_day, 1)
	return float(SimClock.current_tick % tpd) / float(tpd)


# Is the park within its opening hours right now? (Independent of the manual
# park_open toggle.) Defaults open when no day-cycle tuning is loaded.
func is_within_open_hours() -> bool:
	if services == null:
		return true
	var f := time_of_day_fraction()
	return f >= services.open_start and f < services.open_end


func _on_tick_hours(_t: int) -> void:
	var open := is_within_open_hours()
	if open != _hours_open:
		_hours_open = open
		_apply_spawn_rate()
		park_hours_changed.emit(open)


# Convenience for game UI to read the zoo's quality rating without
# instantiating a model itself.
func get_quality_rating() -> float:
	return _zoo_quality.compute_rating()


# The registered animal-happiness model, typed so game UI can call the
# zoo-specific compute_breakdown() (the engine only knows compute_happiness).
func get_happiness_model() -> ZooAnimalHappiness:
	return _animal_happiness


# ---------------------------------------------------------------------------
# Donations — called by VisitorBehavior when a guest tips at an exhibit's
# Donation Box. Books the income and tracks a per-exhibit running total.
# ---------------------------------------------------------------------------

func record_donation(region_id: int, amount: int) -> void:
	if amount <= 0:
		return
	Ledger.post_income(amount, "Donation", &"donation")
	donations_by_region[region_id] = int(donations_by_region.get(region_id, 0)) + amount
	donation_collected.emit(region_id, amount)


func donations_for_region(region_id: int) -> int:
	return int(donations_by_region.get(region_id, 0))


# ---------------------------------------------------------------------------
# Reputation — guests render a daily verdict; the rating drifts toward it
# (## Reputation in scenario.md). Called by VisitorBehavior.on_despawn with
# the guest's exit mood; `dominant_need` is the guest's most-depleted need at
# departure ("" when nothing was pressing) so the HUD can name the fix.
# ---------------------------------------------------------------------------

func record_departure(mood: float, dominant_need: StringName, world_pos: Vector2) -> void:
	departures_total += 1
	var verdict: int = 0
	if scenario == null or mood >= scenario.rep_happy_threshold:
		verdict = 1
	elif mood < scenario.rep_unhappy_threshold:
		verdict = -1
	match verdict:
		1:
			departures_happy += 1
		-1:
			departures_unhappy += 1
			if dominant_need != &"":
				unhappy_need_counts[dominant_need] = \
					int(unhappy_need_counts.get(dominant_need, 0)) + 1
	guest_departed.emit(verdict, world_pos)


# The unmet need that drove the most unhappy departures today, or &"" when
# the books are clean. Used for the "guests are leaving thirsty" coaching.
func top_unhappy_need() -> StringName:
	var best: StringName = &""
	var best_n: int = 0
	for need_id in unhappy_need_counts.keys():
		var n: int = unhappy_need_counts[need_id]
		if n > best_n:
			best_n = n
			best = need_id
	return best


func _on_day_ending_for_reputation(_day: int) -> void:
	if scenario == null:
		return
	var old_rep: int = ProgressionManager.reputation
	var new_rep: int = scenario.settle_reputation(
		old_rep, departures_happy, departures_unhappy, departures_total)
	var score: int = scenario.day_score(
		departures_happy, departures_unhappy, departures_total)
	if new_rep != old_rep:
		ProgressionManager.set_reputation(new_rep)
	reputation_settled.emit(score, departures_happy, departures_unhappy,
		departures_total, old_rep, new_rep)
	departures_happy = 0
	departures_unhappy = 0
	departures_total = 0
	unhappy_need_counts.clear()


# ---------------------------------------------------------------------------
# Animal welfare — daily care update + illness/death (roadmap 3.1)
# ---------------------------------------------------------------------------

func _on_day_ending_for_welfare(_day: int) -> void:
	if welfare == null:
		return
	# Keepers tend exhibits: a daily welfare bonus, distributed evenly across
	# populated exhibits, plus their wages. Labor can keep an imperfect
	# exhibit healthy.
	var keeper_bonus: float = 0.0
	if staff != null and hired_keepers > 0:
		var exhibits: int = _populated_exhibit_count()
		if exhibits > 0:
			keeper_bonus = (float(hired_keepers) / float(exhibits)) * staff.keeper_welfare_bonus
		Ledger.post_expense(hired_keepers * staff.keeper_wage_per_day,
			"Keeper wages (%d)" % hired_keepers, &"zoo_staff")
	var deaths: Array = []   # {region_id, index, name, refund}
	for region: Region in RegionRegistry.all_regions():
		for i in region.placements.size():
			var p: Placement = region.placements[i]
			var def: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if def == null or def.appeal_contribution.is_empty():
				continue   # only animals (appeal-contributing) have welfare
			var care: float = _animal_happiness.care_quality(region, i)
			var w: float = float(p.state.get("welfare", 1.0))
			var was_sick: bool = bool(p.state.get("sick", false))
			if care >= welfare.happiness_threshold:
				w = minf(1.0, w + welfare.recovery_per_day)
			else:
				var severity: float = (welfare.happiness_threshold - care) \
					/ maxf(welfare.happiness_threshold, 0.001)
				w = maxf(0.0, w - welfare.decline_per_day * severity)
			w = minf(1.0, w + keeper_bonus)   # keepers help everywhere they tend
			p.state["welfare"] = w
			var sick: bool = w < welfare.illness_threshold
			p.state["sick"] = sick
			if w <= 0.0:
				deaths.append({"region_id": region.region_id, "index": i,
					"name": def.display_name, "refund": int(def.build_cost * 0.5)})
			elif sick and not was_sick:
				animal_welfare_alert.emit(region.region_id, i, "sick", def.display_name)
			elif was_sick and not sick:
				animal_welfare_alert.emit(region.region_id, i, "recovered", def.display_name)
	# Remove the dead. Descending index so earlier removals don't shift the
	# indices of later ones within the same region.
	deaths.sort_custom(func(a, b): return a["index"] > b["index"])
	for d in deaths:
		if not RegionRegistry.remove_placement(d["region_id"], d["index"]):
			continue
		# SEAM NOTE: RegionRegistry.remove_placement posts a half build-cost
		# refund — it can't tell a sale from a death. Negate it; a dead animal
		# isn't an asset you recoup. A no-refund removal option upstream would
		# retire this workaround.
		if int(d["refund"]) > 0:
			Ledger.post_expense(int(d["refund"]), "Loss: %s died" % d["name"], &"animal_loss")
		ProgressionManager.add_reputation(-welfare.death_reputation_penalty)
		animal_welfare_alert.emit(d["region_id"], d["index"], "died", d["name"])


# ---------------------------------------------------------------------------
# Staff
# ---------------------------------------------------------------------------

func set_hired_keepers(n: int) -> void:
	var capped := clampi(n, 0, staff.max_keepers if staff != null else 12)
	if capped == hired_keepers:
		return
	hired_keepers = capped
	staff_changed.emit(hired_keepers)


# Number of exhibits that currently hold at least one animal (keeper coverage
# is split across these).
func _populated_exhibit_count() -> int:
	var n := 0
	for region: Region in RegionRegistry.all_regions():
		for p: Placement in region.placements:
			var def: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if def != null and not def.appeal_contribution.is_empty():
				n += 1
				break
	return n


# ---------------------------------------------------------------------------
# Marketing campaigns
# ---------------------------------------------------------------------------

# Launch a campaign promoting `target` archetype. Charges the cost, boosts that
# archetype's spawn weight for campaign_days. Returns false if one is already
# running, the archetype is unknown, or there isn't enough cash.
func start_campaign(target: StringName) -> bool:
	if marketing == null or campaign_days_left > 0:
		return false
	if not _base_spawn_weights.has(target):
		return false
	if Ledger.get_balance() < marketing.campaign_cost:
		return false
	Ledger.post_expense(marketing.campaign_cost,
		"Marketing campaign", &"marketing")
	campaign_target = target
	campaign_days_left = marketing.campaign_days
	_apply_campaign_weights()
	campaign_changed.emit(campaign_target, campaign_days_left)
	return true


func _apply_campaign_weights() -> void:
	for at_id in _base_spawn_weights.keys():
		var at: AgentType = ContentDB.agent_types.get(at_id)
		if at == null:
			continue
		var boost: float = marketing.campaign_boost if at_id == campaign_target else 1.0
		at.spawn_weight = float(_base_spawn_weights[at_id]) * boost


func _restore_campaign_weights() -> void:
	for at_id in _base_spawn_weights.keys():
		var at: AgentType = ContentDB.agent_types.get(at_id)
		if at != null:
			at.spawn_weight = float(_base_spawn_weights[at_id])


func _tick_campaign(_day: int) -> void:
	if campaign_days_left <= 0:
		return
	campaign_days_left -= 1
	if campaign_days_left <= 0:
		campaign_target = &""
		_restore_campaign_weights()
	campaign_changed.emit(campaign_target, campaign_days_left)


# Daily keeper wage bill at the current headcount.
func keeper_wage_bill() -> int:
	if staff == null:
		return 0
	return hired_keepers * staff.keeper_wage_per_day


# Welfare/sick read for the UI. Returns {welfare:float, sick:bool}.
func animal_welfare(region: Region, index: int) -> Dictionary:
	if index < 0 or index >= region.placements.size():
		return {"welfare": 1.0, "sick": false}
	var st: Dictionary = region.placements[index].state
	return {"welfare": float(st.get("welfare", 1.0)), "sick": bool(st.get("sick", false))}


# ---------------------------------------------------------------------------
# Breeding & aging (roadmap 3.5) — runs at day end, after the welfare update.
# ---------------------------------------------------------------------------

func _on_day_ending_for_breeding(_day: int) -> void:
	if breeding == null:
		return
	var old_age_deaths: Array = []   # {region_id, index, name, refund}
	var births: Array = []           # {region_id, species}
	for region: Region in RegionRegistry.all_regions():
		# species id -> Array[int] of placement indices eligible to breed
		var breeders: Dictionary = {}
		for i in region.placements.size():
			var p: Placement = region.placements[i]
			var def: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if def == null or def.appeal_contribution.is_empty():
				continue   # only animals age / breed
			var age: int = int(p.state.get("age_days", 0)) + 1
			p.state["age_days"] = age
			if age > breeding.max_age_days:
				old_age_deaths.append({"region_id": region.region_id, "index": i,
					"name": def.display_name, "refund": int(def.build_cost * 0.5)})
				continue
			if age >= breeding.min_age_days \
					and float(p.state.get("welfare", 1.0)) >= breeding.welfare_threshold:
				if not breeders.has(p.placeable_def_id):
					breeders[p.placeable_def_id] = [] as Array[int]
				(breeders[p.placeable_def_id] as Array[int]).append(i)
		# A species with two+ eligible adults may produce one offspring/day.
		for species_id in breeders.keys():
			if (breeders[species_id] as Array).size() < 2:
				continue
			if SimClock.rng.randf() < breeding.chance_per_day:
				births.append({"region_id": region.region_id, "species": species_id})

	# Old-age deaths first (descending index within a region).
	old_age_deaths.sort_custom(func(a, b): return a["index"] > b["index"])
	for d in old_age_deaths:
		if not RegionRegistry.remove_placement(d["region_id"], d["index"]):
			continue
		if int(d["refund"]) > 0:   # negate the half-refund (see welfare seam note)
			Ledger.post_expense(int(d["refund"]), "Old age: %s" % d["name"], &"animal_loss")
		animal_welfare_alert.emit(d["region_id"], d["index"], "old_age", d["name"])

	# Births (space permitting — add_placement fails when the pen is full).
	for b in births:
		var species: StringName = b["species"]
		var def: PlaceableDef = ContentDB.placeable_defs.get(species)
		if def == null:
			continue
		# Overcrowding is the natural population cap — skip silently when the
		# pen is full (checking first avoids add_placement's warning).
		if not RegionRegistry.can_add_placement(b["region_id"], species)["ok"]:
			continue
		var placement := RegionRegistry.add_placement(b["region_id"], species)
		if placement == null:
			continue
		# A birth is free — negate the placement build cost (same source so the
		# books wash out).
		if def.build_cost > 0:
			Ledger.post_income(def.build_cost, "Birth: %s" % def.display_name, species)
		placement.state["age_days"] = 0
		placement.state["welfare"] = 1.0
		var rare: bool = SimClock.rng.randf() < breeding.rare_chance
		if rare:
			ProgressionManager.add_reputation(breeding.rare_reputation)
		animal_born.emit(b["region_id"], species, def.display_name, rare)


# Age (in days) of an animal placement, for the UI.
func animal_age(region: Region, index: int) -> int:
	if index < 0 or index >= region.placements.size():
		return 0
	return int(region.placements[index].state.get("age_days", 0))


# ---------------------------------------------------------------------------
# Save / load — completes the engine's save with region placements + zoo state
# ---------------------------------------------------------------------------

# Zoo save payload version (roadmap 2.5 — saves are where tycoon games die;
# catch the migration seam early). Bump when the payload shape changes and
# handle older shapes in _migrate_game_state:
#   1 — original provider (settings + exhibits)
#   2 — adds the mid-day departure-verdict counters (reputation rework)
#   3 — adds the zoo type (land plot + climate selection)
const SAVE_VERSION: int = 3


func _save_game_state() -> Dictionary:
	var exhibits: Array = []
	for region: Region in RegionRegistry.all_regions():
		if region.cells.is_empty():
			continue
		var pls: Array = []
		for p: Placement in region.placements:
			pls.append({
				"def": String(p.placeable_def_id),
				"welfare": float(p.state.get("welfare", 1.0)),
				"age_days": int(p.state.get("age_days", 0)),
				"sick": bool(p.state.get("sick", false)),
				"attitude": float(p.state.get("attitude", 1.0)),
			})
		# Anchor on a cell so we can find the rebuilt region after load.
		exhibits.append({"cell": [region.cells[0].x, region.cells[0].y], "placements": pls})
	return {
		"version": SAVE_VERSION,
		"zoo_type": String(current_zoo_type),
		"ticket_bracket": String(ticket_bracket),
		"park_open": park_open,
		"hired_keepers": hired_keepers,
		"current_weather": String(current_weather),
		"difficulty": String(scenario.difficulty) if scenario != null else "standard",
		"campaign_target": String(campaign_target),
		"campaign_days_left": campaign_days_left,
		"departures_happy": departures_happy,
		"departures_unhappy": departures_unhappy,
		"departures_total": departures_total,
		"exhibits": exhibits,
	}


# Forward-migrate an older zoo payload to the current shape, in place.
# Every reader below also defaults defensively, so migration only needs to
# handle *renames/reshapes*, not additions. Unknown FUTURE versions load
# best-effort with a warning (a newer build's save in an older build).
func _migrate_game_state(data: Dictionary) -> void:
	var version: int = int(data.get("version", 1))
	if version > SAVE_VERSION:
		push_warning("[zoo] save is version %d, this build writes %d — loading best-effort"
			% [version, SAVE_VERSION])
	# v1 → v2: departure counters didn't exist; the day restarts its verdict
	# from zero (defaults below). No reshapes yet.
	# v2 → v3: zoo_type didn't exist; older saves were all built on the
	# default plot, which is exactly what the reader below falls back to.


func _load_game_state(data: Dictionary) -> void:
	_migrate_game_state(data)
	# Land first — the plot decides the grid size and gate cell the views and
	# the rebuilt nav network anchor on. No charge: the restored ledger
	# already paid for it.
	if zoo_types != null:
		set_zoo_type(StringName(data.get("zoo_type", String(zoo_types.default_plot))), false)
	# The engine restored entities + ledger but left the reactive registries
	# stale (it doesn't re-emit entity_placed on load). Rebuild regions + the
	# nav network from the restored entities.
	RegionRegistry.reset()
	NavigationRegistry.reset()
	for inst_id in EntityRegistry.instances.keys():
		EventBus.entity_placed.emit(inst_id)

	# Restore zoo-side settings (apply_difficulty, not set_difficulty — the
	# Ledger is already restored and must not be reset).
	if scenario != null:
		scenario.apply_difficulty(StringName(data.get("difficulty", "standard")))
	park_open = bool(data.get("park_open", true))
	hired_keepers = int(data.get("hired_keepers", 0))
	current_weather = StringName(data.get("current_weather", current_weather))
	set_ticket_bracket(StringName(data.get("ticket_bracket", "standard")))
	# Marketing campaign — re-apply (or clear) the spawn-weight boost to match.
	campaign_target = StringName(data.get("campaign_target", ""))
	campaign_days_left = int(data.get("campaign_days_left", 0))
	if campaign_days_left > 0:
		_apply_campaign_weights()
	else:
		campaign_target = &""
		_restore_campaign_weights()

	# Rebuild placements directly (NOT via add_placement — that would charge
	# the build cost again and double-register maintenance, which Ledger
	# already restored). The restored recurring rules cover their upkeep.
	for ex in data.get("exhibits", []):
		var cell := Vector2i(int(ex["cell"][0]), int(ex["cell"][1]))
		var region := RegionRegistry.region_at_cell(cell)
		if region == null:
			continue
		for pd in ex.get("placements", []):
			var def_id := StringName(pd.get("def", ""))
			if not ContentDB.placeable_defs.has(def_id):
				continue
			var p := Placement.new()
			p.placeable_def_id = def_id
			p.added_at_tick = SimClock.current_tick
			p.primary_cell = region.cells[0]
			p.state = {
				"welfare": float(pd.get("welfare", 1.0)),
				"age_days": int(pd.get("age_days", 0)),
				"sick": bool(pd.get("sick", false)),
				"attitude": float(pd.get("attitude", 1.0)),
			}
			region.placements.append(p)

	departures_happy = int(data.get("departures_happy", 0))
	departures_unhappy = int(data.get("departures_unhappy", 0))
	departures_total = int(data.get("departures_total", 0))
	unhappy_need_counts.clear()

	donations_by_region.clear()
	arena_bookings.clear()
	_apply_spawn_rate()
	admin_changed.emit()
	staff_changed.emit(hired_keepers)
	difficulty_changed.emit(scenario.difficulty if scenario != null else &"standard")
