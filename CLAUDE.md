# CLAUDE.md — Zoo Tycoon

Operating rules for working in this repo. Read fully before making changes.

This is the **Zoo Tycoon product repo**. It began life as the engine's
validation game (per `engine/docs/build-plan.md` Prompt 10) and has since
graduated to being the real product — see `ROADMAP.md`. The engine itself
lives in the submodule at `engine/` (pinned to a tagged release); the actual
addon is at `engine/addons/tycoon_core/`, symlinked into `addons/tycoon_core/`
so the engine's autoload paths (`res://addons/tycoon_core/...`) work unchanged.

The engine's contract is in `engine/CLAUDE.md` — read it. **Everything that
file says about the engine continues to apply when working here.** Zoo work
must not pretend the engine is malleable.

---

## 0. What this repo is

This is the home of the **Zoo Tycoon game**, built on top of the Tycoon
Engine via the read-only submodule contract in §1. `ROADMAP.md` is the
scope contract for *what we build next* — phases, exit criteria, and
backlog. This file is the contract for *how* we build it.

Today the game already ships an honest economic loop: build regions from
zone tiles → drop animals/infrastructure inside → engine computes appeal
from placements → visitors arrive, browse, buy food, leave with a
satisfaction score → daily settlement closes books. Adapter scripts in
`src/` implement `IAgentBehavior`, `IValueModel`, `ISatisfactionModel`,
`IQualityRating`, and `IPlaceableHappiness`; tuning lives in
`design/tuning/*.md`; the HUD covers save/load, financial reports,
region management, hover inspector, reputation, goals, welcome,
mood bubbles.

Future work — welfare, breeding, staff agents, day/night, weather,
research tree, scenarios — is sequenced in `ROADMAP.md`. Promote ideas
into a phase via the roadmap's decision log; don't slip them in silently.

---

## 1. The Prime Directive — the engine submodule is read-only

**Never modify files inside `engine/` or `addons/tycoon_core/`** (the
symlink target). If a needed capability seems to require changing engine
code, that is a SEAM LEAK and the most important thing you can do is:

  1. STOP.
  2. Write down what you wanted to change and why — that's the seam.
  3. Decide with the user whether to (a) generalize the capability in the
     engine repo and bump the tag, or (b) work around it in zoo code.

Seam leaks documented in this repo become bug reports against the engine.
Silently editing the submodule defeats the entire experiment.

---

## 2. Repository structure

```
zoo-tycoon/
  project.godot               # Godot 4.5 project (autoloads from engine)
  engine/                     # git submodule pinned to engine vN.N.N
  addons/
    tycoon_core/ -> ../engine/addons/tycoon_core   (symlink)
    gut/         -> ../engine/addons/gut           (symlink)
  src/
    behaviors/                # IAgentBehavior implementations
    models/                   # IValueModel / ISatisfactionModel / IQualityRating
    bootstrap.gd              # autoload — wires behaviors/models at startup
  design/
    tuning/                   # zoo-specific tuning (markdown, canonical)
  tests/                      # GUT integration tests
```

Symlinks let the engine's `res://addons/tycoon_core/` paths work unchanged
while keeping the submodule's full repo accessible at `engine/`. Both are
git-tracked.

---

## 3. Working rules

  1. **Engine is read-only.** See §1.
  2. **All tunable numbers live in `design/tuning/*.md`** — same rule as the
     engine. The engine's loader compiles them at startup. Never hardcode
     numbers in `.gd` files; the loader will fail loudly on malformed input.
  3. **Game-specific code lives in `src/`.** Adapter scripts here implement
     the engine's interfaces — they may not extend or modify engine types
     in `engine/`. If the engine doesn't expose what you need, that's a
     seam leak (see §1).
  4. **Tests prove the engine runs.** The smoke test in `tests/` exercises
     the full loop (visitors arriving → paying → eating → settling). If it
     goes red, the engine is broken or the tuning is wrong; never assume
     the test is wrong.

---

## 4. Upgrading the engine submodule

```sh
cd engine
git fetch
git checkout v0.2.0     # next tag
cd ..
git add engine
git commit -m "chore: bump engine to v0.2.0"
```

Read the engine's CHANGELOG before bumping — schema or interface changes
may require zoo-side adjustments.

---

## 5. Web export

The engine targets web-first. When wiring up an export later, follow the
engine's web-performance discipline (`engine/CLAUDE.md` §7): object
pooling on, no runtime asset generation, lean node counts. Generate
sprites via Pixel Lab at build time and commit them.
