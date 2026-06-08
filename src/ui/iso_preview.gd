extends BaseMapView
class_name IsoPreview
# Isometric view — a real, interactive view (behind the TYCOON_ISO env var
# while it reaches parity with the top-down MapView). The shipping default is
# still top-down.
#
# The point this proves: the simulation is projection-agnostic. This reads the
# exact same EntityRegistry / RegionRegistry / AgentPool the top-down view
# does and draws them on a 2:1 isometric grid (diamond tiles, fences with
# height, depth-sorted objects), and now handles input through the same
# BaseMapView contract — inverse projection turns clicks into cells, so
# build/place/remove and the build preview work here too. The current top-down
# sprites are reused as upright "billboards" until real iso art exists (see
# design/pixel_lab_isometric_spec.md).

const TW := 64           # iso tile width  (2 : 1)
const TH := 32           # iso tile height
const FENCE_H := 16
const GROUND_W := 28     # cells of ground to draw
const GROUND_H := 18

var origin := Vector2(660, 70)
var _sprites := {}       # name -> Texture2D | null
var _sprite_meta := {}   # name -> {foot, cx, wfrac} anchoring metadata

# Hover/interaction state (mirrors MapView). _hover_cell is the grid cell the
# cursor is over, via inverse projection; _hovering gates the preview.
var _hover_cell: Vector2i = Vector2i.ZERO
var _hover_screen: Vector2 = Vector2.ZERO
var _hovering: bool = false
var _card_box: StyleBoxFlat
const VISITOR_HIT_RADIUS_PX := 16.0

# Camera. Everything is drawn in unscaled "model space" (origin/TW/TH); a single
# view transform maps model→screen with fit-to-view + wheel zoom + drag pan, so
# the projection math below never changes. _user_zoom multiplies the fit scale;
# _pan is a screen-space offset added on top.
const MIN_USER_ZOOM := 0.4
const MAX_USER_ZOOM := 3.0
const FIT_MARGIN := 0.9
var _view_xf := Transform2D()
var _fit_zoom := 1.0
var _model_center := Vector2.ZERO
var _user_zoom := 1.0
var _pan := Vector2.ZERO
var _last_size := Vector2.ZERO
var _panning := false

# Parkland scenery billboards (trees / rocks / bushes), depth-sorted with
# everything else so guests pass behind a tree. Deterministic per cell, cached
# and rebuilt only when the built world changes.
var _scenery: Array = []        # [{cell, sprite, wmul, jitter}]
var _scenery_dirty := true
const SCENERY_WEIGHTS := {
	"tree_oak": 5, "tree_birch": 4, "tree_pine": 3, "tree_palm": 1,
	"bush_large": 3, "bush_small": 3, "bush_flowering": 2, "boulder": 2,
	"tree_stump": 1, "flowers_red": 2, "flowers_yellow": 2}

# Floating "+$N" toasts (ZooBootstrap.money_floated), same model as MapView.
const FLOAT_LIFETIME := 1.4
const FLOAT_RISE := 1.0       # model-space rise (scales with zoom)
const FLOAT_LIMIT := 40
var _money_floats: Array = []


func _ready() -> void:
	# STOP so we receive _gui_input — this is an interactive view now, not a
	# passive overlay.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	resized.connect(_rebuild_view)
	ZooBootstrap.money_floated.connect(_on_money_floated)
	# Parkland scenery (trees/rocks/bushes) is deterministic per cell but must
	# avoid built cells, so rebuild it whenever the world changes.
	for sig in [EventBus.entity_placed, EventBus.entity_removed,
			EventBus.region_created, EventBus.region_destroyed, EventBus.region_changed]:
		sig.connect(_mark_scenery_dirty)
	_card_box = StyleBoxFlat.new()
	_card_box.bg_color = Color("#161e1a")
	_card_box.border_color = Color("#3d4f44")
	_card_box.set_border_width_all(1)
	_card_box.set_corner_radius_all(4)


var _time := 0.0

func _process(d: float) -> void:
	_time += d
	_tick_money_floats()
	queue_redraw()


func _on_money_floated(amount: int, world_pos: Vector2) -> void:
	if _money_floats.size() >= FLOAT_LIMIT:
		_money_floats.pop_front()
	_money_floats.append({"amount": amount, "world_pos": world_pos,
		"born_at": Time.get_ticks_msec() / 1000.0})


func _tick_money_floats() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var i := 0
	while i < _money_floats.size():
		if now - _money_floats[i]["born_at"] >= FLOAT_LIFETIME:
			_money_floats.remove_at(i)
		else:
			i += 1


# Model-space bounding rect of the drawn ground (its four diamond corners).
func _ground_model_rect() -> Rect2:
	var pts := [_project(0, 0), _project(GROUND_W, 0),
		_project(GROUND_W, GROUND_H), _project(0, GROUND_H)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


# Recompute the view transform: fit the ground into the control, then apply the
# user's zoom (about the model centre) and pan.
func _rebuild_view() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var gr := _ground_model_rect()
	_model_center = gr.position + gr.size * 0.5
	_fit_zoom = minf(size.x / gr.size.x, size.y / gr.size.y) * FIT_MARGIN
	var z := _fit_zoom * _user_zoom
	_view_xf = Transform2D(0.0, Vector2(z, z), 0.0, size * 0.5 - _model_center * z + _pan)
	_last_size = size


# Inverse of _project/_tile_center, accounting for the view transform: which
# grid cell does a local screen point fall in? The 2:1 diamond lattice is a
# linear shear of (gx,gy), so invert it and round — rounding the fractional
# cell is exactly "point in diamond". (With an identity view transform this is
# pure model-space math, which is what the unit tests exercise.)
func _screen_to_cell(p: Vector2) -> Vector2i:
	var m := _view_xf.affine_inverse() * p
	var dx := m.x - origin.x
	var dy := m.y - origin.y - TH * 0.5   # _tile_center adds (0, TH/2)
	var u := dx / (TW * 0.5)              # u = gx - gy
	var v := dy / (TH * 0.5)              # v = gx + gy
	return Vector2i(roundi((u + v) * 0.5), roundi((v - u) * 0.5))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _panning:
			_pan += event.relative
			_rebuild_view()
		_hover_screen = event.position
		_hover_cell = _screen_to_cell(event.position)
		_hovering = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			placement_requested.emit(_screen_to_cell(event.position))
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			remove_requested.emit(_screen_to_cell(event.position))


# Zoom about the cursor: keep the model point under `screen_pos` fixed.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var m := _view_xf.affine_inverse() * screen_pos
	_user_zoom = clampf(_user_zoom * factor, MIN_USER_ZOOM, MAX_USER_ZOOM)
	var z := _fit_zoom * _user_zoom
	# Solve pan so screen(m) lands back on the cursor after the zoom change.
	_pan = screen_pos - size * 0.5 - (m - _model_center) * z
	_rebuild_view()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false


func force_hover_at_world(world_pos: Vector2) -> void:
	_hover_cell = Vector2i(roundi(world_pos.x), roundi(world_pos.y))
	_hover_screen = _view_xf * _tile_center(world_pos.x, world_pos.y)
	_hovering = true


# Top corner of cell (gx,gy)'s diamond.
func _project(gx: float, gy: float) -> Vector2:
	return origin + Vector2((gx - gy) * TW * 0.5, (gx + gy) * TH * 0.5)


func _tile_center(gx: float, gy: float) -> Vector2:
	return _project(gx, gy) + Vector2(0, TH * 0.5)


func _draw() -> void:
	if _last_size != size:
		_rebuild_view()
	# Backdrop fills the whole control in screen space.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101a14"), true)
	# The world is drawn in model space under the fit/zoom/pan transform.
	draw_set_transform_matrix(_view_xf)
	_draw_ground()
	_draw_region_fills()
	_draw_water_shimmer()
	_draw_ground_scatter()
	_draw_sorted_objects()
	_draw_money_floats()
	_draw_path_warnings()
	_draw_preview()
	# Back to screen space for the full-screen dusk overlay + hover card.
	draw_set_transform_matrix(Transform2D())
	_draw_day_night()
	_draw_inspector_card()


# Hover inspector — a screen-space info card for the visitor or entity under
# the cursor. Suppressed during build-mode (the preview owns that), mirroring
# MapView. Visitors take priority (smaller, harder to land on).
func _draw_inspector_card() -> void:
	if not _hovering or preview_def_id != &"":
		return
	var lines := _inspect_visitor_at(_hover_screen)
	if lines.is_empty():
		lines = _inspect_entity_at(_hover_cell)
	if lines.is_empty():
		return
	_render_card(lines, _hover_screen)


func _inspect_visitor_at(screen_pos: Vector2) -> Array[String]:
	var hit: Agent = null
	for at in [&"visitor", &"child", &"family", &"enthusiast"]:
		for agent_id in AgentPool.get_agents_by_type(at):
			var ag: Agent = AgentPool.get_agent(agent_id)
			if ag == null or not ag.alive:
				continue
			var body := _view_xf * (_tile_center(ag.position.x, ag.position.y) + Vector2(0, -12.0))
			if body.distance_to(screen_pos) <= VISITOR_HIT_RADIUS_PX:
				hit = ag
				break
		if hit != null:
			break
	if hit == null:
		return [] as Array[String]
	var out: Array[String] = []
	var atype: AgentType = ContentDB.get_agent_type(hit.agent_type_id)
	out.append("%s #%d" % [atype.display_name if atype != null else "Visitor", hit.agent_id])
	out.append("state: %s" % String(hit.behavior_state.get(&"state", &"browsing")))
	out.append("satisfaction: %s %.2f" % [_bar(hit.satisfaction), hit.satisfaction])
	for need_id in hit.need_levels.keys():
		var lvl: float = hit.need_levels[need_id]
		out.append("%s: %s %.2f" % [String(need_id), _bar(lvl), lvl])
	if hit.target_entity_id != 0:
		var inst := EntityRegistry.get_instance(hit.target_entity_id)
		if inst != null and inst.get_def() != null:
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
		out.append("build $%d  ·  maint $%d/day" % [def.build_cost, def.maintenance_cost])
		out.append("visitors heading here: %d" % AgentPool.count_targeting(inst_id))
		if not def.satisfies.is_empty():
			var sats: Array[String] = []
			for s in def.satisfies:
				sats.append(String(s))
			out.append("satisfies: %s" % ", ".join(sats))
		return out
	return [] as Array[String]


func _bar(value: float) -> String:
	var filled := int(round(clampf(value, 0.0, 1.0) * 8.0))
	var s := ""
	for i in 8:
		s += "▰" if i < filled else "▱"
	return s


func _render_card(lines: Array[String], anchor: Vector2) -> void:
	var font := get_theme_default_font()
	var fs := 11
	var line_h := fs + 3
	var max_w := 0.0
	for line in lines:
		max_w = maxf(max_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var card_w := max_w + 20
	var card_h := lines.size() * line_h + 16
	var o := anchor + Vector2(14, 14)
	if o.x + card_w > size.x:
		o.x = maxf(0.0, anchor.x - card_w - 14)
	if o.y + card_h > size.y:
		o.y = maxf(0.0, anchor.y - card_h - 14)
	draw_style_box(_card_box, Rect2(o, Vector2(card_w, card_h)))
	var text_o := o + Vector2(10, 8)
	for i in lines.size():
		var color := Color("#e6e6e6") if i == 0 else Color("#a8c4b0")
		draw_string(font, text_o + Vector2(0, fs + i * line_h), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs + (1 if i == 0 else 0), color)


# Animated glints on water-exhibit cells so pools read as water, not flat blue.
func _draw_water_shimmer() -> void:
	for region: Region in RegionRegistry.all_regions():
		if not (&"water" in region.provided_zone_tags):
			continue
		for c in region.cells:
			var ctr := _tile_center(c.x, c.y)
			var hsh := _hash2(c.x, c.y)
			for k in 2:
				var phase: float = _time * 0.7 + float(hsh ^ (k * 53)) * 0.001
				var yy: float = ctr.y + (float(k) - 0.5) * TH * 0.35 + sin(phase) * 1.5
				var xoff: float = sin(phase * 1.3) * TW * 0.12
				var x0: float = ctr.x - TW * 0.16 + xoff
				draw_line(Vector2(x0, yy), Vector2(x0 + TW * 0.24, yy),
					Color(1, 1, 1, 0.16), 1.5)


# "+$N" toasts rising from where a guest paid. world_pos is in cell coords, so
# project through _tile_center; drawn under the view transform (scales with
# zoom along with everything else).
func _draw_money_floats() -> void:
	if _money_floats.is_empty():
		return
	var font := get_theme_default_font()
	var now := Time.get_ticks_msec() / 1000.0
	for entry in _money_floats:
		var t: float = clampf((now - entry["born_at"]) / FLOAT_LIFETIME, 0.0, 1.0)
		var alpha := 1.0 - t
		var base := _tile_center(entry["world_pos"].x, entry["world_pos"].y)
		var p := Vector2(base.x, base.y - TH - lerpf(0.0, FLOAT_RISE * TH, t))
		var text := "+$%d" % int(entry["amount"])
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var o := p - Vector2(sz.x * 0.5, 0)
		draw_string(font, o + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0, 0, 0, 0.55 * alpha))
		draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.96, 0.83, 0.37, alpha))


# Dusk/night tint — same model as the top-down view: dim toward the edges of
# the open day, darker once the park has closed.
func _draw_day_night() -> void:
	if ZooBootstrap.services == null:
		return
	var f := ZooBootstrap.time_of_day_fraction()
	var open_end: float = ZooBootstrap.services.open_end
	var darkness: float
	if f >= open_end or open_end <= 0.0:
		darkness = 0.45
	else:
		var p := f / open_end
		darkness = 0.30 * (1.0 - sin(p * PI))
	if darkness <= 0.01:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.10, 0.28, darkness), true)
	# Lamps and lit buildings push back the dark (OpenRCT2-style light sources).
	if darkness >= 0.18:
		_draw_night_glows(darkness)


# Warm pools of light at lamp posts, the entrance gate, and building windows
# once it's dark enough. Drawn in screen space (after the dusk overlay) by
# projecting each source through the view transform. Translucent warm circles
# over the darkened ground read as glow without needing an additive material.
func _draw_night_glows(darkness: float) -> void:
	var z := _fit_zoom * _user_zoom
	var lamp := Color("#ffe6ad")
	for sc in _scenery:
		if sc["sprite"] == "lamp_post":
			var c: Vector2i = sc["cell"]
			_glow(_view_xf * (_tile_center(c.x, c.y) + Vector2(0, -10)), 30.0 * z, lamp, darkness)
	_glow(_view_xf * (_tile_center(0, 0) + Vector2(0, -10)), 28.0 * z, lamp, darkness)
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null or def.walkable or def.zone_kind != &"":
			continue
		var cx := inst.position.x + float(def.footprint.x) * 0.5 - 0.5
		var cy := inst.position.y + float(def.footprint.y) * 0.5 - 0.5
		var span: float = maxf(def.footprint.x, def.footprint.y)
		_glow(_view_xf * (_tile_center(cx, cy) + Vector2(0, -8)),
			20.0 * z * (1.0 + 0.4 * (span - 1.0)), Color("#ffce85"), darkness * 0.85)


# A soft pool of light: concentric translucent rings that whiten toward a bright
# core, so warm-over-dark reads as a lamp glow without an additive material.
func _glow(pos: Vector2, radius: float, warm: Color, intensity: float) -> void:
	var core := warm.lerp(Color.WHITE, 0.4)
	for i in 7:
		var t := float(i) / 7.0
		var r := radius * (1.0 - t)
		var col := warm.lerp(core, 1.0 - t)
		draw_circle(pos, r, Color(col.r, col.g, col.b, intensity * 0.16))


# Pulsing ⚠ over any exhibit guests can't path to (set by main from the
# reachability check), floated above the pen so it reads at a glance.
func _draw_path_warnings() -> void:
	if disconnected_regions.is_empty():
		return
	var font := get_theme_default_font()
	var t := Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.55 + 0.45 * sin(t * 3.5)
	for region: Region in RegionRegistry.all_regions():
		if not disconnected_regions.has(region.region_id) or region.cells.is_empty():
			continue
		var sum := Vector2.ZERO
		for c in region.cells:
			sum += Vector2(c)
		var center_cell := sum / float(region.cells.size())
		var screen := _tile_center(center_cell.x, center_cell.y) - Vector2(0, FENCE_H + 14)
		var glyph := "⚠"
		var fs := 22
		var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := screen - Vector2(sz.x * 0.5, sz.y * 0.5)
		draw_string(font, pos + Vector2(1, 1), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5 * pulse))
		draw_string(font, pos, glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.90, 0.43, 0.31, pulse))


# A filled + outlined diamond on cell (gx,gy), used for hover + build feedback.
func _preview_cell(gx: int, gy: int, fill: Color, stroke: Color) -> void:
	var t := _project(gx, gy)
	var pts := PackedVector2Array([
		t, t + Vector2(TW * 0.5, TH * 0.5), t + Vector2(0, TH), t + Vector2(-TW * 0.5, TH * 0.5)])
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), stroke, 2.0)


# Build preview — mirrors MapView: footprint diamonds for entities, a
# whole-region highlight for placeables (green = ok, red = can't). Also a quiet
# hover outline when no build tool is active, so the cursor reads on the grid.
func _draw_preview() -> void:
	if not _hovering:
		return
	if preview_def_id == &"":
		_preview_cell(_hover_cell.x, _hover_cell.y, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.32))
		return
	if ContentDB.placeable_defs.has(preview_def_id):
		_draw_placeable_preview()
		return
	var def: EntityDef = ContentDB.get_entity_def(preview_def_id)
	if def == null:
		return
	var ok := Ledger.get_balance() >= def.build_cost and not _would_collide(_hover_cell, def.footprint)
	var fill: Color = Color(0.51, 0.78, 0.47, 0.35) if ok else Color(0.90, 0.43, 0.31, 0.35)
	var stroke: Color = Color(0.62, 0.88, 0.55, 0.95) if ok else Color(0.95, 0.5, 0.38, 0.95)
	for dx in def.footprint.x:
		for dy in def.footprint.y:
			_preview_cell(_hover_cell.x + dx, _hover_cell.y + dy, fill, stroke)


func _draw_placeable_preview() -> void:
	var region := RegionRegistry.region_at_cell(_hover_cell)
	if region == null:
		_preview_cell(_hover_cell.x, _hover_cell.y, Color(0.90, 0.43, 0.31, 0.30), Color(0.95, 0.5, 0.38, 0.85))
		return
	var check := RegionRegistry.can_add_placement(region.region_id, preview_def_id)
	var ok: bool = check["ok"]
	var def: PlaceableDef = ContentDB.placeable_defs[preview_def_id]
	if Ledger.get_balance() < def.build_cost:
		ok = false
	var fill: Color = Color(0.51, 0.78, 0.47, 0.30) if ok else Color(0.90, 0.43, 0.31, 0.30)
	var stroke: Color = Color(0.62, 0.88, 0.55, 0.85) if ok else Color(0.95, 0.5, 0.38, 0.85)
	for c in region.cells:
		_preview_cell(c.x, c.y, fill, stroke)


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


# Fill cell (gx,gy)'s diamond with a solid colour. The polygon is inflated a
# hair so antialiased neighbours meet with no hairline seam. No edge stroke —
# adjacent solid diamonds share their borders exactly, so the ground reads as
# one continuous surface (no grid). This is why we draw ground procedurally
# instead of tiling the supplied iso PNGs, which bake a dark rim into every
# tile edge and therefore always paint a visible diamond lattice.
func _fill_diamond(gx: float, gy: float, fill: Color) -> void:
	var t := _project(gx, gy)
	var hw := TW * 0.5 + 0.75
	var hh := TH * 0.5 + 0.5
	var c := t + Vector2(0, TH * 0.5)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(hw, 0),
		c + Vector2(0, hh), c + Vector2(-hw, 0)]), fill)


func _draw_diamond(gx: int, gy: int, fill: Color, edge: Color) -> void:
	var t := _project(gx, gy)
	var pts := PackedVector2Array([
		t, t + Vector2(TW * 0.5, TH * 0.5), t + Vector2(0, TH), t + Vector2(-TW * 0.5, TH * 0.5)])
	draw_colored_polygon(pts, fill)
	if edge.a > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), edge, 1.0)


# A grass-toned diamond with subtle per-cell variation so the parkland reads
# as living turf rather than a flat green field — without any tile seams.
func _grass_color(gx: int, gy: int) -> Color:
	var h := _hash2(gx * 3 + 7, gy * 5 + 11)
	var base := Color("#3c5e36")
	var v := float(h % 7) / 7.0
	var col := base.lerp(Color("#4a6e3f"), v * 0.6)
	if (h / 7) % 4 == 0:
		col = col.darkened(0.06)
	return col


func _draw_ground() -> void:
	for gy in range(GROUND_H):
		for gx in range(GROUND_W):
			_fill_diamond(gx, gy, _grass_color(gx, gy))


# Enclosure floors are drawn as solid, varied diamonds (same seamless trick as
# the grass) so a multi-tile pen reads as one continuous surface, not a grid.
func _region_floor_color(region: Region, gx: int, gy: int) -> Color:
	var h := _hash2(gx * 3 + 7, gy * 5 + 11)
	var base: Color
	if &"water" in region.provided_zone_tags:
		base = Color("#3f7fb0")
	elif &"rocks" in region.provided_zone_tags:
		base = Color("#9c7b4f")
	elif &"tall_cage" in region.provided_zone_tags:
		base = Color("#8a6f47")
	else:
		base = Color("#7a5d3a")   # dirt enclosure floor, distinct from grass
	var v := float(h % 7) / 7.0
	return base.lerp(base.lightened(0.12), v).darkened(0.04 * float((h / 7) % 3))


func _draw_region_fills() -> void:
	for region: Region in RegionRegistry.all_regions():
		for c in region.cells:
			_fill_diamond(c.x, c.y, _region_floor_color(region, c.x, c.y))
	_draw_region_fringe()


# Soften the hard diamond boundary where an exhibit floor meets the parkland:
# along every edge that borders a non-region cell, draw a feathered gradient
# band (per-vertex alpha) that fades the boundary into a blend colour — a foam
# shoreline for water, a grassy blend for dirt/rock. (Wesnoth/Factorio terrain
# transitions, done procedurally — see design/research_graphics_tactics.md.)
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
		return Color(0.80, 0.90, 0.95, 0.45)   # pale foam shoreline
	var g := Color("#3f5e38").lerp(Color("#4a6e3f"), 0.5)   # grassy blend
	g.a = 0.5
	return g


# Parkland decoration — tufts and shrubs scattered across grass cells that are
# not inside a region or under a path. Deterministic per cell so it's stable
# frame to frame; drawn after the ground fill, beneath objects.
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
		draw_circle(p + Vector2(0, r * 0.4), r * 1.05, Color(0, 0, 0, 0.18))
		draw_circle(p, r, Color("#35522482"))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color("#5a7b3aaa"))
	else:
		var col := Color("#4f7a3488") if (h % 2) == 0 else Color("#5e8a3c88")
		for i in 3:
			draw_line(p + Vector2(float(i - 1) * 1.6, 1.0),
				p + Vector2(float(i - 1) * 1.6, -3.0 - float(h % 2)), col, 1.0)


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
			var ph := _hash2(inst.position.x * 3 + 7, inst.position.y * 5 + 11)
			var pcol := Color("#c8b083").lerp(Color("#d8c39a"), float(ph % 5) / 5.0)
			_fill_diamond(inst.position.x, inst.position.y, pcol.darkened(0.03 * float((ph / 5) % 3)))
			continue
		if def.zone_kind != &"":
			continue   # zone tiles are GROUND (drawn as region-fill diamonds), not billboards
		var fp := def.footprint
		draws.append({
			"d": float(inst.position.x + inst.position.y) + float(fp.x + fp.y) * 0.5,
			"sprite": String(def.sprite_key), "fp": fp, "cell": inst.position, "label": def.display_name})

	# Animals inside exhibits. Animals amble around their enclosure (a purely
	# presentational wander — the sim still treats them as fixed placements);
	# infrastructure (troughs, donation boxes) stays put.
	for region: Region in RegionRegistry.all_regions():
		if region.cells.is_empty():
			continue
		var bb := _region_bounds(region)
		for i in region.placements.size():
			var p: Placement = region.placements[i]
			var pdef: PlaceableDef = ContentDB.placeable_defs.get(p.placeable_def_id)
			if pdef == null:
				continue
			var home: Vector2i = region.cells[i % region.cells.size()]
			var is_animal := not pdef.appeal_contribution.is_empty()
			if is_animal:
				var seed := _hash2(home.x + i * 97 + 5, home.y + i * 53 + 3)
				var speed: float = 0.8 if (&"bird" in pdef.own_tags) else 0.45
				var pos := _wander_in(region, bb, seed, _time * speed)
				# Heading: sample the wander a hair ahead and pick the facing
				# sprite (true ¾ iso art) when a <species>_4dir/ set exists.
				var ahead := _wander_in(region, bb, seed, _time * speed + 0.12)
				var heading := _tile_center(ahead.x, ahead.y) - _tile_center(pos.x, pos.y)
				var sprite_name := _directional_sprite(String(pdef.sprite_key), heading)
				var bob := sin(_time * speed * 2.3 + float(seed % 17)) * 1.4
				draws.append({"d": pos.x + pos.y + 0.5,
					"sprite": sprite_name, "fp": Vector2i.ONE, "pos": pos,
					"bob": bob, "label": pdef.display_name, "small": false,
					"sick": bool(p.state.get("sick", false))})
			else:
				draws.append({"d": float(home.x + home.y) + 0.4,
					"sprite": String(pdef.sprite_key), "fp": Vector2i.ONE, "cell": home,
					"label": pdef.display_name, "small": true})

	# Entrance gate: the ticket booth at cell (0,0), where guests enter/leave.
	draws.append({"d": 0.4, "sprite": "ticket_booth", "fp": Vector2i.ONE,
		"pos": Vector2(0, 0), "wmul": 1.3, "small": false})

	# Parkland scenery.
	if _scenery_dirty:
		_rebuild_scenery()
	for sc in _scenery:
		var p: Vector2 = Vector2(sc["cell"]) + sc["jitter"]
		draws.append({"d": p.x + p.y + 0.3, "sprite": sc["sprite"], "fp": Vector2i.ONE,
			"pos": p, "wmul": sc["wmul"], "small": false})

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


# Rebuild the deterministic scenery scatter: a dense tree border framing the
# park (the Zoo-Tycoon "park in a forest" look) and sparse interior clumps,
# skipping any cell that's inside an exhibit, under a path/building, or the gate.
func _mark_scenery_dirty(_arg = null) -> void:
	_scenery_dirty = true


func _rebuild_scenery() -> void:
	_scenery_dirty = false
	_scenery.clear()
	var blocked := {Vector2i(0, 0): true}   # entrance gate
	var path_cells: Array = []
	for region: Region in RegionRegistry.all_regions():
		for c in region.cells:
			blocked[c] = true
	for inst_id in EntityRegistry.instances.keys():
		var inst: EntityInstance = EntityRegistry.instances[inst_id]
		var def := inst.get_def()
		if def == null:
			continue
		for dx in def.footprint.x:
			for dy in def.footprint.y:
				blocked[inst.position + Vector2i(dx, dy)] = true
		if def.walkable:
			path_cells.append(inst.position)
	# Lamp posts lining the promenade: beside every few path cells, on a free
	# grass neighbour. Marked blocked so the tree scatter doesn't overlap them.
	for c in path_cells:
		var hp := _hash2(c.x * 5 + 1, c.y * 9 + 2)
		if (hp % 4) != 0:
			continue
		for off in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
			var n: Vector2i = c + off
			if n.x < 0 or n.y < 0 or n.x >= GROUND_W or n.y >= GROUND_H:
				continue
			if blocked.has(n):
				continue
			blocked[n] = true
			_scenery.append({"cell": n, "sprite": "lamp_post", "wmul": 0.7,
				"jitter": Vector2.ZERO})
			break
	var pool: Array = []
	for name in SCENERY_WEIGHTS:
		for _w in range(SCENERY_WEIGHTS[name]):
			pool.append(name)
	for gy in range(GROUND_H):
		for gx in range(GROUND_W):
			if blocked.has(Vector2i(gx, gy)):
				continue
			var border := gx < 2 or gy < 2 or gx >= GROUND_W - 2 or gy >= GROUND_H - 2
			var h := _hash2(gx * 7 + 3, gy * 13 + 5)
			var threshold := 2 if border else 8
			if (h % threshold) != 0:
				continue
			var sprite: String = pool[h % pool.size()]
			var wmul := 1.0
			if sprite.begins_with("tree"):
				wmul = 1.5
			elif sprite.begins_with("flowers"):
				wmul = 0.55
			elif sprite == "boulder" or sprite.begins_with("bush"):
				wmul = 0.85
			var jitter := Vector2(float((h / 7) % 7 - 3) * 0.05, float((h / 11) % 7 - 3) * 0.05)
			_scenery.append({"cell": Vector2i(gx, gy), "sprite": sprite,
				"wmul": wmul, "jitter": jitter})


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
	var post := Color("#4a3f30")
	var post_hi := Color("#6f5c45")
	var rail := Color("#8a7456")
	var rail_hi := Color("#a88e69")
	var rail_lo := Color("#5d4d39")
	# Ground shadow.
	draw_line(a + Vector2(1.5, 2.0), b + Vector2(1.5, 2.0), Color(0, 0, 0, 0.28), 3.0)
	# Two horizontal rails drawn as thick bars (top + middle) so the fence has
	# heft instead of reading as wireframe lines.
	var th := Vector2(0, 3.0)
	for frac: float in [1.0, 0.5]:
		var ra := a + up * frac
		var rb := b + up * frac
		draw_colored_polygon(PackedVector2Array([ra, rb, rb + th, ra + th]), rail)
		draw_line(ra, rb, rail_hi, 1.0)
		draw_line(ra + th, rb + th, rail_lo, 1.0)
	# Chunky end posts (a vertical bar with a lit front edge and a rounded cap).
	for p: Vector2 in [a, b]:
		var pw := Vector2(2.0, 0)
		draw_colored_polygon(PackedVector2Array([p - pw, p + pw, p + pw + up, p - pw + up]), post)
		draw_line(p + up, p, post_hi, 1.5)
		draw_circle(p + up, 2.2, post_hi)


# Bounding box of a region in grid space — centre cell and half-extent, used to
# keep the animal wander inside the enclosure.
func _region_bounds(region: Region) -> Dictionary:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in region.cells:
		mn.x = minf(mn.x, c.x); mn.y = minf(mn.y, c.y)
		mx.x = maxf(mx.x, c.x); mx.y = maxf(mx.y, c.y)
	return {"center": (mn + mx) * 0.5, "half": (mx - mn) * 0.5}


# A smooth, slow, per-animal wander offset in roughly [-1, 1]^2 — summed sines
# at incommensurate frequencies so the path never visibly repeats.
func _wander_offset(seed: int, t: float) -> Vector2:
	var pa := float(seed % 619) * 0.01015
	var pb := float((seed / 3) % 631) * 0.00996
	var fa := 0.7 + float(seed % 5) * 0.06
	var fb := 0.6 + float((seed / 7) % 5) * 0.07
	var ox := 0.66 * sin(t * fa + pa) + 0.34 * sin(t * fa * 1.9 + pa * 2.3)
	var oy := 0.66 * sin(t * fb + pb) + 0.34 * sin(t * fb * 2.1 + pb * 1.7)
	return Vector2(ox, oy)


# Wandered float-grid position, kept inside the enclosure: drift within the
# bounding box, then snap to the nearest real cell if the shape is non-convex.
func _wander_in(region: Region, bb: Dictionary, seed: int, t: float) -> Vector2:
	var off := _wander_offset(seed, t)
	var half: Vector2 = bb["half"]
	var hx := maxf(0.0, half.x - 0.35)
	var hy := maxf(0.0, half.y - 0.35)
	var pos: Vector2 = bb["center"] + Vector2(off.x * hx, off.y * hy)
	if not (Vector2i(roundi(pos.x), roundi(pos.y)) in region.cells):
		var best := pos
		var bestd := INF
		for c in region.cells:
			var dd := Vector2(c).distance_squared_to(pos)
			if dd < bestd:
				bestd = dd; best = Vector2(c)
		pos = best
	return pos


func _draw_billboard(dr: Dictionary) -> void:
	var fp: Vector2i = dr["fp"]
	var base: Vector2
	if dr.has("pos"):
		var pos: Vector2 = dr["pos"]
		base = _tile_center(pos.x, pos.y)
	else:
		var cell: Vector2i = dr["cell"]
		# Anchor at the footprint's centre tile.
		var cx := cell.x + float(fp.x) * 0.5 - 0.5
		var cy := cell.y + float(fp.y) * 0.5 - 0.5
		base = _tile_center(cx, cy)
	var w: float = maxf(fp.x, fp.y) * TW * (0.45 if dr.get("small", false) else 0.78) * dr.get("wmul", 1.0)
	var sprite := _sprite(dr["sprite"])
	# Seat the sprite by its actual opaque pixels rather than a fixed lift, so
	# objects with different internal composition / transparent margins all
	# rest on the tile instead of hovering. `foot` is the fraction down the PNG
	# where opaque content ends; `cx_frac` is its opaque horizontal centre.
	var meta := _sprite_anchor(dr["sprite"])
	var foot: float = meta["foot"]
	var cxf: float = meta["cx"]
	var sink := 2.0   # let the contact point dip just under the tile centre
	# A walking bob lifts the sprite only; the shadow stays on the ground.
	var bob: float = dr.get("bob", 0.0)
	var rect := Rect2(base - Vector2(cxf * w, foot * w - sink - bob), Vector2(w, w))
	# Ground shadow (an ellipse) under the opaque footprint's contact point.
	# Compose the squash with the view transform, then restore to the view
	# (not identity) so following draws stay in model space.
	var shadow_w: float = w * meta["wfrac"]
	draw_set_transform_matrix(_view_xf * Transform2D(Vector2(1, 0), Vector2(0, 0.5), base))
	draw_circle(Vector2.ZERO, shadow_w * 0.42, Color(0, 0, 0, 0.28))
	draw_set_transform_matrix(_view_xf)
	if sprite != null:
		draw_texture_rect(sprite, rect, false)
	else:
		var col := Color("#9a8f7d")
		draw_rect(rect, col, true)
		draw_rect(rect, Color(0, 0, 0, 0.3), false, 1.0)
	# Sick animals (welfare below the illness threshold) get a red medical
	# cross, same legibility cue as the top-down view.
	if dr.get("sick", false):
		var font := get_theme_default_font()
		var badge := Vector2(rect.position.x + rect.size.x - 8, rect.position.y + 2)
		draw_string(font, badge + Vector2(1, 1), "✚", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.5))
		draw_string(font, badge, "✚", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e76f51"))


# Per-sprite anchoring metadata, computed once from the opaque bounding box:
#   foot  — fraction down the PNG where opaque content ends (contact point)
#   cx    — opaque horizontal centre as a fraction of width
#   wfrac — opaque width as a fraction of the canvas (sizes the shadow)
# Falls back to sane defaults when the image can't be inspected.
func _sprite_anchor(name: String) -> Dictionary:
	if _sprite_meta.has(name):
		return _sprite_meta[name]
	var meta := {"foot": 0.92, "cx": 0.5, "wfrac": 0.8}
	var tex := _sprite(name)
	if tex != null:
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			var th := float(img.get_height())
			var tw := float(img.get_width())
			if used.size.y > 0 and th > 0.0:
				meta["foot"] = float(used.position.y + used.size.y) / th
			if used.size.x > 0 and tw > 0.0:
				meta["cx"] = (float(used.position.x) + float(used.size.x) * 0.5) / tw
				meta["wfrac"] = float(used.size.x) / tw
	_sprite_meta[name] = meta
	return meta


# Per-archetype tint + sprite, mirroring MapView so the iso crowd reads the
# same way (filled halo = mood, ring = archetype, chip = unmet need).
const ARCH_COLORS := {
	&"visitor": Color("#dfe6df"), &"child": Color("#f4a261"),
	&"family": Color("#83c779"), &"enthusiast": Color("#c9a4ff")}
const ARCH_SPRITE := {
	&"visitor": "visitor", &"child": "visitor_child",
	&"family": "visitor_family", &"enthusiast": "visitor_enthusiast"}
const NEED_SHOW_THRESHOLD := 0.4
const NEED_BUBBLES := {
	&"hunger":   {"glyph": "H", "color": Color("#e27d60")},
	&"thirst":   {"glyph": "T", "color": Color("#5aa9e6")},
	&"restroom": {"glyph": "R", "color": Color("#41b3a3")},
	&"energy":   {"glyph": "Z", "color": Color("#c9a4ff")}}


func _draw_guest(ag: Agent) -> void:
	var base := _tile_center(ag.position.x, ag.position.y)
	# Ground shadow (squashed; stays put while the body bobs).
	draw_set_transform_matrix(_view_xf * Transform2D(Vector2(1, 0), Vector2(0, 0.5), base))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.25))
	draw_set_transform_matrix(_view_xf)
	var bob := sin(_time * 4.2 + float(ag.agent_id) * 0.83) * 1.2
	var body := base + Vector2(0, -12.0 + bob)
	var sat := _satisfaction_color(ag.satisfaction)
	var arch: Color = ARCH_COLORS.get(ag.agent_type_id, Color("#dfe6df"))
	# Filled halo = mood; crisp ring = archetype.
	draw_circle(body, 9.0, Color(sat.r, sat.g, sat.b, 0.38))
	draw_arc(body, 11.0, 0.0, TAU, 24, arch, 2.0)
	var sprite := _sprite(ARCH_SPRITE.get(ag.agent_type_id, "visitor"))
	if sprite != null:
		var ss := Vector2(26, 26)
		draw_texture_rect(sprite, Rect2(body - ss * 0.5, ss), false)
	else:
		draw_circle(body, 6.0, arch)
		draw_circle(body + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.5))
	_draw_visitor_mood(ag, body)


func _satisfaction_color(s: float) -> Color:
	if s < 0.5:
		return Color("#e76f51").lerp(Color("#f4a261"), s * 2.0)
	return Color("#f4a261").lerp(Color("#83c779"), (s - 0.5) * 2.0)


# Per-need mood bubble: an unmet need wins (colored H/T/R/Z chip); a content
# guest shows cycling ♥/★/♪ delight. Same model as MapView — the crowd
# narrates the sim without a stats overlay.
func _draw_visitor_mood(ag: Agent, pos: Vector2) -> void:
	var urgent_id: StringName = &""
	var lowest := NEED_SHOW_THRESHOLD
	for need_id in ag.need_levels.keys():
		var lvl: float = ag.need_levels[need_id]
		if lvl < lowest:
			lowest = lvl
			urgent_id = need_id
	var t := Time.get_ticks_msec() / 1000.0
	if urgent_id != &"" and NEED_BUBBLES.has(urgent_id):
		var pulse := 0.6 + 0.4 * sin(t * 3.0 + float(ag.agent_id) * 0.7)
		var spec: Dictionary = NEED_BUBBLES[urgent_id]
		_draw_mood_chip(pos, spec["glyph"], spec["color"], pulse)
		return
	if ag.satisfaction < 0.75:
		return
	var phase := fmod(t + float(ag.agent_id) * 0.71, 3.0)
	if phase > 1.4:
		return
	var glyphs := ["♥", "★", "♪"]
	var glyph: String = glyphs[ag.agent_id % glyphs.size()]
	var alpha: float = sin(phase / 1.4 * PI)
	var rise: float = lerpf(0.0, 6.0, phase / 1.4)
	var bubble_color := Color(1.0, 0.55, 0.6, alpha) if glyph == "♥" \
		else (Color(0.96, 0.83, 0.37, alpha) if glyph == "★" else Color(0.7, 0.85, 0.95, alpha))
	var font := get_theme_default_font()
	var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var o := pos + Vector2(-sz.x * 0.5, -18.0 - rise)
	draw_string(font, o + Vector2(1, 1), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.40 * alpha))
	draw_string(font, o, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, bubble_color)


func _draw_mood_chip(pos: Vector2, glyph: String, color: Color, intensity: float) -> void:
	var center := pos + Vector2(0.0, -20.0)
	var r := 7.0
	draw_circle(center + Vector2(0.5, 1.0), r, Color(0, 0, 0, 0.30 * intensity))
	draw_circle(center, r, Color(color.r, color.g, color.b, 0.92 * intensity))
	draw_arc(center, r, 0.0, TAU, 18, Color(1, 1, 1, 0.55 * intensity), 1.0)
	var font := get_theme_default_font()
	var sz := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, center - Vector2(sz.x * 0.5, -11 * 0.36), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, intensity))


func _sprite(name: String) -> Texture2D:
	if _sprites.has(name):
		return _sprites[name]
	var path := "res://assets/sprites/%s.png" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprites[name] = tex
	return tex


# True ¾ isometric directional art: if assets/sprites/<species>_4dir/ exists,
# return the sprite name facing the screen-space heading (N/S/E/W). Falls back
# to the plain billboard sprite when there's no directional set for a species.
var _has_4dir := {}   # species -> bool

func _directional_sprite(species: String, heading: Vector2) -> String:
	if not _has_4dir.has(species):
		_has_4dir[species] = ResourceLoader.exists(
			"res://assets/sprites/%s_4dir/south.png" % species)
	if not _has_4dir[species]:
		return species
	# Map the heading's screen angle to the nearest cardinal facing. Default to
	# "south" (facing the camera) when nearly stationary.
	if heading.length() < 0.01:
		return "%s_4dir/south" % species
	var deg := rad_to_deg(heading.angle())   # screen space: +y is down
	var dir := "south"
	if deg >= -45.0 and deg < 45.0:
		dir = "east"
	elif deg >= 45.0 and deg < 135.0:
		dir = "south"
	elif deg >= -135.0 and deg < -45.0:
		dir = "north"
	else:
		dir = "west"
	return "%s_4dir/%s" % [species, dir]


func _hash2(a: int, b: int) -> int:
	return abs((a * 374761393 + b * 668265263) ^ 0x55555555) & 0x7FFFFFFF
