# Staff — Zoo

<!--
Roadmap 3.3 (Staff agents). Zookeepers as a hire/assign management layer: you
hire keepers for a daily wage, and they tend your exhibits — adding to each
animal's welfare every day, so labor can keep a less-than-perfect exhibit
healthy. Keepers are auto-distributed evenly across populated exhibits, so the
per-exhibit care is (keepers / exhibits) × keeper_welfare_bonus. The decision:
wages now vs. sick/dying animals (and the reputation + lost-asset cost of a
death) later.

(A future version can make keepers visible path-walking agents — a second
population — and let the player assign them per exhibit. The effect model here
is independent of that, so it can be layered on without rebalancing.)

Game-side tuning (the engine doesn't read it), compiled by
src/staff_config.gd; the daily effect + wages live in src/bootstrap.gd.
-->

## Settings

keeper_wage_per_day  = 25
keeper_welfare_bonus = 0.12
max_keepers          = 12
