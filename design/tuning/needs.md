# Needs — Zoo

<!--
v0.5.x — Zoo Tycoon character pack (adaptation plan §2 item 3).

Expanded from the single validation-pass hunger need to the four classic
Zoo Tycoon (2001) guest needs: hunger, thirst, restroom, energy. The
restroom need is mostly *driven* by satisfying hunger/thirst — see the
"negative spillover" rule in design/tuning/services.md — so its own base
decay is deliberately slow; eating and drinking are what fill the
bladder, not the passage of time.

Decay rates are tuned against balance.md ticks_per_day = 800 and visitor
stay_duration 730–1530 ticks (≈1–2 in-park days). They were HALVED after
playtesting: with four needs plus the eat→restroom spillover, the original
rates starved guests faster than a small park's amenities could serve them
(min-need hovered near 0), which tanked satisfaction and reputation. Gentler
decay lets a modest set of amenities keep guests content:

  - hunger   0.0008/tick → full→threshold(0.40) in ~750 ticks (≈once/visit)
  - thirst   0.0010/tick → a little faster than hunger
  - restroom 0.0005/tick → slow base; spillover from eating/drinking dominates
  - energy   0.0006/tick → slowest; guests tire late in a visit
-->

## Needs

| id       | display_name | base_decay_per_tick |
| -------- | ------------ | ------------------- |
| hunger   | Hunger       | 0.0008              |
| thirst   | Thirst       | 0.0010              |
| restroom | Restroom     | 0.0005              |
| energy   | Energy       | 0.0006              |
| food     | Animal Food  | 0.0006              |
| water    | Animal Water | 0.0007              |

<!--
food / water (6.6 animals-as-agents) — the two decaying needs for the `animal`
population. Slow enough that an animal empties roughly once an in-park day
(threshold 0.45 at ~900 ticks), so a single in-enclosure trough plus keepers
keeps a pen content; the AnimalBehavior refills these on arrival at a
provides_food / provides_water placement inside the region.
-->

