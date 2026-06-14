extends Control
class_name LineageModal
## Name-your-animals + family/lineage view (roadmap 6.5).
##
## The breeding system already produces generations; this surfaces them. Every
## living animal is listed grouped by species, each row editable so the player
## can name the lion they bred three generations ago, with its generation and
## parent shown — the emotional hook that turns a stocked pen into a zoo.
##
## Self-contained like SettingsModal: it reads the roster from ZooBootstrap
## (`get_lineage`) and writes names back through `rename_animal`, so it needs
## no hook into the big region panel.

const _BG := Color("#2a3a22")
const _ACCENT := Color("#f4d35e")
const _TEXT := Color("#dde4cf")
const _MUTE := Color("#97a387")

var _list: VBoxContainer


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
	card.offset_left = -300
	card.offset_top = -280
	card.offset_right = 300
	card.offset_bottom = 280
	card.add_theme_stylebox_override("panel", _box())
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(540, 0)
	margin.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.text = I18n.t("lineage.title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", _ACCENT)
	header.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(36, 30)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 460)
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func open() -> void:
	_refresh()
	visible = true


func close() -> void:
	visible = false


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var roster: Array = ZooBootstrap.get_lineage()
	if roster.is_empty():
		_list.add_child(_caption(I18n.t("lineage.empty")))
		return
	# Group by species, generation ascending so founders read above offspring.
	var by_species: Dictionary = {}
	for a in roster:
		var key := String(a["species"])
		if not by_species.has(key):
			by_species[key] = []
		by_species[key].append(a)
	var species_keys: Array = by_species.keys()
	species_keys.sort()
	for key in species_keys:
		var group: Array = by_species[key]
		group.sort_custom(func(x, y): return int(x["generation"]) < int(y["generation"]))
		_list.add_child(_species_header(I18n.t("lineage.species_count") % [key, group.size()]))
		for a in group:
			_list.add_child(_animal_row(a))


func _animal_row(a: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_edit := LineEdit.new()
	name_edit.text = String(a["name"])
	name_edit.custom_minimum_size = Vector2(170, 28)
	name_edit.tooltip_text = I18n.t("lineage.rename_tip")
	var rid: int = int(a["region_id"])
	var idx: int = int(a["index"])
	var commit := func(new_text: String):
		ZooBootstrap.rename_animal(RegionRegistry.get_region(rid), idx, new_text)
	name_edit.text_submitted.connect(commit)
	name_edit.focus_exited.connect(func(): commit.call(name_edit.text))
	row.add_child(name_edit)

	var gen: int = int(a["generation"])
	var meta := Label.new()
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", _MUTE)
	var parent := String(a["parent"])
	var lineage_text := I18n.t("lineage.founder") if gen == 0 or parent == "" \
		else (I18n.t("lineage.born_to") % parent)
	meta.text = "%s · %s · %s" % [
		I18n.t("lineage.gen") % gen, I18n.t("lineage.age") % int(a["age"]), lineage_text]
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(meta)
	return row


func _box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = _BG
	b.border_color = Color(0.55, 0.48, 0.29, 0.5)
	b.set_border_width_all(1)
	b.set_corner_radius_all(3)
	return b


func _species_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", _ACCENT)
	return l


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", _MUTE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
