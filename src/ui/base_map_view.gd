extends Control
class_name BaseMapView
# The shared contract between the top-down MapView and the isometric
# IsoPreview, so main.gd can drive either interchangeably: the same
# build/place/remove signals, the same preview / disconnected-region / hover
# inputs. Concrete views own their own projection and _draw; this base owns
# only the surface main talks to.

signal placement_requested(grid_cell: Vector2i)
signal remove_requested(grid_cell: Vector2i)
# Drag-paint signals: emitted while the mouse button is held and the hovered
# cell changes. main treats these like placement/remove but silent on failure
# (so dragging across occupied tiles doesn't spam the log).
signal placement_drag_requested(grid_cell: Vector2i)
signal remove_drag_requested(grid_cell: Vector2i)

# Set by main when a build button is toggled on; empty string = none.
var preview_def_id: StringName = &""
# Per-entity-def fill colors, used by fallback rendering and the build preview.
var entity_colors: Dictionary = {}
# region_id -> true for exhibits guests can't path to; drawn as a ⚠ badge so
# the disconnect is visible without opening the manage panel.
var disconnected_regions: Dictionary = {}


# Force the hover state from outside — used by the screenshot harness so
# scripted scenarios can capture the inspector. `world_pos` is in game
# (cell) coordinates. Default is a safe no-op; concrete views override.
func force_hover_at_world(_world_pos: Vector2) -> void:
	pass


# When placing a zone tile at `cell`, the region it would MERGE into (4-adjacent
# region whose kind matches the tile's zone kind), or null if it would start a
# new exhibit. Both views use this to color the ghost — a tile that LOOKS
# adjacent but is only diagonal silently created an orphan 1-cell region with
# zero feedback (playtest 2026-06-09, iso run).
func zone_merge_region(cell: Vector2i, def: EntityDef) -> Region:
	if def == null or def.zone_kind == &"":
		return null
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var r := RegionRegistry.region_at_cell(cell + d)
		if r != null and r.kind == def.zone_kind:
			return r
	return null
