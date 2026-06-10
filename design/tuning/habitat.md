# Habitat — per-species exhibit preferences (ZT1 suitability model)

<!--
The Zoo Tycoon (2001) exhibit-authoring layer: each species wants a
specific TERRAIN MIX (fractions of the pen's zone tiles), an amount of
FOLIAGE (fraction of pen area, with a preferred plant family), some
ROCKS, a SHELTER, and — for playful species — an ENRICHMENT toy.
Reference: design/research/zoo_tycoon_2001_reference.md §3.

Loaded zoo-side by src/habitat_config.gd (the engine never reads this
file) and consumed by src/models/zoo_animal_happiness.gd, which adds
these axes to the space/social/needs model in
design/algorithms/animal_happiness.md.

Conventions:
  - terrain_mix: comma list of zone_tag:fraction. Scored deficit-only —
    a pen missing the tag-fraction is penalized, extra is fine. Fractions
    needn't sum to 1; the remainder is "don't care".
  - foliage_frac: target foliage count as a fraction of pen area
    (e.g. 0.10 on a 20-cell pen = 2 plants). Preferred plant family
    (plant_savannah / plant_rainforest / plant_conifer) counts fully;
    other foliage counts at offtype_foliage_credit.
  - rocks_frac: same idea for rock_item placements; rock_big counts as
    rock_big_value.
  - wants_shelter / wants_enrichment: true = missing one costs the flat
    weight below.
-->

## Weights

terrain_weight = 0.45
foliage_weight = 0.18
rocks_weight = 0.10
shelter_weight = 0.12
enrichment_weight = 0.10
offtype_foliage_credit = 0.5
rock_big_value = 2

## Species habitat

| species    | terrain_mix              | foliage_frac | foliage_pref     | rocks_frac | wants_shelter | wants_enrichment |
| ---------- | ------------------------ | ------------ | ---------------- | ---------- | ------------- | ---------------- |
| lion       | grass:0.75,rocks:0.15    | 0.10         | plant_savannah   | 0.04       | true          | false            |
| tiger      | grass:0.60,water:0.10    | 0.20         | plant_rainforest | 0.04       | true          | false            |
| zebra      | grass:0.90               | 0.08         | plant_savannah   | 0          | true          | false            |
| elephant   | grass:0.70,water:0.20    | 0.10         | plant_savannah   | 0          | true          | true             |
| giraffe    | grass:0.85               | 0.15         | plant_savannah   | 0          | true          | false            |
| monkey     | tall_cage:0.80           | 0.20         | plant_rainforest | 0          | false         | true             |
| parrot     | tall_cage:0.80           | 0.15         | plant_rainforest | 0          | false         | true             |
| toucan     | tall_cage:0.80           | 0.15         | plant_rainforest | 0          | false         | false            |
| peacock    | grass:0.80               | 0.12         | plant_savannah   | 0          | false         | false            |
| penguin    | water:0.55,rocks:0.35    | 0            |                  | 0.08       | true          | false            |
| seal       | water:0.60,rocks:0.20    | 0            |                  | 0.05       | false         | true             |
| flamingo   | water:0.50,grass:0.30    | 0.06         | plant_savannah   | 0          | false         | false            |
| polar_bear | water:0.45,rocks:0.45    | 0            |                  | 0.08       | true          | true             |
