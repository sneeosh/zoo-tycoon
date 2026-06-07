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
stay_duration 730–1530 ticks (≈1–2 in-park days):

  - hunger   0.0015/tick → full→threshold(0.40) in ~400 ticks (≈twice/day)
  - thirst   0.0018/tick → faster than hunger; guests drink more often
  - restroom 0.0008/tick → slow base; spillover from eating/drinking dominates
  - energy   0.0011/tick → full→threshold(0.35) in ~590 ticks (≈once/stay)
-->

## Needs

| id       | display_name | base_decay_per_tick |
| -------- | ------------ | ------------------- |
| hunger   | Hunger       | 0.0015              |
| thirst   | Thirst       | 0.0018              |
| restroom | Restroom     | 0.0008              |
| energy   | Energy       | 0.0011              |
