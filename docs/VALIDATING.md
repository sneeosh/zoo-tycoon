# How to validate this branch

The 6.9 "make the day-to-day sing" cluster (emergent events, contracts, zoo
identity, economic levers, scenarios) was authored in an environment **without
a Godot binary or the engine submodule checked out**, so every change was
verified by static review only. Before merging, run it against a real Godot.

In a **Claude Code on the web** session the `SessionStart` hook
(`.claude/hooks/session-start.sh`) does steps 1–4 automatically and prints the
GUT summary. To do it by hand (or locally), follow the checklist.

## Prerequisites

- **Godot 4.5.1** (standard Linux build runs headless; web export also needs
  the matching 4.5.1 export templates).
- The engine submodule checked out (it's read-only — see `CLAUDE.md` §1).

```sh
git submodule update --init --recursive
```

## Checklist

1. **Import cleanly (this is the GDScript "lint").** Two cold passes; the
   second resolves all resources. Watch for parse/compile errors — a typo in
   any `.gd` file shows up here.

   ```sh
   godot --headless --import
   godot --headless --import
   ```

2. **Boot the project** without script errors (autoloads parse + `_ready`
   runs). `ZooBootstrap` wires the new systems on boot, so a bad signal/Method
   surfaces immediately.

3. **Run the GUT suite — expect green.** The cluster added five test files
   (`test_events`, `test_contracts`, `test_zoo_identity`, `test_finance`,
   `test_scenarios`).

   ```sh
   tools/run_tests.sh                # whole suite
   tools/run_tests.sh test_events    # one file
   ```

4. **Web export** packs without error (and includes the new tuning — the
   `design/tuning/*.md` glob in `export_presets.cfg` already covers
   `events.md`, `contracts.md`, `finance.md`).

   ```sh
   godot --headless --export-release "Web" build/web/index.html
   ```

## Smoke-test the new systems by hand

- **Events (6.9 A/B):** play a few days; a log line + toast should fire
  (celebrity visit, grant, heatwave…). Let an animal go sick (no keepers, poor
  habitat) and confirm the **animal-escape** / inspection events can trigger.
- **Contracts (6.9 C):** the **CONTRACTS** HUD panel shows three objectives;
  meeting one (e.g. house 6 animals) pays out at day close with a toast and the
  slot refills.
- **Zoo identity (6.9 D):** name the zoo on the welcome screen → it shows in the
  top bar, the settings About panel, and the win/lose title. A busy donation
  exhibit appears as the **★ star attraction** stat.
- **Economic levers (6.9 E):** gate → Park Admin → **Financing**: take a loan
  (cash now, daily repayment) and accept a sponsor (bonus + daily income, −rep).
- **Scenarios (6.9 F):** the welcome screen offers **Rescue Zoo / Shoestring /
  Frozen Frontier** alongside Easy/Standard/Hard; picking one defaults the land
  plot and shows its blurb in the MISSION panel.

## Save-compat note

The save payload went **v4 → v8** across this cluster (events, contracts,
identity, finance). Each bump is additive with a defaulting reader and a
migration note in `ZooBootstrap._migrate_game_state`; loading an older save is
covered, but it's worth loading a pre-cluster save once to confirm.
