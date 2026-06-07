extends Node
# Zoo Tycoon — main scene script.
#
# Game UI for the engine validation game. Builds a top stat bar, a build
# menu, a tile-grid map view, and an event log — all programmatically — and
# wires them to the engine's autoloads.
#
# This script is GAME CODE — not engine. The engine drives ticks, spawning,
# satisfaction, etc.; this just stages content and observes/dispatches input.

const STARTER_VISITOR_COUNT: int = 6
const GATE_TILE: Vector2i = Vector2i(0, 0)
const HUD_REFRESH_SECONDS: float = 0.2
const LOG_MAX_LINES: int = 60
const MAP_VIEW_SCRIPT := preload("res://src/ui/map_view.gd")

# Distinct colour per entity type. Keys must match design/tuning/entities.md ids.
const ENTITY_COLORS := {
	&"grass_patch": Color("#3f6b35"),
	&"rock_patch":  Color("#65726f"),
	&"water_patch": Color("#3a7eb2"),
	&"cage_panel":  Color("#7e8a92"),
	&"path":        Color("#9a8f7d"),
	&"food_stand":  Color("#e27d60"),
	&"drink_stand": Color("#5aa9e6"),
	&"restroom":    Color("#41b3a3"),
	&"bench":       Color("#b08968"),
	&"compost":     Color("#6b5d4f"),
	&"restaurant":  Color("#d98c5f"),
	&"arena":       Color("#a86a32"),
}

var _selected_def_id: StringName = &""
var _selected_region_id: int = -1   # -1 = no region selected; manage panel hidden
var _map_view: MapView
# region_id -> true for populated exhibits with no gate-reachable path cell
# within viewing distance (guests can't reach them). Recomputed each HUD tick.
var _disconnected_regions: Dictionary = {}
var _money_label: Label
var _day_label: Label
var _quality_label: Label
var _reputation_label: Label
var _agents_label: Label
var _yesterday_label: Label
var _fps_label: Label
var _log_text: RichTextLabel
var _build_buttons: Dictionary = {}    # StringName -> Button
var _speed_buttons: Dictionary = {}    # String -> Button
# Build ids currently locked behind a reputation gate (entity id -> true).
# Kept in sync by _refresh_build_locks so _refresh_affordability respects it.
var _locked_build_ids: Dictionary = {}
# Reputation-gated buildables: entity id -> the unlock node that frees it.
const REP_GATED_BUILDS := {
	&"restaurant": &"dining",
}
var _region_panel: PanelContainer
var _region_panel_body: VBoxContainer
var _reports_modal: Control
var _reports_body: VBoxContainer
var _reports_period: String = "today"   # today / week / month / all_time
var _welcome_modal: Control
var _welcome_btn_row: HBoxContainer
var _goals_box: VBoxContainer
var _goals_labels: Dictionary = {}     # goal_id (String) -> Label
var _goals_state: Dictionary = {       # one-way: true once completed
	"earn_1k":    false,
	"crowd_10":   false,
	"second":     false,
	"happy_lion": false,
	"day_3":      false,
}
# Mission HUD elements (filled in by _build_mission_section).
var _mission_cash_label: Label
var _mission_rep_label: Label
var _mission_days_label: Label
# End-game modal — pops up on win or lose, blocks the sim until dismissed.
var _endgame_modal: Control
var _endgame_title: Label
var _endgame_body: VBoxContainer
var _endgame_resolved: bool = false    # idempotent: only fire end-game once
var _admin_modal: Control
var _admin_bracket_row: HBoxContainer
var _admin_bracket_buttons: Dictionary = {}   # bracket id (StringName) -> Button
var _admin_fee_caption: Label
var _admin_open_label: Label
var _arena_modal: Control
var _arena_body: VBoxContainer
var _arena_subject_id: int = 0   # entity_instance_id of the open arena

# Active "move placement" mode — set by the ⇄ button in the Manage Exhibit
# panel. Next map click in the same region writes state["primary_cell"].
# -1 region id means inactive.
var _moving_region_id: int = -1
var _moving_index: int = -1

# Tutorial state — set by _start_tutorial. The overlay's only visible while
# active. Each step has its own advance condition checked via engine signals.
var _tutorial_active: bool = false
var _tutorial_step: int = 0
var _tutorial_overlay: PanelContainer
var _tutorial_prompt: RichTextLabel
var _tutorial_progress: Label
# Captured at the start of step 3 so we can detect "visitor paid us" by
# watching the balance climb above the floor by some margin.
var _tutorial_step3_floor: int = 0

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
		sess.register_action("open_reports", _harness_open_reports)
		await sess.run()
		return

	_refresh_hud()
	_push_log("Welcome to your Zoo. Pick Tutorial or Skip to begin.")
	# In screenshot / scripted modes the welcome modal would just block the
	# capture, so we stage the starter park directly and skip the welcome.
	# Interactive launches go through the welcome which then either runs the
	# tutorial or stages the starter park itself.
	if Screenshotter.get_spec().is_empty():
		_open_welcome()
	else:
		_stage_starter_park()

	# One-shot screenshot mode runs against the staged starter park.
	if await Screenshotter.maybe_capture(self):
		return


# ============================================================================
# Manage Region panel (right side, shown when a region is selected)
# ============================================================================

func _build_region_panel(parent: Control) -> void:
	_region_panel = PanelContainer.new()
	_region_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_region_panel.offset_top = 56
	_region_panel.offset_left = -300   # extend 300px left of right edge
	_region_panel.offset_right = 0
	_region_panel.offset_bottom = 0
	_region_panel.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	_region_panel.visible = false
	parent.add_child(_region_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_region_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_region_panel_body = VBoxContainer.new()
	_region_panel_body.add_theme_constant_override("separation", 8)
	_region_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_region_panel_body)


func _refresh_region_panel() -> void:
	# Clear current body.
	for child in _region_panel_body.get_children():
		child.queue_free()

	if _selected_region_id < 0:
		_region_panel.visible = false
		return
	var region := RegionRegistry.get_region(_selected_region_id)
	if region == null:
		_region_panel.visible = false
		_selected_region_id = -1
		return
	_region_panel.visible = true

	# Header
	var title := _stat("Exhibit #%d" % region.region_id, 18, Color("#e6e6e6"))
	_region_panel_body.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s  ·  %d cells\nProvides: %s" % [
		String(region.kind),
		region.area,
		", ".join(region.provided_zone_tags.map(func(t): return String(t))),
	]
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("#7e9286"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_panel_body.add_child(subtitle)

	# Appeal summary (from EffectResolver) so the player sees the consequence
	# of their placement choices in real time.
	var appeal: Dictionary = EffectResolver.compute_region_appeal(region)
	if not appeal.is_empty():
		var appeal_lines: Array[String] = []
		for axis in appeal.keys():
			appeal_lines.append("%s %.2f" % [String(axis), appeal[axis]])
		var appeal_label := Label.new()
		appeal_label.text = "Appeal: %s" % ", ".join(appeal_lines)
		appeal_label.add_theme_font_size_override("font_size", 11)
		appeal_label.add_theme_color_override("font_color", Color("#f4d35e"))
		appeal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_region_panel_body.add_child(appeal_label)

	# Suitability — single 0–100 read plus an always-on recommendation.
	var suit := _exhibit_suitability(region)
	if suit.get("has_animals", false):
		var pct: int = suit["percent"]
		var suit_label := Label.new()
		suit_label.text = "Suitability: %d%%" % pct
		suit_label.add_theme_font_size_override("font_size", 14)
		suit_label.add_theme_color_override("font_color",
			_happiness_color(float(pct) / 100.0))
		_region_panel_body.add_child(suit_label)
		var rec: String = suit.get("recommendation", "")
		if rec != "":
			var rec_label := Label.new()
			rec_label.text = "→ %s" % rec
			rec_label.add_theme_font_size_override("font_size", 11)
			rec_label.add_theme_color_override("font_color", Color("#c9a4ff"))
			rec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_region_panel_body.add_child(rec_label)

	# Path-access warning — guests can't reach an exhibit with no path nearby.
	if _disconnected_regions.has(region.region_id):
		var warn := Label.new()
		warn.text = "⚠ No path access — lay a path within view so guests can reach it."
		warn.add_theme_font_size_override("font_size", 11)
		warn.add_theme_color_override("font_color", Color("#e76f51"))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_region_panel_body.add_child(warn)

	# Donations collected at this exhibit's Donation Box (if any).
	var donated := ZooBootstrap.donations_for_region(region.region_id)
	var has_box := false
	for p in region.placements:
		var pd: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
		if pd != null and &"donation_box" in pd.own_tags:
			has_box = true
			break
	if has_box or donated > 0:
		var donate_label := Label.new()
		if has_box:
			donate_label.text = "Donations: $%s collected" % _format_thousands(donated)
		else:
			donate_label.text = "Donations: $%s  (box removed)" % _format_thousands(donated)
		donate_label.add_theme_font_size_override("font_size", 11)
		donate_label.add_theme_color_override("font_color", Color("#83c779"))
		_region_panel_body.add_child(donate_label)

	_region_panel_body.add_child(HSeparator.new())

	# Placements list with remove buttons + happiness bars.
	var placements_header := Label.new()
	placements_header.text = "INSIDE  (%d)" % region.placements.size()
	placements_header.add_theme_font_size_override("font_size", 12)
	placements_header.add_theme_color_override("font_color", Color("#7e9286"))
	_region_panel_body.add_child(placements_header)

	for i in region.placements.size():
		var placement: Placement = region.placements[i]
		var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
		if def == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_region_panel_body.add_child(row)

		var name_label := Label.new()
		var is_animal := not def.appeal_contribution.is_empty()
		# Animals show care quality (suitability) here, not the welfare-
		# discounted appeal, plus a welfare read + sick flag.
		var care := ZooBootstrap.get_happiness_model().care_quality(region, i) \
			if is_animal else EffectResolver._happiness_model.compute_happiness(region, i)
		var row_text := "%s  (%.0f%%)" % [def.display_name, care * 100.0]
		var row_color := _happiness_color(care)
		if is_animal:
			var wf := ZooBootstrap.animal_welfare(region, i)
			row_text += "  · welfare %.0f%%" % (float(wf["welfare"]) * 100.0)
			if bool(wf["sick"]):
				row_text += "  ⚠ sick"
				row_color = Color("#e76f51")
		name_label.text = row_text
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", row_color)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var move := Button.new()
		move.text = "⇄"
		move.tooltip_text = "Move to a different tile in this exhibit"
		move.custom_minimum_size = Vector2(28, 28)
		move.focus_mode = Control.FOCUS_NONE
		move.pressed.connect(_begin_move_placement.bind(_selected_region_id, i))
		row.add_child(move)

		var rm := Button.new()
		rm.text = "×"
		rm.tooltip_text = "Remove (½ refund)"
		rm.custom_minimum_size = Vector2(28, 28)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(_on_remove_placement.bind(_selected_region_id, i))
		row.add_child(rm)

	_region_panel_body.add_child(HSeparator.new())

	# Add Placeable section — list every PlaceableDef, grey out the ones
	# that fail can_add_placement (and surface the reason in the tooltip).
	var add_header := Label.new()
	add_header.text = "ADD"
	add_header.add_theme_font_size_override("font_size", 12)
	add_header.add_theme_color_override("font_color", Color("#7e9286"))
	_region_panel_body.add_child(add_header)

	for def_id in ContentDB.placeable_defs.keys():
		var def: PlaceableDef = ContentDB.placeable_defs[def_id]
		var check := RegionRegistry.can_add_placement(_selected_region_id, def_id)
		var btn := Button.new()
		btn.text = "+  %s  $%d" % [def.display_name, def.build_cost]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.focus_mode = Control.FOCUS_NONE
		if not check["ok"]:
			btn.disabled = true
			btn.tooltip_text = check["reason"]
		else:
			btn.tooltip_text = "%s  ·  upkeep $%d/day" % [
				def.display_name, def.maintenance_cost]
			btn.pressed.connect(_on_add_placement.bind(_selected_region_id, def_id))
		_region_panel_body.add_child(btn)

	# Close button at the bottom.
	_region_panel_body.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func():
		_selected_region_id = -1
		_refresh_region_panel())
	_region_panel_body.add_child(close)


# ============================================================================
# Reports modal — Income Statement + Balance Sheet from engine Accounting
# ============================================================================

func _build_reports_modal(parent: Control) -> void:
	_reports_modal = Control.new()
	_reports_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reports_modal.visible = false
	_reports_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_reports_modal)

	# Dimmed backdrop catches clicks and closes the modal.
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_reports())
	_reports_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -380
	card.offset_top = -320
	card.offset_right = 380
	card.offset_bottom = 320
	card.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	# Stop clicks on the card itself from bubbling to the backdrop.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_reports_modal.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_top", 16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card_margin.add_child(col)

	# Header row: title + period selector + close.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	col.add_child(header)

	var title := _stat("Financial Reports", 22, Color("#f4d35e"))
	header.add_child(title)

	var period_spacer := Control.new()
	period_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(period_spacer)

	for spec in [
		{"key": "today", "label": "Today"},
		{"key": "week",  "label": "Week"},
		{"key": "month", "label": "Month"},
		{"key": "all",   "label": "All"},
	]:
		var b := Button.new()
		b.text = spec["label"]
		b.custom_minimum_size = Vector2(60, 30)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = spec["key"]
		b.pressed.connect(func():
			_reports_period = key
			_refresh_reports())
		header.add_child(b)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_close_reports)
	header.add_child(close_btn)

	# Body — populated lazily on open.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_reports_body = VBoxContainer.new()
	_reports_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reports_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_reports_body)


func _on_reports_pressed() -> void:
	_reports_modal.visible = true
	_refresh_reports()


# ============================================================================
# Welcome modal — shown once at start, reopenable via the Help button
# ============================================================================

const WELCOME_LINES: Array = [
	"Welcome to your Zoo!",
	"",
	"You're the new director. Build exhibits, attract guests, and turn",
	"a profit — see the MISSION panel on the left for your 30-day goal.",
	"",
	"First time here? Take the 60-second tutorial — it walks you through",
	"building your first exhibit, placing an animal, and watching a",
	"guest pay. Otherwise, jump straight in with a pre-built starter zoo.",
]


func _build_welcome_modal(parent: Control) -> void:
	_welcome_modal = Control.new()
	_welcome_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_welcome_modal.visible = false
	_welcome_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_welcome_modal)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.70)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_welcome_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -310
	card.offset_top = -200
	card.offset_right = 310
	card.offset_bottom = 200
	card.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_welcome_modal.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	for i in WELCOME_LINES.size():
		var line: String = WELCOME_LINES[i]
		var lbl := Label.new()
		lbl.text = line
		if i == 0:
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color("#f4d35e"))
		else:
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color("#cdd6cf"))
		col.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_welcome_btn_row = HBoxContainer.new()
	_welcome_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_welcome_btn_row.add_theme_constant_override("separation", 12)
	col.add_child(_welcome_btn_row)
	# Buttons are added on open so we can render either choice-mode (first
	# launch — tutorial vs skip) or info-mode (the "?" help button — close).


func _on_welcome_start_tutorial() -> void:
	_welcome_modal.visible = false
	_start_tutorial()
	SimClock.play()
	_refresh_speed_buttons()


func _on_welcome_skip_tutorial() -> void:
	_welcome_modal.visible = false
	_stage_starter_park()
	SimClock.play()
	_refresh_speed_buttons()


# ============================================================================
# End-game modal — pops up on win or lose
# ============================================================================

func _build_endgame_modal(parent: Control) -> void:
	_endgame_modal = Control.new()
	_endgame_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_endgame_modal.visible = false
	_endgame_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_endgame_modal)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_endgame_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_top = -180
	card.offset_right = 280
	card.offset_bottom = 180
	card.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_endgame_modal.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	_endgame_body = VBoxContainer.new()
	_endgame_body.add_theme_constant_override("separation", 12)
	margin.add_child(_endgame_body)

	_endgame_title = Label.new()
	_endgame_title.text = ""
	_endgame_title.add_theme_font_size_override("font_size", 24)
	_endgame_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_endgame_body.add_child(_endgame_title)


func _endgame_show(won: bool, headline: String, body: String) -> void:
	# Clear any prior body content beyond the title.
	for child in _endgame_body.get_children():
		if child != _endgame_title:
			child.queue_free()

	_endgame_title.text = headline
	_endgame_title.add_theme_color_override("font_color",
		Color("#f4d35e") if won else Color("#e76f51"))

	var body_label := Label.new()
	body_label.text = body
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_color_override("font_color", Color("#cdd6cf"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_endgame_body.add_child(body_label)

	# Summary stats so the player can read the run at a glance.
	var summary := Label.new()
	summary.text = "Final score · $%s · Rep %+d · %.1f★" % [
		_format_thousands(Ledger.get_balance()),
		ProgressionManager.reputation,
		ZooBootstrap.get_quality_rating()]
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color("#a8c4b0"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_endgame_body.add_child(summary)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_endgame_body.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_endgame_body.add_child(row)

	var replay := Button.new()
	replay.text = "  Play again  "
	replay.custom_minimum_size = Vector2(160, 40)
	replay.focus_mode = Control.FOCUS_NONE
	replay.pressed.connect(_on_replay_pressed)
	row.add_child(replay)

	var sandbox := Button.new()
	sandbox.text = "  Keep playing  "
	sandbox.custom_minimum_size = Vector2(160, 40)
	sandbox.focus_mode = Control.FOCUS_NONE
	sandbox.pressed.connect(_on_endgame_continue)
	row.add_child(sandbox)

	_endgame_modal.visible = true


func _on_replay_pressed() -> void:
	# Engine autoloads persist across scene reloads, so we explicitly reset
	# every stateful one before reloading the main scene. The starting cash
	# is the canonical value the engine compiled from economy.md.
	#
	# SEAM NOTE: SimClock has no reset() method — we poke its public fields
	# directly. Worth filing against the engine for the v0.6 bump (alongside
	# the audio + save-migration seams already on the roadmap).
	Ledger.reset(ContentDB.balance_config.starting_cash)
	Accounting.reset()
	ProgressionManager.reset()
	EntityRegistry.reset()
	RegionRegistry.reset()
	AgentPool.reset()
	SimClock.current_tick = 0
	SimClock.current_day = 0
	SimClock.current_period = 0
	SimClock.rng.seed = SimClock.DEFAULT_SEED
	# Re-grant the starter tier; bootstrap normally does this but it won't
	# re-run unless the autoload is reloaded too.
	ProgressionManager.force_unlock(&"start")
	get_tree().reload_current_scene()


func _on_endgame_continue() -> void:
	# Sandbox-mode continuation. The end-game flag stays true so we won't
	# pop the modal again, even if the player later goes broke or hits the
	# target again. Lets them keep building after a win or limp through
	# a bankruptcy run for screenshots / fun.
	_endgame_modal.visible = false
	SimClock.play()
	_refresh_speed_buttons()


# ============================================================================
# Arena modal — book an animal to perform
# ============================================================================

func _build_arena_modal(parent: Control) -> void:
	_arena_modal = Control.new()
	_arena_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena_modal.visible = false
	_arena_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_arena_modal)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_arena_modal())
	_arena_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -300
	card.offset_top = -260
	card.offset_right = 300
	card.offset_bottom = 260
	card.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena_modal.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := _stat("Arena", 22, Color("#f4d35e"))
	header.add_child(title)
	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hspacer)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_close_arena_modal)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_arena_body = VBoxContainer.new()
	_arena_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_arena_body)


func _open_arena_modal(arena_id: int) -> void:
	_arena_subject_id = arena_id
	_refresh_arena_modal()
	_arena_modal.visible = true


func _close_arena_modal() -> void:
	_arena_modal.visible = false
	_arena_subject_id = 0


func _refresh_arena_modal() -> void:
	if _arena_body == null or _arena_subject_id == 0:
		return
	for child in _arena_body.get_children():
		child.queue_free()

	var booking := ZooBootstrap.get_booking(_arena_subject_id)

	# Current performer.
	var now_label := Label.new()
	now_label.text = "Now performing"
	now_label.add_theme_font_size_override("font_size", 12)
	now_label.add_theme_color_override("font_color", Color("#7e9286"))
	_arena_body.add_child(now_label)

	if booking.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "  (empty — pick an animal below to start a show)"
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color("#cdd6cf"))
		_arena_body.add_child(none_lbl)
	else:
		var region: Region = RegionRegistry.get_region(booking["region_id"])
		if region != null and booking["index"] < region.placements.size():
			var placement: Placement = region.placements[booking["index"]]
			var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
			if def != null:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				_arena_body.add_child(row)
				var attitude: float = float(placement.state.get("attitude", 1.0))
				var name_lbl := Label.new()
				name_lbl.text = "  %s  ·  exhibit #%d  ·  attitude %.0f%%" % [
					def.display_name, region.region_id, attitude * 100.0]
				name_lbl.add_theme_font_size_override("font_size", 13)
				name_lbl.add_theme_color_override("font_color",
					_happiness_color(attitude))
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(name_lbl)
				var stop := Button.new()
				stop.text = "Stop show"
				stop.custom_minimum_size = Vector2(110, 30)
				stop.focus_mode = Control.FOCUS_NONE
				stop.pressed.connect(_on_stop_show)
				row.add_child(stop)
				var rev: int = _show_revenue_for(def)
				var rev_lbl := Label.new()
				rev_lbl.text = "    Pays $%d/day · animals lose %.0f%% attitude/day; rest restores %.0f%%." % [
					rev,
					ZooBootstrap.SHOW_DAILY_FATIGUE * 100.0,
					ZooBootstrap.SHOW_REST_RECOVERY * 100.0]
				rev_lbl.add_theme_font_size_override("font_size", 11)
				rev_lbl.add_theme_color_override("font_color", Color("#7e9286"))
				rev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_arena_body.add_child(rev_lbl)

	_arena_body.add_child(HSeparator.new())

	var roster := Label.new()
	roster.text = "Book a performer"
	roster.add_theme_font_size_override("font_size", 12)
	roster.add_theme_color_override("font_color", Color("#7e9286"))
	_arena_body.add_child(roster)

	# Roster of animals in the park grouped by exhibit.
	var any_listed: bool = false
	for region: Region in RegionRegistry.all_regions():
		for i in region.placements.size():
			var placement: Placement = region.placements[i]
			var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
			if def == null or def.appeal_contribution.is_empty():
				continue
			any_listed = true
			var booked_here: bool = not booking.is_empty() \
				and booking["region_id"] == region.region_id \
				and booking["index"] == i
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_arena_body.add_child(row)
			var attitude: float = float(placement.state.get("attitude", 1.0))
			var name_lbl := Label.new()
			name_lbl.text = "  %s  ·  Exhibit #%d  ·  attitude %.0f%%  ·  $%d/day" % [
				def.display_name, region.region_id,
				attitude * 100.0, _show_revenue_for(def)]
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color",
				Color("#cdd6cf") if not booked_here else Color("#f4d35e"))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)
			if booked_here:
				var marker := Label.new()
				marker.text = "★ on stage"
				marker.add_theme_font_size_override("font_size", 11)
				marker.add_theme_color_override("font_color", Color("#f4d35e"))
				row.add_child(marker)
			else:
				var book_btn := Button.new()
				book_btn.text = "Book"
				book_btn.custom_minimum_size = Vector2(80, 30)
				book_btn.focus_mode = Control.FOCUS_NONE
				book_btn.pressed.connect(_on_book_show.bind(region.region_id, i))
				row.add_child(book_btn)

	if not any_listed:
		var none := Label.new()
		none.text = "  (No animals in the park yet. Add one to an exhibit first.)"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Color("#7e9286"))
		_arena_body.add_child(none)


func _on_book_show(region_id: int, index: int) -> void:
	if ZooBootstrap.book_animal(_arena_subject_id, region_id, index):
		var region: Region = RegionRegistry.get_region(region_id)
		var def: PlaceableDef = null
		if region != null and index < region.placements.size():
			def = ContentDB.placeable_defs.get(
				region.placements[index].placeable_def_id)
		if def != null:
			_push_log("[color=#f4d35e]Show booked:[/color] %s takes the stage." %
				def.display_name)
	_refresh_arena_modal()


func _on_stop_show() -> void:
	ZooBootstrap.stop_show(_arena_subject_id)
	_push_log("Show ended.")
	_refresh_arena_modal()


func _show_revenue_for(def: PlaceableDef) -> int:
	var appeal_sum: float = 0.0
	for v in def.appeal_contribution.values():
		appeal_sum += float(v)
	return int(round(appeal_sum * float(ZooBootstrap.SHOW_REVENUE_PER_APPEAL)))


# ============================================================================
# Park admin modal — opens on clicking the entrance gate
# ============================================================================

func _build_admin_modal(parent: Control) -> void:
	_admin_modal = Control.new()
	_admin_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_admin_modal.visible = false
	_admin_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_admin_modal)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_admin_modal())
	_admin_modal.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -260
	card.offset_top = -180
	card.offset_right = 260
	card.offset_bottom = 180
	card.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_admin_modal.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := _stat("Park Admin", 22, Color("#f4d35e"))
	header.add_child(title)
	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hspacer)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_close_admin_modal)
	header.add_child(close_btn)

	# Ticket-bracket selector — a button per bracket from services.md.
	var ticket_label := Label.new()
	ticket_label.text = "Ticket price"
	ticket_label.add_theme_font_size_override("font_size", 14)
	ticket_label.add_theme_color_override("font_color", Color("#cdd6cf"))
	col.add_child(ticket_label)

	_admin_bracket_row = HBoxContainer.new()
	_admin_bracket_row.add_theme_constant_override("separation", 8)
	col.add_child(_admin_bracket_row)
	var brackets: Array = ZooBootstrap.services.ticket_brackets \
		if ZooBootstrap.services != null else []
	for b in brackets:
		var id: StringName = b["id"]
		var btn := Button.new()
		btn.text = "%s\n$%d" % [b["label"], int(b["price"])]
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = "Demand ×%.2f vs. Standard" % float(b["demand_multiplier"])
		btn.pressed.connect(_on_pick_ticket_bracket.bind(id))
		_admin_bracket_buttons[id] = btn
		_admin_bracket_row.add_child(btn)

	_admin_fee_caption = Label.new()
	_admin_fee_caption.add_theme_font_size_override("font_size", 11)
	_admin_fee_caption.add_theme_color_override("font_color", Color("#7e9286"))
	_admin_fee_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_admin_fee_caption)

	col.add_child(HSeparator.new())

	# Park open/closed toggle.
	var open_row := HBoxContainer.new()
	open_row.add_theme_constant_override("separation", 10)
	col.add_child(open_row)
	var open_label := Label.new()
	open_label.text = "Park status"
	open_label.add_theme_font_size_override("font_size", 14)
	open_label.add_theme_color_override("font_color", Color("#cdd6cf"))
	open_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_row.add_child(open_label)
	_admin_open_label = Label.new()
	_admin_open_label.custom_minimum_size = Vector2(100, 0)
	_admin_open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_admin_open_label.add_theme_font_size_override("font_size", 14)
	open_row.add_child(_admin_open_label)
	var toggle := Button.new()
	toggle.text = "Toggle"
	toggle.custom_minimum_size = Vector2(90, 32)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(_toggle_park_open)
	open_row.add_child(toggle)

	var open_hint := Label.new()
	open_hint.text = "Close the park to stop new guest arrivals — useful while you build or save money on a slow day."
	open_hint.add_theme_font_size_override("font_size", 11)
	open_hint.add_theme_color_override("font_color", Color("#7e9286"))
	open_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(open_hint)


func _open_admin_modal() -> void:
	_refresh_admin_modal()
	_admin_modal.visible = true


func _close_admin_modal() -> void:
	_admin_modal.visible = false


func _refresh_admin_modal() -> void:
	if _admin_bracket_row == null:
		return
	# Highlight the active bracket.
	for id in _admin_bracket_buttons.keys():
		var btn: Button = _admin_bracket_buttons[id]
		var active: bool = id == ZooBootstrap.ticket_bracket
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f4d35e") if active else Color("#2c3a32")
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color",
			Color("#1a241f") if active else Color("#e6e6e6"))
	var mult := ZooBootstrap.current_demand_multiplier()
	_admin_fee_caption.text = (
		"Guests pay $%d at the gate. Cheaper tickets pull a bigger crowd " +
		"(demand ×%.2f) that spends more inside; pricier tickets earn more " +
		"per head but thin the crowd.") % [ZooBootstrap.entry_fee, mult]
	if ZooBootstrap.park_open:
		_admin_open_label.text = "Open"
		_admin_open_label.add_theme_color_override("font_color", Color("#83c779"))
	else:
		_admin_open_label.text = "Closed"
		_admin_open_label.add_theme_color_override("font_color", Color("#e76f51"))


func _on_pick_ticket_bracket(id: StringName) -> void:
	ZooBootstrap.set_ticket_bracket(id)
	var b: Dictionary = ZooBootstrap.services.bracket(id)
	if not b.is_empty():
		_push_log("[color=#f4d35e]Ticket price → %s ($%d).[/color]" %
			[b["label"], int(b["price"])])
	_refresh_admin_modal()


func _toggle_park_open() -> void:
	ZooBootstrap.set_park_open(not ZooBootstrap.park_open)
	_refresh_admin_modal()
	if ZooBootstrap.park_open:
		_push_log("[color=#83c779]Park reopened.[/color]")
	else:
		_push_log("[color=#e76f51]Park closed — no new guests will arrive.[/color]")


# ============================================================================
# Tutorial overlay — 3-step guided onboarding per ROADMAP §1.2
# ============================================================================

const TUTORIAL_STEPS: Array = [
	{
		"title": "Step 1 of 3 — Build an exhibit",
		"body": "Click [color=#f4d35e]Grass Enclosure[/color] in the BUILD panel on the left, then click the map [color=#f4d35e]two or three times[/color] in a row to lay down tiles. Adjacent tiles merge into one exhibit automatically.",
	},
	{
		"title": "Step 2 of 3 — Add an animal",
		"body": "[color=#f4d35e]Click the green tiles[/color] you just placed to open the Manage Exhibit panel on the right. Then click [color=#f4d35e]+ Lion[/color] in the ADD section.",
	},
	{
		"title": "Step 3 of 3 — Speed time, watch them pay",
		"body": "Click [color=#f4d35e]4x[/color] at the top right. Guests will walk in and pay — watch for the [color=#f4d35e]+$10[/color] floats above their heads.",
	},
]


func _build_tutorial_overlay(parent: Control) -> void:
	# Banner across the top of the map area (under the top bar, above the
	# play surface). Doesn't block input — visitors and the map work fine
	# behind it. Hidden until _start_tutorial.
	_tutorial_overlay = PanelContainer.new()
	_tutorial_overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tutorial_overlay.offset_top = 64
	_tutorial_overlay.offset_left = 240
	_tutorial_overlay.offset_right = -320
	_tutorial_overlay.custom_minimum_size = Vector2(0, 88)
	_tutorial_overlay.add_theme_stylebox_override("panel",
		_panel_box(Color("#2a3324")))
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.visible = false
	parent.add_child(_tutorial_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_tutorial_overlay.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	_tutorial_progress = Label.new()
	_tutorial_progress.text = ""
	_tutorial_progress.add_theme_font_size_override("font_size", 12)
	_tutorial_progress.add_theme_color_override("font_color", Color("#f4d35e"))
	col.add_child(_tutorial_progress)

	_tutorial_prompt = RichTextLabel.new()
	_tutorial_prompt.bbcode_enabled = true
	_tutorial_prompt.fit_content = true
	_tutorial_prompt.scroll_active = false
	_tutorial_prompt.add_theme_font_size_override("normal_font_size", 13)
	_tutorial_prompt.add_theme_color_override("default_color", Color("#e6e6e6"))
	_tutorial_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_tutorial_prompt)

	# A small skip link — never trap a player who already knows the game.
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_color_override("font_color", Color("#7e9286"))
	skip.add_theme_font_size_override("font_size", 11)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.pressed.connect(_end_tutorial.bind(false))
	row.add_child(skip)


func _start_tutorial() -> void:
	_tutorial_active = true
	_tutorial_step = 0
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = true
	_show_tutorial_step()
	# Don't auto-stage the starter park — the tutorial IS the starter.
	# A handful of starter guests so step 3 has someone to pay quickly.
	for i in range(3):
		AgentPool.spawn(&"visitor", Vector2(
			SimClock.rng.randf_range(0.0, 3.0),
			SimClock.rng.randf_range(0.0, 4.0)))


func _show_tutorial_step() -> void:
	if _tutorial_step >= TUTORIAL_STEPS.size():
		_end_tutorial(true)
		return
	var spec: Dictionary = TUTORIAL_STEPS[_tutorial_step]
	_tutorial_progress.text = spec["title"]
	_tutorial_prompt.text = spec["body"]
	if _tutorial_step == 2:
		_tutorial_step3_floor = Ledger.get_balance()


func _check_tutorial_advance() -> void:
	if not _tutorial_active:
		return
	match _tutorial_step:
		0:
			# Done when the player has built a region with at least 2 cells
			# (any zone kind — they may have picked rocks or water).
			for r in RegionRegistry.all_regions():
				if r.cells.size() >= 2:
					_advance_tutorial()
					return
		1:
			# Done when any region has any placement.
			for r in RegionRegistry.all_regions():
				if not r.placements.is_empty():
					_advance_tutorial()
					return
		2:
			# Done when balance has gone up by at least $10 (one ticket)
			# since the step began.
			if Ledger.get_balance() >= _tutorial_step3_floor + 10:
				_advance_tutorial()
				return


func _advance_tutorial() -> void:
	_tutorial_step += 1
	if _tutorial_step >= TUTORIAL_STEPS.size():
		_end_tutorial(true)
	else:
		_push_log("[color=#83c779]✓ Tutorial step done.[/color]")
		_show_tutorial_step()


func _end_tutorial(completed: bool) -> void:
	_tutorial_active = false
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false
	if completed:
		_push_log("[color=#f4d35e]★ Tutorial complete. Keep building — you're aiming for $20k and 50 rep in 30 days.[/color]")
	else:
		_push_log("[color=#7e9286]Tutorial skipped.[/color]")


func _open_welcome() -> void:
	# Initial launch — offer the tutorial vs the pre-built starter zoo.
	if _welcome_modal == null:
		return
	_render_welcome_buttons(true)
	_welcome_modal.visible = true
	SimClock.pause()
	_refresh_speed_buttons()


func _open_help() -> void:
	# Mid-game "?" button — same modal, info-only. Doesn't touch sim state
	# beyond pausing while the player reads.
	if _welcome_modal == null:
		return
	_render_welcome_buttons(false)
	_welcome_modal.visible = true
	SimClock.pause()
	_refresh_speed_buttons()


func _close_welcome() -> void:
	_welcome_modal.visible = false
	SimClock.play()
	_refresh_speed_buttons()


func _render_welcome_buttons(initial_launch: bool) -> void:
	for child in _welcome_btn_row.get_children():
		child.queue_free()
	if initial_launch:
		var tutorial_btn := Button.new()
		tutorial_btn.text = "  Start tutorial  "
		tutorial_btn.custom_minimum_size = Vector2(190, 42)
		tutorial_btn.focus_mode = Control.FOCUS_NONE
		tutorial_btn.pressed.connect(_on_welcome_start_tutorial)
		_welcome_btn_row.add_child(tutorial_btn)

		var skip_btn := Button.new()
		skip_btn.text = "  Skip — pre-built zoo  "
		skip_btn.custom_minimum_size = Vector2(220, 42)
		skip_btn.focus_mode = Control.FOCUS_NONE
		skip_btn.pressed.connect(_on_welcome_skip_tutorial)
		_welcome_btn_row.add_child(skip_btn)
	else:
		var close_btn := Button.new()
		close_btn.text = "  Got it  "
		close_btn.custom_minimum_size = Vector2(160, 42)
		close_btn.focus_mode = Control.FOCUS_NONE
		close_btn.pressed.connect(_close_welcome)
		_welcome_btn_row.add_child(close_btn)


# ============================================================================
# Goals panel — small persistent checklist in the bottom of the left column
# ============================================================================

const GOAL_SPECS: Array = [
	{"id": "earn_1k",    "label": "Earn $1,000 in revenue"},
	{"id": "crowd_10",   "label": "Host 10 guests at once"},
	{"id": "second",     "label": "Open a third exhibit"},
	{"id": "happy_lion", "label": "Lion happiness ≥ 80%"},
	{"id": "day_3",      "label": "Reach Day 3"},
]


func _build_mission_section(col: VBoxContainer) -> void:
	col.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "MISSION"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#f4d35e"))
	col.add_child(title)

	var s: Scenario = ZooBootstrap.scenario
	var subtitle := Label.new()
	subtitle.text = "Reach $%s cash and %d reputation\nbefore day %d ends." % [
		_format_thousands(s.target_cash), s.target_reputation, s.days_limit]
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("#a8c4b0"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(subtitle)

	# Three live progress rows. Bound in _refresh_mission.
	_mission_cash_label = _make_mission_row(col)
	_mission_rep_label = _make_mission_row(col)
	_mission_days_label = _make_mission_row(col)


func _make_mission_row(col: VBoxContainer) -> Label:
	var lbl := Label.new()
	lbl.text = "—"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#cdd6cf"))
	col.add_child(lbl)
	return lbl


func _format_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-" + out) if n < 0 else out


func _build_goals_section(col: VBoxContainer) -> void:
	col.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "MILESTONES"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#7e9286"))
	col.add_child(title)

	_goals_box = VBoxContainer.new()
	_goals_box.add_theme_constant_override("separation", 2)
	col.add_child(_goals_box)

	for spec in GOAL_SPECS:
		var goal_id: String = spec["id"]
		var lbl := Label.new()
		lbl.text = "○  %s" % spec["label"]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color("#a8c4b0"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_goals_box.add_child(lbl)
		_goals_labels[goal_id] = lbl


func _evaluate_goals() -> void:
	# Each goal is one-way: once flipped to true it stays done. Compute the
	# current value from engine state and OR with the cached completion.
	var today := SimClock.current_day
	var is_data: Dictionary = Accounting.get_income_statement(0, today)
	var revenue := int(is_data.get("revenue", 0))
	var guests := AgentPool.alive_count()

	# Region count = regions whose placements are non-empty.
	var populated_regions: int = 0
	for r in RegionRegistry.all_regions():
		if not r.placements.is_empty():
			populated_regions += 1

	# Lion happiness: scan placements for a lion; report max happiness found.
	var max_lion_happiness: float = 0.0
	for r in RegionRegistry.all_regions():
		for i in r.placements.size():
			var p: Placement = r.placements[i]
			if p.placeable_def_id == &"lion":
				var h := EffectResolver._happiness_model.compute_happiness(r, i)
				if h > max_lion_happiness:
					max_lion_happiness = h

	var new_state := {
		"earn_1k":    revenue >= 1000,
		"crowd_10":   guests >= 10,
		"second":     populated_regions >= 3,
		"happy_lion": max_lion_happiness >= 0.80,
		"day_3":      today >= 2,  # 0-indexed; day_3 in player terms
	}
	for goal_id in _goals_state.keys():
		var was_done: bool = _goals_state[goal_id]
		var now_done: bool = new_state[goal_id]
		if now_done and not was_done:
			_goals_state[goal_id] = true
			# Find the spec for the toast.
			for spec in GOAL_SPECS:
				if spec["id"] == goal_id:
					_push_log("[color=#f4d35e]★ Goal achieved:[/color] %s" % spec["label"])
					break
		_refresh_goal_label(goal_id)


func _refresh_mission() -> void:
	if _mission_cash_label == null:
		return
	var s: Scenario = ZooBootstrap.scenario
	var cash := Ledger.get_balance()
	var rep := ProgressionManager.reputation
	# current_day is 0-indexed; day_in_progress = current_day + 1 in player
	# terms. days_left counts days *yet to fully close*.
	var day_in_progress: int = SimClock.current_day + 1
	var days_left: int = max(0, s.days_limit - SimClock.current_day)
	_mission_cash_label.text = "  Cash:  $%s / $%s" % [
		_format_thousands(cash), _format_thousands(s.target_cash)]
	_mission_cash_label.add_theme_color_override("font_color",
		Color("#83c779") if cash >= s.target_cash else Color("#cdd6cf"))
	_mission_rep_label.text = "  Reputation:  %d / %d" % [rep, s.target_reputation]
	_mission_rep_label.add_theme_color_override("font_color",
		Color("#83c779") if rep >= s.target_reputation else Color("#cdd6cf"))
	if days_left <= 5:
		_mission_days_label.add_theme_color_override("font_color", Color("#e76f51"))
	elif days_left <= 10:
		_mission_days_label.add_theme_color_override("font_color", Color("#f4a261"))
	else:
		_mission_days_label.add_theme_color_override("font_color", Color("#cdd6cf"))
	_mission_days_label.text = "  Day %d of %d  ·  %d left" % [
		day_in_progress, s.days_limit, days_left]


# Day-settled hook. Engine fires this after the day's books close and
# `current_day` has incremented. So when day_settled emits with day == N,
# SimClock.current_day is now N+1 and N days have fully elapsed.
func _check_endgame(settled_day: int) -> void:
	if _endgame_resolved:
		return
	var s: Scenario = ZooBootstrap.scenario
	var cash := Ledger.get_balance()
	var rep := ProgressionManager.reputation
	# Bankruptcy: balance dipped below the threshold after settlement.
	if cash < s.bankruptcy_threshold:
		_resolve_endgame(false, "Bankruptcy",
			"Your zoo ran out of money on day %d. Expenses outpaced income — try fewer high-upkeep animals or more amenities to drive food revenue." %
			(settled_day + 1))
		return
	# Victory check at end of any day within the window.
	if cash >= s.target_cash and rep >= s.target_reputation:
		_resolve_endgame(true, "Zoo of the Year!",
			"You hit $%s and %d reputation by the end of day %d. The zoo is a success!" % [
				_format_thousands(cash), rep, settled_day + 1])
		return
	# Timeout: 30 days elapsed without meeting the target.
	if settled_day + 1 >= s.days_limit:
		_resolve_endgame(false, "Time's up",
			"Day %d closed at $%s cash and %d reputation — short of the $%s / %d goal. Closer next run!" % [
				settled_day + 1, _format_thousands(cash), rep,
				_format_thousands(s.target_cash), s.target_reputation])
		return


func _resolve_endgame(won: bool, headline: String, body: String) -> void:
	_endgame_resolved = true
	SimClock.pause()
	_refresh_speed_buttons()
	if _endgame_modal != null:
		_endgame_show(won, headline, body)
	# Log line so the event log carries the outcome too.
	var color := "#83c779" if won else "#e76f51"
	_push_log("[color=%s][b]%s[/b][/color] %s" % [color, headline, body])


func _refresh_goal_label(goal_id: String) -> void:
	var lbl: Label = _goals_labels.get(goal_id)
	if lbl == null:
		return
	# Look up the static label text.
	var text := ""
	for spec in GOAL_SPECS:
		if spec["id"] == goal_id:
			text = spec["label"]
			break
	var done: bool = _goals_state[goal_id]
	if done:
		lbl.text = "✓  %s" % text
		lbl.add_theme_color_override("font_color", Color("#83c779"))
	else:
		lbl.text = "○  %s" % text
		lbl.add_theme_color_override("font_color", Color("#a8c4b0"))


func _close_reports() -> void:
	_reports_modal.visible = false


func _refresh_reports() -> void:
	for c in _reports_body.get_children():
		c.queue_free()
	# Compute IS and BS for the chosen period.
	var today := SimClock.current_day
	var is_data: Dictionary
	match _reports_period:
		"today":
			is_data = Accounting.get_income_statement(today, today)
		"week":
			is_data = Accounting.get_income_statement(max(0, today - 7), today)
		"month":
			is_data = Accounting.get_income_statement(max(0, today - 30), today)
		_:
			is_data = Accounting.get_income_statement(0, today)
	var bs_data: Dictionary = Accounting.get_balance_sheet(today)

	_reports_body.add_child(_make_section_header("Income Statement"))
	_reports_body.add_child(_make_is_view(is_data))
	_reports_body.add_child(HSeparator.new())
	_reports_body.add_child(_make_section_header("Balance Sheet"))
	_reports_body.add_child(_make_bs_view(bs_data))


func _make_section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("#7e9286"))
	return l


func _make_is_view(d: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(_make_money_row("Revenue", int(d.get("revenue", 0))))
	col.add_child(_make_money_row("  Cost of services", -int(d.get("cogs", 0)), Color("#a8c4b0")))
	col.add_child(_make_money_row("Gross profit", int(d.get("gross_profit", 0)),
		Color("#e6e6e6"), true))
	# Per-sub-category lines, summed for the header total.
	var sub: Dictionary = d.get("operating_expenses", {})
	var opex_total: int = 0
	for label in sub.keys():
		opex_total += int(sub[label])
	var depr: int = int(d.get("depreciation", 0))
	col.add_child(_make_money_row("Operating expenses", -(opex_total + depr)))
	for label in sub.keys():
		col.add_child(_make_money_row("  " + String(label),
			-int(sub[label]), Color("#a8c4b0")))
	col.add_child(_make_money_row("  Depreciation", -depr, Color("#a8c4b0")))
	col.add_child(_make_money_row("Operating income", int(d.get("operating_income", 0)),
		Color("#e6e6e6"), true))
	col.add_child(_make_money_row("Other income/(expense)", int(d.get("other", 0))))
	var net: int = int(d.get("net_income", 0))
	col.add_child(HSeparator.new())
	col.add_child(_make_money_row("Net income", net,
		Color("#83c779") if net >= 0 else Color("#e76f51"), true))
	return col


func _make_bs_view(d: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var assets: Dictionary = d.get("assets", {})
	var liab: Dictionary = d.get("liabilities", {})
	var equity: Dictionary = d.get("equity", {})

	col.add_child(_make_section_subheader("Assets"))
	col.add_child(_make_money_row("  Cash", int(assets.get("cash", 0))))
	col.add_child(_make_money_row("  PP&E (gross)", int(assets.get("ppe_gross", 0))))
	col.add_child(_make_money_row("  Accumulated depreciation",
		-int(assets.get("accumulated_depreciation", 0)), Color("#a8c4b0")))
	col.add_child(_make_money_row("  PP&E (net)", int(assets.get("ppe_net", 0))))
	col.add_child(_make_money_row("Total assets", int(assets.get("total_assets", 0)),
		Color("#e6e6e6"), true))

	col.add_child(_make_section_subheader("Liabilities"))
	col.add_child(_make_money_row("  Debt", int(liab.get("total_liabilities", 0))))

	col.add_child(_make_section_subheader("Equity"))
	col.add_child(_make_money_row("  Starting capital", int(equity.get("starting_capital", 0))))
	col.add_child(_make_money_row("  Retained earnings", int(equity.get("retained_earnings", 0))))
	col.add_child(_make_money_row("Total equity", int(equity.get("total_equity", 0)),
		Color("#e6e6e6"), true))

	col.add_child(HSeparator.new())
	var balances: bool = d.get("balances", true)
	var balance_label := _make_money_row(
		"Assets − (Liabilities + Equity)",
		int(d.get("balance_check_delta", 0)),
		Color("#83c779") if balances else Color("#e76f51"), true)
	col.add_child(balance_label)
	return col


func _make_section_subheader(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#f4d35e"))
	return l


func _make_money_row(label: String, amount: int,
	color: Color = Color("#e6e6e6"), bold: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = label
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", color)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)

	var amount_l := Label.new()
	amount_l.text = _fmt_money(amount)
	amount_l.add_theme_font_size_override("font_size", 13)
	amount_l.add_theme_color_override("font_color", color)
	amount_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount_l)

	if bold:
		name_l.add_theme_color_override("font_color", color.lightened(0.1))
		amount_l.add_theme_color_override("font_color", color.lightened(0.1))
	return row


func _fmt_money(n: int) -> String:
	var sign := "-" if n < 0 else ""
	var abs_n := absi(n)
	var s := str(abs_n)
	# Insert thousands separators.
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return "%s$%s" % [sign, out]


func _happiness_color(h: float) -> Color:
	if h < 0.4:
		return Color("#e76f51")
	if h < 0.7:
		return Color("#f4a261")
	return Color("#83c779")


# Exhibit suitability — the single 0–100 read on how well an exhibit suits
# its animals (adaptation plan §2 item 1). It's the mean happiness across the
# exhibit's animals, plus an always-on recommendation naming the single
# most-impactful improvement — even at 99% (§5 divergence #2: never leave the
# player guessing what to fix next).
func _exhibit_suitability(region: Region) -> Dictionary:
	var model := ZooBootstrap.get_happiness_model()
	var sum_h: float = 0.0
	var count: int = 0
	var worst := {"penalty": -1.0}
	for i in region.placements.size():
		var def: PlaceableDef = ContentDB.placeable_defs.get(
			region.placements[i].placeable_def_id)
		if def == null or def.appeal_contribution.is_empty():
			continue   # score only animals (appeal-contributing placements)
		var b: Dictionary = model.compute_breakdown(region, i)
		if not b.get("valid", false):
			continue
		sum_h += float(b["happiness"])
		count += 1
		for factor in ["space", "social", "needs"]:
			if float(b[factor]) > float(worst["penalty"]):
				worst = {"penalty": float(b[factor]), "factor": factor,
					"def": def, "b": b}
		var att_pen: float = 1.0 - float(b["attitude"])
		if att_pen > float(worst["penalty"]):
			worst = {"penalty": att_pen, "factor": "attitude", "def": def, "b": b}
	if count == 0:
		return {"has_animals": false}
	return {
		"has_animals": true,
		"percent": int(round(sum_h / count * 100.0)),
		"recommendation": _recommendation_for(worst),
	}


func _recommendation_for(worst: Dictionary) -> String:
	if not worst.has("def"):
		return ""
	var def: PlaceableDef = worst["def"]
	var name: String = def.display_name
	# Near-perfect: §5 says still surface the next axis, framed positively.
	if float(worst["penalty"]) < 0.01:
		return "Looking great — only marginal gains left."
	var b: Dictionary = worst["b"]
	match worst["factor"]:
		"space":
			return "Enlarge this exhibit — the %s is cramped." % name
		"social":
			if b.get("social_kind", "") == "excess":
				return "Too many %s — thin the group (max %d)." % [
					name, int(b["social_max"])]
			return "Add more %s — it's lonely (wants %d–%d together)." % [
				name, int(b["social_min"]), int(b["social_max"])]
		"needs":
			var missing: Array = b.get("missing_needs", [])
			var tag: StringName = missing[0] if not missing.is_empty() else &""
			return "%s for the %s — a need is unmet." % [_need_fix_label(tag), name]
		"attitude":
			return "Let the %s rest — show fatigue is lowering its mood." % name
	return ""


# Map a missing needs_provided tag to a plain build suggestion.
func _need_fix_label(tag: StringName) -> String:
	match tag:
		&"provides_food":
			return "Add a Feeding Trough"
		&"provides_water":
			return "Add a Water Trough"
		_:
			return "Provide %s" % String(tag).replace("provides_", "")


func _begin_move_placement(region_id: int, index: int) -> void:
	var region := RegionRegistry.get_region(region_id)
	if region == null or index >= region.placements.size():
		return
	var def: PlaceableDef = ContentDB.placeable_defs.get(
		region.placements[index].placeable_def_id)
	_moving_region_id = region_id
	_moving_index = index
	_clear_build_selection()
	if def != null:
		_push_log("Move mode: click a tile in Exhibit #%d to relocate the %s. (Esc cancels.)" %
			[region_id, def.display_name])


func _cancel_move_placement() -> void:
	if _moving_region_id < 0:
		return
	_moving_region_id = -1
	_moving_index = -1
	_push_log("[color=#7e9286]Move cancelled.[/color]")


func _try_move_placement_at(cell: Vector2i) -> bool:
	# Returns true if the click was consumed by an active move.
	if _moving_region_id < 0:
		return false
	var region := RegionRegistry.get_region(_moving_region_id)
	if region == null or _moving_index >= region.placements.size():
		_moving_region_id = -1
		_moving_index = -1
		return false
	var target_region := RegionRegistry.region_at_cell(cell)
	if target_region == null or target_region.region_id != _moving_region_id:
		_push_log("[color=#e76f51]Pick a tile inside Exhibit #%d.[/color]" %
			_moving_region_id)
		return true   # still consume the click; move stays armed
	# Stash the new anchor on the placement's state dict — the map renderer
	# already prefers state["primary_cell"] when present.
	var placement: Placement = region.placements[_moving_index]
	placement.state["primary_cell"] = cell
	var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
	if def != null:
		_push_log("Moved %s to (%d, %d)." % [def.display_name, cell.x, cell.y])
	_moving_region_id = -1
	_moving_index = -1
	# region_changed isn't fired by us touching state, but the map redraws
	# every frame so the new position renders immediately. Force a panel
	# refresh in case any happiness shifted.
	_refresh_region_panel()
	return true


func _on_add_placement(region_id: int, def_id: StringName) -> void:
	var p := RegionRegistry.add_placement(region_id, def_id)
	if p != null:
		var def: PlaceableDef = ContentDB.placeable_defs[def_id]
		_push_log("Added [b]%s[/b] to Exhibit #%d" % [def.display_name, region_id])
		_refresh_region_panel()


func _on_remove_placement(region_id: int, index: int) -> void:
	var region := RegionRegistry.get_region(region_id)
	if region == null or index >= region.placements.size():
		return
	var def: PlaceableDef = ContentDB.placeable_defs.get(
		region.placements[index].placeable_def_id)
	if RegionRegistry.remove_placement(region_id, index):
		var name := def.display_name if def != null else "placement"
		_push_log("Removed %s from Exhibit #%d" % [name, region_id])
		_refresh_region_panel()


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


func _harness_open_reports(_action: Dictionary) -> bool:
	_on_reports_pressed()
	return true


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
	_fps_label = _stat("", 11, Color("#5b6f63"))
	row.add_child(_money_label)
	row.add_child(_v_sep())
	row.add_child(_day_label)
	row.add_child(_quality_label)
	row.add_child(_reputation_label)
	row.add_child(_agents_label)
	row.add_child(_v_sep())
	row.add_child(_yesterday_label)
	row.add_child(_v_sep())
	row.add_child(_fps_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "Show the welcome guide again"
	help_btn.custom_minimum_size = Vector2(36, 36)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.pressed.connect(_open_help)
	row.add_child(help_btn)

	var reports_btn := Button.new()
	reports_btn.text = "Reports"
	reports_btn.custom_minimum_size = Vector2(72, 36)
	reports_btn.focus_mode = Control.FOCUS_NONE
	reports_btn.pressed.connect(_on_reports_pressed)
	row.add_child(reports_btn)

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


func _add_build_subhead(col: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#5b6f63"))
	col.add_child(lbl)


func _add_build_button(col: VBoxContainer, def_id: StringName) -> void:
	var def: EntityDef = ContentDB.entity_defs[def_id]
	var btn := Button.new()
	btn.text = "%s\n$%d  ·  %d×%d" % [
		def.display_name,
		def.build_cost,
		def.footprint.x,
		def.footprint.y,
	]
	# Small sprite thumbnail so the visual identity of each option lands
	# faster than reading the name. Falls back gracefully if the sprite
	# doesn't exist — the text label still works.
	var sprite_path := "res://assets/sprites/%s.png" % String(def.sprite_key)
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		if tex != null:
			btn.icon = tex
			btn.expand_icon = true
	btn.tooltip_text = _build_tooltip_for(def)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 56)
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	# Constrain the icon so it doesn't dominate; expand_icon scales to fit.
	btn.add_theme_constant_override("icon_max_width", 38)
	btn.add_theme_constant_override("h_separation", 10)
	btn.toggled.connect(_on_build_toggled.bind(def_id))
	_build_buttons[def_id] = btn
	col.add_child(btn)


func _add_placeable_button(col: VBoxContainer, def_id: StringName) -> void:
	# Same shape as _add_build_button but for PlaceableDefs. A toggled
	# placeable enters "place inside a region" mode: clicking a region tile
	# calls RegionRegistry.add_placement.
	var def: PlaceableDef = ContentDB.placeable_defs[def_id]
	var btn := Button.new()
	btn.text = "%s\n$%d" % [def.display_name, def.build_cost]
	var sprite_path := "res://assets/sprites/%s.png" % String(def.sprite_key)
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		if tex != null:
			btn.icon = tex
			btn.expand_icon = true
	btn.tooltip_text = _placeable_tooltip_for(def)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 56)
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_constant_override("icon_max_width", 38)
	btn.add_theme_constant_override("h_separation", 10)
	btn.toggled.connect(_on_build_toggled.bind(def_id))
	_build_buttons[def_id] = btn
	col.add_child(btn)


func _placeable_tooltip_for(def: PlaceableDef) -> String:
	var lines: Array[String] = []
	lines.append(def.display_name)
	lines.append("Build:  $%d" % def.build_cost)
	if def.maintenance_cost > 0:
		lines.append("Upkeep: $%d/day" % def.maintenance_cost)
	if not def.required_zone_tags.is_empty():
		var tags: Array[String] = []
		for t in def.required_zone_tags:
			tags.append(String(t))
		lines.append("Needs habitat: %s" % ", ".join(tags))
	if def.social_min > 0 or def.social_max < 99:
		lines.append("Group size: %d–%d" % [def.social_min, def.social_max])
	if def.space_ideal > 0:
		lines.append("Ideal space: %d tiles each" % def.space_ideal)
	if not def.appeal_contribution.is_empty():
		var bits: Array[String] = []
		for axis in def.appeal_contribution.keys():
			bits.append("%s %.1f" % [String(axis), def.appeal_contribution[axis]])
		lines.append("Appeal: %s" % ", ".join(bits))
	lines.append("")
	lines.append("Select then click an exhibit to add.")
	return "\n".join(lines)


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

	# With the BUILD menu now hosting zones + amenities + animals +
	# infrastructure (~13 buttons) plus the Mission + Milestones panels,
	# the column easily exceeds 1000px. Wrap it in a ScrollContainer so it
	# stays usable on short windows.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var title := Label.new()
	title.text = "BUILD"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#7e9286"))
	col.add_child(title)

	# Group entities by zone_kind (zone tiles) vs none (amenities), and
	# group placeables by has-appeal (animals) vs not (infrastructure).
	# Stable order inside each group: alphabetical by def_id.
	var zone_ids: Array[StringName] = []
	var path_ids: Array[StringName] = []
	var amenity_ids: Array[StringName] = []
	for def_id in ContentDB.entity_defs.keys():
		var d: EntityDef = ContentDB.entity_defs[def_id]
		if d.walkable:
			path_ids.append(def_id)
		elif d.zone_kind != &"":
			zone_ids.append(def_id)
		else:
			amenity_ids.append(def_id)
	zone_ids.sort_custom(func(a, b): return String(a) < String(b))
	path_ids.sort_custom(func(a, b): return String(a) < String(b))
	amenity_ids.sort_custom(func(a, b): return String(a) < String(b))

	var animal_ids: Array[StringName] = []
	var infra_ids: Array[StringName] = []
	for def_id in ContentDB.placeable_defs.keys():
		var p: PlaceableDef = ContentDB.placeable_defs[def_id]
		# Anything that contributes an appeal axis is an "animal" in the UI
		# sense (it attracts visitors). Troughs and similar pure-utility
		# placeables fall under "infrastructure".
		if not p.appeal_contribution.is_empty():
			animal_ids.append(def_id)
		else:
			infra_ids.append(def_id)
	animal_ids.sort_custom(func(a, b): return String(a) < String(b))
	infra_ids.sort_custom(func(a, b): return String(a) < String(b))

	_add_build_subhead(col, "Exhibit tiles")
	for def_id in zone_ids:
		_add_build_button(col, def_id)
	_add_build_subhead(col, "Paths")
	for def_id in path_ids:
		_add_build_button(col, def_id)
	_add_build_subhead(col, "Amenities")
	for def_id in amenity_ids:
		_add_build_button(col, def_id)
	_add_build_subhead(col, "Animals")
	for def_id in animal_ids:
		_add_placeable_button(col, def_id)
	_add_build_subhead(col, "Infrastructure")
	for def_id in infra_ids:
		_add_placeable_button(col, def_id)

	_build_mission_section(col)
	_build_goals_section(col)

	col.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "L-click map: place / select exhibit\nR-click map: sell (½ refund)\nEsc: clear selection\nP: toggle pause"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("#7e9286"))
	col.add_child(hint)


func _build_right_column(parent: Control) -> void:
	# Three-column layout for the area below the top bar:
	#   left build panel (220 wide, already in _build_left_panel)
	#   center: map + log
	#   right region-manage panel (300 wide, hidden until a region is selected)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 220
	center.offset_top = 56
	center.offset_right = -300   # leave room for the region panel
	center.add_theme_constant_override("separation", 0)
	parent.add_child(center)

	_map_view = MAP_VIEW_SCRIPT.new()
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.entity_colors = ENTITY_COLORS
	_map_view.placement_requested.connect(_on_placement_requested)
	_map_view.remove_requested.connect(_on_remove_requested)
	center.add_child(_map_view)

	_build_region_panel(parent)
	_build_reports_modal(parent)
	_build_tutorial_overlay(parent)
	_build_welcome_modal(parent)
	_build_endgame_modal(parent)
	_build_admin_modal(parent)
	_build_arena_modal(parent)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 140)
	log_panel.add_theme_stylebox_override("panel", _panel_box(Color("#1c2823")))
	center.add_child(log_panel)

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

	# Tutorial step advance: any signal that could indicate progress.
	EventBus.region_created.connect(func(_rid): _check_tutorial_advance())
	EventBus.region_changed.connect(func(_rid): _check_tutorial_advance())
	EventBus.placement_added.connect(func(_rid, _idx): _check_tutorial_advance())
	EventBus.balance_changed.connect(func(_b): _check_tutorial_advance())

	# Keep the region panel synced with engine state.
	EventBus.region_changed.connect(func(rid):
		if rid == _selected_region_id:
			_refresh_region_panel())
	EventBus.region_destroyed.connect(func(rid):
		if rid == _selected_region_id:
			_selected_region_id = -1
			_refresh_region_panel())
	EventBus.placement_added.connect(func(rid, _idx):
		if rid == _selected_region_id:
			_refresh_region_panel())
	EventBus.placement_removed.connect(func(rid, _idx):
		if rid == _selected_region_id:
			_refresh_region_panel())
	ZooBootstrap.donation_collected.connect(func(rid, _amt):
		if rid == _selected_region_id:
			_refresh_region_panel())
	ZooBootstrap.animal_welfare_alert.connect(_on_welfare_alert)


func _stage_starter_park() -> void:
	# A welcoming starter park spread across the map: a Lion savanna and a
	# Penguin pool, with a food stand + restroom on the visitor path between
	# the entrance and the exhibits. Tuned so a non-technical first-time
	# player can run the sim and immediately see activity.

	# --- Lion savanna: grass with rocks at one end. ---
	for x in range(5, 9):
		for y in range(3, 5):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(9, 3))
	EntityRegistry.place(&"rock_patch", Vector2i(9, 4))

	# --- Penguin pool: pure water tiles, separated from the lion region
	# by a one-tile gap so they don't merge into one big Region. ---
	for x in range(5, 9):
		for y in range(8, 10):
			EntityRegistry.place(&"water_patch", Vector2i(x, y))

	# --- Path network: a spine from the entrance gate (0,0) down to a main
	# concourse that runs past both exhibits. Guests spawn at the gate and
	# walk the path; they view an exhibit from any path cell within the
	# engagement distance (navigation.md), so the concourse alone lets them
	# see the lion and the penguins. Lay paths BEFORE amenities so the
	# amenities can sit adjacent to the concourse without colliding. ---
	for y in range(0, 7):
		EntityRegistry.place(&"path", Vector2i(0, y))   # gate → concourse
	for x in range(1, 16):
		EntityRegistry.place(&"path", Vector2i(x, 6))   # concourse

	# --- Amenities, each adjacent to the concourse so guests reach them.
	# The starter park covers all four guest needs (food / drink / restroom /
	# rest) so a first-time player sees a contented crowd before they learn
	# to balance them. ---
	EntityRegistry.place(&"food_stand",  Vector2i(13, 4))  # touches (13,6)/(14,6)
	EntityRegistry.place(&"drink_stand", Vector2i(11, 5))  # touches (11,6)
	EntityRegistry.place(&"restroom",    Vector2i(4, 5))   # touches (4,6)
	EntityRegistry.place(&"bench",       Vector2i(2, 5))   # touches (2,6)

	# --- Lion + its infrastructure. ---
	var lion_region := RegionRegistry.region_at_cell(Vector2i(5, 3))
	if lion_region != null:
		RegionRegistry.add_placement(lion_region.region_id, &"lion")
		RegionRegistry.add_placement(lion_region.region_id, &"feeding_trough")
		RegionRegistry.add_placement(lion_region.region_id, &"water_trough")

	# --- Penguin colony — they're social, start with 4 so the herd
	# requirement is met (social_min=4). ---
	var penguin_region := RegionRegistry.region_at_cell(Vector2i(5, 8))
	if penguin_region != null:
		for _i in 4:
			RegionRegistry.add_placement(penguin_region.region_id, &"penguin")
		RegionRegistry.add_placement(penguin_region.region_id, &"feeding_trough")

	# Visitors enter at the gate and walk in along the path. Spawn them on the
	# entrance path column (x=0, y 0..6) so they start on the network and
	# route immediately; auto-spawned guests enter at the gate cell (0,0).
	for i in range(STARTER_VISITOR_COUNT):
		AgentPool.spawn(&"visitor", Vector2(
			0.0, SimClock.rng.randf_range(0.0, 6.0)))


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
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _goals_box != null:
		_evaluate_goals()
	_refresh_mission()
	_refresh_build_locks()
	_recompute_path_access()


# Find populated exhibits that no gate-reachable path cell can see. Only
# meaningful once a path network exists — with zero paths the game is in
# free-roam mode and every exhibit is reachable, so we stay quiet. Surfaced
# as a map warning + a Manage Exhibit panel line so the player knows to
# connect a path.
func _recompute_path_access() -> void:
	_disconnected_regions.clear()
	var net: WalkableNetwork = NavigationRegistry.get_network()
	if net != null and net.cell_count() > 0:
		var d := _view_engage_d()
		for region in RegionRegistry.all_regions():
			if region.placements.is_empty():
				continue
			if not _region_path_connected(net, region, d):
				_disconnected_regions[region.region_id] = true
	if _map_view != null:
		_map_view.disconnected_regions = _disconnected_regions


func _region_path_connected(net: WalkableNetwork, region: Region, d: int) -> bool:
	var viewing := NavigationRegistry.nearest(GATE_TILE, func(c: Vector2i) -> bool:
		return net.within_engagement_distance(c, region.cells, d))
	return viewing != INetworkNavigator.NO_STEP


func _view_engage_d() -> int:
	var bc: BalanceConfig = ContentDB.balance_config
	return bc.nav_default_engagement_distance if bc != null else 10


func _refresh_affordability() -> void:
	var balance := Ledger.get_balance()
	for def_id in _build_buttons.keys():
		var btn: Button = _build_buttons[def_id]
		var cost := _build_cost_for(def_id)
		btn.disabled = balance < cost or _locked_build_ids.has(def_id)
		if btn.disabled and btn.button_pressed:
			btn.button_pressed = false
			if _selected_def_id == def_id:
				_clear_build_selection()


# Keep reputation-gated build buttons locked until the player earns the
# required reputation, then auto-acquire the unlock (cost 0) and free them.
# Driven from the periodic HUD refresh so it tracks reputation live.
func _refresh_build_locks() -> void:
	for ent_id in REP_GATED_BUILDS.keys():
		var btn: Button = _build_buttons.get(ent_id)
		if btn == null:
			continue
		var node_id: StringName = REP_GATED_BUILDS[ent_id]
		if not ProgressionManager.is_unlocked(node_id) \
				and ProgressionManager.can_unlock(node_id):
			ProgressionManager.try_unlock(node_id)
		if ProgressionManager.is_unlocked(node_id):
			if _locked_build_ids.has(ent_id):
				_locked_build_ids.erase(ent_id)
				var def: EntityDef = ContentDB.get_entity_def(ent_id)
				if def != null:
					btn.tooltip_text = _build_tooltip_for(def)
					_push_log("[color=#f4d35e]★ Unlocked: %s[/color] — your reputation opened it up." %
						def.display_name)
		else:
			_locked_build_ids[ent_id] = true
			var node := ContentDB.get_unlock_node(node_id)
			var req: int = node.reputation_required if node != null else 0
			btn.tooltip_text = "Locked — unlocks at Reputation %d (now %d)." % [
				req, ProgressionManager.reputation]
	_refresh_affordability()


func _build_cost_for(def_id: StringName) -> int:
	# Same BUILD panel hosts EntityDefs (zone tiles + amenities) and
	# PlaceableDefs (animals + infrastructure). Either has build_cost.
	if ContentDB.entity_defs.has(def_id):
		return (ContentDB.entity_defs[def_id] as EntityDef).build_cost
	if ContentDB.placeable_defs.has(def_id):
		return (ContentDB.placeable_defs[def_id] as PlaceableDef).build_cost
	return 0


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
			# Cancel cascade: active move > build tool > region selection.
			# Only quits if there's nothing to cancel (and never on web —
			# a web tab "quit" is a no-op).
			if _moving_region_id >= 0:
				_cancel_move_placement()
			elif _selected_def_id != &"":
				_clear_build_selection()
			elif _selected_region_id >= 0:
				_selected_region_id = -1
				_refresh_region_panel()
			else:
				if OS.has_feature("web"):
					pass
				else:
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
		KEY_S:
			# Stress test: spawn 20 visitors at once so we can profile the
			# crowd. Doesn't change spawn rate — these are just one-off pops.
			for i in range(20):
				AgentPool.spawn(&"visitor", Vector2(
					SimClock.rng.randf_range(0.0, 4.0),
					SimClock.rng.randf_range(0.0, 6.0)))
			_push_log("[color=#7e9286]+20 visitors (stress)[/color]")


func _on_build_toggled(pressed: bool, def_id: StringName) -> void:
	if not pressed:
		if _selected_def_id == def_id:
			_clear_build_selection()
		return
	# Single-select: untoggle every other build button.
	for other_id in _build_buttons.keys():
		if other_id != def_id:
			(_build_buttons[other_id] as Button).set_pressed_no_signal(false)
	_selected_def_id = def_id
	_map_view.preview_def_id = def_id


func _clear_build_selection() -> void:
	if _selected_def_id == &"":
		return
	if _build_buttons.has(_selected_def_id):
		(_build_buttons[_selected_def_id] as Button).set_pressed_no_signal(false)
	_selected_def_id = &""
	_map_view.preview_def_id = &""


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


func _place_placeable_at(cell: Vector2i) -> void:
	var def: PlaceableDef = ContentDB.placeable_defs[_selected_def_id]
	var region := RegionRegistry.region_at_cell(cell)
	if region == null:
		_push_log("[color=#e76f51]Click an exhibit tile to add a %s.[/color]" %
			def.display_name)
		return
	if Ledger.get_balance() < def.build_cost:
		_push_log("[color=#e76f51]Not enough money for %s ($%d).[/color]" %
			[def.display_name, def.build_cost])
		return
	var check := RegionRegistry.can_add_placement(region.region_id, _selected_def_id)
	if not check["ok"]:
		_push_log("[color=#e76f51]Can't add %s to Exhibit #%d: %s[/color]" %
			[def.display_name, region.region_id, check["reason"]])
		return
	var placement := RegionRegistry.add_placement(region.region_id, _selected_def_id)
	if placement == null:
		_push_log("[color=#e76f51]Failed to add %s to Exhibit #%d.[/color]" %
			[def.display_name, region.region_id])
		return
	_push_log("Added [b]%s[/b] to Exhibit #%d" % [def.display_name, region.region_id])
	# Stay in place mode so the player can quickly add more of the same.


func _on_placement_requested(cell: Vector2i) -> void:
	# Active "move placement" mode wins over everything else.
	if _try_move_placement_at(cell):
		return
	# Placeable mode: selected def is an animal or piece of infrastructure
	# that lives inside a Region. Find the region under the cursor and add.
	if ContentDB.placeable_defs.has(_selected_def_id):
		_place_placeable_at(cell)
		return
	# Entity mode: selected def is a zone tile or amenity placed on the grid.
	if _selected_def_id != &"":
		var id := EntityRegistry.place(_selected_def_id, cell)
		if id == 0:
			var def: EntityDef = ContentDB.get_entity_def(_selected_def_id)
			var reason := "blocked"
			if Ledger.get_balance() < def.build_cost:
				reason = "not enough money"
			_push_log("[color=#e76f51]Can't place %s at (%d, %d): %s[/color]" %
				[def.display_name, cell.x, cell.y, reason])
		return
	# No build selection: gate → admin modal; arena → arena modal;
	# exhibit tile → Manage Exhibit panel; blank ground → clear panel.
	if cell == GATE_TILE:
		_open_admin_modal()
		return
	var arena_id := _arena_at(cell)
	if arena_id != 0:
		_open_arena_modal(arena_id)
		return
	var region := RegionRegistry.region_at_cell(cell)
	if region != null:
		_selected_region_id = region.region_id
		_refresh_region_panel()
	else:
		_selected_region_id = -1
		_refresh_region_panel()


func _arena_at(cell: Vector2i) -> int:
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		if inst.entity_def_id != &"arena":
			continue
		var def := inst.get_def()
		if def == null:
			continue
		if cell.x >= inst.position.x and cell.x < inst.position.x + def.footprint.x \
		and cell.y >= inst.position.y and cell.y < inst.position.y + def.footprint.y:
			return inst_id
	return 0


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

func _on_welfare_alert(region_id: int, _index: int, kind: String, animal_name: String) -> void:
	match kind:
		"sick":
			_push_log("[color=#e76f51]⚠ %s in Exhibit #%d is unwell.[/color] Improve its exhibit before it's too late." %
				[animal_name, region_id])
		"recovered":
			_push_log("[color=#83c779]%s in Exhibit #%d is back to health.[/color]" %
				[animal_name, region_id])
		"died":
			_push_log("[color=#e76f51][b]✝ %s in Exhibit #%d died of neglect.[/b][/color] Reputation took a hit." %
				[animal_name, region_id])
	if region_id == _selected_region_id:
		_refresh_region_panel()


func _on_day_settled(day: int, income: int, expense: int) -> void:
	var net := income - expense
	var color := "#83c779" if net >= 0 else "#e76f51"
	# Engine day is 0-indexed; show 1-indexed in the log.
	_push_log("[b]Day %d closed.[/b] [color=%s]Net $%d[/color]  (+$%d / −$%d)" %
		[day + 1, color, net, income, expense])
	_check_endgame(day)


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
