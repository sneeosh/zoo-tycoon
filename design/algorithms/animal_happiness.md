# Animal Happiness — Zoo Tycoon's `IPlaceableHappiness` implementation

Zoo-side spec. The engine ships `IPlaceableHappiness` as a registerable
extension point (see `engine/design/algorithms/zone_pattern.md` and
`engine/addons/tycoon_core/interfaces/i_placeable_happiness.gd`); the
engine's region-appeal math multiplies a placeable's `appeal_contribution`
by whatever happiness number the registered implementation returns. Other
games can — and will — define happiness differently (a golf hazard doesn't
have feelings; a hospital patient's mood model uses comfort, wait time,
staff presence). This document is the *zoo's* answer.

Once a placement has passed
[`engine/design/algorithms/placement_compatibility.md`](../../engine/design/algorithms/placement_compatibility.md),
it is *valid* — but valid isn't the same as *happy*. A lone wolf in a pack
animal's body, a herd of zebras crammed into a starter pen, an aviary with
half the parrots a flock wants — all valid placements, all unhappy
animals. Happiness flows through into the region's effective appeal
([`engine/design/algorithms/region_appeal.md`](../../engine/design/algorithms/region_appeal.md)):
unhappy contents drag the visit experience down.

## Intent

Each placeable inside a region scores `[0, 1]`. Start at 1.0 and subtract
penalties for the things the placeable cares about:

- **Space** below per-individual ideal (cramped)
- **Social** group too small (lonely) or too large (crowded)
- **Missing needs** — required infrastructure tags (food trough, water,
  enrichment) not present in the same region

Then multiply by **attitude** — a per-individual `[0, 1]` mood factor the
game maintains in `Placement.state["attitude"]`. The engine doesn't compute
attitude (games may model trauma, age, illness, time-since-last-feed,
etc.); it just respects whatever the game wrote there. Default attitude is
`1.0` (no modifier).

Don't reward beyond the baseline of 1.0; "perfect conditions" = 1.0,
anything less reduces. This keeps the sign convention with the region
appeal math (happiness multiplies contribution, capped at 1).

Happiness is **per placeable instance**, not per species. Five lions in one
region all share the same space + social + provided-needs context, so all
five score the same on those three factors — but each has its own
`attitude` so the final happiness can still differ per individual.

## Inputs

- `region` — `Region` from `RegionRegistry` (uses `region.area` and
  `region.placements`)
- `self_index` — which placement we're scoring (the `region.placements[self_index]`)
- For each placement, look up its `PlaceableDef` via `ContentDB.placeable_defs`

## Output

- `happiness` — float in `[0.0, 1.0]`

## Pseudocode

```
function placeable_happiness(region, self_index):
    placement = region.placements[self_index]
    self_def  = ContentDB.placeable_defs[placement.placeable_def_id]
    penalty   = 0.0

    # --- Space penalty ----------------------------------------------------
    # Even-split model: the region's cells divided across all placements.
    # Coarse but matches player intuition that "the bigger the pen, the
    # better, and crowding hurts everyone."
    actual_space = region.area / max(len(region.placements), 1)
    if actual_space < self_def.space_ideal:
        deficit = 1.0 - actual_space / self_def.space_ideal
        penalty += deficit * SPACE_WEIGHT  # SPACE_WEIGHT = 0.5

    # --- Social penalty ---------------------------------------------------
    # Count companions of the SAME species (excluding self).
    companions = count(p for p in region.placements
                       if p.placeable_def_id == self_def.id) - 1

    if companions < self_def.social_min:
        missing = self_def.social_min - companions
        penalty += missing * SOCIAL_DEFICIT_WEIGHT  # 0.1 per missing

    if companions > self_def.social_max:
        excess = companions - self_def.social_max
        penalty += excess * SOCIAL_EXCESS_WEIGHT    # 0.05 per excess

    # --- Needs penalty ----------------------------------------------------
    # Union of own_tags across all OTHER placements in the region. A lion
    # that needs `provides_food` is happy iff some other placement in the
    # same region (e.g. a Feeding Trough) has `provides_food` in its
    # own_tags. This is what makes infrastructure placeables (troughs,
    # waterers, shade structures, enrichment toys) materially affect
    # gameplay — animals without their needs met drag region appeal down.
    provided = set()
    for i, other in enumerate(region.placements):
        if i == self_index:
            continue
        provided.update(ContentDB.placeable_defs[other.placeable_def_id].own_tags)

    for required_tag in self_def.needs_provided_tags:
        if required_tag not in provided:
            penalty += NEEDS_DEFICIT_WEIGHT  # 0.2 per missing need

    base_happiness = clamp(1.0 - penalty, 0.0, 1.0)

    # --- Attitude multiplier ---------------------------------------------
    # Game-driven per-individual mood. Engine doesn't touch this — games
    # write to placement.state["attitude"] from wherever they want
    # (trauma events, age, illness, time-since-feed decay, etc.).
    attitude = float(placement.state.get("attitude", 1.0))
    attitude = clamp(attitude, 0.0, 1.0)

    return base_happiness * attitude
```

Tuning constants (`SPACE_WEIGHT`, `SOCIAL_DEFICIT_WEIGHT`,
`SOCIAL_EXCESS_WEIGHT`, `NEEDS_DEFICIT_WEIGHT`) live in
`design/tuning/balance.md` under a new `## Happiness` section so designers
can shift the curve without editing code. Initial values shown in the
pseudocode comments.

### Schema addition

```gdscript
class_name PlaceableDef
# … existing fields unchanged …

# Tags this placeable needs in its region's provided pool (= union of
# own_tags from every OTHER placement in the same region). Missing tags
# apply NEEDS_DEFICIT_WEIGHT penalty each. Empty means "no infrastructure
# needs" — typical for the infrastructure placeables themselves
# (feeding troughs, water sources) that PROVIDE tags instead of needing them.
@export var needs_provided_tags: Array[StringName] = []
```

## Worked Examples

Tuning shared across specs:

```
Animal placeables:
  lion:    space_ideal 4, social [1, 3],  needs [provides_food, provides_water]
  zebra:   space_ideal 3, social [3, 8],  needs [provides_food, provides_water]
  parrot:  space_ideal 1, social [2, 8],  needs [provides_food]
  penguin: space_ideal 1, social [4, 20], needs [provides_food]

Infrastructure placeables (own_tags shown; needs is []):
  feeding_trough:  own [provides_food, infrastructure],   space_required 1
  water_trough:    own [provides_water, infrastructure],  space_required 1

Weights:
  SPACE_WEIGHT           = 0.5
  SOCIAL_DEFICIT_WEIGHT  = 0.1
  SOCIAL_EXCESS_WEIGHT   = 0.05
  NEEDS_DEFICIT_WEIGHT   = 0.2
```

Regions (built up from zone tiles in region_detection.md):
- R_small: area=4   (small grass pen)
- R_med:   area=9   (medium pen)
- R_big:   area=16  (large pen)
- R_aviary:area=9   (8 tiles? — use 9 for math symmetry)

| # | region   | placements                     | scoring   | actual_space | companions | penalty                              | happiness |
|---|----------|--------------------------------|-----------|-------------:|-----------:|--------------------------------------|----------:|
All examples assume `attitude = 1.0` unless otherwise noted in the
"attitude" column.

| #  | region   | placements                                   | scoring   | space | comp. | needs (missing tags)   | penalty                                              | attitude | happiness |
|----|----------|----------------------------------------------|-----------|------:|------:|------------------------|------------------------------------------------------|---------:|----------:|
| 1  | R_small  | [lion]                                       | lion #0   | 4.0   | 0     | provides_food, _water  | social 0.10 + needs 0.40 = 0.50                      | 1.0      | 0.50      |
| 2  | R_med    | [lion, lion]                                 | lion #0   | 4.5   | 1     | provides_food, _water  | needs 0.40                                           | 1.0      | 0.60      |
| 3  | R_med    | [lion, lion, feeding_trough, water_trough]   | lion #0   | 2.25  | 1     | (none missing)         | space (1-2.25/4)*0.5 = 0.219                         | 1.0      | 0.78      |
| 4  | R_big    | [lion, lion, lion, lion, feeding_trough, water_trough] | lion #0 | 2.67 | 3 | (none missing)         | space (1-2.67/4)*0.5 = 0.166                         | 1.0      | 0.83      |
| 5  | R_big    | [lion]×4 + feeding_trough + water_trough     | lion #0   | 2.67  | 3     | (none missing)         | space 0.166                                          | 0.5      | 0.42      |
| 6  | R_aviary | [parrot] + feeding_trough                    | parrot #0 | 4.5   | 0     | (none missing)         | social (2-0)*0.1 = 0.20                              | 1.0      | 0.80      |
| 7  | R_aviary | [parrot]×5 + feeding_trough                  | parrot #0 | 1.5   | 4     | (none missing)         | space (1-1.5/1)? no penalty (actual ≥ ideal); social 0 | 1.0    | 1.00      |
| 8  | R_aviary | [parrot]×5 (no trough)                       | parrot #0 | 1.8   | 4     | provides_food          | needs 0.20                                           | 1.0      | 0.80      |
| 9  | R_big    | [zebra]×3 + feeding_trough + water_trough    | zebra #0  | 3.2   | 2     | (none missing)         | social (3-2)*0.1 = 0.10                              | 1.0      | 0.90      |
| 10 | R_big    | [zebra]×5 + feeding_trough + water_trough    | zebra #0  | 2.286 | 4     | (none missing)         | space (1-2.286/3)*0.5 = 0.119                        | 1.0      | 0.88      |
| 11 | R_med    | [penguin]×4 + feeding_trough                 | penguin #0| 1.8   | 3     | (none missing)         | social (4-3)*0.1 = 0.10                              | 1.0      | 0.90      |
| 12 | R_med    | [penguin]×4 (no trough)                      | penguin #0| 2.25  | 3     | provides_food          | social 0.10 + needs 0.20 = 0.30                      | 1.0      | 0.70      |
| 13 | R_med    | [lion, tiger, feeding_trough, water_trough]  | lion #0   | 2.25  | 0     | (none missing)         | space 0.219 + social 0.10 = 0.319                    | 1.0      | 0.68      |

Notes:

- Row 1 vs. row 2 vs. row 3 shows the cumulative cost of unmet needs.
  A single lion is lonely AND hungry AND thirsty (happiness 0.50). Add a
  companion (row 2): the lonely penalty disappears but needs still hit
  (0.60). Add food + water troughs (row 3): all the unmet-need penalty
  goes away; the only remaining cost is the space split across the four
  placements (now 4 things share 9 cells, 2.25 each, below lion's
  ideal 4 — penalty 0.219). Net: 0.78. *Infrastructure matters.*
- Row 5 shows the **attitude** factor in isolation. Identical to row 4
  except this lion has a game-set `attitude = 0.5` (perhaps the game
  applies it after a trauma event). Final happiness halves from 0.83 to
  0.42.
- Row 8 vs. row 7: same parrots, same space, only difference is the
  trough. Without it: 0.80. With it: 1.00. Infrastructure pays.
- Row 13: the lion + tiger pair from the previous version of this spec
  now also has needs met by the troughs, but the space split across 4
  placeables is harsher than 2.

Row 4 compounds penalties — over space *and* over social max.
Row 8 shows a fully-stocked aviary is still ideal because parrots have
tiny space needs.
Row 12 (lion + tiger): lion has 0 companions of its own species (tiger
doesn't count) → lonely. Same logic applies to the tiger.

Each row above mirrors one-to-one as a GUT test in
`tests/systems/test_placeable_happiness.gd`. Drift between table and code
is a build failure.

## Habitat axes (2026-06 extension — the ZT1 exhibit-authoring layer)

The base model above is exactly what the worked-example table and its
mirror tests exercise. On top of it, the zoo adds five **habitat axes**
driven by per-species preferences in
[`design/tuning/habitat.md`](../tuning/habitat.md) (loaded by
`src/habitat_config.gd`, injected into the model by bootstrap — a `null`
config, or a species with no entry, disables all five and reduces to the
base model):

```
penalty += terrain_weight   * Σ_tag max(0, want_frac - actual_frac)
penalty += foliage_weight   * clamp(1 - have/target, 0, 1)   # target = ceil(frac × area)
penalty += rocks_weight     * clamp(1 - have/target, 0, 1)   # rock_big counts rock_big_value
penalty += shelter_weight     if wants_shelter and none placed
penalty += enrichment_weight  if wants_enrichment and no toy placed
```

- **Terrain** compares the pen's actual zone-tile composition (fraction of
  cells carrying each zone tag, cached per region and invalidated on world
  changes) against the species' `terrain_mix`. Deficit-only: extra terrain
  the animal didn't ask for is fine.
- **Foliage** counts placements tagged `foliage`; the species' preferred
  plant family (`plant_savannah` / `plant_rainforest` / `plant_conifer`)
  counts 1.0, other plants `offtype_foliage_credit`.
- **Rocks** counts `rock_item` placements (`rock_big` counts double by
  default).
- **Shelter / enrichment** are presence checks on the `shelter` /
  `enrichment` own_tags.

Habitat dressing has `space_required 0`, and the space axis above now
splits the pen only across placements with `space_required > 0` — so
planting trees never makes the animals feel cramped. (The worked examples
are unaffected: every placeable in them has `space_required ≥ 1`.)

Tests: `tests/test_habitat.gd`.

## What this spec deliberately does NOT model (yet)

- **Mixed-species companion bonuses** — currently a lion alone with five
  zebras is lonely (zebras don't count as lions). Future: optional
  `social_kin: Array[StringName]` tags so a lion sees other big
  predators as "tolerable company."
- **Attitude dynamics in the engine.** `Placement.state["attitude"]` is
  read but never written by the engine. Games drive it. Possible game
  systems include: time-since-feed decay, trauma events (visitor scares
  prey species → attitude drop for N days), illness, age. The engine
  intentionally stays out of all of these — it just exposes the hook so
  every game can model attitude the way its theme calls for.
- **Proximity-weighted needs** — currently `provides_food` from a trough
  on the far side of a 50-cell region satisfies a lion's hunger just as
  much as one right next to it. Future: per-cell distance from the
  trough modulates whether it counts. (The same applies to the habitat
  axes — they are bag-of-placements, matching the original game's
  placement-agnostic suitability; see adaptation plan §5 item 5.)
