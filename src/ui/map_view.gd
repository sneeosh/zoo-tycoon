extends Control
class_name MapView
# Zoo Tycoon — map view.
#
# Draws the EntityRegistry's placed entities, the AgentPool's visitors, and
# the park entrance gate on a tile grid; handles click-to-place /
# right-click-to-sell. Pure game UI; no engine modifications.

signal placement_requested(grid_cell: Vector2i)
signal remove_requested(grid_cell: Vector2i)

const TILE_SIZE: int = 36
const GRID_ORIGIN: Vector2 = Vector2(28, 28)
const BUILDABLE_TILES: Vector2i = Vector2i(32, 18)
# Footprints with width below this skip the inline name and show a centred
# letter instead — full text doesn't fit and clipping looks broken.
const MIN_TILES_FOR_LABEL: int = 3

# The entrance gate visually anchors visitor spawn/exit at world (0,0).
# Without it, visitors clustering at one corner reads as a bug.
const GATE_TILE: Vector2i = Vector2i(0, 0)
const GATE_COLOR: Color = Color("#f4d35e")
const GATE_POST_COLOR: Color = Color("#e6b32f")

var entity_colors: Dictionary = {}
# Set by main when a build button is toggled on; empty string = none.
var preview_def_id: StringName = &""
# region_id -> true for exhibits guests can't path to. Set by main; drawn as
# a ⚠ badge so the disconnect is visible without opening the manage panel.
var disconnected_regions: Dictionary = {}

# Pixel-art sprites generated via Pixel Lab. Loaded lazily so the game
# doesn't crash if a sprite is missing — we fall back to the colored
# rounded rect.
const SPRITE_DIR := "res://assets/sprites/"
var _sprite_cache: Dictionary = {}       # entity_def_id (StringName) -> Texture2D
var _sprites_checked: Dictionary = {}    # entity_def_id (StringName) -> bool (true once looked up)
var _placeable_sprite_cache: Dictionary = {}  # placeable_def_id (StringName) -> Texture2D
var _visitor_sprite: Texture2D

# Per-archetype body tint so the crowd is legible at a glance (the
# satisfaction halo stays separate). Keys match agents.md agent-type ids.
const ARCHETYPE_COLORS := {
	&"visitor":    Color("#dfe6df"),   # Adult — neutral
	&"child":      Color("#f4a261"),   # Child — orange
	&"family":     Color("#83c779"),   # Family — green
	&"enthusiast": Color("#c9a4ff"),   # Enthusiast — purple
}

var _hover_cell: Vector2i = Vector2i.ZERO
var _hover_pos: Vector2 = Vector2.ZERO
var _hovering: bool = false

# Floating "+$N" toasts spawned by ZooBootstrap.money_floated. Each entry is
# {amount: int, world_pos: Vector2, born_at: float}. We tick them in _process
# and drop them after their lifetime expires.
var _money_floats: Array = []
const FLOAT_LIFETIME: float = 1.4
const FLOAT_RISE_PX: float = 28.0
const FLOAT_LIMIT: int = 40           # cap so a fast 4× day doesn't pile up


# Force the hover state from outside — used by the harness so scripted
# scenarios can capture screenshots that include the inspector card.
# `world_pos` is in game coordinates (same units as Agent.position); we
# convert to the panel's local pixel space.
func force_hover_at_world(world_pos: Vector2) -> void:
	_hover_pos = _world_to_screen(world_pos)
	_hover_cell = _to_grid(_hover_pos)
	_hovering = true

# Cached StyleBoxes per entity def — rounded + bordered drawing is much
# easier through draw_style_box than open-coding the corner geometry.
# Created lazily on first draw of each def.
var _style_cache: Dictionary = {}        # entity_def_id -> StyleBoxFlat
var _shadow_box: StyleBoxFlat
var _card_box: StyleBoxFlat
const VISITOR_HIT_RADIUS_PX: float = 14.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_visitor_sprite = _load_sprite_optional("visitor")
	ZooBootstrap.money_floated.connect(_on_money_floated)
	# Static layers (ground, lawn texture, parkland foliage, grid, vignette)
	# live in a child Control that only redraws on world changes. Drops the
	# heavy 576-cell loops out of the 60-fps redraw path.
	var bg := MapBackground.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# CanvasItem children draw on top of the parent by default — we want the
	# background to sit *behind* MapView's foreground (entities, visitors,
	# floats), so flip show_behind_parent.
	bg.show_behind_parent = true
	add_child(bg)
	_shadow_box = StyleBoxFlat.new()
	_shadow_box.bg_color = Color(0, 0, 0, 0.35)
	_shadow_box.corner_radius_top_left = 6
	_shadow_box.corner_radius_top_right = 6
	_shadow_box.corner_radius_bottom_left = 6
	_shadow_box.corner_radius_bottom_right = 6
	_card_box = StyleBoxFlat.new()
	_card_box.bg_color = Color("#161e1a")
	_card_box.border_color = Color("#3d4f44")
	_card_box.border_width_top = 1
	_card_box.border_width_bottom = 1
	_card_box.border_width_left = 1
	_card_box.border_width_right = 1
	_card_box.corner_radius_top_left = 4
	_card_box.corner_radius_top_right = 4
	_card_box.corner_radius_bottom_left = 4
	_card_box.corner_radius_bottom_right = 4
	_card_box.content_margin_left = 10
	_card_box.content_margin_right = 10
	_card_box.content_margin_top = 8
	_card_box.content_margin_bottom = 8


func _process(_delta: float) -> void:
	_tick_money_floats()
	queue_redraw()


func _on_money_floated(amount: int, world_pos: Vector2) -> void:
	if _money_floats.size() >= FLOAT_LIMIT:
		_money_floats.pop_front()
	_money_floats.append({
		"amount": amount,
		"world_pos": world_pos,
		"born_at": Time.get_ticks_msec() / 1000.0,
	})


func _tick_money_floats() -> void:
	if _money_floats.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var i := 0
	while i < _money_floats.size():
		var entry: Dictionary = _money_floats[i]
		if now - entry["born_at"] >= FLOAT_LIFETIME:
			_money_floats.remove_at(i)
		else:
			i += 1


func _draw_money_floats() -> void:
	if _money_floats.is_empty():
		return
	var font := get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	var fs := 14
	for entry in _money_floats:
		var t: float = clampf((now - entry["born_at"]) / FLOAT_LIFETIME, 0.0, 1.0)
		var alpha: float = 1.0 - t
		var rise: float = lerpf(0.0, FLOAT_RISE_PX, t)
		var base := _world_to_screen(entry["world_pos"])
		var screen_pos := Vector2(base.x, base.y - 12.0 - rise)
		var text := "+$%d" % int(entry["amount"])
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var origin := screen_pos - Vector2(sz.x * 0.5, 0)
		# Black shadow then bright gold text for legibility on any background.
		draw_string(font, origin + Vector2(1, 1), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(0, 0, 0, 0.55 * alpha))
		draw_string(font, origin, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(0.96, 0.83, 0.37, alpha))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_pos = event.position
		_hover_cell = _to_grid(event.position)
		_hovering = true
	elif event is InputEventMouseButton and event.pressed:
		var cell := _to_grid(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			placement_requested.emit(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			remove_requested.emit(cell)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false


func _draw() -> void:
	# Static layers (ground, grass, foliage, region auras, grid, vignette)
	# are drawn by the MapBackground child Control; they re-render only on
	# world events, not every frame.
	_draw_entities()
	_draw_placements()
	_draw_path_warnings()
	_draw_entrance_gate()
	_draw_visitors()
	_draw_money_floats()
	_draw_preview()
	_draw_inspector_card()


# v0.4.0 — render PlaceableDefs inside their regions. Each placement is
# anchored at its primary_cell (engine stamps the first cell of the
# region at add-time; can be overridden via state["primary_cell"]).
# Drawn smaller than a full tile so multiple placements in the same
# region don't visually collide.
func _draw_placements() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for region: Region in RegionRegistry.all_regions():
		for i in region.placements.size():
			var placement: Placement = region.placements[i]
			# Distribute placements across the region's cells so they don't
			# all stack at primary_cell. Game-set state["primary_cell"]
			# (an explicit override) still wins.
			var anchor: Vector2i
			if placement.state.has("primary_cell"):
				anchor = placement.state["primary_cell"]
			elif not region.cells.is_empty():
				anchor = region.cells[i % region.cells.size()]
			else:
				anchor = placement.primary_cell
			var def: PlaceableDef = ContentDB.placeable_defs.get(placement.placeable_def_id)
			if def == null:
				continue
			# Wander offset for animals (anything with an appeal contribution
			# — troughs and infrastructure stay put). Two Lissajous-style
			# sines with different per-placement phase give a roaming look
			# inside ~⅓ of a tile, never leaving the anchor cell. Pure
			# render-time animation; no engine state.
			var wander := Vector2.ZERO
			if not def.appeal_contribution.is_empty():
				var phase := float(region.region_id) * 1.7 + float(i) * 0.91
				var radius := float(TILE_SIZE) * 0.30
				wander = Vector2(
					sin(t * 0.65 + phase) * radius,
					cos(t * 0.48 + phase * 1.3) * radius)
			var sprite := _load_sprite_optional(String(def.sprite_key))
			var anchor_screen := _cell_to_screen(anchor)
			var sprite_size: float = float(TILE_SIZE) * 1.1  # slight overflow ok
			var rect := Rect2(
				anchor_screen + Vector2(
					(TILE_SIZE - sprite_size) * 0.5,
					(TILE_SIZE - sprite_size) * 0.5) + wander,
				Vector2(sprite_size, sprite_size))
			# Shadow stays anchored to the ground; only the sprite hops.
			draw_circle(
				anchor_screen + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5 + 3) \
					+ Vector2(wander.x, 0.0),
				sprite_size * 0.45, Color(0, 0, 0, 0.30))
			if sprite != null:
				draw_texture_rect(sprite, rect, false)
			else:
				draw_circle(
					rect.position + rect.size * 0.5,
					sprite_size * 0.45, Color("#c89465"))
			# Sick animals (welfare below the illness threshold) get a red
			# medical cross so neglect is visible on the map, not just in the
			# manage panel.
			if bool(placement.state.get("sick", false)):
				var badge := rect.position + Vector2(rect.size.x - 6, 4)
				draw_string(get_theme_default_font(), badge + Vector2(1, 1), "✚",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.5))
				draw_string(get_theme_default_font(), badge, "✚",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e76f51"))


# A pulsing ⚠ badge over each exhibit guests can't path to (set by main via
# disconnected_regions). Drawn above the region centroid.
func _draw_path_warnings() -> void:
	if disconnected_regions.is_empty():
		return
	var font := get_theme_default_font()
	var t := Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.55 + 0.45 * sin(t * 3.5)
	for region: Region in RegionRegistry.all_regions():
		if not disconnected_regions.has(region.region_id):
			continue
		if region.cells.is_empty():
			continue
		var sum := Vector2.ZERO
		for c in region.cells:
			sum += Vector2(c)
		var center_cell := sum / float(region.cells.size())
		var screen := GRID_ORIGIN + (center_cell + Vector2(0.5, 0.5)) * TILE_SIZE
		var glyph := "⚠"
		var fs := 22
		var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var origin := screen - Vector2(sz.x * 0.5, sz.y * 0.5)
		draw_string(font, origin + Vector2(1, 1), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5 * pulse))
		draw_string(font, origin, glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.90, 0.43, 0.31, pulse))


# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------

func _draw_entities() -> void:
	var font := get_theme_default_font()
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		_draw_one_entity(inst, def, font)
		# An arena with an active booking gets a yellow star above the
		# top edge so the player can spot which arenas are running shows
		# without opening their modals.
		if inst.entity_def_id == &"arena":
			var booking := ZooBootstrap.get_booking(inst_id)
			if not booking.is_empty():
				var center := _cell_to_screen(inst.position) + Vector2(
					def.footprint.x * TILE_SIZE * 0.5, -10)
				draw_string(font, center - Vector2(7, 0),
					"★", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
					Color(0.96, 0.83, 0.37, 0.95))


func _draw_one_entity(inst: EntityInstance, def: EntityDef, font: Font) -> void:
	var rect := Rect2(
		_cell_to_screen(inst.position),
		Vector2(def.footprint) * TILE_SIZE)
	# Drop shadow underneath every entity, sprite or fallback.
	var shadow_rect := rect.grow(-3).grow(2)
	shadow_rect.position += Vector2(2, 3)
	draw_style_box(_shadow_box, shadow_rect)

	var sprite := _sprite_for(inst.entity_def_id)
	if sprite != null:
		# Pixel-art sprite fills the footprint with a small inset so it
		# doesn't visually butt up against neighbouring grid cells.
		var sprite_rect := rect.grow(-2)
		draw_texture_rect(sprite, sprite_rect, false)
		return

	# Fallback: rounded coloured rect with display name. Used when a
	# sprite hasn't been generated for an entity def yet.
	var inner := rect.grow(-3)
	var style := _style_for(inst.entity_def_id)
	draw_style_box(style, inner)
	draw_rect(
		Rect2(inner.position + Vector2(3, 3), Vector2(inner.size.x - 6, 3)),
		Color(1, 1, 1, 0.18), true)
	if def.footprint.x >= MIN_TILES_FOR_LABEL:
		draw_string(font,
			inner.position + Vector2(5, 14),
			def.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			inner.size.x - 8,
			11,
			Color("#10171a"))
	else:
		var initial := def.display_name.substr(0, 1).to_upper()
		var fs: int = 16 if def.footprint.x >= 2 else 12
		var sz := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font,
			inner.position + Vector2(
				(inner.size.x - sz.x) * 0.5,
				(inner.size.y + sz.y) * 0.5 - 4),
			initial,
			HORIZONTAL_ALIGNMENT_CENTER,
			inner.size.x,
			fs,
			Color("#10171a"))


func _style_for(def_id: StringName) -> StyleBoxFlat:
	if _style_cache.has(def_id):
		return _style_cache[def_id]
	var col: Color = entity_colors.get(def_id, Color("#7e9286"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = col.lightened(0.30)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_style_cache[def_id] = sb
	return sb


# ---------------------------------------------------------------------------
# Entrance gate
# ---------------------------------------------------------------------------

func _draw_entrance_gate() -> void:
	# Sits at world (0,0) where VisitorBehavior spawns and exits.
	var p := _cell_to_screen(GATE_TILE)
	var sprite := _load_sprite_optional("entrance_gate")
	if sprite != null:
		# Render slightly larger than a single tile so the gate has visual
		# weight and the "ZOO" sign is readable.
		var gate_size := Vector2(TILE_SIZE * 1.6, TILE_SIZE * 1.6)
		var gate_origin := p + Vector2(
			(TILE_SIZE - gate_size.x) * 0.5,
			(TILE_SIZE - gate_size.y) * 0.5)
		# Soft shadow underneath.
		var shadow_rect := Rect2(gate_origin, gate_size).grow(-3)
		shadow_rect.position += Vector2(2, 4)
		draw_style_box(_shadow_box, shadow_rect)
		draw_texture_rect(sprite, Rect2(gate_origin, gate_size), false)
		return
	# Fallback: primitive gate (the pre-sprite version).
	var post_w := 5.0
	var post_h := TILE_SIZE * 1.4
	draw_rect(Rect2(p + Vector2(-post_w * 0.5, -2), Vector2(post_w, post_h)),
		GATE_POST_COLOR, true)
	draw_rect(Rect2(p + Vector2(TILE_SIZE - post_w * 0.5, -2), Vector2(post_w, post_h)),
		GATE_POST_COLOR, true)
	draw_rect(Rect2(p + Vector2(-post_w * 0.5, -2), Vector2(TILE_SIZE + post_w, 5)),
		GATE_COLOR, true)
	draw_rect(Rect2(p, Vector2(TILE_SIZE, TILE_SIZE)),
		Color(1, 1, 1, 0.08), true)
	var font := get_theme_default_font()
	var label := "ENTRANCE"
	var fs := 10
	var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var label_pos := p + Vector2((TILE_SIZE - sz.x) * 0.5, post_h + 12)
	draw_string(font, label_pos, label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GATE_COLOR)


# ---------------------------------------------------------------------------
# Visitors
# ---------------------------------------------------------------------------

func _draw_visitors() -> void:
	for agent_id in AgentPool.get_agents_by_type(&"visitor"):
		var ag: Agent = AgentPool.get_agent(agent_id)
		if ag == null or not ag.alive:
			continue
		_draw_one_visitor(ag)


func _draw_one_visitor(ag: Agent) -> void:
	# Subtle vertical bob keyed off the agent id so each visitor bobs out of
	# phase. Gives the impression of life without burning ticks on real
	# animation curves.
	var bob_phase: float = (Time.get_ticks_msec() / 1000.0) * 4.2 \
		+ float(ag.agent_id) * 0.83
	var bob_offset := Vector2(0.0, sin(bob_phase) * 1.2)
	var pos := _world_to_screen(ag.position) + bob_offset
	var sat_color := _satisfaction_color(ag.satisfaction)

	# Drop shadow on the ground (no bob — shadow stays put while sprite hops).
	var ground_pos := _world_to_screen(ag.position)
	draw_circle(ground_pos + Vector2(0.0, 11.0), 9.0, Color(0, 0, 0, 0.32))
	# Larger satisfaction halo so the mood read is obvious at a glance.
	draw_circle(pos, 11.0, Color(sat_color.r, sat_color.g, sat_color.b, 0.45))
	draw_arc(pos, 11.0, 0.0, TAU, 24,
		Color(sat_color.r, sat_color.g, sat_color.b, 0.85), 1.5)

	var arch_color: Color = ARCHETYPE_COLORS.get(ag.agent_type_id, Color("#dfe6df"))
	if _visitor_sprite != null:
		# Bigger sprite so visitors read clearly from across the map; tinted by
		# archetype so families/children/enthusiasts are distinguishable.
		var sprite_size := Vector2(28, 28)
		var sprite_rect := Rect2(pos - sprite_size * 0.5, sprite_size)
		draw_texture_rect(_visitor_sprite, sprite_rect, false, arch_color)
	else:
		# Fallback: archetype-colored circle visitor.
		draw_circle(pos, 8.0, arch_color)
		draw_arc(pos, 8.0, 0, TAU, 22, arch_color.darkened(0.55), 1.4)
		draw_circle(pos + Vector2(-2.0, -2.0), 2.0, Color(1, 1, 1, 0.55))
	_draw_visitor_mood(ag, pos)


# Per-need mood bubble. An unmet need always wins — a colored chip with a
# letter (H/T/R/Z) shows what the guest is missing, so a cluster of blue "T"
# chips reads as "build a drink stand here" at a glance. A content guest with
# no pressing need shows the old ♥/★/♪ delight. This is the cheapest
# engagement win in the genre (adaptation plan §2 item 7) — the crowd
# narrates the simulation without a stats overlay.
const NEED_SHOW_THRESHOLD: float = 0.4
const NEED_BUBBLES := {
	&"hunger":   {"glyph": "H", "color": Color("#e27d60")},
	&"thirst":   {"glyph": "T", "color": Color("#5aa9e6")},
	&"restroom": {"glyph": "R", "color": Color("#41b3a3")},
	&"energy":   {"glyph": "Z", "color": Color("#c9a4ff")},
}


func _draw_visitor_mood(ag: Agent, pos: Vector2) -> void:
	# Urgent need = the lowest need below the show threshold.
	var urgent_id: StringName = &""
	var lowest: float = NEED_SHOW_THRESHOLD
	for need_id in ag.need_levels.keys():
		var lvl: float = ag.need_levels[need_id]
		if lvl < lowest:
			lowest = lvl
			urgent_id = need_id

	var t := Time.get_ticks_msec() / 1000.0
	if urgent_id != &"" and NEED_BUBBLES.has(urgent_id):
		# Steady pulse so a needy guest is always legible (no on/off cycle).
		var pulse: float = 0.6 + 0.4 * sin(t * 3.0 + float(ag.agent_id) * 0.7)
		var spec: Dictionary = NEED_BUBBLES[urgent_id]
		_draw_mood_chip(pos, spec["glyph"], spec["color"], pulse)
		return

	# Content guest: the old delight bubbles, cycling on/off per agent.
	if ag.satisfaction < 0.75:
		return
	var phase := fmod(t + float(ag.agent_id) * 0.71, 3.0)
	if phase > 1.4:
		return
	var glyphs := ["♥", "★", "♪"]
	var glyph: String = glyphs[ag.agent_id % glyphs.size()]
	var alpha: float = sin(phase / 1.4 * PI)
	var rise: float = lerpf(0.0, 6.0, phase / 1.4)
	var bubble_color := Color(1.0, 0.55, 0.6, alpha) \
		if glyph == "♥" \
		else (Color(0.96, 0.83, 0.37, alpha) if glyph == "★" \
		else Color(0.7, 0.85, 0.95, alpha))
	var font := get_theme_default_font()
	var fs := 14
	var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var origin := pos + Vector2(-sz.x * 0.5, -18.0 - rise)
	draw_string(font, origin + Vector2(1, 1), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0, 0, 0, 0.40 * alpha))
	draw_string(font, origin, glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bubble_color)


# A small rounded "thought chip" above a visitor: a filled circle in the
# need's color with a white letter, used for the urgent-need bubble.
func _draw_mood_chip(pos: Vector2, glyph: String, color: Color, intensity: float) -> void:
	var center := pos + Vector2(0.0, -20.0)
	var r := 7.0
	draw_circle(center + Vector2(0.5, 1.0), r, Color(0, 0, 0, 0.30 * intensity))
	draw_circle(center, r, Color(color.r, color.g, color.b, 0.92 * intensity))
	draw_arc(center, r, 0.0, TAU, 18,
		Color(1, 1, 1, 0.55 * intensity), 1.0)
	var font := get_theme_default_font()
	var fs := 11
	var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, center - Vector2(sz.x * 0.5, -fs * 0.36), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, intensity))


# ---------------------------------------------------------------------------
# Build preview
# ---------------------------------------------------------------------------

func _draw_preview() -> void:
	if not (_hovering and preview_def_id != &""):
		return
	# Placeables: highlight the entire region under the cursor, green if it
	# accepts the placeable, red if not (or if the cell isn't in any region).
	if ContentDB.placeable_defs.has(preview_def_id):
		_draw_placeable_preview()
		return
	# Entities (zone tiles + amenities): the classic footprint preview.
	var def: EntityDef = ContentDB.get_entity_def(preview_def_id)
	if def == null:
		return
	var rect := Rect2(_cell_to_screen(_hover_cell),
		Vector2(def.footprint) * TILE_SIZE)
	var can_afford := Ledger.get_balance() >= def.build_cost
	var collides := _would_collide(_hover_cell, def.footprint)
	var col: Color
	if not can_afford or collides:
		col = Color(0.85, 0.25, 0.25, 0.45)
	else:
		col = entity_colors.get(preview_def_id, Color.WHITE)
		col.a = 0.45
	draw_rect(rect.grow(-3), col, true)
	draw_rect(rect.grow(-3), Color(1, 1, 1, 0.7), false, 1.5)


func _draw_placeable_preview() -> void:
	var region := RegionRegistry.region_at_cell(_hover_cell)
	if region == null:
		# Tile-sized warning rectangle on the hover cell so the player sees
		# they need to aim at an exhibit.
		var rect := Rect2(_cell_to_screen(_hover_cell),
			Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect.grow(-3), Color(0.85, 0.25, 0.25, 0.30), true)
		return
	var check := RegionRegistry.can_add_placement(region.region_id, preview_def_id)
	var ok: bool = check["ok"]
	var def: PlaceableDef = ContentDB.placeable_defs[preview_def_id]
	if Ledger.get_balance() < def.build_cost:
		ok = false
	var fill: Color = Color(0.51, 0.78, 0.47, 0.30) if ok \
		else Color(0.90, 0.43, 0.31, 0.30)
	var stroke: Color = Color(0.51, 0.78, 0.47, 0.85) if ok \
		else Color(0.90, 0.43, 0.31, 0.85)
	# Paint every cell of the region so an L-shaped exhibit reads correctly.
	for c in region.cells:
		var rect := Rect2(_cell_to_screen(c),
			Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect, fill, true)
	# Trace the same perimeter MapBackground uses for region auras, in our
	# accept/reject color so the player sees which exhibit they're targeting.
	var cell_set := {}
	for c in region.cells:
		cell_set[c] = true
	for c in region.cells:
		var s := _cell_to_screen(c)
		var p0 := s
		var p1 := s + Vector2(TILE_SIZE, 0)
		var p2 := s + Vector2(TILE_SIZE, TILE_SIZE)
		var p3 := s + Vector2(0, TILE_SIZE)
		if not cell_set.has(c + Vector2i(0, -1)):
			draw_line(p0, p1, stroke, 2.5)
		if not cell_set.has(c + Vector2i(1, 0)):
			draw_line(p1, p2, stroke, 2.5)
		if not cell_set.has(c + Vector2i(0, 1)):
			draw_line(p2, p3, stroke, 2.5)
		if not cell_set.has(c + Vector2i(-1, 0)):
			draw_line(p3, p0, stroke, 2.5)


# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------

func _to_grid(local_pos: Vector2) -> Vector2i:
	var p := (local_pos - GRID_ORIGIN) / float(TILE_SIZE)
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


func _cell_to_screen(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * TILE_SIZE


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return GRID_ORIGIN + world_pos * TILE_SIZE


func _satisfaction_color(s: float) -> Color:
	if s < 0.5:
		return Color("#e76f51").lerp(Color("#f4a261"), s * 2.0)
	return Color("#f4a261").lerp(Color("#83c779"), (s - 0.5) * 2.0)


func _would_collide(pos: Vector2i, footprint: Vector2i) -> bool:
	for dx in footprint.x:
		for dy in footprint.y:
			var cell := pos + Vector2i(dx, dy)
			for inst_id in EntityRegistry.instances.keys():
				var inst: EntityInstance = EntityRegistry.instances[inst_id]
				var def := inst.get_def()
				if def == null:
					continue
				if cell.x >= inst.position.x and cell.x < inst.position.x + def.footprint.x \
				and cell.y >= inst.position.y and cell.y < inst.position.y + def.footprint.y:
					return true
	return false


# ---------------------------------------------------------------------------
# Hover inspector
# ---------------------------------------------------------------------------

# Hover info card. Suppressed during build-mode hover so it doesn't fight
# the placement preview for attention. Visitors take priority over entities
# because they're smaller and harder to land the cursor on.
func _draw_inspector_card() -> void:
	if not _hovering or preview_def_id != &"":
		return
	var lines := _inspect_visitor_at(_hover_pos)
	if lines.is_empty():
		lines = _inspect_entity_at(_hover_cell)
	if lines.is_empty():
		return
	_render_card(lines, _hover_pos)


func _inspect_visitor_at(local_pos: Vector2) -> Array[String]:
	var hit_id: int = 0
	for agent_id in AgentPool.get_agents_by_type(&"visitor"):
		var ag: Agent = AgentPool.get_agent(agent_id)
		if ag == null or not ag.alive:
			continue
		var pos := _world_to_screen(ag.position)
		if pos.distance_to(local_pos) <= VISITOR_HIT_RADIUS_PX:
			hit_id = agent_id
			break
	if hit_id == 0:
		return []
	var ag: Agent = AgentPool.get_agent(hit_id)
	if ag == null:
		return []
	var state: StringName = ag.behavior_state.get(&"state", &"browsing")
	var out: Array[String] = []
	var atype: AgentType = ContentDB.get_agent_type(ag.agent_type_id)
	var type_name: String = atype.display_name if atype != null else "Visitor"
	out.append("%s #%d" % [type_name, hit_id])
	out.append("state: %s" % String(state))
	out.append("satisfaction: %s %.2f" %
		[_bar(ag.satisfaction), ag.satisfaction])
	for need_id in ag.need_levels.keys():
		var lvl: float = ag.need_levels[need_id]
		out.append("%s: %s %.2f" % [String(need_id), _bar(lvl), lvl])
	# Traits worth surfacing — skip the noise/internal ones.
	var ws: float = ag.traits.get(&"walking_speed", 0.0)
	var sd: float = ag.traits.get(&"stay_duration", 0.0)
	if ws > 0.0:
		out.append("walking_speed: %.2f" % ws)
	if sd > 0.0:
		var spawn_tick: int = int(ag.behavior_state.get(&"spawn_tick", 0))
		var ticks_left: int = max(0, int(sd) - (SimClock.current_tick - spawn_tick))
		out.append("stays %d more ticks" % ticks_left)
	if ag.target_entity_id != 0:
		var inst := EntityRegistry.get_instance(ag.target_entity_id)
		if inst != null:
			out.append("heading to: %s" % inst.get_def().display_name)
	return out


func _inspect_entity_at(cell: Vector2i) -> Array[String]:
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		if cell.x < inst.position.x or cell.x >= inst.position.x + def.footprint.x:
			continue
		if cell.y < inst.position.y or cell.y >= inst.position.y + def.footprint.y:
			continue
		var out: Array[String] = []
		out.append(def.display_name)
		out.append("build $%d  ·  maint $%d/day" %
			[def.build_cost, def.maintenance_cost])
		var targeters := AgentPool.count_targeting(inst_id)
		out.append("visitors heading here: %d" % targeters)
		if not def.satisfies.is_empty():
			var sats: Array[String] = []
			for s in def.satisfies:
				sats.append(String(s))
			out.append("satisfies: %s" % ", ".join(sats))
		if not def.appeal_profile.is_empty():
			var bits: Array[String] = []
			for axis in def.appeal_profile.keys():
				bits.append("%s %.1f" % [String(axis), def.appeal_profile[axis]])
			out.append("appeal: %s" % ", ".join(bits))
		return out
	return []


func _render_card(lines: Array[String], anchor: Vector2) -> void:
	var font := get_theme_default_font()
	var fs := 11
	var line_h := fs + 3
	var max_w: float = 0.0
	for line in lines:
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > max_w:
			max_w = w
	var card_w := max_w + 20  # left/right margins from _card_box
	var card_h := lines.size() * line_h + 16
	# Pin card to keep it on-screen.
	var origin := anchor + Vector2(14, 14)
	if origin.x + card_w > size.x:
		origin.x = max(0.0, anchor.x - card_w - 14)
	if origin.y + card_h > size.y:
		origin.y = max(0.0, anchor.y - card_h - 14)
	var rect := Rect2(origin, Vector2(card_w, card_h))
	draw_style_box(_card_box, rect)
	var text_origin := origin + Vector2(10, 8)
	for i in lines.size():
		var color := Color("#e6e6e6") if i == 0 else Color("#a8c4b0")
		var size_modifier := 0 if i > 0 else 1
		draw_string(font,
			text_origin + Vector2(0, fs + i * line_h),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs + size_modifier,
			color)


# ---------------------------------------------------------------------------
# Sprite loading
# ---------------------------------------------------------------------------

# Returns the Texture2D for `def_id` or null if no sprite exists. Caches
# both hits and misses so missing files don't trigger a disk check every
# frame. The fallback rounded-rect renderer takes over when this returns
# null, so missing sprites degrade gracefully.
func _sprite_for(def_id: StringName) -> Texture2D:
	if _sprite_cache.has(def_id):
		return _sprite_cache[def_id]
	if _sprites_checked.has(def_id):
		return null  # previously looked up and absent
	var tex := _load_sprite_optional(String(def_id))
	_sprites_checked[def_id] = true
	if tex != null:
		_sprite_cache[def_id] = tex
	return tex


var _sprite_by_name: Dictionary = {}  # name -> Texture2D (or null for cached misses)


# Centralized sprite loader. Caches misses too so a missing PNG doesn't
# hit the disk every frame. The cache also avoids a baffling Godot
# behaviour where re-`load()`-ing the same Resource path each frame can
# return a placeholder white texture (observed on v4.5.1) — caching the
# Texture2D reference on first load sidesteps that entirely.
func _load_sprite_optional(name: String) -> Texture2D:
	if _sprite_by_name.has(name):
		return _sprite_by_name[name]
	var path := SPRITE_DIR + name + ".png"
	if not ResourceLoader.exists(path):
		_sprite_by_name[name] = null
		return null
	var res := load(path)
	if res is Texture2D:
		_sprite_by_name[name] = res
		return res
	_sprite_by_name[name] = null
	return null


func _bar(value: float) -> String:
	# ASCII progress bar — 8 cells, each = 0.125 of full.
	var filled := int(round(clampf(value, 0.0, 1.0) * 8.0))
	var s := ""
	for i in 8:
		s += "▰" if i < filled else "▱"
	return s
