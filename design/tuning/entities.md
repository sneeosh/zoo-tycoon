# Entities — Zoo

<!--
v0.4.0: switched from "one exhibit EntityDef = whole enclosure" to the
engine's zone-tile / placeable model. Now there are:

  - Zone tiles: 1-cell entities the player places to define exhibit shape.
    Adjacent same-kind tiles auto-merge into a Region (engine handles).
  - Amenities: traditional entities (food stand, restroom) that aren't
    inside an exhibit. Same model as before.

Animals + infrastructure (feeding troughs, water troughs) are PlaceableDefs
in placeables.md — they go inside regions, not on the grid directly.
-->

## Entities

| id          | display_name    | build_cost | maintenance_cost | footprint_x | footprint_y | sprite_key   | satisfies | appeal_profile | zone_kind | zone_tags    | walkable |
| ----------- | --------------- | ---------- | ---------------- | ----------- | ----------- | ------------ | --------- | -------------- | --------- | ------------ | -------- |
| grass_patch | Grass Enclosure | 60         | 1                | 1           | 1           | grass_patch  |           |                | pen       | grass        |          |
| rock_patch  | Rocky Enclosure | 90         | 1                | 1           | 1           | rock_patch   |           |                | pen       | grass,rocks  |          |
| water_patch | Water Enclosure | 140        | 2                | 1           | 1           | water_patch  |           |                | pen       | water,grass  |          |
| cage_panel  | Aviary Cage     | 120        | 2                | 1           | 1           | cage_panel   |           |                | aviary    | tall_cage,grass |       |
| path        | Path            | 15         | 0                | 1           | 1           | path         |           |                |           |              | true     |
| food_stand  | Food Stand      | 200        | 3                | 2           | 2           | food_stand   | hunger    |                |           |              |          |
| drink_stand | Drink Stand     | 160        | 2                | 1           | 1           | food_stand   | thirst    |                |           |              |          |
| restroom    | Restroom        | 150        | 2                | 1           | 1           | restroom     | restroom  |                |           |              |          |
| bench       | Bench           | 80         | 1                | 1           | 1           | bench        | energy    |                |           |              |          |
| compost     | Compost Building| 400        | 0                | 2           | 2           | compost      |           |                |           |              |          |
| restaurant  | Restaurant      | 1200       | 8                | 2           | 2           | food_stand   | hunger,thirst,restroom,energy |  |           |              |          |
| arena       | Arena           | 1500       | 15               | 3           | 3           | arena        |           |                |           |              |          |

## Effects

<!--
Visitor revenue from the food stand stays at the entity level — it's a
direct service interaction (visitor walks up, buys food). Exhibit appeal
is no longer at the entity level — it's computed from a region's
placements via the engine's compute_region_appeal (see
engine/design/algorithms/region_appeal.md).
-->

<!--
Compost Building (adaptation plan §2 item 8): zero-upkeep, high-margin, but
"stinky". It earns by composting the litter of the crowd around it — a
revenue effect scaling with nearby guests (wide radius) — while a tight
satisfaction penalty drives off guests who stand too close. The placement
puzzle: park it near guest flow to earn, but away from where they linger.
-->

| id              | entity_id  | target       | operation | magnitude | proximity | conditions |
| --------------- | ---------- | ------------ | --------- | --------- | --------- | ---------- |
| food_revenue    | food_stand | revenue      | add       | 2.0       | 3.0       |            |
| compost_revenue | compost    | revenue      | add       | 1.5       | 6.0       |            |
| compost_stink   | compost    | satisfaction | add       | -0.08     | 2.5       |            |
