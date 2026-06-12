extends Control
class_name IsoBackground
# Static world layers for the isometric view: backdrop, lawn, exhibit floors,
# terrain fringes, path pavers, and the ground scatter. Mirrors MapBackground
# (the top-down view's static layer): these only change when the built world
# changes or the camera moves, so they redraw on those events instead of every
# frame. Before this split the iso view pushed ~600 textured polygons through
# draw() at 60fps — a direct violation of the engine's web-perf discipline
# (engine/CLAUDE.md §7) and the prime suspect feeding the WebGL object-handle
# exhaustion that bricked long web sessions (playtest 2026-06-09 blocker:
# RangeError in _glGenVertexArrays/Buffers after ~10 min).
#
# IsoPreview owns the camera: it pushes `view_xf` + `origin` here and calls
# queue_redraw() when the view transform changes. World-change redraws are
# wired locally in _ready.

# Projection constants — must match IsoPreview's (the parent asserts at setup).
const TW := 64
const TH := 32
const GROUND_W := 28
const GROUND_H := 18
const GROUND_TEX_SCALE := 96.0

# Set by IsoPreview before first draw.
var view_xf := Transform2D()
var origin := Vector2(660, 70)
var ground_noise: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Redraw only when the built world changes (region painted, path laid,
	# entity sold...). Camera changes are pushed by the parent.
	for sig in [EventBus.entity_placed, EventBus.entity_removed,
			EventBus.region_created, EventBus.region_destroyed, EventBus.region_changed]:
		sig.connect(func(_arg = null): queue_redraw())


func _draw() -> void:
	# Deep park green backdrop (screen space), then the world under the
	# camera transform.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2c4420"), true)
	draw_set_transform_matrix(view_xf)
	_draw_ground()
	_draw_region_fills()
	_draw_paths()
	_draw_ground_scatter()
	draw_set_transform_matrix(Transform2D())


# --- Projection helpers (model space; the view transform maps to screen) ----

func _project(gx: float, gy: float) -> Vector2:
	return origin + Vector2((gx - gy) * TW * 0.5, (gx + gy) * TH * 0.5)


func _tile_center(gx: float, gy: float) -> Vector2:
	return _project(gx, gy) + Vector2(0, TH * 0.5)


func _hash2(a: int, b: int) -> int:
	return abs((a * 374761393 + b * 668265263) ^ 0x55555555) & 0x7FFFFFFF


# Fill cell (gx,gy)'s diamond with a solid colour, world-locked noise grain.
# Inflated a hair so antialiased neighbours meet with no hairline seam (see
# the original note in iso_preview.gd about why ground is procedural).
func _fill_diamond(gx: float, gy: float, fill: Color) -> void:
	var t := _project(gx, gy)
	var hw := TW * 0.5 + 0.75
	var hh := TH * 0.5 + 0.5
	var c := t + Vector2(0, TH * 0.5)
	var pts := PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
	if ground_noise == null:
		draw_colored_polygon(pts, fill)
		return
	var uvs := PackedVector2Array([
		pts[0] / GROUND_TEX_SCALE, pts[1] / GROUND_TEX_SCALE,
		pts[2] / GROUND_TEX_SCALE, pts[3] / GROUND_TEX_SCALE])
	draw_polygon(pts, PackedColorArray([fill, fill, fill, fill]), uvs, ground_noise)


# --- Lawn ---------------------------------------------------------------

func _grass_color(gx: int, gy: int) -> Color:
	var h := _hash2(gx * 3 + 7, gy * 5 + 11)
	var base := Color("#609f36")
	var v := float(h % 7) / 7.0
	var col := base.lerp(Color("#68a93b"), v)
	if (h / 7) % 4 == 0:
		col = col.darkened(0.02)
	return col


func _draw_ground() -> void:
	for gy in range(GROUND_H):
		for gx in range(GROUND_W):
			_fill_diamond(gx, gy, _grass_color(gx, gy))


# --- Exhibit floors + fringes --------------------------------------------

func _zone_tile_floor_color(def: EntityDef, gx: int, gy: int) -> Color:
	var h := _hash2(gx * 3 + 7, gy * 5 + 11)
	var base: Color
	var tags := def.zone_tags
	if &"water" in tags:
		base = Color("#46a0d8")        # bright pool blue
	elif &"rocks" in tags:
		base = Color("#b3905c")        # sunlit rocky ground
	elif &"tall_cage" in tags:
		base = Color("#c2a468")        # aviary sand
	elif &"grass" in tags:
		base = Color("#74a943")        # exhibit turf, a shade warmer than lawn
	else:
		base = Color("#d0ad62")        # savannah sand — the ZT1 exhibit floor
	var v := float(h % 7) / 7.0
	return base.lerp(base.lightened(0.10), v).darkened(0.04 * float((h / 7) % 3))


func _draw_region_fills() -> void:
	var painted := {}
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null or def.zone_kind == &"":
			continue
		var c: Vector2i = inst.position
		_fill_diamond(c.x, c.y, _zone_tile_floor_color(def, c.x, c.y))
		painted[c] = true
	# Defensive: any region cells without a painted zone tile (e.g., loaded
	# from an older save) still get a sensible fill.
	for region: Region in RegionRegistry.all_regions():
		for c in region.cells:
			if painted.has(c):
				continue
			_fill_diamond(c.x, c.y, _region_fallback_color(region, c.x, c.y))
	_draw_region_fringe()


func _region_fallback_color(region: Region, gx: int, gy: int) -> Color:
	var h := _hash2(gx * 3 + 7, gy * 5 + 11)
	var base: Color
	var tags := region.provided_zone_tags
	if &"water" in tags: base = Color("#46a0d8")
	elif &"rocks" in tags: base = Color("#b3905c")
	elif &"tall_cage" in tags: base = Color("#c2a468")
	elif &"grass" in tags: base = Color("#74a943")
	else: base = Color("#d0ad62")
	var v := float(h % 7) / 7.0
	return base.lerp(base.lightened(0.10), v).darkened(0.04 * float((h / 7) % 3))


# Feathered gradient band where an exhibit floor meets the parkland — foam
# shoreline for water, grassy blend elsewhere.
func _draw_region_fringe() -> void:
	for region: Region in RegionRegistry.all_regions():
		var cellset := {}
		for c in region.cells:
			cellset[c] = true
		var edge: Color = _region_fringe_color(region)
		var inner := Color(edge.r, edge.g, edge.b, 0.0)
		for c in region.cells:
			var t := _project(c.x, c.y)
			var top := t
			var right := t + Vector2(TW * 0.5, TH * 0.5)
			var bottom := t + Vector2(0, TH)
			var left := t + Vector2(-TW * 0.5, TH * 0.5)
			var ctr := t + Vector2(0, TH * 0.5)
			for spec in [[Vector2i(-1, 0), top, left], [Vector2i(0, -1), top, right],
					[Vector2i(1, 0), right, bottom], [Vector2i(0, 1), left, bottom]]:
				if cellset.has(c + spec[0]):
					continue
				var a: Vector2 = spec[1]
				var b: Vector2 = spec[2]
				var a2: Vector2 = a.lerp(ctr, 0.30)
				var b2: Vector2 = b.lerp(ctr, 0.30)
				draw_polygon(PackedVector2Array([a, b, b2, a2]),
					PackedColorArray([edge, edge, inner, inner]))


func _region_fringe_color(region: Region) -> Color:
	if &"water" in region.provided_zone_tags:
		return Color(0.85, 0.93, 0.97, 0.45)   # pale foam shoreline
	var g := Color("#5a9c33").lerp(Color("#6cb03d"), 0.5)   # grassy blend
	g.a = 0.5
	return g


# --- Path pavers ----------------------------------------------------------

func _draw_paths() -> void:
	var path_cells := {}
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def != null and def.walkable:
			path_cells[inst.position] = true
	for c in path_cells.keys():
		_draw_path_cell(c, path_cells)


# A path cell as light stone pavers: warm-gray fill, grout joints continuous
# across adjacent cells, and a curb wherever the path meets grass.
func _draw_path_cell(cell: Vector2i, path_cells: Dictionary) -> void:
	var ph := _hash2(cell.x * 3 + 7, cell.y * 5 + 11)
	var pcol := Color("#cfc6ae").lerp(Color("#ded6c0"), float(ph % 5) / 5.0)
	_fill_diamond(cell.x, cell.y, pcol.darkened(0.03 * float((ph / 5) % 3)))
	var t := _project(cell.x, cell.y)
	var top := t
	var right := t + Vector2(TW * 0.5, TH * 0.5)
	var bottom := t + Vector2(0, TH)
	var left := t + Vector2(-TW * 0.5, TH * 0.5)
	var grout := Color(0, 0, 0, 0.09)
	draw_line(top.lerp(left, 0.5), right.lerp(bottom, 0.5), grout, 1.0)
	draw_line(top.lerp(right, 0.5), left.lerp(bottom, 0.5), grout, 1.0)
	var curb := Color("#9a9078")
	for spec in [[Vector2i(-1, 0), top, left], [Vector2i(0, -1), top, right],
			[Vector2i(1, 0), right, bottom], [Vector2i(0, 1), left, bottom]]:
		if path_cells.has(cell + spec[0]):
			continue
		draw_line(spec[1], spec[2], curb, 1.5)


# --- Ground scatter (tufts) ------------------------------------------------

func _draw_ground_scatter() -> void:
	var blocked := {}
	for region: Region in RegionRegistry.all_regions():
		for c in region.cells:
			blocked[c] = true
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def != null and def.walkable:
			blocked[inst.position] = true
	for gy in range(GROUND_H):
		for gx in range(GROUND_W):
			if blocked.has(Vector2i(gx, gy)):
				continue
			var h := _hash2(gx + 31, gy + 17)
			if (h % 4) != 0:
				continue
			var c := _tile_center(gx, gy)
			var off := Vector2(
				float((h / 7) % 16) - 8.0, float((h / 13) % 8) - 4.0)
			_draw_tuft(c + off, h)


func _draw_tuft(p: Vector2, h: int) -> void:
	if (h % 3) == 0:
		var r := 3.0 + float(h % 2)
		draw_circle(p + Vector2(0, r * 0.4), r * 1.05, Color(0, 0, 0, 0.12))
		draw_circle(p, r, Color("#4d862a82"))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color("#7fbf4daa"))
	else:
		var col := Color("#74ad4288") if (h % 2) == 0 else Color("#84bd4c88")
		for i in 3:
			draw_line(p + Vector2(float(i - 1) * 1.6, 1.0),
				p + Vector2(float(i - 1) * 1.6, -3.0 - float(h % 2)), col, 1.0)
