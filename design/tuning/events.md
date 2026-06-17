# Events — Zoo

<!--
Roadmap 6.9 ("Make the day-to-day sing"). Emergent **park stories**: a
once-a-day roll that can fire a one-off event with instant and/or multi-day
effects, narrated in the HUD log + a toast. This is the layer that turns the
honest simulation into *stories you remember* — a celebrity visit, a
conservation grant, a heatwave, an animal escape — rather than a wall of
meters. It is the cheapest fun-per-line we have: every effect routes through
systems that already exist (Ledger, reputation, the spawn-rate curve).

Game-side tuning (the engine doesn't read it), compiled by
src/events_config.gd; the daily roll, effect application, expiry, and save
round-trip live in src/bootstrap.gd.

Design contract:
  - At the start of each new day with day >= min_day, and only if at least
    cooldown_days have passed since the last event, with probability
    daily_chance ONE event is drawn — by weight — from the rows whose
    `requires` gate currently passes.
  - Effects compose with the rest of the economy, they don't replace it:
      cash          posts to the Ledger immediately (+income / -expense).
      reputation    an instant rating bump; the daily reputation drift then
                    erodes it (news fades — the same model as a birth/death).
      demand_mult   scales guest arrivals for `duration_days` days
                    (duration 1 = today only). Several active demand events
                    multiply together, on top of ticket/weather/season/climate.
  - `requires` gates an event on world state so events read as *consequences*,
    not random dice:
      none         always eligible.
      animals      needs >= 1 animal placed.
      sick_animal  needs >= 1 currently-sick animal. This is the escape /
                   inspection-failure crisis — it can only happen to a zoo
                   that is already neglecting welfare, so it has teeth without
                   feeling unfair.
      reputation   needs reputation >= the row's min_reputation (a celebrity
                   only drops by a zoo that's already well regarded).
  - The roll uses a dedicated, fixed-seed RNG (see src/bootstrap.gd) so it
    never perturbs the tuned weather / breeding / spawn sequence — the same
    discipline AnimalBehavior uses for its idle wander.

Authoring rules:
  - `category` is one of positive / negative / neutral — it only drives the
    log colour + toast icon, nothing mechanical.
  - Messages are markdown-table cells, so they may NOT contain a pipe (|).
    Commas, apostrophes and em-dashes are fine.
  - Keep `id` stable; it is the save key for an active multi-day effect.
  - A row with demand_mult = 1.0 (or duration_days = 0) registers no lasting
    effect — use it for pure cash/reputation beats.
-->

## Globals

daily_chance   = 0.45
min_day        = 3
cooldown_days  = 2

## Events

| id              | label              | weight | category | requires    | min_reputation | cash  | reputation | demand_mult | duration_days | message                                                                                                              |
| --------------- | ------------------ | ------ | -------- | ----------- | -------------- | ----- | ---------- | ----------- | ------------- | -------------------------------------------------------------------------------------------------------------------- |
| celebrity_visit | Celebrity Visit    | 3      | positive | reputation  | 30             | 0     | 2          | 1.40        | 2             | A film star posted a selfie at your gates. Crowds are flocking in for the next couple of days.                        |
| tv_feature      | On the Morning Show| 4      | positive | animals     | 0              | 0     | 1          | 1.50        | 1             | A morning show filmed your exhibits. Expect a packed house today.                                                    |
| conservation_grant | Conservation Grant | 4   | positive | animals     | 0              | 1500  | 1          | 1.00        | 1             | A wildlife trust awarded your zoo a conservation grant. The cheque just cleared.                                     |
| philanthropist  | Generous Patron    | 3      | positive | animals     | 0              | 2500  | 1          | 1.00        | 1             | A wealthy patron fell in love with one of your animals and made a generous donation.                                |
| school_trip     | School Field Trip  | 4      | positive | animals     | 0              | 300   | 0          | 1.30        | 1             | Three school buses booked a field trip. The little ones are excited to see the animals.                             |
| perfect_day     | Glorious Weather   | 4      | positive | none        | 0              | 0     | 0          | 1.25        | 1             | A glorious, clear day — perfect weather to spend an afternoon at the zoo.                                            |
| inspection_pass | Inspection Passed  | 3      | positive | animals     | 0              | 0     | 3          | 1.00        | 1             | The welfare inspector toured your exhibits and left impressed by the standard of care.                              |
| heatwave        | Heatwave           | 3      | neutral  | none        | 0              | 0     | 0          | 0.70        | 2             | A blistering heatwave is keeping crowds at home. Hopefully your drink stands are well stocked.                       |
| bad_press       | Unflattering Review| 3      | negative | none        | 0              | 0     | -2         | 0.85        | 1             | A snarky review made the rounds online. A few visitors are giving the zoo a miss today.                             |
| inspection_fail | Inspection Cited   | 4      | negative | sick_animal | 0              | 0     | -3         | 1.00        | 1             | The welfare inspector cited a sick animal in your care. Clean up the exhibit before the next visit.                 |
| animal_escape   | Animal Escape!     | 5      | negative | sick_animal | 0              | -800  | -4         | 0.60        | 1             | A neglected animal slipped its enclosure! Keepers recaptured it, but guests are rattled and the press noticed. Raise welfare before it happens again. |
