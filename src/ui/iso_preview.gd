extends Control
class_name IsoPreview
# EXPERIMENTAL isometric renderer — a prototype to validate the isometric
# direction. OFF by default; enabled with the TYCOON_ISO env var so the
# shipping build stays top-down.
#
# The point this proves: the simulation is projection-agnostic. This reads the
# exact same EntityRegistry / RegionRegistry / AgentPool the top-down view
# does and just draws them on a 2:1 isometric grid (diamond tiles, fences with
# height, depth-sorted objects). The current top-down sprites are reused as
# flat "billboards" — placeholders until real isometric art exists (see
# design/pixel_lab_isometric_spec.md).

const TW := 64           # iso tile width  (2 : 1)
const TH := 32           # iso tile height
const FENCE_H := 16
const GROUND_W := 28     # cells of ground to draw
const GROUND_H := 18

var origin := Vector2(660, 70)
var _sprites := {}       # name -> Texture2D | null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_d: float) -> void:
	queue_redraw()


# Top corner of cell (gx,gy)'s diamond.
func _project(gx: float, gy: float) -> Vector2:
	return origin + Vector2((gx - gy) * TW * 0.5, (gx + gy) * TH * 0.5)


func _tile_center(gx: float, gy: float) -> Vector2:
	return _project(gx, gy) + Vector2(0, TH * 0.5)


func _draw() -> void:
	# Backdrop.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101a14"), true)
	_draw_ground()
	_draw_region_fills()
	_draw_sorted_objects()


func _draw_diamond(gx: int, gy: int, fill: Color, edge: Color) -> void:
	var t := _project(gx, gy)
	var pts := PackedVector2Array([
		t, t + Vector2(TW * 0.5, TH * 0.5), t + Vector2(0, TH), t + Vector2(-TW * 0.5, TH * 0.5)])
	draw_colored_polygon(pts, fill)
	if edge.a > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), edge, 1.0)


# Draw a 64×32 isometric ground tile texture at cell (gx,gy). Falls back to a
# flat diamond if the texture is missing.
func _draw_tile_tex(gx: int, gy: int, tex_name: String) -> void:
	var tex := _iso_tex(tex_name)
	if tex == null:
		_draw_diamond(gx, gy, Color("#3c5e36"), Color(0, 0, 0, 0.07))
		return
	draw_texture_rect(tex, Rect2(_project(gx, gy) - Vector2(TW * 0.5, 0),
		Vector2(TW, TH)), false)


func _iso_tex(name: String) -> Texture2D:
	return _sprite(name)


func _draw_ground() -> void:
	for gx in GROUND_W:
		for gy in GROUND_H:
			_draw_tile_tex(gx, gy, "iso_grass")


func _region_tint(region: Region) -> Color:
	if &"water" in region.provided_zone_tags:
		return Color("#4f93c4")
	if &"tall_cage" in region.provided_zone_tags:
		return Color("#6fc2a0")
	if &"rocks" in region.provided_zone_tags:
		return Color("#9c7b4f")
	if &"grass" in region.provided_zone_tags:
		return Color("#6fa244")
	return Color("#8a8a8a")


func _region_tile(region: Region) -> String:
	if &"water" in region.provided_zone_tags:
		return "iso_water"
	if &"rocks" in region.provided_zone_tags:
		return "iso_rock"
	if &"tall_cage" in region.provided_zone_tags:
		return "iso_dirt"
	return "iso_dirt"   # enclosure floor reads distinct from parkland grass


func _draw_region_fills() -> void:
	for region: Region in RegionRegistry.all_regions():
		var tile := _region_tile(region)
		for c in region.cells:
			_draw_tile_tex(c.x, c.y, tile)


# Build one depth-sorted list of everything that has height — perimeter fence
# segments, placed entities, animals, and guests — and paint back-to-front so
# nearer things overlap farther ones.
func _draw_sorted_objects() -> void:
	var draws: Array = []

	# Fence segments per region-perimeter edge.
	for region: Region in RegionRegistry.all_regions():
		var cellset := {}
		for c in region.cells:
			cellset[c] = true
		for c in region.cells:
			for spec in [[Vector2i(-1, 0), "tl"], [Vector2i(0, -1), "tr"],
					[Vector2i(1, 0), "br"], [Vector2i(0, 1), "bl"]]:
				if not cellset.has(c + spec[0]):
					draws.append({"d": float(c.x + c.y) + 0.1, "fence": c, "side": spec[1]})

	# Placed entities (buildings / amenities; paths drawn as ground tint).
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		if def.walkable:
			_draw_tile_tex(inst.position.x, inst.position.y, "iso_path")
			continue
		if def.zone_kind != &"":
			continue   # zone tiles are GROUND (drawn as region-fill diamonds), not billboards
		var fp := def.footprint
		draws.append({
			"d": float(inst.position.x + inst.position.y) + float(fp.x + fp.y) * 0.5,
			"sprite": String(def.sprite_key), "fp": fp, "cell": inst.position, "label": def.display_name})

	# Animals inside exhibits.
	for region: Region in RegionRegistry.all_regions():
		for i in region.placements.size():
			var p: Placement = region.placements[i]
			var pdef: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if pdef == null:
				continue
			var anchor: Vector2i = p.state.get("primary_cell",
				region.cells[i % region.cells.size()] if not region.cells.is_empty() else Vector2i.ZERO)
			draws.append({"d": float(anchor.x + anchor.y) + 0.5,
				"sprite": String(pdef.sprite_key), "fp": Vector2i.ONE, "cell": anchor,
				"label": pdef.display_name, "small": pdef.appeal_contribution.is_empty()})

	# Guests.
	for aid in AgentPool.get_agents_by_type(&"visitor"):
		var ag: Agent = AgentPool.get_agent(aid)
		if ag != null and ag.alive:
			draws.append({"d": ag.position.x + ag.position.y + 0.5, "guest": ag})
	for at in [&"child", &"family", &"enthusiast"]:
		for aid in AgentPool.get_agents_by_type(at):
			var ag: Agent = AgentPool.get_agent(aid)
			if ag != null and ag.alive:
				draws.append({"d": ag.position.x + ag.position.y + 0.5, "guest": ag})

	draws.sort_custom(func(a, b): return a["d"] < b["d"])
	for dr in draws:
		if dr.has("fence"):
			_draw_fence_edge(dr["fence"], dr["side"])
		elif dr.has("guest"):
			_draw_guest(dr["guest"])
		else:
			_draw_billboard(dr)


func _draw_fence_edge(cell: Vector2i, side: String) -> void:
	var t := _project(cell.x, cell.y)
	var top := t
	var right := t + Vector2(TW * 0.5, TH * 0.5)
	var bottom := t + Vector2(0, TH)
	var left := t + Vector2(-TW * 0.5, TH * 0.5)
	var a := top
	var b := left
	match side:
		"tl": a = top;   b = left
		"tr": a = top;   b = right
		"br": a = right; b = bottom
		"bl": a = left;  b = bottom
	var up := Vector2(0, -FENCE_H)
	var post := Color("#3f372d")
	var rail := Color("#7a6c58")
	# Posts with a touch of shadow.
	draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.25), 2.0)
	draw_line(a, a + up, post, 2.5)
	draw_line(b, b + up, post, 2.5)
	draw_line(a + up, b + up, rail, 2.0)
	draw_line(a + up * 0.5, b + up * 0.5, rail.darkened(0.1), 1.5)


func _draw_billboard(dr: Dictionary) -> void:
	var fp: Vector2i = dr["fp"]
	var cell: Vector2i = dr["cell"]
	# Anchor at the footprint's centre tile.
	var cx := cell.x + float(fp.x) * 0.5 - 0.5
	var cy := cell.y + float(fp.y) * 0.5 - 0.5
	var base := _tile_center(cx, cy)
	var w: float = maxf(fp.x, fp.y) * TW * (0.45 if dr.get("small", false) else 0.78)
	# Ground shadow (an ellipse).
	draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, w * 0.42, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sprite := _sprite(dr["sprite"])
	var rect := Rect2(base - Vector2(w * 0.5, w * 0.92), Vector2(w, w))
	if sprite != null:
		draw_texture_rect(sprite, rect, false)
	else:
		var col := Color("#9a8f7d")
		draw_rect(rect, col, true)
		draw_rect(rect, Color(0, 0, 0, 0.3), false, 1.0)


func _draw_guest(ag: Agent) -> void:
	var base := _tile_center(ag.position.x, ag.position.y)
	draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var palette := {
		&"child": Color("#f4a261"), &"family": Color("#83c779"),
		&"enthusiast": Color("#c9a4ff")}
	var col: Color = palette.get(ag.agent_type_id, Color("#e6ddc8"))
	# A little capsule body.
	draw_circle(base + Vector2(0, -10), 5.0, col)
	draw_rect(Rect2(base + Vector2(-4, -10), Vector2(8, 10)), col, true)
	draw_circle(base + Vector2(0, -16), 3.5, Color("#e8c9a0"))


func _sprite(name: String) -> Texture2D:
	if _sprites.has(name):
		return _sprites[name]
	var path := "res://assets/sprites/%s.png" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprites[name] = tex
	return tex


func _hash2(a: int, b: int) -> int:
	return abs((a * 374761393 + b * 668265263) ^ 0x55555555) & 0x7FFFFFFF
