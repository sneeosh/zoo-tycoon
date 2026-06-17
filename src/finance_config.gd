extends RefCounted
class_name FinanceConfig
# Economic-lever tuning from design/tuning/finance.md (roadmap 6.9): a loan and
# a sponsorship. Game-side; the lever logic + save round-trip live in
# src/bootstrap.gd. This class parses the two sections and derives the loan's
# daily instalment.

const TUNING_PATH := "res://design/tuning/finance.md"

var loan_principal: int = 4000
var loan_interest_rate: float = 0.25
var loan_term_days: int = 20

var sponsor_signing_bonus: int = 1500
var sponsor_daily_income: int = 80
var sponsor_term_days: int = 25
var sponsor_reputation_cost: int = 3


static func load_from_tuning() -> FinanceConfig:
	var f := FinanceConfig.new()
	var parsed: Dictionary = MarkdownTuningParser.parse(TUNING_PATH)
	for err in parsed["errors"]:
		push_error("[finance] %s" % err)
	var loan: Dictionary = parsed["sections"].get("Loan", {}).get("scalars", {})
	f.loan_principal = maxi(0, int(_f(loan, "principal", float(f.loan_principal))))
	f.loan_interest_rate = maxf(0.0, _f(loan, "interest_rate", f.loan_interest_rate))
	f.loan_term_days = maxi(1, int(_f(loan, "term_days", float(f.loan_term_days))))
	var sp: Dictionary = parsed["sections"].get("Sponsorship", {}).get("scalars", {})
	f.sponsor_signing_bonus = maxi(0, int(_f(sp, "signing_bonus", float(f.sponsor_signing_bonus))))
	f.sponsor_daily_income = maxi(0, int(_f(sp, "daily_income", float(f.sponsor_daily_income))))
	f.sponsor_term_days = maxi(1, int(_f(sp, "term_days", float(f.sponsor_term_days))))
	f.sponsor_reputation_cost = maxi(0, int(_f(sp, "reputation_cost", float(f.sponsor_reputation_cost))))
	return f


# Total owed over the life of the loan (principal + interest).
func loan_total() -> int:
	return int(round(float(loan_principal) * (1.0 + loan_interest_rate)))


# Equal daily instalment (rounded up so the sum covers the total owed).
func loan_daily_payment() -> int:
	return int(ceil(float(loan_total()) / float(maxi(1, loan_term_days))))


static func _f(scalars: Dictionary, key: String, fallback: float) -> float:
	var entry: Dictionary = scalars.get(key, {})
	if entry.is_empty():
		return fallback
	var raw := String(entry.get("raw", "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback
