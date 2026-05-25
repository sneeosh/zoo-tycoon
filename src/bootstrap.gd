extends Node
# Zoo Tycoon — startup wiring. Autoloaded after all engine autoloads.
#
# By the time this _ready() runs, ContentDB has already loaded
# design/tuning/*.md. We just need to register the zoo's
# IAgentBehavior + ISatisfactionModel implementations against the
# visitor AgentType so the engine knows what to call.

# Keep the instances alive at module scope. AgentPool holds refs but
# storing here too means we can swap them at runtime if needed.
var _visitor_behavior: VisitorBehavior
var _visitor_satisfaction: VisitorSatisfactionModel
var _zoo_quality: ZooQualityRating  # callable from game UI


func _ready() -> void:
	if not ContentDB.is_loaded:
		push_error("[Zoo] ContentDB failed to load — refusing to bootstrap. Errors above.")
		return

	_visitor_behavior = VisitorBehavior.new()
	_visitor_satisfaction = VisitorSatisfactionModel.new()
	_zoo_quality = ZooQualityRating.new()

	AgentPool.register_behavior(&"visitor", _visitor_behavior)
	AgentPool.register_satisfaction_model(&"visitor", _visitor_satisfaction)

	# Grant the starting tier so lion_exhibit / food_stand / restroom /
	# visitor are immediately available without the player having to
	# unlock anything on day 1.
	ProgressionManager.force_unlock(&"start")

	print("[Zoo] Bootstrap complete. Starting balance: %d" % Ledger.get_balance())


# Convenience for game UI to read the zoo's quality rating without
# instantiating a model itself.
func get_quality_rating() -> float:
	return _zoo_quality.compute_rating()
