# Services — Zoo

<!--
v0.5.x — Zoo Tycoon character pack (adaptation plan §2 item 3).

Per-need service parameters for the four-need guest model. Like
scenario.md, this is a *game-side* tuning file: the engine's ContentDB
doesn't read it. It's compiled in `src/service_config.gd` via the
engine's MarkdownTuningParser and consumed by VisitorBehavior +
VisitorValueModel.

Columns:
  - need_id            the guest need this row configures
  - price              cash charged when the guest satisfies this need at a
                       satisfier entity (0 = free, e.g. restroom / bench)
  - revenue_source     Ledger source id the income is booked under
  - spillover_need     a *second* need that gets worse when this one is met
                       ("" = none). This is the original game's twist:
                       eating and drinking fill the bladder.
  - spillover_amount   how much spillover_need drops (0..1) on satisfaction

The spillover is what makes restrooms matter: a guest who eats and drinks
across a long visit will need a toilet even though the restroom need's own
base decay (needs.md) is slow.
-->

## Need satisfiers

| need_id  | price | revenue_source | spillover_need | spillover_amount |
| -------- | ----- | -------------- | -------------- | ---------------- |
| hunger   | 5     | food_stand     | restroom       | 0.30             |
| thirst   | 3     | drink_stand    | restroom       | 0.40             |
| restroom | 0     | restroom       |                | 0.0              |
| energy   | 0     | bench          |                | 0.0              |
