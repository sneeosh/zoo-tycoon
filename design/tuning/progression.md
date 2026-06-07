# Progression — Zoo

<!--
Spec: engine/docs/build-plan.md §3 (UnlockNode)

v0.4.0: the old "exhibit EntityDef" ids are gone. Unlocks now reference
zone-tile entities + amenities + the visitor agent type. Animals are
PlaceableDefs and aren't yet unlock-gated — players can place any animal
into a region once they've built it.
-->

## Unlock nodes

| id        | label         | prerequisites | cost | reputation_required | unlocks                                                            |
| --------- | ------------- | ------------- | ---- | ------------------- | ------------------------------------------------------------------ |
| start     | Starting Park |               | 0    | 0                   | grass_patch,rock_patch,cage_panel,food_stand,restroom,visitor      |
| expansion | Expansion     | start         | 0    | 10                  | water_patch                                                        |
| dining    | Fine Dining   | start         | 0    | 25                  | restaurant                                                         |
