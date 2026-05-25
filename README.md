# Zoo Tycoon

A web-first tycoon game built on the standalone [Tycoon Engine](./engine).
Build exhibits from zone tiles, fill them with animals, balance the books,
and chase Zoo of the Year before 30 days run out.

**Play it:** https://sneeosh.github.io/zoo-tycoon/

See [`CLAUDE.md`](./CLAUDE.md) for the operating contract and
[`ROADMAP.md`](./ROADMAP.md) for what's shipping when. The engine submodule
is read-only — changes there cut a tag, then we bump.

## Setup

```sh
git clone <this-repo> zoo-tycoon
cd zoo-tycoon
git submodule update --init --recursive
```

Open `project.godot` in Godot 4.5+. The autoloads resolve through the
`addons/tycoon_core/` symlink into the engine submodule.

## Play it on the web

Every push to `main` builds a web export and publishes it via GitHub
Pages — see `.github/workflows/deploy.yml`. After enabling Pages in repo
settings (Source: GitHub Actions), the build lands at
`https://<owner>.github.io/zoo-tycoon/`.

To export locally:

```sh
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # then open localhost:8000
```

(You need Godot's web export templates installed for the matching Godot
version: download from godotengine.org or via the editor's
*Manage Export Templates* dialog.)

## Tests

```sh
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
| `src/scenario.gd` | win/lose params loaded from `design/tuning/scenario.md` |
| `design/tuning/*.md` | canonical tuning data |
| `tests/` | GUT smoke tests |
