extends Control
class_name SettingsModal
## The player's settings + pause + accessibility + about + achievements
## surface (roadmap 5.4, 5.5, 5.7, and the 6.2 badge list).
##
## Deliberately self-contained: it reads/writes the `Settings` autoload and the
## `Achievements`/`Telemetry` autoloads directly, and only reaches back into
## the HUD through two signals (view flip + close), so it adds a full settings
## screen to the game without bloating the 3.6k-line main.gd.
##
## Opening it pauses the simulation (it *is* the pause menu); closing restores
## the prior run state. Every control writes straight to Settings, so it
## persists to user:// the instant it changes.

signal view_toggle_requested
signal closed

const _BG := Color("#2a3a22")
const _CARD := Color("#243019")
const _ACCENT := Color("#f4d35e")
const _TEXT := Color("#dde4cf")
const _MUTE := Color("#97a387")

var _was_paused: bool = false
var _cb_option: OptionButton
var _ach_list: VBoxContainer
var _master_slider: HSlider
var _sfx_slider: HSlider
var _ambient_slider: HSlider
var _mute_check: CheckButton
var _large_check: CheckButton
var _motion_check: CheckButton
var _tel_check: CheckButton
var _view_label: Label

const _CB_MODES := ["off", "deuteranopia", "protanopia", "tritanopia"]
const _CB_KEYS := ["settings.colorblind_off", "settings.colorblind_deut",
	"settings.colorblind_prot", "settings.colorblind_trit"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -290
	card.offset_top = -300
	card.offset_right = 290
	card.offset_bottom = 300
	card.add_theme_stylebox_override("panel", _box(_BG))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(520, 0)
	scroll.add_child(col)

	# Header
	var header := HBoxContainer.new()
	col.add_child(header)
	header.add_child(_title(I18n.t("settings.title")))
	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hsp)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# --- Audio ---
	col.add_child(_section(I18n.t("settings.audio")))
	_master_slider = _slider_row(col, I18n.t("settings.master_volume"),
		func(v): Settings.set_value(&"master_volume", v))
	_sfx_slider = _slider_row(col, I18n.t("settings.sfx_volume"),
		func(v): Settings.set_value(&"sfx_volume", v))
	_ambient_slider = _slider_row(col, I18n.t("settings.ambient_volume"),
		func(v): Settings.set_value(&"ambient_volume", v))
	_mute_check = _check_row(col, I18n.t("settings.mute"),
		func(on): Settings.set_value(&"muted", on))

	# --- Display ---
	col.add_child(_section(I18n.t("settings.display")))
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 10)
	col.add_child(view_row)
	view_row.add_child(_label(I18n.t("settings.view")))
	var vsp := Control.new()
	vsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_row.add_child(vsp)
	_view_label = _label("")
	_view_label.add_theme_color_override("font_color", _ACCENT)
	view_row.add_child(_view_label)
	var view_btn := Button.new()
	view_btn.text = "⇄"
	view_btn.custom_minimum_size = Vector2(44, 30)
	view_btn.focus_mode = Control.FOCUS_NONE
	view_btn.pressed.connect(func():
		view_toggle_requested.emit()
		_refresh_view_label())
	view_row.add_child(view_btn)

	# --- Accessibility ---
	col.add_child(_section(I18n.t("settings.accessibility")))
	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 10)
	col.add_child(cb_row)
	cb_row.add_child(_label(I18n.t("settings.colorblind")))
	var cbsp := Control.new()
	cbsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(cbsp)
	_cb_option = OptionButton.new()
	_cb_option.focus_mode = Control.FOCUS_NONE
	for i in _CB_MODES.size():
		_cb_option.add_item(I18n.t(_CB_KEYS[i]), i)
	_cb_option.item_selected.connect(func(idx: int):
		Settings.set_value(&"colorblind_mode", _CB_MODES[idx]))
	cb_row.add_child(_cb_option)
	_large_check = _check_row(col, I18n.t("settings.large_font"),
		func(on): Settings.set_value(&"large_font", on))
	_motion_check = _check_row(col, I18n.t("settings.reduced_motion"),
		func(on): Settings.set_value(&"reduced_motion", on))

	# --- Privacy / telemetry ---
	col.add_child(_section(I18n.t("settings.privacy")))
	_tel_check = _check_row(col, I18n.t("settings.telemetry"),
		func(on):
			Settings.set_value(&"telemetry_opt_in", on)
			Settings.set_value(&"telemetry_prompted", true))
	col.add_child(_caption(Telemetry.PRIVACY_NOTICE))

	# --- Achievements ---
	col.add_child(_section(I18n.t("ach.title")))
	_ach_list = VBoxContainer.new()
	_ach_list.add_theme_constant_override("separation", 4)
	col.add_child(_ach_list)

	# --- About ---
	col.add_child(_section(I18n.t("about.title")))
	col.add_child(_caption(I18n.t("about.tagline")))
	var version := String(ProjectSettings.get_setting("application/config/version", "dev"))
	col.add_child(_caption(I18n.t("about.version") % version))
	col.add_child(_caption(I18n.t("about.credits")))
	col.add_child(_label(I18n.t("about.controls_header")))
	col.add_child(_caption(I18n.t("about.controls")))

	# --- Footer ---
	col.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	col.add_child(footer)
	var reset_btn := Button.new()
	reset_btn.text = I18n.t("settings.reset")
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.pressed.connect(func():
		Settings.reset_to_defaults()
		_refresh_controls())
	footer.add_child(reset_btn)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fsp)
	var done_btn := Button.new()
	done_btn.text = I18n.t("settings.close")
	done_btn.custom_minimum_size = Vector2(90, 32)
	done_btn.focus_mode = Control.FOCUS_NONE
	done_btn.pressed.connect(close)
	footer.add_child(done_btn)


# --- Open / close (pause menu behavior) -----------------------------------

func open() -> void:
	_was_paused = SimClock.is_paused()
	SimClock.pause()
	_refresh_controls()
	_refresh_achievements()
	visible = true


func close() -> void:
	visible = false
	if not _was_paused:
		SimClock.play()
	closed.emit()


# --- Refresh from Settings ------------------------------------------------

func _refresh_controls() -> void:
	_master_slider.set_value_no_signal(Settings.get_float(&"master_volume"))
	_sfx_slider.set_value_no_signal(Settings.get_float(&"sfx_volume"))
	_ambient_slider.set_value_no_signal(Settings.get_float(&"ambient_volume"))
	_mute_check.set_pressed_no_signal(Settings.get_bool(&"muted"))
	_large_check.set_pressed_no_signal(Settings.get_bool(&"large_font"))
	_motion_check.set_pressed_no_signal(Settings.get_bool(&"reduced_motion"))
	_tel_check.set_pressed_no_signal(Settings.get_bool(&"telemetry_opt_in"))
	var mode := Settings.get_string(&"colorblind_mode")
	_cb_option.select(maxi(0, _CB_MODES.find(mode)))
	_refresh_view_label()


func _refresh_view_label() -> void:
	_view_label.text = I18n.t("settings.view_iso") if Settings.get_string(&"view") == "iso" \
		else I18n.t("settings.view_top")


func _refresh_achievements() -> void:
	for c in _ach_list.get_children():
		c.queue_free()
	var header := _caption(I18n.t("ach.progress") %
		[Achievements.unlocked_count(), Achievements.total_count()])
	header.add_theme_color_override("font_color", _ACCENT)
	_ach_list.add_child(header)
	for id in Achievements.all_ids():
		var d := Achievements.definition(id)
		var done := Achievements.is_unlocked(id)
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if done:
			row.text = "✓ %s — %s" % [d.get("label", ""), d.get("description", "")]
			row.add_theme_color_override("font_color", Palette.role("good"))
		else:
			row.text = "○ %s — %s" % [d.get("label", ""), I18n.t("ach.locked")]
			row.add_theme_color_override("font_color", _MUTE)
		_ach_list.add_child(row)


# --- Small UI builders ----------------------------------------------------

func _box(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.border_color = Color(0.55, 0.48, 0.29, 0.5)
	b.set_border_width_all(1)
	b.set_corner_radius_all(3)
	return b


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", _ACCENT)
	return l


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", _CARD.lightened(0.6))
	return l


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", _TEXT)
	return l


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", _MUTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _slider_row(col: VBoxContainer, label: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var lbl := _label(label)
	lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(220, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_change)
	row.add_child(s)
	return s


func _check_row(col: VBoxContainer, label: String, on_toggle: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var lbl := _label(label)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var c := CheckButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(on_toggle)
	row.add_child(c)
	return c
