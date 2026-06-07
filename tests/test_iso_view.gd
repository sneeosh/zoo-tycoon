extends GutTest
# Isometric view — projection + interaction.
#
# The iso view is interactive (BaseMapView contract): clicks turn into grid
# cells via inverse projection. These tests pin that math (a screen→cell that
# round-trips _tile_center) and the click→signal path, so the iso build/place
# flow can't silently drift. Pure view logic; no engine touched.


# Build with a real, non-identity view transform (a genuine fit-to-view) so
# the tests exercise the camera path, not just the identity case.
func _new_iso() -> IsoPreview:
	var iso := IsoPreview.new()
	add_child_autofree(iso)
	iso.size = Vector2(900, 600)
	iso._rebuild_view()
	return iso


# Screen position of a cell centre, forward through the view transform — the
# pixel the player actually clicks.
func _cell_pixel(iso: IsoPreview, gx: int, gy: int) -> Vector2:
	return iso._view_xf * iso._tile_center(gx, gy)


func test_screen_to_cell_round_trips_tile_centers() -> void:
	var iso := _new_iso()
	# Every cell's on-screen centre must pick that exact cell — this is what
	# makes "click the diamond you see" land on the right tile, under zoom/pan.
	for gx in range(0, 28):
		for gy in range(0, 18):
			var cell: Vector2i = iso._screen_to_cell(_cell_pixel(iso, gx, gy))
			assert_eq(cell, Vector2i(gx, gy),
				"cell (%d,%d) centre must invert to itself" % [gx, gy])


func test_screen_to_cell_is_stable_within_a_diamond() -> void:
	var iso := _new_iso()
	# A point nudged a few screen px around a tile centre (but inside its
	# diamond) still resolves to that tile — no off-by-one at sub-cell offsets.
	var center := _cell_pixel(iso, 10, 6)
	for off in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 4), Vector2(0, -4)]:
		assert_eq(iso._screen_to_cell(center + off), Vector2i(10, 6),
			"nudged point %s should stay in cell (10,6)" % off)


func test_zoom_keeps_the_cursor_anchored() -> void:
	var iso := _new_iso()
	# Zooming in about a screen point must keep the same cell under the cursor.
	var pix := _cell_pixel(iso, 12, 7)
	var before := iso._screen_to_cell(pix)
	iso._zoom_at(pix, 1.3)
	assert_eq(iso._screen_to_cell(pix), before,
		"the cell under the cursor must not move when zooming")


func test_bar_renders_proportional_fill() -> void:
	var iso := _new_iso()
	assert_eq(iso._bar(0.0).count("▰"), 0, "empty bar has no filled cells")
	assert_eq(iso._bar(1.0).count("▰"), 8, "full bar is all filled")
	assert_eq(iso._bar(0.5).count("▰"), 4, "half bar is half filled")


func test_inspector_finds_a_visitor_at_its_screen_position() -> void:
	AgentPool.reset()
	var id := AgentPool.spawn(&"visitor", Vector2(5, 5))
	assert_ne(id, 0, "visitor agent type must be loaded to spawn")
	var iso := _new_iso()
	# Project the visitor's body the same way the renderer does, then inspect.
	var body: Vector2 = iso._view_xf * (iso._tile_center(5, 5) + Vector2(0, -12.0))
	var lines: Array = iso._inspect_visitor_at(body)
	assert_false(lines.is_empty(), "a visitor under the cursor must inspect")
	assert_true(lines[0].contains("#%d" % id), "card header names the agent id")
	AgentPool.reset()


func test_left_click_emits_placement_for_hovered_cell() -> void:
	var iso := _new_iso()
	watch_signals(iso)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _cell_pixel(iso, 7, 4)
	iso._gui_input(ev)
	assert_signal_emitted_with_parameters(iso, "placement_requested", [Vector2i(7, 4)])


func test_right_click_emits_remove_for_hovered_cell() -> void:
	var iso := _new_iso()
	watch_signals(iso)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = _cell_pixel(iso, 3, 9)
	iso._gui_input(ev)
	assert_signal_emitted_with_parameters(iso, "remove_requested", [Vector2i(3, 9)])
