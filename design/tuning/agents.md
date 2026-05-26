# Agents — Zoo

<!-- Spec: engine/docs/build-plan.md §3 (AgentType, NeedSpec) -->

## Agent types

| id      | display_name | spawn_weight |
| ------- | ------------ | ------------ |
| visitor | Visitor      | 1.0          |

## Need specs

| agent_id | need_id | initial_level | decay_rate_multiplier | threshold |
| -------- | ------- | ------------- | --------------------- | --------- |
| visitor  | hunger  | 1.0           | 1.0                   | 0.4       |

## Traits

<!--
Sampled uniformly per-visitor at spawn. The behavior reads agent.traits[...]
instead of class constants so the variation lives in design data, not code.

- walking_speed:  tiles/tick when moving with intent
- stay_duration:  max ticks in the park before the visitor leaves
- impatience:     bails when satisfaction drops below this floor
                  (low = unflappable; high = leaves at first frustration)
- distance_fudge: noise added to the perceived distance to each food stand
                  when picking one. A focused visitor (low fudge) picks
                  the truly closest; a distracted one (high fudge) might
                  wander further. This is what produces the anti-swarm
                  look without explicit anti-swarm logic.
-->

| agent_id | trait          | min  | max  |
| -------- | -------------- | ---- | ---- |
| visitor  | walking_speed  | 0.12 | 0.26 |
| visitor  | stay_duration  | 730  | 1530 |
| visitor  | impatience     | 0.10 | 0.28 |
| visitor  | distance_fudge | 0.0  | 3.5  |

## Preferences

<!--
Type-level appeal-match parameters. EffectResolver.appeal_match scores
how well an exhibit's appeal_profile[axis] sits within tolerance of preferred.
Visitors gravitate to better-matching exhibits when picking a browse target.
-->

| agent_id | axis   | preferred | tolerance |
| -------- | ------ | --------- | --------- |
| visitor  | thrill | 0.5       | 0.6       |
