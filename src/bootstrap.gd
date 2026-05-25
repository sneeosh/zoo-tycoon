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
	Accounting.register_category(&"zoo_utilities", Accounting.Category.OPERATING_EXPENSE)
	Accounting.register_category(&"zoo_staff",     Accounting.Category.OPERATING_EXPENSE)

	# Grant the starting tier so starter content is immediately available
	# without the player having to unlock anything on day 1.
	ProgressionManager.force_unlock(&"start")

	scenario = Scenario.load_from_tuning()

	print("[Zoo] Bootstrap complete. Starting balance: %d" % Ledger.get_balance())


# Convenience for game UI to read the zoo's quality rating without
# instantiating a model itself.
func get_quality_rating() -> float:
	return _zoo_quality.compute_rating()
