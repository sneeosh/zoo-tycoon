extends Control
class_name MapView
# Zoo Tycoon — map view.
#
# Draws the EntityRegistry's placed entities, the AgentPool's visitors, and
# the park entrance gate on a tile grid; handles click-to-place /
# right-click-to-sell. Pure game UI; no engine modifications.

signal placement_requested(grid_cell: Vector2i)
signal remove_requested(grid_cell: Vector2i)

const TILE_SIZE: int = 28
const GRID_ORIGIN: Vector2 = Vector2(24, 24)
const BUILDABLE_TILES: Vector2i = Vector2i(28, 18)
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

var _hover_cell: Vector2i = Vector2i.ZERO
var _hovering: bool = false

# Cached StyleBoxes per entity def — rounded + bordered drawing is much
# easier through draw_style_box than open-coding the corner geometry.
# Created lazily on first draw of each def.
var _style_cache: Dictionary = {}        # entity_def_id -> StyleBoxFlat
var _shadow_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shadow_box = StyleBoxFlat.new()
	_shadow_box.bg_color = Color(0, 0, 0, 0.35)
	_shadow_box.corner_radius_top_left = 6
	_shadow_box.corner_radius_top_right = 6
	_shadow_box.corner_radius_bottom_left = 6
	_shadow_box.corner_radius_bottom_right = 6


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
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
	_draw_ground()
	_draw_grid()
	_draw_entities()
	_draw_entrance_gate()
	_draw_visitors()
	_draw_preview()


# ---------------------------------------------------------------------------
# Background layers
# ---------------------------------------------------------------------------

func _draw_ground() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#0f1612"), true)
	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	# Layered fills for subtle depth: outer darker, inner lighter.
	draw_rect(build_rect, Color("#1d2922"), true)
	draw_rect(build_rect.grow(-2), Color("#22302a"), true)


func _draw_grid() -> void:
	var minor := Color(1, 1, 1, 0.04)
	for c in range(BUILDABLE_TILES.x + 1):
		var x := GRID_ORIGIN.x + c * TILE_SIZE
		draw_line(Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + BUILDABLE_TILES.y * TILE_SIZE), minor)
	for r in range(BUILDABLE_TILES.y + 1):
		var y := GRID_ORIGIN.y + r * TILE_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + BUILDABLE_TILES.x * TILE_SIZE, y), minor)
	# Major lines every 5 tiles for spatial reference.
	var major := Color(1, 1, 1, 0.08)
	for c in range(0, BUILDABLE_TILES.x + 1, 5):
		var x := GRID_ORIGIN.x + c * TILE_SIZE
		draw_line(Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + BUILDABLE_TILES.y * TILE_SIZE), major, 1.5)
	for r in range(0, BUILDABLE_TILES.y + 1, 5):
		var y := GRID_ORIGIN.y + r * TILE_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + BUILDABLE_TILES.x * TILE_SIZE, y), major, 1.5)
	# Border around buildable area.
	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	draw_rect(build_rect, Color(1, 1, 1, 0.18), false, 2.0)


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


func _draw_one_entity(inst: EntityInstance, def: EntityDef, font: Font) -> void:
	var rect := Rect2(
		_cell_to_screen(inst.position),
		Vector2(def.footprint) * TILE_SIZE)
	var inner := rect.grow(-3)
	# Soft drop shadow underneath, offset down-right.
	var shadow_rect := inner.grow(2)
	shadow_rect.position += Vector2(2, 3)
	draw_style_box(_shadow_box, shadow_rect)
	# Body via cached StyleBox.
	var style := _style_for(inst.entity_def_id)
	draw_style_box(style, inner)
	# Inner highlight strip near the top-left for fake lighting.
	draw_rect(
		Rect2(inner.position + Vector2(3, 3), Vector2(inner.size.x - 6, 3)),
		Color(1, 1, 1, 0.18), true)
	# Label. Padding kept tight on small-ish footprints — rounded
	# corners + a 12pt font leave little usable width on 3-tile entities.
	if def.footprint.x >= MIN_TILES_FOR_LABEL:
		var label_fs: int = 11
		draw_string(font,
			inner.position + Vector2(5, 14),
			def.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			inner.size.x - 8,
			label_fs,
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
	# Two short posts framing the entry tile + a small "ENTRANCE" tag.
	# Sits at the world origin (0,0) where VisitorBehavior spawns and exits.
	var p := _cell_to_screen(GATE_TILE)
	var post_w := 5.0
	var post_h := TILE_SIZE * 1.4
	# Posts
	draw_rect(Rect2(p + Vector2(-post_w * 0.5, -2), Vector2(post_w, post_h)),
		GATE_POST_COLOR, true)
	draw_rect(Rect2(p + Vector2(TILE_SIZE - post_w * 0.5, -2), Vector2(post_w, post_h)),
		GATE_POST_COLOR, true)
	# Lintel across the top
	draw_rect(Rect2(p + Vector2(-post_w * 0.5, -2), Vector2(TILE_SIZE + post_w, 5)),
		GATE_COLOR, true)
	# Subtle ground footprint under the gate
	draw_rect(Rect2(p, Vector2(TILE_SIZE, TILE_SIZE)),
		Color(1, 1, 1, 0.08), true)
	# Label
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
	var pos := _world_to_screen(ag.position)
	var sat_color := _satisfaction_color(ag.satisfaction)
	# Soft shadow.
	draw_circle(pos + Vector2(0.5, 2.0), 6.5, Color(0, 0, 0, 0.35))
	# Body — slightly taller than wide, drawn as a circle for speed.
	draw_circle(pos, 6.0, sat_color)
	# Crisp outline ring to lift it off the dark park ground.
	draw_arc(pos, 6.0, 0, TAU, 22, sat_color.darkened(0.55), 1.2)
	# Specular highlight (fake top-left light source).
	draw_circle(pos + Vector2(-1.8, -1.8), 1.8, Color(1, 1, 1, 0.45))


# ---------------------------------------------------------------------------
# Build preview
# ---------------------------------------------------------------------------

func _draw_preview() -> void:
	if not (_hovering and preview_def_id != &""):
		return
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
