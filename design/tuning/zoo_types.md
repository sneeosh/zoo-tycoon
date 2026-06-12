# Zoo types — land plots & climates

<!--
The land the player buys at the welcome screen (and can trade mid-run via
Park Admin → Land & relocation). Each plot is a climate + a buildable grid
size + a purchase price. Game-side tuning (the engine doesn't read it),
compiled by src/zoo_type_config.gd; purchase/sale/relocation logic lives in
src/bootstrap.gd.

Plot constraints (validated by the loader, which skips bad rows loudly):

  - plot_w >= 16, plot_h >= 18 — the smallest grid the pre-built starter
    park (src/starter_park.gd) and the entrance-gate column fit into.
    The gate always sits at (0, plot_h - 1); the starter layout is
    authored against an 18-row plot and shifts down on taller ones.
  - climate must name a row in ## Climates.

Pricing: land is paid out of starting cash before the starter park is
staged, so the welcome screen only offers plots that leave at least
min_cash_after_purchase to build with (staging the pre-built park costs
~$5,100; see design/tuning/entities.md + placeables.md). The default plot
is free so the canonical Standard run — the winnability bar the
integration suite regression-tests — is unchanged.
-->

## Land

resale_fraction         = 0.75
min_cash_after_purchase = 5500

## Plots

<!--
cost 0 marks the default plot (the one new games and old saves start on).
blurb is the welcome-screen flavor line.
-->

| id      | label             | climate   | plot_w | plot_h | cost | blurb                                                          |
| ------- | ----------------- | --------- | ------ | ------ | ---- | -------------------------------------------------------------- |
| meadow  | Greenfield Meadow | temperate | 32     | 18     | 0    | The classic park grounds — mild weather and room to grow.       |
| mesa    | Sunbaked Mesa     | desert    | 22     | 18     | 1500 | A compact desert lot. Sunny days come often and pack the gate.  |
| glacier | Frostfell Reach   | tundra    | 40     | 24     | 3000 | Huge icefield acreage at a discount — guests brave the cold.    |
| lagoon  | Emerald Lagoon    | tropical  | 36     | 20     | 4500 | Sprawling rainforest grounds. Lush and busy, but it rains.      |

## Climates

<!--
demand_multiplier scales gate demand all season (composes with weather,
season, ticket bracket and difficulty in ZooBootstrap._apply_spawn_rate).
The remaining columns multiply the ## Weather roll weights in
design/tuning/weather.md — desert almost never rolls rain, the tropics
roll it often. Column names must match weather ids.
-->

| id        | label     | demand_multiplier | sunny | cloudy | rainy |
| --------- | --------- | ----------------- | ----- | ------ | ----- |
| temperate | Temperate | 1.00              | 1.0   | 1.0    | 1.0   |
| desert    | Desert    | 1.05              | 2.5   | 0.8    | 0.25  |
| tundra    | Tundra    | 0.85              | 0.6   | 1.6    | 1.1   |
| tropical  | Tropical  | 1.10              | 0.7   | 1.0    | 2.2   |
