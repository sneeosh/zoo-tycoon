# Engine dependencies — the contract Zoo Tycoon binds

**Audience:** an agent (or human) working in the **engine submodule**
(`tycoon-engine`, vendored at `engine/`, pinned **v0.6.1**). This file is the
inventory of engine surfaces the Zoo Tycoon product depends on **today**, so a
change on the engine side can tell at a glance what it would break here.

It is the *consumer's* view. The authoritative engine docs are
[`engine/CLAUDE.md`](../engine/CLAUDE.md) and the doc-comments in
`engine/addons/tycoon_core/`. The read-only contract and upgrade flow live in
this repo's [`CLAUDE.md`](../CLAUDE.md) §1–4 and the cadence map in
[`ROADMAP.md`](../ROADMAP.md) §4.

> **Rule of thumb for engine work:** anything listed here is a *published
> surface*. Renaming/removing/reshaping it is a breaking change — bump the
> engine tag + CHANGELOG, then update this repo via `CLAUDE.md` §4. Adding to
> the surface is safe.

---

## 1. How the submodule is wired

- `engine/` is a git **submodule** (gitlink). Fresh clones need
  `git submodule update --init --recursive` before Godot can open the project.
- `addons/tycoon_core` and `addons/gut` are **symlinks** into
  `engine/addons/...`, so the engine's `res://addons/tycoon_core/...` paths
  resolve unchanged. Both the symlinks and the gitlink are git-tracked.
- **Autoloads** (`project.godot`) — order matters. Engine autoloads are
  bracketed; the zoo adds four of its own:

  ```
  Settings        ← zoo, dependency-free; must precede everything that reads prefs
  I18n            ← zoo, dependency-free
  EventBus … SaveService   ← engine (unchanged order)
  ZooBootstrap    ← zoo; the game-side wiring
  Telemetry       ← zoo; binds EventBus + reads Settings → after them
  Achievements    ← zoo; binds ZooBootstrap signals + reads Ledger/SimClock/
                    ProgressionManager → must come AFTER ZooBootstrap
  ```

  If the engine ever changes its own autoload set/order, keep `Settings`/`I18n`
  first and the two zoo listeners (`Telemetry`, `Achievements`) **after**
  `ZooBootstrap`.

---

## 2. Engine surfaces the zoo binds

### Interfaces (implemented by zoo adapters in `src/`)
`IAgentBehavior`, `IValueModel`, `ISatisfactionModel`, `IQualityRating`,
`IPlaceableHappiness`, `INetworkNavigator`. Changing any method signature
breaks the matching adapter in `src/behaviors/` or `src/models/`.

### EventBus signals (consumed)
`day_ending`, `day_ended`, `day_settled`, `balance_changed`, `entity_placed`,
`entity_removed`, `agent_spawned`, `unlock_acquired`, `reputation_changed`,
`load_failed`, `region_created`, `region_changed`, `region_destroyed`,
`placement_added`, `placement_removed`, `network_changed`.
*(New listeners added this cycle: `Telemetry`→`day_ended`;
`Achievements`→`day_ended`.)*

### SaveService
`register_game_state_provider(key, save_fn, load_fn)` — the zoo persists region
placements + all zoo state under key `"zoo"`. `register_migration(from, fn)`,
`SAVE_VERSION`, signals `save_completed` / `load_completed` / `load_failed`,
autosave on `day_ended`. The engine must keep calling the registered
`save_fn`/`load_fn` and **must not** inspect their payload.

### ProgressionManager
`reputation`, `set_reputation` / `add_reputation`, `try_unlock` / `can_unlock`
/ `force_unlock` / `is_unlocked` / `is_id_available`, `save_state` /
`load_state`. (`Achievements` reads `reputation`.)

### SimClock
`current_tick`, `current_day`, `ticks_per_day`, `speed`, `rng`,
`pause` / `play` / `set_speed` / `is_paused`. (Settings persists the speed; the
pause-menu pauses/resumes through these.)

### RegionRegistry + Region + Placement
`get_region(id)`, `region_at_cell`, `all_regions`, `add_placement`,
`remove_placement`, `can_add_placement`. `Region.region_id` / `.cells` /
`.placements`. **`Placement.state` is game-owned** — the engine reads only
`attitude` (float). The zoo writes `welfare`, `age_days`, `sick`, **and now
`name` / `generation` / `parent`** (6.5 naming/lineage) into that dict; the
engine must continue to leave non-`attitude` keys untouched.

### ContentDB / Ledger / AgentPool / EntityRegistry
`ContentDB.placeable_defs`, `entity_defs`, `get_entity_def`, `get_agent_type`,
`get_unlock_node`, `load_errors`, `is_loaded`. `Ledger.get_balance`,
`post_income`, `post_expense`, `reset`. `AgentPool.spawn`, `get_agent`, `reset`.
`EntityRegistry.place`, `remove`, `instances`, `refund_fraction`.

### Tuning loader
`MarkdownTuningParser.parse(path)` (strict format: `# title` + `<!-- -->`
comments, `## Section`, `key = value`, pipe tables). The zoo now ships
`design/tuning/achievements.md` through it in addition to the existing files.

---

## 3. Filed seams (engine work that *is* expected)

These are the only places the zoo wants the engine to change; each is already
written up — don't patch them in `engine/` silently, bump a tag.

- **`AgentType.drives_spawn_balance` flag** — animal welfare must not leak into
  guest spawn demand via `AgentPool.compute_aggregate_satisfaction()` (which
  averages over *all* agents). Spec:
  [`animals_as_agents_spec.md`](./animals_as_agents_spec.md). Gates roadmap
  **6.6**. Target engine v0.6.x.
- **Agent navigation on a constrained network** — landed in v0.6.1
  (`WalkableNetwork`, `INetworkNavigator`). Writeup:
  [`engine_seam_agent_navigation.md`](./engine_seam_agent_navigation.md) and
  the durable patch in [`engine_patches/`](./engine_patches/).
- **Engine v1.0** gates the Phase 6 **research tree (6.1)** and **scenario
  editor (6.3)** — see `ROADMAP.md` §4. Don't start those zoo features before
  the tag.

No **new** seam was introduced by the Phase 5/6 product build-out (settings,
telemetry, achievements, i18n, naming/lineage, audio depth, portrait): every
surface it touches is pre-existing and listed in §2.

---

## 4. Verifying locally (what CI does)

```sh
# 1. Materialize the engine submodule (fresh clones only)
git submodule update --init --recursive

# 2. Godot 4.5.1 — same build CI uses
#    (https://github.com/godotengine/godot-builds/releases/tag/4.5.1-stable)

# 3. Import twice on a cold project (populates the .godot cache)
godot --headless --import || true
godot --headless --import

# 4. Run the GUT suite (currently 89 green)
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# 5. Web export (needs the matching export templates installed)
godot --headless --export-release "Web" build/web/index.html
```

`tools/generate_audio.py` regenerates the committed `assets/audio/*.wav`
(pure stdlib, deterministic) — run it if you change the audio synthesis.
