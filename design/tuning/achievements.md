# Achievements — milestones a launched zoo game lives on (roadmap 6.2).
#
# Each row is one achievement. `metric` names a value the Achievements
# autoload knows how to read; the achievement unlocks the moment that metric
# first reaches `threshold`. Keep `id` stable — it is the save key.
#
# Supported metrics (all observed engine/zoo-side, no new engine surface):
#   balance       — Ledger balance (peak seen)
#   reputation    — ProgressionManager reputation (peak seen)
#   day           — in-game day reached
#   guests        — cumulative guest departures (lifetime, across games)
#   happy_guests  — cumulative happy departures
#   births        — cumulative animal births
#   rare_births   — cumulative rare-genome births

## Achievements

| id | label | description | metric | threshold |
|----|-------|-------------|--------|-----------|
| open_for_business | Open for Business | Welcome your first guest. | guests | 1 |
| word_of_mouth | Word of Mouth | Send 100 guests home happy. | happy_guests | 100 |
| crowd_pleaser | Crowd Pleaser | Host 1,000 guests in total. | guests | 1000 |
| first_payday | First Payday | Build a balance of $10,000. | balance | 10000 |
| tycoon | Tycoon | Build a balance of $50,000. | balance | 50000 |
| beloved | Beloved | Reach 50 reputation. | reputation | 50 |
| landmark | Landmark | Reach 80 reputation. | reputation | 80 |
| settling_in | Settling In | Keep the zoo running to day 10. | day | 10 |
| institution | Institution | Keep the zoo running to day 30. | day | 30 |
| new_arrival | New Arrival | Breed your first animal. | births | 1 |
| menagerie | Menagerie | Breed 10 animals across generations. | births | 10 |
| rare_genome | Rare Genome | Breed a rare-genome animal. | rare_births | 1 |
