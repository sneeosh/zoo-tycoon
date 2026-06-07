# Spec: Animals as Agents

**Status:** Proposed. Created 2026-06-07.
**Author:** Eng.
**Scope:** Zoo Tycoon repo (zoo-side feature) + **one** engine seam filed
against `engine/` (tycoon_core).
**Depends on:** engine v0.5.0 agent system (already in tree); the navigation
seam (`engine_seam_agent_navigation.md`) is **not** required — animals
free-roam, see §5.

> Per [`CLAUDE.md`](./CLAUDE.md) §1 the engine submodule is read-only. This
> document is a design contract for code we'd write **in this repo**, plus a
> single seam report (§4) for the one thing the engine genuinely lacks. If
> implementing it makes us reach into `engine/`, that's a new seam — stop and
> document it, don't patch in place.

---

## 1. The problem & the payoff

Today an animal is a **`Placement`** — a static record inside a `Region`
(`engine/addons/tycoon_core/schema/placement.gd`). It has a `primary_cell`, a
`state` dict the game owns, and **no position that ever changes**. All the
"life" you see is faked in the view layer: both renderers wobble the sprite on
a sine path (`src/ui/map_view.gd` `_draw_placements`, `src/ui/iso_preview.gd`
`_wander_in`). The simulation thinks every animal stands perfectly still on one
tile forever.

Promoting animals to real **`Agent`s** makes their movement a *consequence of
the model* instead of a cosmetic lie — which is exactly North Star principle 2
("the simulation is honest"). Concretely it unlocks:

- **Legible welfare.** A cramped animal paces the fence; a lonely herd animal
  drifts to the corner; a well-kept one grazes calmly. Welfare stops being a
  once-a-day dice roll (`bootstrap.gd` `_on_day_ending_for_welfare`) and
  becomes a continuous thing the player *watches*.
- **Genuine behaviors.** Walk to the feeding trough when hungry; cluster with
  conspecifics up to `social_max`; shy away from a crowded fence; a predator
  paces more than a basking flamingo.
- **One source of truth.** Both renderers read one real `position`; the two
  separate fake-wander implementations are deleted.
- **A foundation** for later roadmap systems (keepers walking to tend animals,
  escapes, enrichment objects the animal seeks out).

This is **not** a visitor-style spawn population. Animals are a *persistent,
hand-placed, region-bound* agent population — a new shape the engine supports
but the zoo has never used.

---

## 2. The core model

> An animal is **an `Agent` of a zoo-defined `AgentType` whose home is a
> `Region`, spawned and despawned by the game in lockstep with its
> `Placement`, free-roaming within the region's cells, with needs that decay
> into a welfare score.**

Everything the engine needs already exists:

| Need | Engine provides |
|---|---|
| An instance with a moving `position` + per-need levels | `Agent` (`systems/agent.gd`) |
| Per-tick decay + behavior dispatch | `AgentPool._on_tick` → `IAgentBehavior` |
| Spawn/despawn at a chosen position | `AgentPool.spawn(type_id, position)` / `despawn(id)` |
| Don't auto-spawn from the visitor loop | `spawn_weight = 0` ⇒ never picked by `_spawn_from_weighted_types` |
| Per-individual runtime state | `Agent.behavior_state`, `Agent.traits`, `Agent.need_levels` |
| Region membership + cells | `Region` (`systems/region.gd`), `RegionRegistry` |

The **only** thing the engine doesn't cleanly support is keeping animal
satisfaction *out of* the visitor spawn-rate balancer — that's the single seam
in §4.

---

## 3. What the zoo builds (no engine change)

### 3a. Content: the `animal` AgentType

Add **one** agent type in `design/tuning/agents.md`:

| id     | display_name | spawn_weight |
|--------|--------------|--------------|
| animal | Animal       | **0.0**      |

`spawn_weight = 0` is load-bearing: `AgentPool._spawn_from_weighted_types`
sums weights, so a zero-weight type is *never* auto-spawned by the visitor
loop. The game is the only thing that ever calls `AgentPool.spawn(&"animal",
…)`.

**Species data stays in `placeables.md`.** A penguin and a lion differ in
space/social/habitat — but `PlaceableDef` already carries all of that
(`space_required`, `social_min/max`, `own_tags`, `needs_provided_tags`). Rather
than duplicate every species into `agents.md`, the animal carries its species
id in `behavior_state["species"]` and the behavior looks up the `PlaceableDef`
for husbandry numbers. One `AgentType` for the engine plumbing; `PlaceableDef`
remains the species authority.

> **Open question (§9.1):** one shared `animal` type vs. one type per species.
> Recommended: one shared type + `PlaceableDef` lookup, to avoid forking
> species data across two tuning files.

### 3b. Needs: animal welfare as decaying needs

Add animal need specs to `agents.md` (`agent_id = animal`). Proposed axes,
mapped from today's welfare model:

| need_id   | meaning                                  | replenished by |
|-----------|------------------------------------------|----------------|
| `food`    | hunger                                   | in-region `provides_food` placeable (feeding trough) |
| `water`   | thirst                                   | in-region `provides_water` placeable (water trough) |
| `social`  | herd satisfaction                        | conspecific count within `[social_min, social_max]` |
| `space`   | room to roam                             | region cells per animal ≥ `space_required` |
| `health`  | aggregate welfare (derived, slow)        | the other four |

Decay rates live in `needs.md` / `agents.md` (never hardcoded — CLAUDE.md §3).
`AgentPool._decay_needs` runs these automatically every tick and fires
`on_need_threshold_crossed` when one drops below its `threshold`.

> **Important plumbing note.** `AgentPool._decay_needs` lets `EffectResolver`
> modify decay based on nearby **`EntityInstance`s** — but troughs are
> **`Placement`s inside a region**, invisible to `EffectResolver`. So
> *feeding* is handled by the **behavior** (read the region's placements for
> `provides_food`/`provides_water` tags and refill on arrival), **not** by an
> EffectResolver modifier. This keeps the engine ignorant of "troughs."

### 3c. Behavior: `AnimalBehavior` (implements `IAgentBehavior`)

New `src/behaviors/animal_behavior.gd`, registered in `bootstrap.gd`:

```gdscript
AgentPool.register_behavior(&"animal", _animal_behavior)
AgentPool.register_satisfaction_model(&"animal", _animal_satisfaction)
```

State stashed in `behavior_state` at spawn: `species` (StringName),
`home_region_id` (int), `placement_index` (int back-ref), a per-individual
`temperament` from `traits`, and a `goal` (idle / seek_food / seek_water /
flee).

`on_tick(agent)` — a small state machine, **all randomness from
`SimClock.rng`** (determinism, CLAUDE.md §5):

1. **Re-home guard.** If `home_region_id` no longer exists or no longer
   contains the animal (region split/merge — engine re-derives regions), snap
   to the nearest valid region cell or, if the enclosure is gone, mark for
   despawn (handled by the lifecycle binding in §3e).
2. **Need seeking.** If a need is below threshold and an in-region provider
   exists, set goal and step toward the nearest provider cell; on arrival,
   refill that need (rate from tuning). Providers are found by scanning
   `region.placements` for the tag — no pathfinding (§5).
3. **Social drift.** Count conspecifics in the region. Below `social_min`,
   bias movement toward the nearest conspecific; above `social_max`, bias away.
4. **Stress / flee.** If guests cluster on the fence near the animal (query
   `AgentPool.get_agents_by_type(&"visitor"…)` within N cells), bias away from
   them — shy species (low temperament) more than bold ones.
5. **Idle wander.** Otherwise amble: pick a slow heading, advance
   `species_speed` tiles/tick (birds faster, big cats slower — from tuning),
   reflect off the region's bounding cells, and snap back inside on the rare
   non-convex overshoot (same containment idea as today's renderer wander, now
   in the sim).

`on_need_threshold_crossed(agent, need_id)` sets the seek goal so the response
fires on the transition tick, not every tick (mirrors how visitors react).

`on_spawn` initializes `behavior_state`, position (a region cell from
`SimClock.rng`), and need levels. `on_despawn` clears the back-ref.

### 3d. Satisfaction: `AnimalSatisfactionModel` (implements `ISatisfactionModel`)

`Agent.satisfaction` becomes the animal's **welfare** — a blend of its needs
(weakest-link weighted, like the visitor model) times its temperament. The
behavior writes this back to the **placement's** `state["attitude"]` /
`state["welfare"]` each day so the two existing engine-facing seams keep
working unchanged:

- `IPlaceableHappiness` (`src/models/zoo_animal_happiness.gd`) — the engine
  multiplies a placement's `appeal_contribution` by happiness when computing
  region appeal. It reads placement state; we keep feeding it.
- Breeding/aging/arena daily logic (`bootstrap.gd`) reads/writes placement
  `state`. Unchanged.

⚠️ **But `Agent.satisfaction` also feeds the visitor spawn curve** — see §4.

### 3e. Lifecycle binding: Placement ↔ Agent

The `Placement` stays as the **slot** the engine's region-appeal math counts;
the `Agent` becomes the **living individual**. They're bound 1:1:

- **Add** (player drops an animal, or breeding produces one in
  `_on_day_ending_for_breeding`): after the engine creates the placement, call
  `AgentPool.spawn(&"animal", cell)`, then store `agent_id` in
  `placement.state["agent_id"]` and the species/region/back-ref in
  `agent.behavior_state`.
- **Remove** (sold, neglect death, old age): `AgentPool.despawn(agent_id)` in
  the same handler that removes the placement, so the two never drift.
- **Region split/merge:** on `EventBus.region_changed`, reconcile — re-home
  agents whose cell moved to a new region id; despawn any whose enclosure
  vanished.

A reconcile pass on load and on region events keeps `placements` and `animal`
agents in exact correspondence. (A debug assert `animal_count ==
animal_placement_count` is cheap and worth keeping in tests.)

### 3f. Rendering: read agents, delete the fake wander

Both renderers switch the animal pass from `region.placements[i]` +
sine-wander to `AgentPool.get_agents_by_type(&"animal")` + the agent's real
`position`:

- `src/ui/iso_preview.gd`: `_draw_sorted_objects` reads animal agents; **delete
  `_wander_in` / `_wander_offset` / `_region_bounds`** (now redundant — the sim
  owns the position). Keep the opaque-pixel seating and the depth sort.
- `src/ui/map_view.gd`: `_draw_placements` reads animal agents instead of
  placements for the *animal* rows; **delete the Lissajous wander block**.
  Infrastructure placements (troughs, donation boxes) still render from
  `region.placements` since they're not agents.

Net: less code, and the sprite is finally where the simulation says it is.

### 3g. Save/load: animals must persist

Visitors are transient — the engine never persists agents. **Animals are
not.** The zoo's existing `SaveService.register_game_state_provider("zoo", …)`
in `bootstrap.gd` already persists placements; extend it to serialize each
animal agent's full state (`agent_id` link, species, home region, `position`,
`need_levels`, `behavior_state`, name/age/welfare) and **re-`spawn` them on
load** (the engine won't). Order matters: rebuild regions → restore placements
→ respawn + rebind animal agents → reconcile.

---

## 4. The one engine seam: spawn-curve population

**This is the only thing the engine genuinely lacks.**

`AgentPool.compute_aggregate_satisfaction()` averages `satisfaction` over
**every live agent** and `_on_day_ended` feeds that mean into the visitor
`spawn_curve` to set the next day's arrival multiplier. If animals are agents,
**a hungry lion would suppress guest arrivals** — animal welfare would leak
into visitor demand. That's wrong, and the engine has no concept of "which
agent types drive the spawn curve."

Per the prime directive this belongs in the engine (it's a generic
"some agent populations are customers, some aren't" distinction — a hospital
has patients vs. staff, a mall has shoppers vs. employees). **Filed as a seam,
not patched in place.**

**Proposed engine change (additive, target tag v0.6.x):**

- New `AgentType` flag: `@export var drives_spawn_balance: bool = true`.
- `AgentPool.compute_aggregate_satisfaction()` averages only over agents whose
  type has `drives_spawn_balance == true` (default preserves today's behavior;
  zoo sets it `false` on the `animal` type).
- Bonus: the same flag can gate whether a type participates in the auto-spawn
  loop, making the `spawn_weight = 0` trick explicit rather than incidental.

**Zoo-side stopgap if we ship before the engine bump:** have
`AnimalSatisfactionModel` leave `Agent.satisfaction` parked at the current
visitor mean (a no-op contribution to the average) and store real welfare in
`behavior_state["welfare"]` instead. This is **dishonest** (animal welfare and
the field named `satisfaction` diverge) and should be a clearly-commented
temporary measure, removed the moment the engine flag lands. Prefer waiting for
the engine bump.

**What the engine still must NOT learn:** nothing here names "animal,"
"welfare," or "exhibit." It's a boolean on a population. If implementing it
requires the engine to know what an animal *is*, that's a second seam — stop.

---

## 5. Why no pathfinding (navigation seam not required)

Visitors path on the `default` `WalkableNetwork` (paths). Animals **don't path
on paths** — they roam a small, obstacle-free enclosure. Within ~1–12 cells,
"step toward target, reflect off the bounds, snap inside on overshoot" looks
correct and costs nothing. We deliberately **don't** build a per-region
`WalkableNetwork` because:

- Enclosures are tiny and convex-ish; A* buys no visible quality.
- `NavigationRegistry` builds networks reactively from *walkable entities*;
  region zone-tiles aren't walkable entities, so wiring them in would mean
  either an engine change or poking `NavigationRegistry.networks` directly (a
  soft seam). Not worth it.

If a later feature needs animals to navigate around in-enclosure obstacles
(rocks, water hazards), revisit and consider a per-region network then — but
that's out of scope here.

---

## 6. Determinism & performance

- **Determinism (CLAUDE.md §5):** `on_tick` runs inside the deterministic sim,
  so *every* random choice uses `SimClock.rng` — never wall-clock time
  (unlike the current renderer wander, which is view-only and may use
  `Time.get_ticks_msec`). This keeps save/load exact and tests reproducible.
- **Performance (web budget, ROADMAP §1):** animals number in the **dozens**,
  not hundreds, and free-roam (no A*). ~50 animals × a tiny per-tick state
  machine is negligible next to the 100+ visitor budget the navigation seam
  already targets. No pooling concern beyond what `AgentPool` gives for free.

---

## 7. Migration & rollout

1. **Engine v0.6.x** ships `drives_spawn_balance` (§4) — additive, default
   true, no behavior change for existing games/tests.
2. **Zoo bumps engine**, sets `drives_spawn_balance = false` on `animal`.
3. **Add the `animal` AgentType + needs** (`agents.md`), `AnimalBehavior`,
   `AnimalSatisfactionModel`, register in `bootstrap.gd`.
4. **Bind lifecycle** (§3e): spawn/despawn alongside placement add/remove +
   breeding/death; reconcile on region events and load.
5. **Switch renderers** to read animal agents; delete both fake-wander blocks.
6. **Extend the save provider** to persist + respawn animals.
7. **Keep `IPlaceableHappiness` / breeding / arena reading placement state** —
   the behavior writes welfare/attitude back so those seams are untouched.

Each step is independently testable; the renderer switch (5) is the visible
payoff and can trail behind the sim work.

---

## 8. Test plan (GUT, headless)

- **Lifecycle:** placing an animal spawns exactly one `animal` agent at a
  region cell; removing it despawns exactly that agent; counts stay equal.
- **Containment:** over N ticks, no animal's `position` leaves its region's
  cells (assert against `region.cells`).
- **Feeding:** a hungry animal with an in-region trough recovers `food`; one
  without keeps starving.
- **Social:** an under-`social_min` animal drifts toward conspecifics; an
  over-`social_max` one drifts apart.
- **Spawn isolation (the seam):** a park of miserable animals + happy visitors
  yields a visitor spawn multiplier driven by the *visitors only* (requires
  the engine flag; until then, assert the stopgap keeps animals neutral).
- **Save/load:** round-trip a zoo with animals mid-wander; positions, needs,
  species, names, and counts restore exactly.
- **Smoke loop unaffected:** `tests/test_zoo_integration.gd` still goes green
  (visitors arrive → pay → eat → settle) with animals now live.

---

## 9. Open questions

1. **One `animal` type vs. per-species types.** Recommended: one type +
   `PlaceableDef` species lookup (keeps species data in one file). Per-species
   would let `agents.md` express per-species need decay directly at the cost of
   duplication. Decide before 3a.
2. **Does `Agent.satisfaction` *become* welfare, or stay separate?** If the
   engine flag (§4) lands, satisfaction = welfare is clean and honest. If we
   ship the stopgap, they must diverge temporarily. Prefer waiting for the
   flag.
3. **Breeding spawn point.** New offspring spawn at a parent's cell — do they
   inherit traits/temperament? Out of scope for v1; default to fresh trait
   sampling.
4. **Escapes (later).** Once animals have real positions, a broken fence could
   let one onto the path network — a fun future hook, explicitly **not** in
   this spec. Noted so we don't design it out.

---

## 10. Acceptance criteria

- [ ] Engine v0.6.x: `AgentType.drives_spawn_balance` shipped, default true,
      `compute_aggregate_satisfaction` honors it, CHANGELOG + GUT test; no
      engine reference to "animal"/"welfare"/"exhibit."
- [ ] `animal` AgentType + need specs in tuning; `spawn_weight = 0`,
      `drives_spawn_balance = false`.
- [ ] `AnimalBehavior` + `AnimalSatisfactionModel` implemented and registered.
- [ ] Placement↔Agent lifecycle binding incl. breeding/death + region
      reconcile + load.
- [ ] Both renderers read animal agents; both fake-wander blocks deleted.
- [ ] Save provider persists + respawns animals with exact round-trip.
- [ ] Animal welfare still flows to `IPlaceableHappiness`, breeding, and arena
      via placement state.
- [ ] All GUT tests in §8 green; smoke loop unaffected.
- [ ] No file under `engine/` modified in this repo.
</content>
