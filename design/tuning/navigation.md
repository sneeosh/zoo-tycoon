# Navigation — Pathing defaults (Zoo)

<!--
Engine spec: engine/design/algorithms/navigation.md (v0.6.0).

Engine-wide fallbacks + budgets for guest movement on the walkable path
network. Per-tile knobs (which tiles are walkable, their traversal_cost,
network_id, access tags) are authored per-entity in entities.md — the `path`
tile sets walkable = true there. These are just the defaults the engine's
NavigationRegistry / default A* navigator fall back to.

  - default_engagement_distance: a guest standing on a path cell can "view"
    an exhibit (and tip / browse it) when any of the exhibit's tiles is
    within this many tiles, measured Manhattan. Tight on purpose — guests
    walk up to the fence to see, not stand half a map away.
  - max_path_expansions: fail-soft A* budget; a route needing more nodes than
    this returns empty and the guest re-plans / falls back.
-->

## Defaults

default_traversal_cost      = 1.0
default_engagement_distance = 5
max_path_expansions         = 4096
