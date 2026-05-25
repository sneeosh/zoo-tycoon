# CLAUDE.md — Zoo Tycoon (Engine Validation)

Operating rules for working in this repo. Read fully before making changes.

This repo is the **validation game** for the Tycoon Engine — Prompt 10 in
`engine/docs/build-plan.md`. The engine itself lives in the submodule at
`engine/` (pinned to a tagged release). The actual addon is at
`engine/addons/tycoon_core/` and is symlinked into `addons/tycoon_core/` so
the engine's autoload paths (`res://addons/tycoon_core/...`) work unchanged.

The engine's contract is in `engine/CLAUDE.md` — read it. **Everything that
file says about the engine continues to apply when working here.** Zoo work
must not pretend the engine is malleable.

---

## 0. What this repo is — and what it is NOT

This is a **deliberately minimal Zoo Tycoon**. Its only purpose is to prove
that the engine works end-to-end with ZERO modifications to the submodule:

  - 2–3 animal exhibits + 1 food stand + 1 restroom
  - One visitor `AgentType` with a single "hunger" need
  - Adapter scripts implementing `IAgentBehavior`, `IValueModel`,
    `ISatisfactionModel`, and `IQualityRating`
  - Just enough tuning data in `design/tuning/*.md` to run an economic
    loop: visitors arrive → pay ticket → buy food → satisfaction drives
    spawn → daily settlement

A **full** Zoo Tycoon (welfare, breeding, suitability, two agent
populations, …) is a different repo down the road. Do not bolt features
onto this validation repo.

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
