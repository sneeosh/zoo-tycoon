# Welfare — Zoo

<!--
Roadmap 3.1 (Animal welfare). A slow-moving per-animal welfare meter [0,1]
driven by the *care quality* the exhibit provides (the suitability the
happiness model already computes from space / social / needs / attitude —
NOT the welfare-discounted appeal, so there's no death-spiral feedback).

Each day:
  care = suitability of this animal (0..1)
  if care >= happiness_threshold:  welfare += recovery_per_day   (capped at 1)
  else:                            welfare -= decline_per_day * severity
                                   where severity = (threshold - care) / threshold

Effects:
  - welfare scales the animal's appeal to guests (a neglected animal draws
    fewer visitors) — applied in src/models/zoo_animal_happiness.gd.
  - welfare < illness_threshold  → the animal is "sick" (HUD alert).
  - welfare <= 0                 → the animal dies (removed; reputation hit).

Game-side tuning (the engine doesn't read this file), compiled by
src/welfare_config.gd.
-->

## Settings

happiness_threshold      = 0.5
recovery_per_day         = 0.15
decline_per_day          = 0.20
illness_threshold        = 0.35
death_reputation_penalty = 3
