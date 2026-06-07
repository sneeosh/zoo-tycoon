extends Control
class_name MapBackground
# The non-animated layers of the map view: ground color, painted-lawn
# texture, parkland foliage, the major grid, and the corner vignette.
#
# This Control's _draw is only called when invalidated — either on resize
# or when the set of placed entities / regions changes (foliage skips
# those cells). MapView's foreground _draw still runs every frame, but the
# heavy 576-cell loops live here and run rarely, not 60 times per second.

const TILE_SIZE: int = 36
const GRID_ORIGIN: Vector2 = Vector2(28, 28)
const BUILDABLE_TILES: Vector2i = Vector2i(32, 18)
const GATE_TILE: Vector2i = Vector2i(0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Foliage and region cells depend on the placed entity set, so any
	# change to entities or regions invalidates the background.
	EventBus.entity_placed.connect(func(_id): queue_redraw())
	EventBus.entity_removed.connect(func(_id): queue_redraw())
	EventBus.region_created.connect(func(_rid): queue_redraw())
	EventBus.region_destroyed.connect(func(_rid): queue_redraw())
	EventBus.region_changed.connect(func(_rid): queue_redraw())
	resized.connect(func(): queue_redraw())


func _draw() -> void:
	_draw_ground()
	_draw_grass_texture()
	_draw_decorative_foliage()
	_draw_region_auras()
	_draw_grid()
	_draw_vignette()


# ---------------------------------------------------------------------------
# Region auras — tint + perimeter for each connected region.
# ---------------------------------------------------------------------------

func _draw_region_auras() -> void:
	for region: Region in RegionRegistry.all_regions():
		if region.cells.is_empty():
			continue
		var color := _region_tint(region)
		var cell_set := {}
		for c in region.cells:
			cell_set[c] = true
		var fill_color := Color(color.r, color.g, color.b, 0.38)
		for c in region.cells:
			var rect := Rect2(_cell_to_screen(c),
				Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(rect, fill_color, true)
		var stroke := Color(color.r, color.g, color.b, 0.85)
		var w: float = 2.5
		for c in region.cells:
			var screen := _cell_to_screen(c)
			var p0 := screen
			var p1 := screen + Vector2(TILE_SIZE, 0)
			var p2 := screen + Vector2(TILE_SIZE, TILE_SIZE)
			var p3 := screen + Vector2(0, TILE_SIZE)
			if not cell_set.has(c + Vector2i(0, -1)):
				draw_line(p0, p1, stroke, w)
			if not cell_set.has(c + Vector2i(1, 0)):
				draw_line(p1, p2, stroke, w)
			if not cell_set.has(c + Vector2i(0, 1)):
				draw_line(p2, p3, stroke, w)
			if not cell_set.has(c + Vector2i(-1, 0)):
				draw_line(p3, p0, stroke, w)


func _region_tint(region: Region) -> Color:
	if &"water" in region.provided_zone_tags:
		return Color("#5fa8d4")
	if &"tall_cage" in region.provided_zone_tags:
		return Color("#6fc2a0")
	if &"rocks" in region.provided_zone_tags:
		return Color("#d49a5a")
	if &"grass" in region.provided_zone_tags:
		return Color("#9bc26a")
	return Color("#a0a0a0")


# ---------------------------------------------------------------------------
# Static layers
# ---------------------------------------------------------------------------

func _draw_ground() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("#0c1410"), true)
	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	draw_rect(build_rect, Color("#24402a"), true)
	draw_rect(build_rect.grow(-2), Color("#3c5e36"), true)
	# Gentle top-to-bottom light banding for depth (lighter near the top).
	var bands := 6
	for i in bands:
		var t := float(i) / float(bands)
		var band := Rect2(
			build_rect.position + Vector2(0, t * build_rect.size.y),
			Vector2(build_rect.size.x, build_rect.size.y / float(bands)))
		draw_rect(band, Color(1, 1, 1, 0.04 * (1.0 - t)), true)


func _draw_grass_texture() -> void:
	for cx in BUILDABLE_TILES.x:
		for cy in BUILDABLE_TILES.y:
			var h := _hash2(cx, cy)
			if (h % 6) != 0:
				continue
			var origin := _cell_to_screen(Vector2i(cx, cy))
			var ox := float(h % 23) / 23.0
			var oy := float((h / 23) % 19) / 19.0
			var center := origin + Vector2(ox * TILE_SIZE, oy * TILE_SIZE)
			var variant := (h / 100) % 3
			var radius := 5.0 + float(h % 5)
			match variant:
				0:
					draw_circle(center, radius,
						Color(0.18, 0.31, 0.16, 0.30))
				1:
					draw_circle(center, radius,
						Color(0.30, 0.45, 0.22, 0.22))
				_:
					draw_circle(center, radius * 0.85,
						Color(0.38, 0.40, 0.22, 0.16))
	for cx in BUILDABLE_TILES.x:
		for cy in BUILDABLE_TILES.y:
			var h2 := _hash2(cx * 7 + 13, cy * 11 + 5)
			for sub in 3:
				var hs := h2 ^ (sub * 137)
				if (hs % 4) != 0:
					continue
				var origin := _cell_to_screen(Vector2i(cx, cy))
				var dx := float(hs % 19) / 19.0
				var dy := float((hs / 19) % 17) / 17.0
				var p := origin + Vector2(dx * TILE_SIZE, dy * TILE_SIZE)
				var bright: bool = (hs % 13) == 0
				if bright:
					draw_circle(p, 1.0, Color(0.55, 0.65, 0.30, 0.45))
				else:
					draw_circle(p, 1.0, Color(0.10, 0.18, 0.08, 0.55))


func _draw_decorative_foliage() -> void:
	var occupied := {}
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		for dx in def.footprint.x:
			for dy in def.footprint.y:
				occupied[inst.position + Vector2i(dx, dy)] = true

	for cx in BUILDABLE_TILES.x:
		for cy in BUILDABLE_TILES.y:
			if occupied.has(Vector2i(cx, cy)):
				continue
			var h := _hash2(cx + 31, cy + 17)
			var on_border := cx < 2 or cy < 2 \
				or cx >= BUILDABLE_TILES.x - 2 or cy >= BUILDABLE_TILES.y - 2
			var threshold: int = 2 if on_border else 48
			if (h % threshold) != 0:
				continue
			if Vector2i(cx, cy) == GATE_TILE:
				continue
			if RegionRegistry.region_at_cell(Vector2i(cx, cy)) != null:
				continue
			var origin := _cell_to_screen(Vector2i(cx, cy))
			var dx := float((h / 7) % 19) / 19.0
			var dy := float((h / 13) % 17) / 17.0
			var center := origin + Vector2(
				(0.15 + 0.7 * dx) * TILE_SIZE,
				(0.15 + 0.7 * dy) * TILE_SIZE)
			_draw_foliage(center, h)

	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	var canvas := Rect2(Vector2.ZERO, size)
	var step: int = 24
	for px in range(0, int(canvas.size.x), step):
		for py in range(0, int(canvas.size.y), step):
			var anchor := Vector2(px, py)
			if build_rect.grow(8).has_point(anchor):
				continue
			var h := _hash2(px, py)
			if (h % 3) != 0:
				continue
			var jitter := Vector2(
				float(h % 13) - 6.0,
				float((h / 17) % 13) - 6.0)
			_draw_foliage(anchor + Vector2(step * 0.5, step * 0.5) + jitter, h)


func _draw_foliage(center: Vector2, h: int) -> void:
	var variant: int = h % 5
	match variant:
		0, 1, 2:
			var r: float = 4.0 + float((h / 5) % 4)
			draw_circle(center + Vector2(0, r * 0.4),
				r * 1.05, Color(0, 0, 0, 0.30))
			draw_circle(center, r, Color("#3c5a2a"))
			draw_circle(center + Vector2(-r * 0.3, -r * 0.3),
				r * 0.55, Color("#5a7b3a"))
		3:
			var r2: float = 4.5 + float((h / 11) % 3)
			draw_rect(Rect2(center + Vector2(-1, 0), Vector2(2, r2 * 1.8)),
				Color("#3a2a1a"), true)
			draw_circle(center + Vector2(0, r2 * 0.4),
				r2 * 1.1, Color(0, 0, 0, 0.30))
			draw_circle(center, r2 * 1.1, Color("#2f4c22"))
			draw_circle(center + Vector2(-r2 * 0.3, -r2 * 0.5),
				r2 * 0.6, Color("#4d6a30"))
		_:
			var c: Color = Color("#4a6a30")
			draw_circle(center, 2.5, c)
			draw_circle(center + Vector2(3.5, 1.5), 2.0, c.darkened(0.15))
			draw_circle(center + Vector2(-3.0, 1.0), 1.8, c.darkened(0.20))


func _draw_grid() -> void:
	var build_rect := Rect2(GRID_ORIGIN, Vector2(BUILDABLE_TILES) * TILE_SIZE)
	var major := Color(1, 1, 1, 0.045)
	for c in range(0, BUILDABLE_TILES.x + 1, 5):
		var x := GRID_ORIGIN.x + c * TILE_SIZE
		draw_line(Vector2(x, GRID_ORIGIN.y),
			Vector2(x, GRID_ORIGIN.y + BUILDABLE_TILES.y * TILE_SIZE), major, 1.0)
	for r in range(0, BUILDABLE_TILES.y + 1, 5):
		var y := GRID_ORIGIN.y + r * TILE_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, y),
			Vector2(GRID_ORIGIN.x + BUILDABLE_TILES.x * TILE_SIZE, y), major, 1.0)
	draw_rect(build_rect, Color("#6a5132").darkened(0.1), false, 2.0)


func _draw_vignette() -> void:
	var w := size.x
	var h := size.y
	var corner: float = minf(w, h) * 0.40
	for i in 5:
		var t: float = float(i) / 5.0
		var alpha: float = (1.0 - t) * 0.05
		var inset: float = t * corner
		draw_polygon(
			PackedVector2Array([
				Vector2(0, 0),
				Vector2(corner - inset, 0),
				Vector2(0, corner - inset)]),
			PackedColorArray([Color(0, 0, 0, alpha), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(
			PackedVector2Array([
				Vector2(w, 0),
				Vector2(w - (corner - inset), 0),
				Vector2(w, corner - inset)]),
			PackedColorArray([Color(0, 0, 0, alpha), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(
			PackedVector2Array([
				Vector2(0, h),
				Vector2(corner - inset, h),
				Vector2(0, h - (corner - inset))]),
			PackedColorArray([Color(0, 0, 0, alpha), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(
			PackedVector2Array([
				Vector2(w, h),
				Vector2(w - (corner - inset), h),
				Vector2(w, h - (corner - inset))]),
			PackedColorArray([Color(0, 0, 0, alpha), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))


# ---------------------------------------------------------------------------
# Helpers — duplicated from MapView so this Control is self-contained.
# ---------------------------------------------------------------------------

func _cell_to_screen(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * TILE_SIZE


func _hash2(a: int, b: int) -> int:
	return abs((a * 374761393 + b * 668265263) ^ 0x55555555) & 0x7FFFFFFF
