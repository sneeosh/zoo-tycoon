extends IValueModel
class_name VisitorValueModel
# Zoo's IValueModel implementation — Prompt 10 / engine/docs/build-plan.md §3.
#
# A real game would tune fees by visitor traits, time of day, condition
# modifiers, etc. For the validation pass we just expose two flat prices
# (ticket + food purchase). The numbers live in code here because Prompt
# 10 explicitly keeps this trivial; if these ever grew real depth, they'd
# move to design/tuning/economy.md.

const TICKET_PRICE: int = 10
const FOOD_PRICE: int = 5


func compute_entry_fee(_agent: Agent) -> int:
	return TICKET_PRICE


func compute_food_purchase(_agent: Agent) -> int:
	return FOOD_PRICE
