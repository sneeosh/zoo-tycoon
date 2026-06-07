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
var _visitor_behavior: VisitorBehavior
var _visitor_satisfaction: VisitorSatisfactionModel
var _zoo_quality: ZooQualityRating         # callable from game UI
var _animal_happiness: ZooAnimalHappiness  # engine reads via EffectResolver

# Scenario (win/lose params) loaded from design/tuning/scenario.md at startup.
# Exposed so the UI can show targets, evaluate end-game, etc.
var scenario: Scenario

# Per-need service pricing + spillover (design/tuning/services.md). Read by
# VisitorBehavior when a guest satisfies a need at a satisfier entity.
var services: ServiceConfig

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
var park_open: bool = true
var _default_base_spawn_rate: float = 0.5

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

	AgentPool.register_behavior(&"visitor", _visitor_behavior)
	AgentPool.register_satisfaction_model(&"visitor", _visitor_satisfaction)
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
	donations_by_region.clear()

	# Cache the engine's default spawn rate so the open/closed toggle and
	# ticket-bracket elasticity can scale from it. ContentDB has already
	# applied balance.md by now.
	_default_base_spawn_rate = AgentPool.base_spawn_rate

	# Start on the bracket marked default in services.md (Standard / $10).
	if services != null and services.default_bracket != &"":
		set_ticket_bracket(services.default_bracket)

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
# when the park is closed. Composes with the engine's per-day
# satisfaction→spawn multiplier (AgentPool.current_spawn_multiplier).
func _apply_spawn_rate() -> void:
	AgentPool.base_spawn_rate = (_default_base_spawn_rate
		* current_demand_multiplier()) if park_open else 0.0


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
