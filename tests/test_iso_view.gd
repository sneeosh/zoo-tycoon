extends GutTest
# Isometric view — projection + interaction.
#
# The iso view is interactive (BaseMapView contract): clicks turn into grid
# cells via inverse projection. These tests pin that math (a screen→cell that
# round-trips _tile_center) and the click→signal path, so the iso build/place
# flow can't silently drift. Pure view logic; no engine touched.


func _new_iso() -> IsoPreview:
	var iso := IsoPreview.new()
	# _ready sets mouse_filter etc.; not required for the pure math, but call
	# it so the instance is in the same state as in-game.
	add_child_autofree(iso)
	return iso


func test_screen_to_cell_round_trips_tile_centers() -> void:
	var iso := _new_iso()
	# Every cell's projected centre must invert back to that exact cell —
	# this is what makes "click the diamond you see" land on the right tile.
	for gx in range(0, 28):
		for gy in range(0, 18):
			var center: Vector2 = iso._tile_center(gx, gy)
			var cell: Vector2i = iso._screen_to_cell(center)
			assert_eq(cell, Vector2i(gx, gy),
				"cell (%d,%d) centre must invert to itself" % [gx, gy])


func test_screen_to_cell_is_stable_within_a_diamond() -> void:
	var iso := _new_iso()
	# A point nudged a few px around a tile centre (but inside its diamond)
	# still resolves to that tile — no off-by-one at sub-cell offsets.
	var center: Vector2 = iso._tile_center(10, 6)
	for off in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 4), Vector2(0, -4)]:
		assert_eq(iso._screen_to_cell(center + off), Vector2i(10, 6),
			"nudged point %s should stay in cell (10,6)" % off)


func test_left_click_emits_placement_for_hovered_cell() -> void:
	var iso := _new_iso()
	watch_signals(iso)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = iso._tile_center(7, 4)
	iso._gui_input(ev)
	assert_signal_emitted_with_parameters(iso, "placement_requested", [Vector2i(7, 4)])


func test_right_click_emits_remove_for_hovered_cell() -> void:
	var iso := _new_iso()
	watch_signals(iso)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = iso._tile_center(3, 9)
	iso._gui_input(ev)
	assert_signal_emitted_with_parameters(iso, "remove_requested", [Vector2i(3, 9)])
