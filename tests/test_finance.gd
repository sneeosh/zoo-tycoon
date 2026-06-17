extends GutTest
# Economic levers (roadmap 6.9): a loan and a sponsorship. FinanceConfig is
# pure; the levers live on ZooBootstrap. Tests restore any global state.


func before_each() -> void:
	SaveService.autosave_enabled = false


# --- FinanceConfig ---------------------------------------------------------

func test_config_loads_and_derives_instalment() -> void:
	var f := FinanceConfig.load_from_tuning()
	assert_eq(f.loan_principal, 4000)
	assert_almost_eq(f.loan_interest_rate, 0.25, 0.001)
	assert_eq(f.loan_term_days, 20)
	# Total owed = 4000 * 1.25 = 5000; daily = ceil(5000/20) = 250.
	assert_eq(f.loan_total(), 5000)
	assert_eq(f.loan_daily_payment(), 250)


# --- Loan ------------------------------------------------------------------

func test_take_loan_credits_principal_and_sets_term() -> void:
	_reset_finance()
	var bal0 := Ledger.get_balance()
	var fin: FinanceConfig = ZooBootstrap.finance
	assert_true(ZooBootstrap.take_loan())
	assert_eq(Ledger.get_balance(), bal0 + fin.loan_principal)
	assert_eq(ZooBootstrap.loan_days_left, fin.loan_term_days)
	assert_eq(ZooBootstrap.loan_daily_payment, fin.loan_daily_payment())
	# Outstanding = remaining instalments.
	assert_eq(ZooBootstrap.loan_outstanding(),
		fin.loan_term_days * fin.loan_daily_payment())
	# A second loan is refused while one is outstanding.
	assert_false(ZooBootstrap.take_loan())
	_reset_finance()


func test_loan_repays_at_day_close() -> void:
	_reset_finance()
	ZooBootstrap.take_loan()
	var days0: int = ZooBootstrap.loan_days_left
	var pay: int = ZooBootstrap.loan_daily_payment
	var bal0 := Ledger.get_balance()
	ZooBootstrap._tick_finance(1)
	assert_eq(ZooBootstrap.loan_days_left, days0 - 1)
	assert_eq(Ledger.get_balance(), bal0 - pay)
	_reset_finance()


# --- Sponsor ---------------------------------------------------------------

func test_accept_sponsor_pays_bonus_and_costs_reputation() -> void:
	_reset_finance()
	var bal0 := Ledger.get_balance()
	var rep0 := ProgressionManager.reputation
	var fin: FinanceConfig = ZooBootstrap.finance
	assert_true(ZooBootstrap.accept_sponsor())
	assert_eq(Ledger.get_balance(), bal0 + fin.sponsor_signing_bonus)
	assert_eq(ProgressionManager.reputation, rep0 - fin.sponsor_reputation_cost)
	assert_eq(ZooBootstrap.sponsor_days_left, fin.sponsor_term_days)
	assert_false(ZooBootstrap.accept_sponsor(), "one sponsor at a time")
	ProgressionManager.set_reputation(rep0)
	_reset_finance()


func test_sponsor_pays_daily_at_day_close() -> void:
	_reset_finance()
	var rep0 := ProgressionManager.reputation
	ZooBootstrap.accept_sponsor()
	var days0: int = ZooBootstrap.sponsor_days_left
	var income: int = ZooBootstrap.sponsor_daily_income
	var bal0 := Ledger.get_balance()
	ZooBootstrap._tick_finance(1)
	assert_eq(ZooBootstrap.sponsor_days_left, days0 - 1)
	assert_eq(Ledger.get_balance(), bal0 + income)
	ProgressionManager.set_reputation(rep0)
	_reset_finance()


# --- Persistence -----------------------------------------------------------

func test_save_payload_carries_finance_at_v8() -> void:
	var data := ZooBootstrap._save_game_state()
	assert_eq(int(data["version"]), 8)
	assert_true(data.has("loan_days_left"))
	assert_true(data.has("sponsor_days_left"))


func _reset_finance() -> void:
	ZooBootstrap.loan_days_left = 0
	ZooBootstrap.loan_daily_payment = 0
	ZooBootstrap.sponsor_days_left = 0
	ZooBootstrap.sponsor_daily_income = 0
