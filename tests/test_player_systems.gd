extends GutTest
# Player-facing systems added in the launch-readiness sweep (roadmap Phase 5/6):
# persisted Settings (5.4), colorblind Palette (5.5), the I18n catalog (6.4),
# opt-in Telemetry (5.3), and Achievements (6.2). These are all engine-clean
# autoloads/helpers, so the tests exercise them directly.


func before_each() -> void:
	SaveService.autosave_enabled = false


# --- Settings (5.4) -------------------------------------------------------

func test_settings_defaults_present() -> void:
	# Every schema key resolves to its default even before anything is set.
	assert_eq(Settings.get_float(&"master_volume"), 0.8)
	assert_false(Settings.get_bool(&"telemetry_opt_in"))
	assert_eq(Settings.get_string(&"view"), "iso")


func test_settings_coerce_and_clamp() -> void:
	Settings.set_value(&"master_volume", 2.5)   # out of [0,1]
	assert_eq(Settings.get_float(&"master_volume"), 1.0)
	Settings.set_value(&"muted", "true")        # coerced to bool
	assert_true(Settings.get_bool(&"muted"))
	Settings.set_value(&"muted", false)


func test_settings_unknown_key_rejected() -> void:
	assert_false(Settings.set_value(&"not_a_setting", 1))


func test_settings_persist_round_trip() -> void:
	Settings.set_value(&"colorblind_mode", "deuteranopia")
	Settings.set_value(&"master_volume", 0.3)
	# A fresh read from disk reproduces what we wrote.
	Settings.load_from_disk()
	assert_eq(Settings.get_string(&"colorblind_mode"), "deuteranopia")
	assert_eq(Settings.get_float(&"master_volume"), 0.3)
	Settings.reset_to_defaults()


# --- Palette (5.5) --------------------------------------------------------

func test_palette_welfare_thresholds() -> void:
	Settings.set_value(&"colorblind_mode", "off")
	assert_eq(Palette.welfare(0.9), Palette.role("good"))
	assert_eq(Palette.welfare(0.5), Palette.role("warn"))
	assert_eq(Palette.welfare(0.1), Palette.role("bad"))


func test_palette_mode_shifts_colors() -> void:
	Settings.set_value(&"colorblind_mode", "off")
	var default_good := Palette.role("good")
	Settings.set_value(&"colorblind_mode", "deuteranopia")
	assert_ne(Palette.role("good"), default_good)
	Settings.set_value(&"colorblind_mode", "off")


# --- I18n (6.4) -----------------------------------------------------------

func test_i18n_known_key() -> void:
	assert_eq(I18n.t("top.save"), "Save")


func test_i18n_missing_key_returns_key() -> void:
	assert_eq(I18n.t("definitely.not.a.real.key"), "definitely.not.a.real.key")


# The 6.9 cluster surfaces (contracts / zoo identity / finance) must all be in
# the catalog — a missing key would render as a visible "domain.key" in the HUD.
func test_i18n_6_9_keys_present() -> void:
	for key in ["contracts.title", "contracts.complete_head", "contracts.complete_tail",
			"contracts.reward_rep", "welcome.name_label", "top.star_tip",
			"top.zoo_name_tip", "finance.title", "finance.loan_btn",
			"finance.loan_active", "finance.sponsor_btn", "finance.caption",
			"finance.loan_log_tail", "finance.sponsor_busy"]:
		assert_ne(I18n.t(key), key, "missing i18n key: %s" % key)


# Format-bearing keys must interpolate with the arg shapes their call sites use.
func test_i18n_6_9_format_keys_interpolate() -> void:
	assert_string_contains(I18n.t("finance.loan_btn") % "4,000", "4,000")
	assert_string_contains(I18n.t("contracts.reward_rep") % 3, "3")
	assert_string_contains(I18n.t("contracts.reward_rep_short") % 2, "2")
	assert_string_contains(I18n.t("contracts.complete_tail") % ["Leo", "$500"], "Leo")
	# The finance caption takes eight args; a wrong count would error here.
	assert_string_contains(
		I18n.t("finance.caption") % ["4,000", "250", 20, "5,000", "1,500", 80, 25, 3],
		"250")


# --- Telemetry (5.3) ------------------------------------------------------

func test_telemetry_disabled_by_default() -> void:
	Settings.set_value(&"telemetry_opt_in", false)
	assert_false(Telemetry.is_enabled())


func test_telemetry_opt_in_enables() -> void:
	Settings.set_value(&"telemetry_opt_in", true)
	assert_true(Telemetry.is_enabled())
	Settings.set_value(&"telemetry_opt_in", false)


# --- Achievements (6.2) ---------------------------------------------------

func test_achievements_loaded_from_tuning() -> void:
	assert_gt(Achievements.total_count(), 0, "achievements.md should define rows")
	var d := Achievements.definition(&"open_for_business")
	assert_eq(d.get("metric"), &"guests")
	assert_eq(int(d.get("threshold")), 1)


# --- Animal naming + lineage (6.5) ----------------------------------------

func test_animal_name_lazy_and_stable() -> void:
	var p := Placement.new()
	p.placeable_def_id = &"lion"
	var n := ZooBootstrap.name_for(p)
	assert_ne(n, "", "an animal gets a name on first sight")
	assert_eq(ZooBootstrap.name_for(p), n, "name is stable, not reassigned")


func test_animal_rename_trims_and_ignores_blank() -> void:
	var p := Placement.new()
	var r := Region.new()
	r.placements.append(p)
	ZooBootstrap.rename_animal(r, 0, "  Leo  ")
	assert_eq(String(p.state.get("name", "")), "Leo")
	ZooBootstrap.rename_animal(r, 0, "   ")   # blank keeps the prior name
	assert_eq(String(p.state.get("name", "")), "Leo")
