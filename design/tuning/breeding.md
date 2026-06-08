# Breeding — Zoo

<!--
Roadmap 3.5 (Breeding & generations). Depends on welfare (3.1): only
well-kept animals breed. Each day, in every exhibit, for each species with
two or more adult individuals whose welfare is high enough, there's a chance
of a birth — a new animal of that species, age 0, added to the exhibit (free;
the placement's build cost is negated). Births are gated by space, so a pen
fills until overcrowding drops welfare and breeding stops — a natural
population cap, not a hard limit.

Animals also age a day each day and die of old age past max_age_days (no
reputation penalty — natural, unlike a neglect death). A small fraction of
births are "rare" milestones worth bonus reputation.

Game-side tuning (the engine doesn't read it), compiled by
src/breeding_config.gd; the daily logic lives in src/bootstrap.gd.
-->

## Settings

welfare_threshold = 0.75
chance_per_day    = 0.15
min_age_days      = 2
max_age_days      = 60
rare_chance       = 0.05
rare_reputation   = 5
