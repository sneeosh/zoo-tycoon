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

## Donations

<!--
Adaptation plan §2 item 5. A Donation Box placed inside an exhibit lets
happy guests tip while they watch the animals — turning guest enjoyment
into per-exhibit income instead of only gate take. A guest rolls once per
exhibit view (when they arrive to linger):

  if satisfaction >= donation_min_satisfaction and rng < donation_view_chance:
      amount = round(donation_amount_max * satisfaction * exhibit_appeal)

where exhibit_appeal is the exhibit's strongest appeal axis (0..1), so a
well-built crowd-pleaser earns more tips than a dull pen. Minimum $1 when
a donation fires at all.
-->

donation_view_chance      = 0.35
donation_amount_max       = 6
donation_min_satisfaction = 0.55

## Guest types

<!--
Adaptation plan §2 item 2 — per-archetype spend. spend_multiplier scales
everything a guest of that type pays: the gate ticket, food/drink/meals, and
donations. A Family is a whole party (2.2×); a Child spends little on their
own (0.5×); an Enthusiast splurges and tips (1.4×); an Adult is the 1.0
baseline. This is what makes the guest mix — driven by which exhibits you
build — show up in the books. Archetype ids must match agents.md; an
unlisted type defaults to 1.0.
-->

| agent_id   | spend_multiplier |
| ---------- | ---------------- |
| visitor    | 1.0              |
| child      | 0.5              |
| family     | 2.2              |
| enthusiast | 1.4              |

## Day cycle

<!--
Roadmap 3.4 (day/night + opening hours). Opening hours as a fraction of the
day in [0,1) — derived from SimClock (current_tick % ticks_per_day). Guests
only arrive while the park is open; it empties through the evening as the
last visitors finish up. open_end < 1.0 leaves a closed stretch each night
so the day has a rhythm instead of a flat 24-hour spawn.

(Nocturnal animals shifting appeal by time is a planned follow-up — it needs
a time factor in appeal scoring and is noted as an engine time-hook.)
-->

open_start = 0.0
open_end   = 0.80
