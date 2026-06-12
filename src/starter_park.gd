extends RefCounted
class_name StarterPark
# The pre-built zoo staged by "Skip — pre-built zoo" on the welcome screen.
# Lives outside main.gd so the integration suite can run the EXACT park a
# new player gets through multi-day arc tests (winnability regression — the
# 2026-06-09 playtest lost the Standard scenario from this very layout).
#
# Layout: a Lion savanna and a Penguin pool above a concourse, with amenity
# capacity sized for the ~40–50 guest crowd the park pulls by day 6 (thirst
# gets the most capacity because drink demand peaks first).

const STARTER_VISITOR_COUNT: int = 6
const GATE_TILE: Vector2i = Vector2i(0, 17)


static func stage() -> void:
	# --- Lion savanna: grass with rocks at one end. ---
	for x in range(5, 9):
		for y in range(7, 9):
			EntityRegistry.place(&"grass_patch", Vector2i(x, y))
	EntityRegistry.place(&"rock_patch", Vector2i(9, 7))
	EntityRegistry.place(&"rock_patch", Vector2i(9, 8))

	# --- Penguin pool: pure water tiles, separated from the lion region
	# by a one-tile gap so they don't merge into one big Region. ---
	for x in range(5, 9):
		for y in range(12, 14):
			EntityRegistry.place(&"water_patch", Vector2i(x, y))

	# --- Path network: a spine from the entrance gate (0,17) up to a main
	# concourse at y=10 that runs past both exhibits. Guests spawn at the gate
	# and walk the path; they view an exhibit from any path cell within the
	# engagement distance (navigation.md), so the concourse alone lets them
	# see the lion and the penguins. Lay paths BEFORE amenities so the
	# amenities can sit adjacent to the concourse without colliding. ---
	for y in range(10, 18):
		EntityRegistry.place(&"path", Vector2i(0, y))   # gate → concourse
	for x in range(1, 16):
		EntityRegistry.place(&"path", Vector2i(x, 10))  # concourse

	# --- Amenities, each adjacent to the concourse so guests reach them.
	# Density sized for the crowd this park actually pulls — one-of-each left
	# 27/47 guests thirsty and sank reputation unrecoverably (playtest
	# 2026-06-09). Doing nothing should be a slow drift, not a death spiral. ---
	EntityRegistry.place(&"food_stand",  Vector2i(13, 11))  # touches (13,10)/(14,10)
	EntityRegistry.place(&"food_stand",  Vector2i(1, 8))    # 2nd food, gate end; touches (1,10)/(2,10) via (1,9)/(2,9)
	EntityRegistry.place(&"drink_stand", Vector2i(11, 11))  # touches (11,10)
	EntityRegistry.place(&"drink_stand", Vector2i(6, 9))    # mid-concourse, touches (6,10)
	EntityRegistry.place(&"drink_stand", Vector2i(9, 11))   # touches (9,10)
	EntityRegistry.place(&"restroom",    Vector2i(4, 11))   # touches (4,10)
	EntityRegistry.place(&"restroom",    Vector2i(8, 11))   # 2nd restroom (spillover bottleneck)
	EntityRegistry.place(&"bench",       Vector2i(2, 11))   # touches (2,10)
	EntityRegistry.place(&"bench",       Vector2i(12, 11))  # touches (12,10)
	EntityRegistry.place(&"bench",       Vector2i(3, 9))    # touches (3,10)

	# --- Lion + its infrastructure. ---
	var lion_region := RegionRegistry.region_at_cell(Vector2i(5, 7))
	if lion_region != null:
		RegionRegistry.add_placement(lion_region.region_id, &"lion")
		RegionRegistry.add_placement(lion_region.region_id, &"feeding_trough")
		RegionRegistry.add_placement(lion_region.region_id, &"water_trough")

	# --- Penguin colony — they're social, start with 4 so the herd
	# requirement is met (social_min=4). ---
	var penguin_region := RegionRegistry.region_at_cell(Vector2i(5, 12))
	if penguin_region != null:
		for _i in 4:
			RegionRegistry.add_placement(penguin_region.region_id, &"penguin")
		RegionRegistry.add_placement(penguin_region.region_id, &"feeding_trough")

	# Visitors enter at the gate and walk in along the path. Spawn them on the
	# entrance path column (x=0, y 10..17) so they start on the network and
	# route immediately; auto-spawned guests enter at the gate cell.
	for i in range(STARTER_VISITOR_COUNT):
		AgentPool.spawn(&"visitor", Vector2(
			0.0, SimClock.rng.randf_range(10.0, 17.0)))
