extends Control
class_name MapView
# Zoo Tycoon — map view.
#
# Draws the EntityRegistry's placed entities and the AgentPool's visitors on a
# tile grid, and handles click-to-place / right-click-to-sell. Pure game UI;
# no engine modifications.

signal placement_requested(grid_cell: Vector2i)
signal remove_requested(grid_cell: Vector2i)

const TILE_SIZE: int = 28
const GRID_ORIGIN: Vector2 = Vector2(24, 24)
const BUILDABLE_TILES: Vector2i = Vector2i(28, 18)
# Footprints with width below this skip the inline name and show a centred
# letter instead — full text doesn't fit and clipping looks broken.
const MIN_TILES_FOR_LABEL: int = 3

var entity_colors: Dictionary = {}
# Set by main when a build button is toggled on; empty string = none.
var preview_def_id: StringName = &""

var _hover_cell: Vector2i = Vector2i.ZERO
var _hovering: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	# Map state changes every tick (agents move); cheap to repaint.
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
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#141d18"), true)

	# Buildable area — a lighter "park ground" that frames where the player
	# can place. Empty space outside this is clearly off-limits.
	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	draw_rect(build_rect, Color("#1f2c25"), true)

	var grid_color := Color(1, 1, 1, 0.05)
	for c in range(BUILDABLE_TILES.x + 1):
		var x := GRID_ORIGIN.x + c * TILE_SIZE
		draw_line(Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + BUILDABLE_TILES.y * TILE_SIZE), grid_color)
	for r in range(BUILDABLE_TILES.y + 1):
		var y := GRID_ORIGIN.y + r * TILE_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + BUILDABLE_TILES.x * TILE_SIZE, y), grid_color)

	# Stronger lines every 5 tiles for orientation.
	var major_color := Color(1, 1, 1, 0.09)
	for c in range(0, BUILDABLE_TILES.x + 1, 5):
		var x := GRID_ORIGIN.x + c * TILE_SIZE
		draw_line(Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + BUILDABLE_TILES.y * TILE_SIZE), major_color, 1.5)
	for r in range(0, BUILDABLE_TILES.y + 1, 5):
		var y := GRID_ORIGIN.y + r * TILE_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + BUILDABLE_TILES.x * TILE_SIZE, y), major_color, 1.5)

	# Bright border around the buildable area.
	draw_rect(build_rect, Color(1, 1, 1, 0.18), false, 2.0)

	var font := get_theme_default_font()

	# Entities.
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		var rect := Rect2(
			_cell_to_screen(inst.position),
			Vector2(def.footprint) * TILE_SIZE)
		var col: Color = entity_colors.get(inst.entity_def_id, Color("#7e9286"))
		var inner := rect.grow(-3)
		draw_rect(inner, col, true)
		draw_rect(inner, col.lightened(0.35), false, 2.0)
		if def.footprint.x >= MIN_TILES_FOR_LABEL:
			draw_string(font,
				inner.position + Vector2(6, 14),
				def.display_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				inner.size.x - 12,
				11,
				Color("#1a241f"))
		else:
			# Tight footprint — show a centred initial instead of clipping.
			var initial := def.display_name.substr(0, 1).to_upper()
			var fs := 16 if def.footprint.x >= 2 else 12
			var sz := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string(font,
				inner.position + Vector2(
					(inner.size.x - sz.x) * 0.5,
					(inner.size.y + sz.y) * 0.5 - 4),
				initial,
				HORIZONTAL_ALIGNMENT_CENTER,
				inner.size.x,
				fs,
				Color("#1a241f"))

	# Visitors. Bigger than v1: 8px body + outline + highlight so they read
	# clearly against the grid and their satisfaction colour is visible at
	# a glance.
	for agent_id in AgentPool.get_agents_by_type(&"visitor"):
		var ag: Agent = AgentPool.get_agent(agent_id)
		if ag == null or not ag.alive:
			continue
		var pos := _world_to_screen(ag.position)
		var sat_color := _satisfaction_color(ag.satisfaction)
		draw_circle(pos + Vector2(0.5, 1.5), 7.5, Color(0, 0, 0, 0.35))  # soft shadow
		draw_circle(pos, 7.0, sat_color)
		draw_arc(pos, 7.0, 0, TAU, 20, sat_color.darkened(0.4), 1.5)
		draw_circle(pos + Vector2(-2.0, -2.0), 2.0, Color(1, 1, 1, 0.45))  # highlight

	# Build preview.
	if _hovering and preview_def_id != &"":
		var def: EntityDef = ContentDB.get_entity_def(preview_def_id)
		if def != null:
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
			draw_rect(rect.grow(-3),
				Color(1, 1, 1, 0.7), false, 1.5)


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
