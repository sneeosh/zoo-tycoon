extends Node
# Zoo Tycoon — main scene script.
#
# Game UI for the engine validation game. Builds a top stat bar, a build
# menu, a tile-grid map view, and an event log — all programmatically — and
# wires them to the engine's autoloads.
#
# This script is GAME CODE — not engine. The engine drives ticks, spawning,
# satisfaction, etc.; this just stages content and observes/dispatches input.

const STARTER_VISITOR_COUNT: int = 4
const HUD_REFRESH_SECONDS: float = 0.2
const LOG_MAX_LINES: int = 60
const MAP_VIEW_SCRIPT := preload("res://src/ui/map_view.gd")

# Distinct colour per entity type. Keys must match design/tuning/entities.md ids.
const ENTITY_COLORS := {
	&"grass_patch": Color("#3f6b35"),
	&"rock_patch":  Color("#65726f"),
	&"water_patch": Color("#3a7eb2"),
	&"cage_panel":  Color("#7e8a92"),
	&"food_stand":  Color("#e27d60"),
	&"restroom":    Color("#41b3a3"),
}

var _selected_def_id: StringName = &""
var _map_view: MapView
var _money_label: Label
var _day_label: Label
var _quality_label: Label
var _reputation_label: Label
var _agents_label: Label
var _yesterday_label: Label
var _log_text: RichTextLabel
var _build_buttons: Dictionary = {}    # StringName -> Button
var _speed_buttons: Dictionary = {}    # String -> Button

var _hud_accumulator: float = 0.0


func _ready() -> void:
	_build_ui()
	_wire_engine_signals()
	_refresh_speed_buttons()

	# Headless harness modes take over before anything game-specific runs,
	# so scripted scenarios start from a known-empty world.
	var sess := ScriptedSession.create_from_env(self)
	if sess != null:
		sess.register_action("assert_quality_at_least", _harness_assert_quality)
		sess.register_action("hover_at", _harness_hover_at)
		await sess.run()
		return

	_stage_starter_park()
	_refresh_hud()
	_push_log("Zoo opened. Click a building, then click the map to place. Right-click to sell.")

	# One-shot screenshot mode runs against the staged starter park.
	if await Screenshotter.maybe_capture(self):
		return


# Build the tooltip body shown when hovering a build-menu button.
# Pulls everything from EntityDef so adding a new entity to tuning
# requires no UI changes — its tooltip auto-populates.
func _build_tooltip_for(def: EntityDef) -> String:
	var lines: Array[String] = []
	lines.append(def.display_name)
	lines.append("Build:  $%d" % def.build_cost)
	if def.maintenance_cost > 0:
		lines.append("Upkeep: $%d/day" % def.maintenance_cost)
	lines.append("Size:   %d × %d tiles" % [def.footprint.x, def.footprint.y])
	if not def.satisfies.is_empty():
		var sats: Array[String] = []
		for s in def.satisfies:
			sats.append(String(s))
		lines.append("Satisfies: %s" % ", ".join(sats))
	if not def.appeal_profile.is_empty():
		var bits: Array[String] = []
		for axis in def.appeal_profile.keys():
			bits.append("%s %.1f" % [String(axis), def.appeal_profile[axis]])
		lines.append("Appeal: %s" % ", ".join(bits))
	# Effects worth knowing about (revenue / satisfaction proximity bonuses).
	for eff: Effect in def.effects:
		var target_label := String(eff.target).capitalize()
		if eff.proximity > 0.0:
			lines.append("• %s %+.2f within %d tiles" %
				[target_label, eff.magnitude, int(eff.proximity)])
		else:
			lines.append("• %s %+.2f (global)" %
				[target_label, eff.magnitude])
	return "\n".join(lines)


func _harness_hover_at(action: Dictionary) -> bool:
	# Drives the MapView's hover state from a scripted scenario so we can
	# screenshot the inspector card without a real cursor. action.pos is
	# in world (tile) coordinates.
	var pos_arr: Array = action.get("pos", [0, 0])
	if _map_view == null:
		return false
	_map_view.force_hover_at_world(Vector2(float(pos_arr[0]), float(pos_arr[1])))
	return true


func _harness_assert_quality(action: Dictionary) -> bool:
	var min_v := float(action.get("value", 0.0))
	var actual: float = ZooBootstrap.get_quality_rating()
	var ok := actual >= min_v
	var status := "OK " if ok else "FAIL"
	print("[assert %s] quality >= %.2f  (actual=%.2f)" % [status, min_v, actual])
	return ok


# ============================================================================
# UI construction
# ============================================================================

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color("#141d18")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	_build_top_bar(root)
	_build_left_panel(root)
	_build_right_column(root)


func _build_top_bar(parent: Control) -> void:
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 56)
	top.add_theme_stylebox_override("panel", _panel_box(Color("#23302a")))
	parent.add_child(top)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	top.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	_money_label = _stat("$0", 22, Color("#f4d35e"))
	_day_label = _stat("Day 1", 16, Color("#e6e6e6"))
	_quality_label = _stat("0.0★", 16, Color("#f4d35e"))
	_reputation_label = _stat("Rep 0", 16, Color("#c9a4ff"))
	_agents_label = _stat("0 guests", 16, Color("#a8c4b0"))
	_yesterday_label = _stat("", 12, Color("#7e9286"))
	row.add_child(_money_label)
	row.add_child(_v_sep())
	row.add_child(_day_label)
	row.add_child(_quality_label)
	row.add_child(_reputation_label)
	row.add_child(_agents_label)
	row.add_child(_v_sep())
	row.add_child(_yesterday_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(56, 36)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_on_save_pressed)
	row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(56, 36)
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.pressed.connect(_on_load_pressed)
	row.add_child(load_btn)

	# Small separator before speed controls keeps the two groups distinct.
	row.add_child(_v_sep())

	for spec in [
		{"key": "pause", "label": "Pause"},
		{"key": "1x",    "label": "1x"},
		{"key": "2x",    "label": "2x"},
		{"key": "4x",    "label": "4x"},
	]:
		var b := Button.new()
		b.text = spec["label"]
		b.custom_minimum_size = Vector2(56, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_speed_pressed.bind(spec["key"]))
		_speed_buttons[spec["key"]] = b
		row.add_child(b)


func _build_left_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_top = 56
	panel.offset_left = 0
	panel.offset_bottom = 0
	panel.custom_minimum_size = Vector2(220, 0)
	panel.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "BUILD"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#7e9286"))
	col.add_child(title)

	# Stable ordering: walk in tuning-file declaration order if we can.
	var def_ids: Array = ContentDB.entity_defs.keys()
	def_ids.sort_custom(func(a, b): return String(a) < String(b))
	for def_id in def_ids:
		var def: EntityDef = ContentDB.entity_defs[def_id]
		var btn := Button.new()
		btn.text = "%s\n$%d  ·  %d×%d" % [
			def.display_name,
			def.build_cost,
			def.footprint.x,
			def.footprint.y,
		]
		btn.tooltip_text = _build_tooltip_for(def)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 52)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggled.connect(_on_build_toggled.bind(def_id))
		_build_buttons[def_id] = btn
		col.add_child(btn)

	col.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "L-click map: place\nR-click map: sell (½ refund)\nSpace: add a visitor\nP: toggle pause"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("#7e9286"))
	col.add_child(hint)


func _build_right_column(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 220
	col.offset_top = 56
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_map_view = MAP_VIEW_SCRIPT.new()
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.entity_colors = ENTITY_COLORS
	_map_view.placement_requested.connect(_on_placement_requested)
	_map_view.remove_requested.connect(_on_remove_requested)
	col.add_child(_map_view)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 140)
	log_panel.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	col.add_child(log_panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 14)
	log_margin.add_theme_constant_override("margin_right", 14)
	log_margin.add_theme_constant_override("margin_top", 10)
	log_margin.add_theme_constant_override("margin_bottom", 10)
	log_panel.add_child(log_margin)

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_active = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", 12)
	_log_text.add_theme_color_override("default_color", Color("#a8c4b0"))
	log_margin.add_child(_log_text)


# ============================================================================
# Engine wiring
# ============================================================================

func _wire_engine_signals() -> void:
	EventBus.balance_changed.connect(func(_b): _refresh_affordability())
	EventBus.day_settled.connect(_on_day_settled)
	EventBus.entity_placed.connect(_on_entity_placed)
	EventBus.entity_removed.connect(_on_entity_removed)
	EventBus.agent_spawned.connect(func(id):
		var ag := AgentPool.get_agent(id)
		if ag != null:
			_push_log("[color=#a8c4b0]A guest entered.[/color]"))
	EventBus.unlock_acquired.connect(func(node_id):
		_push_log("[color=#f4d35e]Unlocked: %s[/color]" % node_id))


func _stage_starter_park() -> void:
	# v0.4.0: paint a small mixed region (grass + rocks) so a Lion (which
	# needs both habitats) can move in on day 1. Engine's RegionRegistry
	# auto-detects the connected component as one Region.
	for x in range(3, 6):
		for y in range(3, 5):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	# A couple of rock tiles to give the region the `rocks` zone tag.
	EntityRegistry.place(&"rock_patch", Vector2i(6, 3))
	EntityRegistry.place(&"rock_patch", Vector2i(6, 4))

	EntityRegistry.place(&"food_stand", Vector2i(11, 3))
	EntityRegistry.place(&"restroom",   Vector2i(15, 3))

	# Drop a starter Lion + the infrastructure that keeps it happy.
	var region := RegionRegistry.region_at_cell(Vector2i(3, 3))
	if region != null:
		RegionRegistry.add_placement(region.region_id, &"lion")
		RegionRegistry.add_placement(region.region_id, &"feeding_trough")
		RegionRegistry.add_placement(region.region_id, &"water_trough")
	for i in range(STARTER_VISITOR_COUNT):
		AgentPool.spawn(&"visitor", Vector2(
			SimClock.rng.randf_range(0, 6),
			SimClock.rng.randf_range(0, 6)))


# ============================================================================
# Per-frame HUD refresh
# ============================================================================

func _process(delta: float) -> void:
	_hud_accumulator += delta
	if _hud_accumulator >= HUD_REFRESH_SECONDS:
		_hud_accumulator = 0.0
		_refresh_hud()


func _refresh_hud() -> void:
	var breakdown: Dictionary = Ledger.get_yesterday_breakdown()
	var quality: float = ZooBootstrap.get_quality_rating()
	_money_label.text = "$%d" % Ledger.get_balance()
	# Engine current_day is 0-indexed (incremented on day boundaries).
	# Player-facing displays use 1-indexed days.
	_day_label.text = "Day %d  ·  Tick %d" % [SimClock.current_day + 1, SimClock.current_tick]
	_quality_label.text = "%.1f★" % quality
	var rep := ProgressionManager.reputation
	var rep_color := Color("#c9a4ff") if rep >= 0 else Color("#e76f51")
	_reputation_label.text = "Rep %+d" % rep
	_reputation_label.add_theme_color_override("font_color", rep_color)
	_agents_label.text = "%d guests" % AgentPool.alive_count()
	_yesterday_label.text = "Yesterday  +$%d  −$%d  =  $%d" % [
		breakdown["income"], breakdown["expense"], breakdown["net"]]


func _refresh_affordability() -> void:
	var balance := Ledger.get_balance()
	for def_id in _build_buttons.keys():
		var def: EntityDef = ContentDB.entity_defs[def_id]
		var btn: Button = _build_buttons[def_id]
		btn.disabled = balance < def.build_cost
		if btn.disabled and btn.button_pressed:
			btn.button_pressed = false
			_selected_def_id = &""
			_map_view.preview_def_id = &""


func _refresh_speed_buttons() -> void:
	var current := "pause"
	if not SimClock.is_paused():
		var sp := SimClock.speed
		if is_equal_approx(sp, 2.0):
			current = "2x"
		elif is_equal_approx(sp, 4.0):
			current = "4x"
		else:
			current = "1x"
	for key in _speed_buttons.keys():
		var b: Button = _speed_buttons[key]
		var active: bool = key == current
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f4d35e") if active else Color("#2c3a32")
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_color_override("font_color",
			Color("#1a241f") if active else Color("#e6e6e6"))


# ============================================================================
# Input
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			AgentPool.spawn(&"visitor", Vector2(
				SimClock.rng.randf_range(0, 6),
				SimClock.rng.randf_range(0, 6)))
			_push_log("[color=#7e9286]+1 visitor (manual)[/color]")
		KEY_P:
			if SimClock.is_paused():
				SimClock.play()
			else:
				SimClock.pause()
			_refresh_speed_buttons()


func _on_build_toggled(pressed: bool, def_id: StringName) -> void:
	if not pressed:
		if _selected_def_id == def_id:
			_selected_def_id = &""
			_map_view.preview_def_id = &""
		return
	# Single-select: untoggle every other build button.
	for other_id in _build_buttons.keys():
		if other_id != def_id:
			(_build_buttons[other_id] as Button).set_pressed_no_signal(false)
	_selected_def_id = def_id
	_map_view.preview_def_id = def_id


const SAVE_SLOT := "main"


func _on_save_pressed() -> void:
	var ok := SaveService.save_to_slot(SAVE_SLOT)
	if ok:
		_push_log("[color=#f4d35e]Saved.[/color]  Slot: %s" % SAVE_SLOT)
	else:
		_push_log("[color=#e76f51]Save failed.[/color]")


func _on_load_pressed() -> void:
	if not SaveService.slot_exists(SAVE_SLOT):
		_push_log("[color=#e76f51]No save found in slot %s.[/color]" % SAVE_SLOT)
		return
	var ok := SaveService.load_from_slot(SAVE_SLOT)
	if ok:
		_push_log("[color=#83c779]Loaded.[/color]  Day %d, Balance $%d" %
			[SimClock.current_day + 1, Ledger.get_balance()])
		_refresh_hud()
		_refresh_speed_buttons()
	else:
		_push_log("[color=#e76f51]Load failed — see error log.[/color]")


func _on_speed_pressed(key: String) -> void:
	match key:
		"pause":
			SimClock.pause()
		"1x":
			SimClock.set_speed(1.0)
			SimClock.play()
		"2x":
			SimClock.set_speed(2.0)
			SimClock.play()
		"4x":
			SimClock.set_speed(4.0)
			SimClock.play()
	_refresh_speed_buttons()


func _on_placement_requested(cell: Vector2i) -> void:
	if _selected_def_id == &"":
		return
	var id := EntityRegistry.place(_selected_def_id, cell)
	if id == 0:
		# place() already pushed a warning; surface it for the player.
		var def: EntityDef = ContentDB.get_entity_def(_selected_def_id)
		var reason := "blocked"
		if Ledger.get_balance() < def.build_cost:
			reason = "not enough money"
		_push_log("[color=#e76f51]Can't place %s at (%d, %d): %s[/color]" %
			[def.display_name, cell.x, cell.y, reason])


func _on_remove_requested(cell: Vector2i) -> void:
	# Find the instance whose footprint covers `cell`.
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		if cell.x >= inst.position.x and cell.x < inst.position.x + def.footprint.x \
		and cell.y >= inst.position.y and cell.y < inst.position.y + def.footprint.y:
			EntityRegistry.remove(inst_id)
			return


# ============================================================================
# Event-log helpers
# ============================================================================

func _on_day_settled(day: int, income: int, expense: int) -> void:
	var net := income - expense
	var color := "#83c779" if net >= 0 else "#e76f51"
	# Engine day is 0-indexed; show 1-indexed in the log.
	day = day + 1
	_push_log("[b]Day %d closed.[/b] [color=%s]Net $%d[/color]  (+$%d / −$%d)" %
		[day, color, net, income, expense])


func _on_entity_placed(inst_id: int) -> void:
	var inst := EntityRegistry.get_instance(inst_id)
	if inst == null:
		return
	var def := inst.get_def()
	_push_log("Built [b]%s[/b] for $%d" % [def.display_name, def.build_cost])


func _on_entity_removed(_inst_id: int) -> void:
	_push_log("Sold a building.")


func _push_log(line: String) -> void:
	_log_text.append_text(line + "\n")
	# Trim if it grows; RichTextLabel doesn't auto-cap.
	if _log_text.get_paragraph_count() > LOG_MAX_LINES:
		_log_text.remove_paragraph(0)


# ============================================================================
# Style helpers
# ============================================================================

func _panel_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(1, 1, 1, 0.05)
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.border_width_left = 1
	box.border_width_right = 1
	return box


func _stat(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _v_sep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(1, 0)
	return s
