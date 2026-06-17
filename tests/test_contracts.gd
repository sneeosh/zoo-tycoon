extends GutTest
# Short-term contracts (roadmap 6.9). ContractsConfig is pure (parses
# design/tuning/contracts.md); the slate management + payout live on
# ZooBootstrap. Tests that mutate the global slate snapshot and restore it.


func before_each() -> void:
	SaveService.autosave_enabled = false


# --- ContractsConfig -------------------------------------------------------

func test_config_loads_pool_and_slots() -> void:
	var cfg := ContractsConfig.load_from_tuning()
	assert_eq(cfg.active_slots, 3)
	assert_gt(cfg.contracts.size(), 5)
	var c := cfg.by_id(&"first_litter")
	assert_false(c.is_empty())
	assert_eq(String(c["metric"]), "births")
	assert_eq(int(c["target"]), 1)
	assert_eq(int(c["reward_cash"]), 500)
	assert_eq(int(c["reward_reputation"]), 3)


# --- ZooBootstrap slate ----------------------------------------------------

func test_opening_slate_fills_every_slot() -> void:
	assert_not_null(ZooBootstrap.contracts_cfg)
	assert_eq(ZooBootstrap.active_contracts.size(),
		ZooBootstrap.contracts_cfg.active_slots)


func test_metric_births_reads_run_tally() -> void:
	var saved: int = ZooBootstrap._run_births
	ZooBootstrap._run_births = 5
	assert_eq(ZooBootstrap.contract_metric(&"births"), 5)
	ZooBootstrap._run_births = saved


func test_metric_balance_and_reputation_track_live_state() -> void:
	assert_eq(ZooBootstrap.contract_metric(&"balance"), Ledger.get_balance())
	assert_eq(ZooBootstrap.contract_metric(&"reputation"),
		ProgressionManager.reputation)


func test_progress_reports_met_when_target_reached() -> void:
	var saved: int = ZooBootstrap._run_births
	ZooBootstrap._run_births = 1
	var prog := ZooBootstrap.contract_progress(&"first_litter")
	assert_eq(int(prog["target"]), 1)
	assert_true(bool(prog["met"]))
	ZooBootstrap._run_births = saved


func test_evaluate_pays_out_and_refills() -> void:
	var saved_active: Array = ZooBootstrap.active_contracts.duplicate()
	var saved_completed: Dictionary = ZooBootstrap.completed_contracts.duplicate()
	var saved_births: int = ZooBootstrap._run_births
	var rep0: int = ProgressionManager.reputation
	var bal0: int = Ledger.get_balance()

	# Force exactly first_litter active, its births metric met.
	ZooBootstrap.active_contracts = [&"first_litter"]
	ZooBootstrap.completed_contracts = {}
	ZooBootstrap._run_births = 1
	ZooBootstrap._evaluate_contracts(1)

	assert_true(ZooBootstrap.completed_contracts.has(&"first_litter"),
		"a met contract is marked complete")
	assert_false(ZooBootstrap.active_contracts.has(&"first_litter"),
		"a completed contract leaves the active slate")
	assert_eq(Ledger.get_balance(), bal0 + 500, "reward cash posts to the ledger")
	assert_eq(ProgressionManager.reputation, rep0 + 3, "reward reputation lands")
	assert_eq(ZooBootstrap.active_contracts.size(),
		ZooBootstrap.contracts_cfg.active_slots, "the slot refills from the pool")

	# Restore the slate + reputation (ledger reward is left, as in test_events).
	ProgressionManager.set_reputation(rep0)
	ZooBootstrap.active_contracts = saved_active
	ZooBootstrap.completed_contracts = saved_completed
	ZooBootstrap._run_births = saved_births


func test_save_payload_carries_contract_state_at_v6() -> void:
	var data := ZooBootstrap._save_game_state()
	assert_eq(int(data["version"]), 6)
	assert_true(data.has("active_contracts"))
	assert_true(data.has("completed_contracts"))
	assert_true(data.has("run_births"))
	# Active ids serialize as plain strings for JSON.
	for entry in data["active_contracts"]:
		assert_true(entry is String)
