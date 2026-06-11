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

## Reputation

<!--
The zoo's reputation is a RATING, not a lifetime tally. Each day the guests
who left render a verdict, and reputation drifts toward that verdict — so a
rough opening week is a hole you can climb out of, and a great week must be
*sustained* to hold a high rating. (The 2026-06-09 playtest showed the old
unbounded ±1-per-departure counter made Standard unwinnable: −89 by day 30
with no path back. See design/playtest/fable_report_2026-06-09.md.)

The model, settled once per day in ZooBootstrap:

  day_score = clamp(day_score_scale × (happy − unhappy) / departures, −100, 100)
  reputation += round((day_score − reputation) × daily_adapt_rate)

  - happy_threshold / unhappy_threshold: a departing guest's recency-weighted
    mood at or above happy_threshold counts as a happy departure (+), below
    unhappy_threshold as an unhappy one (−); in between is forgettable.
  - day_score_scale: how loudly the net margin converts into a 0–100 verdict.
    125 means "60% happy / 10% unhappy" scores ~62 — a strong day.
  - daily_adapt_rate: fraction of the gap closed per day. 0.35 ≈ a sustained
    verdict is fully priced in after ~5 days.
  - No-departure days leave reputation untouched (an empty park is no news).

Instant reputation events (a neglect death's penalty, a rare birth's press
bump) still apply immediately on top — the drift then erodes them, which is
the point: news fades, the rating reflects how the zoo runs *now*.
-->

happy_threshold     = 0.68
unhappy_threshold   = 0.42
day_score_scale     = 125
daily_adapt_rate    = 0.35
