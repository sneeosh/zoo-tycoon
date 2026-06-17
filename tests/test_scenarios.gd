extends GutTest
# Hand-tuned scenarios (roadmap 6.9 F): themed presets layered into the same
# selectable-preset list as the difficulties. Scenario is pure (parses
# design/tuning/scenario.md), so this exercises it directly.


func test_scenarios_join_the_preset_list() -> void:
	var s := Scenario.load_from_tuning()
	# The three difficulties plus the three scenarios.
	assert_true(_has(s.difficulties, &"standard"))
	assert_true(_has(s.difficulties, &"rescue"))
	assert_true(_has(s.difficulties, &"tight_budget"))
	assert_true(_has(s.difficulties, &"frozen"))


func test_difficulty_presets_have_blank_scenario_extras() -> void:
	var s := Scenario.load_from_tuning()
	var std := s.difficulty_preset(&"standard")
	assert_eq(String(std["zoo_type"]), "")
	assert_eq(String(std["blurb"]), "")


func test_scenario_carries_plot_and_blurb() -> void:
	var s := Scenario.load_from_tuning()
	assert_eq(s.preset_zoo_type(&"frozen"), &"glacier")
	var resc := s.difficulty_preset(&"rescue")
	assert_false(String(resc["blurb"]).is_empty())
	assert_eq(s.preset_zoo_type(&"rescue"), &"meadow")


func test_apply_scenario_overlays_bar_and_blurb() -> void:
	var s := Scenario.load_from_tuning()
	assert_true(s.apply_difficulty(&"frozen"))
	assert_eq(s.difficulty, &"frozen")
	assert_eq(s.target_cash, 22000)
	assert_eq(s.days_limit, 34)
	assert_false(s.active_blurb.is_empty())
	# A plain difficulty clears the blurb again.
	s.apply_difficulty(&"standard")
	assert_eq(s.active_blurb, "")


func test_forced_plots_leave_the_purchase_buffer() -> void:
	# A scenario's suggested plot must be affordable from its starting cash,
	# leaving the zoo_types min_cash_after_purchase buffer — otherwise the
	# welcome screen would disable the very plot it suggested.
	var s := Scenario.load_from_tuning()
	var zt: ZooTypeConfig = ZooBootstrap.zoo_types
	assert_not_null(zt)
	for id in [&"rescue", &"tight_budget", &"frozen"]:
		var preset := s.difficulty_preset(id)
		var plot_id := s.preset_zoo_type(id)
		if plot_id == &"":
			continue
		var plot := zt.plot(plot_id)
		assert_false(plot.is_empty(), "scenario %s names a real plot" % id)
		var left: int = int(preset["starting_cash"]) - int(plot["cost"])
		assert_gte(left, zt.min_cash_after_purchase,
			"scenario %s can afford its plot %s" % [id, plot_id])


func _has(presets: Array, id: StringName) -> bool:
	for p in presets:
		if p["id"] == id:
			return true
	return false
