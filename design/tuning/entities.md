# Entities — Zoo

<!--
Spec: engine/docs/build-plan.md §3 (EntityDef, Effect)

Build-plan §7 (Prompt 10) target: 2–3 animal exhibits + 1 food stand + 1
restroom. Restroom has no need attached for now — it's a placeholder for
the next expansion.

Exhibits contribute satisfaction to nearby visitors via SATISFACTION
effects (proximity = a few tiles). The food stand is the only entity
that satisfies a need (hunger) AND produces revenue.
-->

## Entities

| id               | display_name      | build_cost | maintenance_cost | footprint_x | footprint_y | sprite_key       | satisfies | appeal_profile |
| ---------------- | ----------------- | ---------- | ---------------- | ----------- | ----------- | ---------------- | --------- | -------------- |
| lion_exhibit     | Lion Exhibit      | 500        | 10               | 3           | 3           | lion             |           | thrill:0.7     |
| elephant_exhibit | Elephant Exhibit  | 600        | 12               | 4           | 4           | elephant         |           | thrill:0.5     |
| aviary           | Bird Aviary       | 300        | 5                | 3           | 3           | aviary           |           | thrill:0.3     |
| food_stand       | Food Stand        | 200        | 3                | 2           | 2           | food_stand       | hunger    |                |
| restroom         | Restroom          | 150        | 2                | 1           | 1           | restroom         |           |                |

## Effects

| id              | entity_id        | target       | operation | magnitude | proximity | conditions |
| --------------- | ---------------- | ------------ | --------- | --------- | --------- | ---------- |
| lion_thrill     | lion_exhibit     | satisfaction | add       | 0.02      | 4.0       |            |
| elephant_thrill | elephant_exhibit | satisfaction | add       | 0.015     | 4.0       |            |
| aviary_thrill   | aviary           | satisfaction | add       | 0.01      | 4.0       |            |
| food_revenue    | food_stand       | revenue      | add       | 2.0       | 3.0       |            |
