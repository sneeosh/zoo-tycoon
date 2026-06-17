# Contracts — Zoo

<!--
Roadmap 6.9 ("Make the day-to-day sing"). Short-term **contracts**: a small
rotating slate of bite-size objectives, each with a cash and/or reputation
reward, that completes and refills. This is the steady pull the single 30-day
win bar lacks — a reason to do the *next* thing, not just the last one. It
complements the cross-game Achievements (6.2, lifetime badges) and the
one-shot MILESTONES (onboarding nudges): contracts are *in-run*, *rewarded*,
and *replenishing*.

Game-side tuning (the engine doesn't read it), compiled by
src/contracts_config.gd; the slate, evaluation, reward payout and save
round-trip live in src/bootstrap.gd.

Design contract:
  - `active_slots` contracts are offered at once, drawn in table order from the
    pool, skipping any already completed this run. When one is fulfilled it
    pays out and the next undrawn pool entry takes its slot.
  - Contracts are reviewed at the end of each day (the natural settlement
    cadence). A contract whose `metric` has reached its `target` pays
    `reward_cash` to the Ledger and `reward_reputation` to the rating (the
    daily drift then prices the bump in, same as any other reputation event).
  - Progress is shown live in the HUD; only the payout waits for day close.

Supported metrics (all read from existing engine/zoo state — no new surface):
    reputation  — current rating (ProgressionManager.reputation)
    balance     — current Ledger balance
    animals     — animals placed across all exhibits
    species     — distinct animal species exhibited
    exhibits    — populated exhibits (>= 1 animal)
    revenue     — cumulative revenue this run (Accounting income statement)
    births      — animals bred this run

Authoring rules:
  - Keep `id` stable; it is the save key for completion + the active slate.
  - Order matters: the first `active_slots` rows are the opening slate, so put
    early-achievable contracts first and let the harder ones refill in behind.
  - A reward of 0 in either column is fine (a pure-cash or pure-prestige goal).
-->

## Globals

active_slots = 3

## Contracts

| id              | label             | metric     | target | reward_cash | reward_reputation | description                              |
| --------------- | ----------------- | ---------- | ------ | ----------- | ----------------- | ---------------------------------------- |
| full_house      | Full House        | animals    | 6      | 700         | 0                 | House 6 animals across your zoo.         |
| variety_show    | Variety Show      | species    | 4      | 800         | 2                 | Exhibit 4 different species.             |
| room_to_grow    | Room to Grow      | exhibits   | 4      | 600         | 0                 | Open 4 populated exhibits.               |
| first_litter    | First Litter      | births     | 1      | 500         | 3                 | Breed your first animal.                 |
| big_earner      | Big Earner        | revenue    | 5000   | 1000        | 0                 | Take $5,000 in total revenue.            |
| crowd_favorite  | Crowd Favorite    | reputation | 40     | 600         | 0                 | Reach 40 reputation.                     |
| conservationist | Conservationist   | births     | 3      | 1200        | 4                 | Breed 3 animals across generations.      |
| well_funded     | Well Funded       | balance    | 15000  | 1000        | 0                 | Build a $15,000 balance.                 |
| five_star       | Five-Star Zoo     | reputation | 60     | 1500        | 0                 | Reach 60 reputation.                     |
| menagerie       | Menagerie         | animals    | 10     | 1500        | 3                 | House 10 animals.                        |
