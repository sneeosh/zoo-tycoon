extends GutTest
# Zoo identity (roadmap 6.9): the park name + the derived "star attraction".
# Both live on ZooBootstrap; tests mutate global state and restore it.


func before_each() -> void:
	SaveService.autosave_enabled = false


# --- Naming ----------------------------------------------------------------

func test_set_zoo_name_trims_and_keeps_nonblank() -> void:
	var saved: String = ZooBootstrap.zoo_name
	ZooBootstrap.set_zoo_name("  Serengeti Park  ")
	assert_eq(ZooBootstrap.zoo_name, "Serengeti Park")
	# Blank input must not erase the title.
	ZooBootstrap.set_zoo_name("   ")
	assert_eq(ZooBootstrap.zoo_name, "Serengeti Park")
	ZooBootstrap.zoo_name = saved


func test_set_zoo_name_caps_length() -> void:
	var saved: String = ZooBootstrap.zoo_name
	ZooBootstrap.set_zoo_name("X".repeat(80))
	assert_eq(ZooBootstrap.zoo_name.length(), 28)
	ZooBootstrap.zoo_name = saved


func test_zoo_name_change_emits() -> void:
	var saved: String = ZooBootstrap.zoo_name
	watch_signals(ZooBootstrap)
	ZooBootstrap.set_zoo_name("Tidepool Zoo")
	assert_signal_emitted(ZooBootstrap, "zoo_name_changed")
	ZooBootstrap.zoo_name = saved


# --- Star attraction -------------------------------------------------------

func test_star_attraction_empty_without_donations() -> void:
	var saved: Dictionary = ZooBootstrap.donations_by_region.duplicate()
	ZooBootstrap.donations_by_region = {}
	assert_false(ZooBootstrap.star_attraction().get("has", false))
	ZooBootstrap.donations_by_region = saved


func test_star_attraction_picks_top_donated_exhibit() -> void:
	var saved: Dictionary = ZooBootstrap.donations_by_region.duplicate()
	ZooBootstrap.donations_by_region = {1: 40, 2: 175, 3: 90}
	var star := ZooBootstrap.star_attraction()
	assert_true(bool(star["has"]))
	assert_eq(int(star["region_id"]), 2)
	assert_eq(int(star["donations"]), 175)
	assert_false(String(star["label"]).is_empty())
	ZooBootstrap.donations_by_region = saved


# --- Persistence -----------------------------------------------------------

func test_save_payload_carries_zoo_name_at_v7() -> void:
	var data := ZooBootstrap._save_game_state()
	assert_eq(int(data["version"]), ZooBootstrap.SAVE_VERSION)
	assert_true(data.has("zoo_name"))
	assert_eq(String(data["zoo_name"]), ZooBootstrap.zoo_name)
