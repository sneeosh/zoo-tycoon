# Zoo Land Types — catalog & authoring guide

The land your zoo sits on is a **zoo type**: a climate, a buildable plot
size, and a purchase price. You pick one on the welcome screen when starting
a game, and you can sell your whole zoo mid-run to move to a different plot
(Park Admin → Land & relocation).

Everything here is data, not code. The single source of truth is
[`design/tuning/zoo_types.md`](./tuning/zoo_types.md) — **adding a new plot
or climate is a markdown edit and a restart; no GDScript changes are
needed.** This document describes the shipped catalog and then explains
exactly how to author your own.

---

## 1. The catalog

Prices assume the Standard difficulty's $10,000 starting bankroll; the
welcome screen greys out any plot that wouldn't leave you at least $5,500
to build with (`min_cash_after_purchase`). Anything you can't afford at
the start can still be reached later by selling up and relocating.

| Plot | Climate | Size (tiles) | Price | Character |
| --- | --- | --- | --- | --- |
| **Greenfield Meadow** | Temperate | 32×18 | Free | The default grounds. Neutral weather, honest demand — the baseline every other plot trades against. |
| **Halfmoon Atoll** | Tropical | 16×18 | $800 | The smallest legal plot. Tropical demand (+10%) on a shoestring, but rain is frequent and every tile is precious. A puzzle-box zoo. |
| **Sunbaked Mesa** | Desert | 22×18 | $1,500 | Compact and almost never rained out — desert skies roll sunny 2.5× as often. Small land, reliable gate. |
| **Riverbend Flats** | Wetland | 28×18 | $2,000 | Mid-sized and cheap because the weather is against you: rain rolls nearly twice as often and demand sits 5% under par. |
| **Larchwood Taiga** | Tundra | 36×26 | $2,400 | The best acreage-per-dollar in the catalog. Cold (−15% demand, grey skies) but enormous — build wide, price tickets low. |
| **Gullwing Cliffs** | Coastal | 26×20 | $2,800 | Sea air: a touch more sun *and* cloud, demand at par. A balanced step up from the Meadow with a different rhythm. |
| **Frostfell Reach** | Tundra | 40×24 | $3,000 | Huge icefield grounds at a discount. Same cold economics as the Taiga, even more room. |
| **Acacia Plains** | Savanna | 34×20 | $3,500 | Big, golden, sunny (2× sun weight, +5% demand). The natural home for a large-exhibit safari park. |
| **Eagle's Perch** | Alpine | 24×22 | $3,800 | A mountain terrace. Demand runs 10% light and clouds linger, but it's a roomy, dramatic mid-size plot. |
| **Cypress Riviera** | Mediterranean | 30×18 | $4,200 | Premium weather — near-desert sunshine with +10% demand. Pays for itself if you can serve the crowds it pulls. |
| **Emerald Lagoon** | Tropical | 36×20 | $4,500 | Sprawling rainforest acreage with tropical demand. Budget for rainy days: they come 2.2× as often. |
| **Crownleaf Estate** | Temperate | 44×26 | $7,500 | The largest grounds money can buy, on neutral weather. Out of reach of a Standard start — sell a thriving zoo and move here. |

### How climate actually plays

A climate does two things, both visible in the table in
`zoo_types.md ## Climates`:

1. **`demand_multiplier`** — a flat scale on guest arrivals, composing with
   weather, season, ticket bracket, and difficulty. Tropical/Mediterranean
   (+10%) plots are busier every single day; tundra (−15%) plots are
   quieter and priced accordingly.
2. **Weather-weight multipliers** (`sunny` / `cloudy` / `rainy` columns) —
   these multiply the daily weather roll's weights from
   [`design/tuning/weather.md`](./tuning/weather.md). Weather then feeds
   demand again (sunny days are +15%, rainy days −30%), so a desert plot's
   real advantage is that its *bad* weather days are rare.

### Selling & relocating

Selling recovers `resale_fraction` (75%) of the land's purchase price plus
the standard sell-back on everything you built — half the build cost of
every animal and placement, and the engine's refund fraction of every
building's invested cost. The whole zoo is demolished, guests go home
(without filing reputation verdicts), and you start the new plot empty.
The estimate shown in Park Admin is exact — it's computed with the same
arithmetic as the actual postings.

---

## 2. Adding your own zoo type

Open [`design/tuning/zoo_types.md`](./tuning/zoo_types.md) and add a row.
That's it — the loader (`src/zoo_type_config.gd`) compiles the file at
startup, the welcome screen, Park Admin, save files, views, and tests all
iterate whatever it contains.

### Plot columns (`## Plots`)

| Column | Meaning | Rules |
| --- | --- | --- |
| `id` | Stable identifier, saved into save files | Unique. Don't rename one that players may have saves on. |
| `label` | Display name in the UI | — |
| `climate` | Which `## Climates` row applies | Must name an existing climate id. |
| `plot_w`, `plot_h` | Buildable grid size in tiles | Minimum **16 × 18**. The entrance gate sits at `(0, plot_h − 1)`; the pre-built starter park is authored for an 18-row plot and shifts down on taller ones, and it needs 16 columns. Rows below the minimum are rejected at load with an error. |
| `cost` | Purchase price | `0` on exactly one row marks the default plot (first free row wins). Keep `starting_cash − cost ≥ min_cash_after_purchase` for at least one difficulty or the plot is only reachable via relocation — which can be a deliberate design, see Crownleaf Estate. |
| `blurb` | One flavor sentence, shown on the welcome screen and tooltips | — |

### Climate columns (`## Climates`)

| Column | Meaning |
| --- | --- |
| `id`, `label` | Identifier (referenced by plots) and display name. Unique ids. |
| `demand_multiplier` | Flat scale on guest arrivals while on this climate. `1.0` = neutral. Stay roughly within `0.8–1.2`; this multiplies *every* day of the run. |
| one column per weather id | Multiplier on that weather's daily roll weight. Column names must match the ids in `weather.md ## Weather` (currently `sunny`, `cloudy`, `rainy`). `0` makes a weather impossible; `1.0` is neutral. If you add a new weather to `weather.md`, add a matching column here — unknown weathers default to ×1. |

### Pricing guidance

A plot's value is land area × climate quality. The shipped catalog prices
roughly along `cost ≈ (tiles − 576) × 4 + climate premium`, where 576 is
the free Meadow's area and sunny/high-demand climates carry a $1–2k
premium while cold/wet ones carry a discount. You don't have to follow
that curve — but remember two hard numbers when you price:

- **$5,500** (`min_cash_after_purchase`): the working capital the welcome
  screen protects, sized so staging the pre-built starter park (~$5,100)
  can never strand a new game broke.
- **75%** (`resale_fraction`): what the player gets back on the land when
  they move on, so overpriced land is also an overpriced *exit*.

### Validation — what the loader enforces

`ZooTypeConfig.load_from_tuning()` pushes a loud error and **skips the
row** when: the plot is under 16×18, names an unknown climate, or reuses
an id. A file with zero valid plots falls back to the historical 32×18
grid. Run the GUT suite (`tests/test_zoo_types.gd`) after editing — it
validates every row generically (size minimums, climate resolution,
unique ids, a free default plot) and stages the starter park on every
plot in the file, so a bad row fails fast instead of corrupting a save.
