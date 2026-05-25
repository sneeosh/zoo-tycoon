# Scenario — Zoo

<!--
Win + lose conditions for the default tycoon scenario, per ROADMAP §1.2.
Parsed in `src/scenario.gd` via the engine's MarkdownTuningParser. The
engine itself doesn't read this file — these are zoo-side gameplay
parameters layered on top of the engine's economy.md.

The contract:
  - Win: balance >= target_cash AND reputation >= target_reputation,
    achieved before the end of day == days_limit.
  - Lose (bankruptcy): balance < bankruptcy_threshold after day settlement.
  - Lose (timeout): day_limit elapses without the win conditions met.
-->

## Goal

target_cash             = 20000
target_reputation       = 50
days_limit              = 30
bankruptcy_threshold    = 0
