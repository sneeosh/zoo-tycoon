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
	# Buying/selling land changes the lawn footprint.
	ZooBootstrap.zoo_type_changed.connect(func(_id): queue_redraw())


func _draw() -> void:
	# Horizon-gradient backdrop (screen space), then the world under the
	# camera transform. The park sits in a clearing: a forest-floor apron
	# fades out from the lawn so the playable diamond doesn't float on void.
	_draw_backdrop()
	draw_set_transform_matrix(view_xf)
	_draw_apron()
	_draw_ground()
	_draw_region_fills()
	_draw_paths()
	_draw_ground_scatter()
	draw_set_transform_matrix(Transform2D())


# Sky-to-understory gradient: darkest at the top of the screen, easing toward
# the apron's outer green at the bottom, so the world reads as receding forest
# instead of a flat backdrop color.
func _draw_backdrop() -> void:
	var top := Color("#16240f")
	var bottom := Color("#243a1b")
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


# Forest clearing around the playable ground: four gradient quads from the
# lawn's edge color out to the backdrop, textured with the same ground grain.
# Four draws total — deliberately not per-cell diamonds, to keep the static
# layer cheap while the camera pans (engine/CLAUDE.md §7).
const APRON_DEPTH := 7.0

func _draw_apron() -> void:
	var e := APRON_DEPTH
	var g := Vector2(ZooBootstrap.plot_size())   # apron rings whatever plot we own
	var inner: Array[Vector2] = [_project(0, 0), _project(g.x, 0),
		_project(g.x, g.y), _project(0, g.y)]
	var outer: Array[Vector2] = [_project(-e, -e), _project(g.x + e, -e),
		_project(g.x + e, g.y + e), _project(-e, g.y + e)]
	var near := Color("#3b5e26")    # forest floor right at the clearing's edge
	var far := Color("#243a1b")     # melts into the backdrop
	for i in 4:
		var j := (i + 1) % 4
		var pts := PackedVector2Array([inner[i], inner[j], outer[j], outer[i]])
		var cols := PackedColorArray([near, near, far, far])
		if ground_noise != null:
			var uvs := PackedVector2Array([
				pts[0] / GROUND_TEX_SCALE, pts[1] / GROUND_TEX_SCALE,
				pts[2] / GROUND_TEX_SCALE, pts[3] / GROUND_TEX_SCALE])
			draw_polygon(pts, cols, uvs, ground_noise)
		else:
			draw_polygon(pts, cols)
	# A soft shade band just inside the apron so lawn→forest reads as a real
	# boundary (canopy shade), not a color seam.
	for i in 4:
		var j := (i + 1) % 4
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[j]
		var a2 := a + (outer[i] - a) * 0.12
		var b2 := b + (outer[j] - b) * 0.12
		draw_polygon(PackedVector2Array([a, b, b2, a2]),
			PackedColorArray([Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18),
				Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))


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
	# Low-frequency meadow patches: broad sunny and deep drifts across the
	# lawn so a big park reads as parkland, not one flat fill.
	var n := _meadow_noise(float(gx) / 5.5, float(gy) / 5.5)
	if n > 0.5:
		col = col.lerp(Color("#74b440"), (n - 0.5) * 0.9)
	else:
		col = col.lerp(Color("#54932f"), (0.5 - n) * 0.9)
	# Faint mowing bands along the iso rows — the groundskeeper was here.
	if ((gx + gy) >> 1) & 1:
		col = col.lightened(0.025)
	return col


# Smooth 2D value noise over an unbounded lattice (for meadow patches; doesn't
# need to tile — the ground-noise texture handles fine grain).
func _meadow_noise(fx: float, fy: float) -> float:
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var v00 := float(_hash2(x0 + 211, y0 + 89) % 1000) / 1000.0
	var v10 := float(_hash2(x0 + 212, y0 + 89) % 1000) / 1000.0
	var v01 := float(_hash2(x0 + 211, y0 + 90) % 1000) / 1000.0
	var v11 := float(_hash2(x0 + 212, y0 + 90) % 1000) / 1000.0
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)


func _draw_ground() -> void:
	var ground := ZooBootstrap.plot_size()
	for gy in range(ground.y):
		for gx in range(ground.x):
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
	var water_cells: Array = []
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null or def.zone_kind == &"":
			continue
		var c: Vector2i = inst.position
		_fill_diamond(c.x, c.y, _zone_tile_floor_color(def, c.x, c.y))
		painted[c] = true
		if &"water" in def.zone_tags:
			water_cells.append(c)
	# Defensive: any region cells without a painted zone tile (e.g., loaded
	# from an older save) still get a sensible fill.
	for region: Region in RegionRegistry.all_regions():
		for c in region.cells:
			if painted.has(c):
				continue
			_fill_diamond(c.x, c.y, _region_fallback_color(region, c.x, c.y))
			if &"water" in region.provided_zone_tags:
				water_cells.append(c)
	for c in water_cells:
		_draw_water_depth(c)
	_draw_region_fringe()


# Concentric darker diamonds toward each pool cell's centre, so water reads
# as having depth instead of sitting on the lawn like a flat sticker. The
# per-frame shimmer in IsoPreview animates on top of this.
func _draw_water_depth(cell: Vector2i) -> void:
	var c := _tile_center(cell.x, cell.y)
	var deep := Color(0.10, 0.32, 0.52)
	for spec in [[0.62, 0.10], [0.34, 0.14]]:
		var hw: float = TW * 0.5 * spec[0]
		var hh: float = TH * 0.5 * spec[0]
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -hh), c + Vector2(hw, 0),
			c + Vector2(0, hh), c + Vector2(-hw, 0)]),
			Color(deep.r, deep.g, deep.b, spec[1]))


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
	var ground := ZooBootstrap.plot_size()
	for gy in range(ground.y):
		for gx in range(ground.x):
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
