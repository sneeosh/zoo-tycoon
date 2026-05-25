# Zoo Tycoon (Engine Validation)

Minimal Zoo Tycoon built on the standalone [Tycoon Engine](./engine). Its
only purpose: prove the engine runs an end-to-end economic loop with zero
modifications to `addons/tycoon_core/`.

See [`CLAUDE.md`](./CLAUDE.md) for the operating contract and
[`engine/docs/build-plan.md`](./engine/docs/build-plan.md) §7 (Prompt 10)
for the rationale.

## Setup

```sh
git clone <this-repo> zoo-tycoon
cd zoo-tycoon
git submodule update --init --recursive
```

Open `project.godot` in Godot 4.5+. The autoloads resolve through the
`addons/tycoon_core/` symlink into the engine submodule.

## Tests

```sh
# from project root
godot --headless --import           # twice — populates the class cache
godot --headless --import
godot --headless -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit \
    -gprefix=test_ -gsuffix=.gd
```

## Repo layout

| Path | What |
|------|------|
| `engine/` | tycoon-engine submodule, pinned to a tag |
| `addons/tycoon_core/` | symlink → `engine/addons/tycoon_core/` |
| `addons/gut/` | symlink → `engine/addons/gut/` |
| `src/behaviors/` | `IAgentBehavior` impls |
| `src/models/` | `IValueModel` / `ISatisfactionModel` / `IQualityRating` impls |
| `src/bootstrap.gd` | autoload — registers behaviors/models at startup |
| `design/tuning/*.md` | canonical tuning data for this game |
| `tests/` | GUT smoke tests proving the loop runs |
