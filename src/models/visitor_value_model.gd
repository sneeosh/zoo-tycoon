extends IValueModel
class_name VisitorValueModel
# Zoo's IValueModel implementation — Prompt 10 / engine/docs/build-plan.md §3.
#
# A real game would tune fees by visitor traits, time of day, condition
# modifiers, etc. For the validation pass we just expose two flat prices
# (ticket + food purchase). The numbers live in code here because Prompt
# 10 explicitly keeps this trivial; if these ever grew real depth, they'd
# move to design/tuning/economy.md.

# Defaults — used by tests and as the fallback when ZooBootstrap hasn't
# loaded yet. The runtime entry fee is editable via the entrance-gate
# admin modal and lives in ZooBootstrap.entry_fee.
const TICKET_PRICE: int = 10
const FOOD_PRICE: int = 5


func compute_entry_fee(agent: Agent) -> int:
	var base: int = ZooBootstrap.entry_fee if ZooBootstrap.scenario != null else TICKET_PRICE
	return int(round(base * _spend_mult(agent)))


func compute_food_purchase(agent: Agent) -> int:
	return int(round(FOOD_PRICE * _spend_mult(agent)))


# Per-archetype spend multiplier (Family parties pay more, Children less).
# Defaults to 1.0 — so the Adult `visitor` baseline is unchanged.
func _spend_mult(agent: Agent) -> float:
	if ZooBootstrap.services == null:
		return 1.0
	return ZooBootstrap.services.spend_multiplier(agent.agent_type_id)
