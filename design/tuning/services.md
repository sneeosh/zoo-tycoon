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

## Ticket brackets

<!--
Adaptation plan §2 item 4 — bracketed gate pricing replaces the old
continuous ±\$5 entry fee. Four brackets, each trading price against demand:

  - demand_multiplier scales the park's base spawn rate (visitors/sec). It
    composes on top of the engine's satisfaction→spawn curve, so a cheap
    ticket and a happy park stack.

The intentional tension: gate revenue per head rises with price, but cheaper
tickets pull a bigger crowd that spends more on food / drink / donations and
turns over reputation faster. Effective gate revenue (price × demand) is
deliberately flattest in the middle so no single bracket dominates:

  budget   5 × 1.35 = 6.75   standard 10 × 1.0  = 10.0
  premium 18 × 0.70 = 12.6   exclusive 30 × 0.4 = 12.0

`default = true` marks the bracket a new park starts on (and the value
VisitorValueModel falls back to). Exactly one row should set it.
-->

| id        | label     | price | demand_multiplier | default |
| --------- | --------- | ----- | ----------------- | ------- |
| budget    | Budget    | 5     | 1.35              |         |
| standard  | Standard  | 10    | 1.0               | true    |
| premium   | Premium   | 18    | 0.70              |         |
| exclusive | Exclusive | 30    | 0.40              |         |
