# Agents — Zoo

<!-- Spec: engine/docs/build-plan.md §3 (AgentType, NeedSpec) -->

## Agent types

<!--
v0.5.x — guest archetypes (adaptation plan §2 item 2). Four guest types, each
a distinct AgentType the engine spawns by weight, sharing the one
VisitorBehavior / VisitorSatisfactionModel (registered for all four in
bootstrap.gd) but differing in appeal preferences, need-decay rates, traits,
and spend. The id `visitor` is the Adult baseline (kept so existing saves /
tests still reference it). Archetypes make exhibit-mix decisions matter: a
park of cute penguins pulls families and children; one of dangerous big cats
pulls enthusiasts.
-->

| id         | display_name | spawn_weight |
| ---------- | ------------ | ------------ |
| visitor    | Adult        | 1.0          |
| child      | Child        | 0.6          |
| family     | Family       | 0.8          |
| enthusiast | Enthusiast   | 0.4          |

## Need specs

<!--
Per-archetype need decay (decay_rate_multiplier scales the base rate in
needs.md). Children run hot on every need and tire fast; families need
restrooms most (kids in tow); enthusiasts are low-maintenance and focused.
-->

| agent_id   | need_id  | initial_level | decay_rate_multiplier | threshold |
| ---------- | -------- | ------------- | --------------------- | --------- |
| visitor    | hunger   | 1.0           | 1.0                   | 0.40      |
| visitor    | thirst   | 1.0           | 1.0                   | 0.40      |
| visitor    | restroom | 1.0           | 1.0                   | 0.45      |
| visitor    | energy   | 1.0           | 1.0                   | 0.35      |
| child      | hunger   | 1.0           | 1.4                   | 0.40      |
| child      | thirst   | 1.0           | 1.3                   | 0.40      |
| child      | restroom | 1.0           | 1.2                   | 0.45      |
| child      | energy   | 1.0           | 1.4                   | 0.35      |
| family     | hunger   | 1.0           | 1.1                   | 0.40      |
| family     | thirst   | 1.0           | 1.1                   | 0.40      |
| family     | restroom | 1.0           | 1.4                   | 0.45      |
| family     | energy   | 1.0           | 1.1                   | 0.35      |
| enthusiast | hunger   | 1.0           | 0.8                   | 0.40      |
| enthusiast | thirst   | 1.0           | 0.9                   | 0.40      |
| enthusiast | restroom | 1.0           | 0.8                   | 0.45      |
| enthusiast | energy   | 1.0           | 0.7                   | 0.35      |

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

Per archetype: children are fast, antsy, distractible and leave early;
families amble, herd kids, and stay long; enthusiasts stay longest, are
unflappable, and beeline (low fudge).
-->

| agent_id   | trait          | min  | max  |
| ---------- | -------------- | ---- | ---- |
| visitor    | walking_speed  | 0.12 | 0.26 |
| visitor    | stay_duration  | 730  | 1530 |
| visitor    | impatience     | 0.10 | 0.28 |
| visitor    | distance_fudge | 0.0  | 3.5  |
| child      | walking_speed  | 0.16 | 0.30 |
| child      | stay_duration  | 400  | 900  |
| child      | impatience     | 0.20 | 0.40 |
| child      | distance_fudge | 1.0  | 4.0  |
| family     | walking_speed  | 0.10 | 0.20 |
| family     | stay_duration  | 900  | 1800 |
| family     | impatience     | 0.08 | 0.20 |
| family     | distance_fudge | 0.0  | 2.5  |
| enthusiast | walking_speed  | 0.14 | 0.24 |
| enthusiast | stay_duration  | 1200 | 2200 |
| enthusiast | impatience     | 0.05 | 0.15 |
| enthusiast | distance_fudge | 0.0  | 1.5  |

## Preferences

<!--
Type-level appeal-match parameters. EffectResolver.appeal_match scores
how well an exhibit's appeal_profile[axis] sits within tolerance of preferred.
Visitors gravitate to better-matching exhibits when picking a browse target.
Axes come from placeables.md appeal_contribution: thrill, danger, beauty,
herd_appeal, exotic, cute.

  - Adult:      broad taste — beauty + exotic.
  - Child:      cute + thrill (penguins, lions doing tricks).
  - Family:     cute + beauty (kid-friendly crowd-pleasers).
  - Enthusiast: exotic + danger + thrill, with tight tolerance (picky).
-->

| agent_id   | axis   | preferred | tolerance |
| ---------- | ------ | --------- | --------- |
| visitor    | beauty | 0.6       | 0.6       |
| visitor    | exotic | 0.5       | 0.6       |
| child      | cute   | 0.8       | 0.5       |
| child      | thrill | 0.6       | 0.6       |
| family     | cute   | 0.7       | 0.6       |
| family     | beauty | 0.6       | 0.6       |
| enthusiast | exotic | 0.8       | 0.4       |
| enthusiast | danger | 0.6       | 0.5       |
| enthusiast | thrill | 0.7       | 0.5       |
