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
