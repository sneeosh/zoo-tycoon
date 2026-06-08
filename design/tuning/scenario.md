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

## Difficulties

<!--
Roadmap 2.6 — Easy / Standard / Hard as a tuning overlay (no forked configs).
Picking a difficulty at the welcome screen overrides the ## Goal targets and
sets the starting cash + a global guest-demand multiplier. Standard mirrors
## Goal so the default play is unchanged. Each row, in order of difficulty:

  - starting_cash:      opening balance
  - target_cash / _rep: the win bar
  - days_limit:         days to reach it
  - demand_multiplier:  global scale on guest arrivals (easier = busier)
-->

| id       | label    | starting_cash | target_cash | target_reputation | days_limit | demand_multiplier |
| -------- | -------- | ------------- | ----------- | ----------------- | ---------- | ----------------- |
| easy     | Easy     | 14000         | 15000       | 35                | 40         | 1.20              |
| standard | Standard | 10000         | 20000       | 50                | 30         | 1.00              |
| hard     | Hard     | 7000          | 28000       | 70                | 24         | 0.80              |
