# Balance — Zoo

<!--
Spec: engine/docs/build-plan.md §3 (BalanceConfig)
Parsed by ContentDB at startup into the engine's BalanceConfig Resource.
-->

## Time

ticks_per_day      = 240
days_per_period    = 7

## Spawn curve

spawn_curve_min_multiplier   = 0.25
spawn_curve_max_multiplier   = 3.0
spawn_curve_midpoint         = 0.5
spawn_curve_steepness        = 6.0

## Entities

remove_refund_fraction       = 0.5

## Agents

base_spawn_rate              = 0.5
