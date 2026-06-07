# Engine Seam: Agent Navigation on a Constrained Network

**Status:** Proposed engine capability. Created 2026-06-06.
**Filed against:** `engine/` (tycoon_core), target tag **v0.6.x**.
**Triggered by:** Zoo Tycoon Adaptation Plan, item 0 (paths-only guest
movement). See [`zoo_tycoon_adaptation_plan.md`](./zoo_tycoon_adaptation_plan.md).

> Per [`CLAUDE.md`](../CLAUDE.md) §1, we do not patch the engine
> submodule in place. This document is the **seam report** — what the
> engine needs to grow before the zoo can ship paths-only movement.

---

## 1. Why this belongs in the engine

Every tycoon game on this engine will need it:

- **Zoo Tycoon** — guests walk paths to view exhibits.
- **Theme park** — guests walk paths to rides.
- **Hospital** — patients walk corridors to departments.
- **Transit** — passengers walk platforms to vehicles.
- **Mall / shop** — customers walk aisles to shelves.

The shared capability is **"agents move on a player-built network of
walkable cells toward goals, scored by some appeal function, with
needs that decay during travel."** That is a generic tycoon primitive
— the same shape as `IAgentBehavior` itself. Theme-specific bits
(what *is* a "path," what *is* a "goal") plug in via existing
interfaces.

Building it in the zoo repo would create exactly the seam leak
[`CLAUDE.md`](../CLAUDE.md) §1 exists to prevent: every other game on
this engine would have to either reinvent it or import zoo code.

---

## 2. What the engine grows

### 2a. New schema: `WalkableNetwork`

A theme-agnostic resource representing the set of tiles an agent is
allowed to traverse, plus the graph induced by adjacency.

- **Source of truth:** populated by the game from any placeables that
  declare `walkable = true` in their schema.
- **Storage:** a sparse tile→node map; recomputed (or incrementally
  patched) whenever a walkable placeable is added or removed.
- **Properties per cell:** `traversal_cost` (float, default 1.0),
  optional `tags: PackedStringArray` (so games can express
  "staff-only," "paid," "indoor," etc. without the engine knowing
  what they mean).
- **Query API:**
  - `path(from: Vector2i, to: Vector2i, agent_tags: PackedStringArray) -> PackedVector2iArray`
  - `reachable_from(origin: Vector2i, agent_tags) -> Set[Vector2i]`
  - `nearest(origin, predicate: Callable, agent_tags) -> Vector2i`
- **Invalidation:** event bus signal `network_changed(network_id, dirty_rect)` so
  consumers can drop cached routes.

### 2b. New interface: `INetworkNavigator`

Implements pathing for one agent population. The engine ships a
default A\* implementation that most games will never need to
override.

```gdscript
# engine/interfaces/i_network_navigator.gd
class_name INetworkNavigator extends RefCounted

# Pick the next cell for an agent given its current position and target.
func step(agent: AgentState, network: WalkableNetwork) -> Vector2i: ...

# Return all goals (with score) reachable from this position.
func score_goals(agent: AgentState, network: WalkableNetwork,
                 candidates: Array[GoalRef]) -> Array[ScoredGoal]: ...
```

Why an interface and not just a hardcoded A\* function:

- Games may want **path *preference***, not just path-only. (Hospital:
  patients prefer wide corridors but will cut through narrow ones.
  Mall: customers prefer the main aisle but will branch when crowded.)
- Games may want **per-archetype routing** (children path differently
  than adults — original Zoo Tycoon's M/W/B/G personalities map here).
- Games may want to layer **avoidance** (stink radius, crowded
  amenity, noisy ride) without forking the engine pathfinder.

### 2c. Extension to `IAgentBehavior`

Today's `IAgentBehavior.decide_next_target` returns *what* to seek.
The engine grows a parallel hook:

```gdscript
func decide_next_step(agent: AgentState, world: WorldView) -> Vector2i:
    # default impl: delegate to the bound INetworkNavigator
```

This keeps the existing `IAgentBehavior` contract intact for games
that don't use networks (free-roam validation games, debug harnesses)
while routing path-walking games through the new surface.

### 2d. Viewing / engagement-distance helper

The "10-tile viewing distance" pattern from Zoo Tycoon is generic:
"agent on a network cell engages with target T if any of T's anchor
cells is within distance D of the agent's current cell, measured on
the network graph (or as Manhattan, configurable)."

Ship as a stateless system function on `WalkableNetwork`:

```gdscript
func within_engagement_distance(cell: Vector2i, target_anchors: Array[Vector2i],
                                d: int, metric: Metric) -> bool
```

Theme-agnostic. The zoo wires "exhibit boundary tiles" to
`target_anchors`. A mall wires "shelf-facing tiles." A hospital wires
"reception desk tile."

---

## 3. What the engine does *not* learn

Per the prime directive, the engine still doesn't know:

- What a "path" *is* in any game. (Zoo paths, mall aisles, hospital
  corridors are all just placeables with `walkable = true`.)
- What a "viewer" *is*. (Engagement-distance is generic.)
- What a "goal" *is*. (Existing `GoalRef`/`AppealMatch` plumbing
  carries this.)
- That "exhibits" exist. (They're entities the game declares.)

If we find ourselves reaching for any of those concepts in engine
code, that is a *second* seam leak and we stop, document it here, and
push the boundary back into the game.

---

## 4. Tuning surface

New entries in `design/tuning/` (engine side):

- `navigation.md` — default traversal costs by cell tag, default
  engagement distance, default avoidance weights.
- `agents.md` — extended with `path_preference_weight` per agent
  type, so an "adult" agent prefers wide cobblestone aisles and a
  "child" agent prefers anything novel.

Zoo-side tuning consumes these via overlay (the engine's tuning
loader already supports overlays per the v0.5 architecture).

---

## 5. Performance budget

Phase 1's web budget is **60 fps with 100+ visitors.** A\* on a tiny
grid is cheap, but **100 agents pathing every tick is not.** The
engine's default `INetworkNavigator` must:

- **Cache routes** keyed on (start, goal, agent_tags) with TTL
  invalidated by `network_changed`.
- **Step incrementally** — pop one cell per tick, don't recompute the
  full route every tick.
- **Batch reachability** — compute reachable-set once per network
  change, share across agents.
- **Fail soft** — if a route can't be found in N nodes expanded,
  return `Vector2i.ZERO_INF` and let the behavior re-plan with a
  fallback goal.

If profiling shows pathing is still dominant at 100 agents, the
engine can fall back to **flow fields** (one field per goal, all
agents read from it) — cheaper at the cost of less individual
variation. Document this in `algorithms/navigation.md` with worked
examples per the engine's algorithm-spec rule (`engine/CLAUDE.md`
§3b).

---

## 6. Migration & rollout

1. **Engine v0.6.x** — ship `WalkableNetwork`, `INetworkNavigator`,
   default A\* impl, engagement-distance helper, tuning files,
   algorithm spec, GUT tests with worked examples.
2. **Zoo bumps engine.** No zoo code changes yet — existing
   perimeter-browse behavior keeps working because `IAgentBehavior`
   without a bound network falls through to its old path.
3. **Zoo adopts paths.** Declares its `path` placeable as
   `walkable = true`, wires the visitor agent type to the default
   navigator, registers exhibit boundary tiles as anchors.
4. **Zoo deletes perimeter browsing** once paths are proven in
   playtest.

No breaking change to existing zoo code at step 2. The engine bump is
additive.

---

## 7. Open questions for engine review

1. Should `WalkableNetwork` be a singleton (one per world) or
   plural (multiple disjoint networks for indoor/outdoor)? Default to
   plural to leave room for mall/hospital later; zoo uses one.
2. Should engagement-distance be measured on the network graph
   (realistic — guest must walk that far) or Manhattan (cheap —
   matches original Zoo Tycoon)? Default to Manhattan, expose graph
   option.
3. Should the engine ship an editor-mode visualization (debug overlay
   showing the network + cached routes)? Useful for tuning, low cost.
4. Where do crowd-density and amenity-queueing avoidance live? Likely
   a separate engine seam — out of scope for this ticket but worth
   noting now so we don't design ourselves into a corner.

---

## 8. Acceptance criteria for engine v0.6.x

- [ ] `WalkableNetwork` schema + autoload registry shipped.
- [ ] `INetworkNavigator` interface + default A\* impl shipped.
- [ ] `IAgentBehavior` extended with `decide_next_step`.
- [ ] Engagement-distance helper shipped.
- [ ] Algorithm spec with ≥3 worked examples (`design/algorithms/navigation.md`).
- [ ] GUT tests covering: simple route, blocked route, network mutation,
      engagement-distance, agent-tag-restricted route, route invalidation.
- [ ] Perf test: 100 agents, 200-tile network, holds 60 fps in a
      headless harness run.
- [ ] CHANGELOG entry documenting the additive surface.
- [ ] No engine reference to "path," "exhibit," "guest," or any
      theme word.
