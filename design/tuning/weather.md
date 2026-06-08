# Weather — Zoo

<!--
Roadmap 3.6 (Weather + seasons). Variety + another forcing function on the
economy. Both are functional (they scale guest demand) and cosmetic (HUD
readout + log). Weather is re-rolled each day from the weighted table below
(seeded, so a given seed is reproducible). Seasons cycle by day count.

Effective gate demand = ticket-bracket demand × weather × season — so a sunny
summer day packs the park and a rainy winter one thins it.

(Per-animal climate effects on welfare — desert animals unhappy in winter,
etc. — would need animal climate tags and are a noted follow-up.)

Game-side tuning (the engine doesn't read it), compiled by
src/weather_config.gd; the daily roll + demand effect live in src/bootstrap.gd.
-->

## Seasons

days_per_season = 8

## Season effects

| id     | label  | demand_multiplier |
| ------ | ------ | ----------------- |
| spring | Spring | 1.0               |
| summer | Summer | 1.2               |
| autumn | Autumn | 1.0               |
| winter | Winter | 0.7               |

## Weather

| id     | label  | demand_multiplier | weight |
| ------ | ------ | ----------------- | ------ |
| sunny  | Sunny  | 1.15              | 4      |
| cloudy | Cloudy | 1.0               | 3      |
| rainy  | Rainy  | 0.7               | 2      |
