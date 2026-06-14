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
