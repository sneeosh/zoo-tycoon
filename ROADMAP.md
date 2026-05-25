# Zoo Tycoon — Product Roadmap

**Status:** Living document. Last updated 2026-05-25.
**Owner:** Kenny Johnson (PM + Eng).
**Audience:** development + design team.

> **This is the Zoo Tycoon repo.** It started as the engine's validation
> game and is now the home of the real product. The engine submodule
> stays read-only (see [`CLAUDE.md`](./CLAUDE.md) §1) — that contract
> still holds — but the scope rules in §0 are superseded by this
> document.

---

## Table of contents

1. [North Star](#1-north-star)
2. [Where we are today](#2-where-we-are-today)
3. [Phase plan (overview)](#3-phase-plan-overview)
4. [Phase 1 — Make it a game](#4-phase-1--make-it-a-game)
5. [Phase 2 — Make it sing](#5-phase-2--make-it-sing)
6. [Phase 3 — Make it a zoo *(new)*](#6-phase-3--make-it-a-zoo)
7. [Phase 4 — Make it deep](#7-phase-4--make-it-deep)
8. [Phase 5 — Make it reach](#8-phase-5--make-it-reach)
9. [Engine dependency map](#9-engine-dependency-map)
10. [Cross-cutting concerns](#10-cross-cutting-concerns)
11. [Risks & mitigations](#11-risks--mitigations)
12. [Decision log](#12-decision-log)
13. [Backlog (parking lot)](#13-backlog-parking-lot)
14. [How we work (process notes)](#14-how-we-work-process-notes)

---

## 1. North Star

> **A web-first zoo tycoon that a stranger can fall into in 90 seconds
> and lose an evening to — built on a clean engine seam so each new
> system (welfare, breeding, staff, weather) plugs in without
> destabilizing the rest.**

Three durable principles, in priority order:

1. **Read & play fast.** Browser tab, 60 fps, no install.
2. **The simulation is honest.** Every visible behavior is a consequence
   of the model. No scripted events, no fake numbers.
3. **Engine submodule is read-only.** Capabilities are reached through
   `tycoon_core` interfaces; seams become engine issues, never patches.

One stretch principle, added after the zoo-ops review:

4. **A zookeeper should recognize this as a zoo.** Veterinary care,
   enrichment, individual animals, accreditation are load-bearing
   identity systems, not flavor.

---

## 2. Where we are today

Built on **engine v0.5.0**. Loop is live and honest: build regions →
place animals → visitors arrive, browse, buy, leave. 5 animals, 4 zone
kinds, 2 amenities, trait-driven visitors, save/load, financial reports,
region management, hover inspector, reputation, mood bubbles.

**Strengths:** loop is real, art reads as a tycoon, no engine seam
leaks accumulated.

**Identity gaps (zoo-ops critique, 2026-05-25):** no vet/medical layer,
no enrichment, no individual animals, accreditation is a single scalar,
no back-of-house geometry, no commissary/infrastructure, staff plans
are too flat, no education layer, revenue model is theme-park-shaped
not zoo-shaped (no membership, donor giving, grants).

**Game gaps:** no sound, no win/lose, no mobile input, no scenarios,
no public build.

---

## 3. Phase plan (overview)

Five phases, gated. Each phase ships a public web build. Don't start
phase N+1 until N's exit criteria are met.

| Phase | Theme | Duration | Status |
|---|---|---|---|
| 1 | Make it a game — ship a session, with stakes | ~4 weeks | active |
| 2 | Make it sing — sound, mobile, accessibility, telemetry | ~6 weeks | planned |
| 3 | **Make it a zoo — vet care, individuals, enrichment, accreditation** | ~3–4 months | planned |
| 4 | Make it deep — breeding, staff strings, archetypes, seasons | ~3 months | planned |
| 5 | Make it reach — research, membership, scenarios, launch | ~3–6 months | planned |

The big change from v2 of this doc: **a new Phase 3** ("Make it a
zoo") sits between polish and depth, owning the systems that make this
read as a zoo rather than a generic tycoon. Old Phase 3 becomes Phase 4,
old Phase 4 becomes Phase 5. Rationale in the [decision log](#12-decision-log).

---

## 4. Phase 1 — Make it a game

*Now → ~4 weeks. Goal: a public web build with a session, win/lose
state, and an onboarding flow.*

This phase doesn't add new systems — it makes the systems we have
*legible* to a new player in a browser tab.

| # | Initiative | Brief |
|---|---|---|
| 1.1 | Web export, hosted publicly | HTML5 build deployed to itch.io or claude.site. Loads <5s, plays without crash |
| 1.2 | Win + lose conditions | "$20k cash + 50 reputation in 30 days" win; bankruptcy = lose. Surfaced in goals panel |
| 1.3 | Onboarding flow | Guided first 60s: build region → place animal → watch a visitor pay |
| 1.4 | Performance budget pass | 60 fps with 100+ visitors on a mid-2022 laptop browser |
| 1.5 | Playtest gauntlet #1 | 5+ external testers, recorded sessions, structured notes |

**Exit criteria:**

- [ ] Public URL plays to win or lose without crash.
- [ ] ≥5 external playtest sessions logged.
- [ ] Smoke test green; no new engine seams uncaptured.

---

## 5. Phase 2 — Make it sing

*Weeks 5–10. Goal: the game feels alive on the platforms players
actually use.*

| # | Initiative | Brief | Engine impact |
|---|---|---|---|
| 2.1 | Audio integration | SFX on purchase/visitor leave/day rollover, one ambient loop, master volume | **Likely engine v0.6 seam** — no audio surface today |
| 2.2 | Mobile / touch input | Pinch-zoom, drag-pan, tap-to-place, portrait HUD | Input routing |
| 2.3 | Accessibility pass | Colorblind-safe auras, min font size, keyboard nav | Theme plumbing |
| 2.4 | Telemetry | Opt-in: session length, day reached, win/lose, drop-off step | Event bus |
| 2.5 | Save format migration | Write a save on v0.5, load it on v0.6 with a migrator | **Likely engine seam** — no migration story today |
| 2.6 | Difficulty scenarios | Easy / Standard / Hard as tuning overlays | Tuning loader composition |

**Exit criteria:**

- [ ] Audio + touch shipped, accessibility audit passed.
- [ ] ≥20 external playtest sessions; "would you play again" ≥ 60%.
- [ ] Engine seams from 2.1/2.5 resolved upstream or formally deferred.

---

## 6. Phase 3 — Make it a zoo

*~3–4 months. Goal: the simulation reads as a zoo to someone who's
worked at one. This phase is load-bearing for the product's identity.*

The order inside this phase matters — later items depend on earlier
ones. Sequencing:

```
3.1 Individual animals  ──┐
                          ├──► 3.3 Veterinary system ──► 3.4 Accreditation
3.2 Back-of-house geom ───┘                              ▲
                                                         │
3.5 Enrichment ──────────────────────────────────────────┘
3.6 Commissary + infrastructure  (parallel to 3.3–3.5)
```

Each initiative below has a brief shape: **Problem / Shape / Out of
scope / Open design questions / Engine surface / Data files**.

---

### 3.1 — Individual animals (the studbook)

**Problem.** Today "Lion" is a placeable type. There are no individual
animals — no names, no ages, no medical history, no kinship. Players
don't bond with a stat block. This is the foundation that vet care,
breeding, and accreditation all stand on.

**Shape.**

- Every placed animal becomes a tracked **individual** with: studbook
  ID, name (auto-generated, player-renameable), species, sex, age in
  days, parentage refs, arrival date, arrival source.
- Hover inspector shows the individual's record.
- A new **Animal Roster** HUD panel lists all animals with sortable
  columns (species, age, welfare).
- Placeables become *templates* (species definitions); the things on the
  map are *instances* with state.

**Out of scope for 3.1.**

- Personality / behavioral traits (lands in 4.1 with breeding).
- Acquisition mechanics — animals still arrive via build menu for now.
  SSP transfer mechanics arrive in 4.x.

**Open design questions.**

- Do all visible animals get individual records, or only "headline"
  species? *Recommendation: all. Half-measures invite weird edges.*
- Name generation — pulled from a static list per species, or templated?
- How does this interact with the save format? **(See cross-cutting §10.)**

**Engine surface needed.**

- The engine's placeable system today is type-keyed. We need
  per-instance state without modifying the engine. Spike: can we attach
  zoo-side instance state via a side-table keyed by placement ID? If
  not → engine seam, v0.7.x.

**Data files / tuning impact.**

- `design/tuning/animals.md` (new) — species-level data extracted from
  `placeables.md` (lifespan, mature_age, gestation_days, etc.).
- `placeables.md` stays as template/build-menu data.

---

### 3.2 — Back-of-house geometry

**Problem.** Every real exhibit has a public side and a holding side
(night-house). Today there's only the public side. Without
back-of-house, vet care and shift-gating can't be modeled honestly.

**Shape.**

- Each region gains an attached **holding area** — smaller, fenced,
  not visible to visitors, where animals can be shifted off-exhibit.
- Keeper-only **service paths** connect holding areas to the commissary
  and hospital (placed in 3.3, 3.6).
- A keeper "shift gate" action moves an animal between public and
  holding; affects welfare and visitor visibility.
- Holding areas have a minimum size requirement per species (an AZA
  hook for 3.4).

**Out of scope.**

- Climate control / life-support systems (backlog).
- Visitor-side holding viewing windows (Phase 5 polish).

**Open design questions.**

- Do players *build* the holding area explicitly (more agency, more
  micromanagement) or is it auto-generated when a region is built
  (cleaner UX, less control)? *Recommendation: auto-generated at a
  minimum viable size, optionally expandable by the player.*
- Service paths: pathfinding mesh or hand-placed tiles?

**Engine surface needed.**

- Zones currently define one public area. We need a "linked private
  zone" concept. Spike: can this be done with two adjacent zones and
  a zoo-side relationship map? If not → engine seam, v0.7.x.

**Data files.**

- `entities.md` — new zone kind `holding`, new entity `service_path`.

---

### 3.3 — Veterinary system

**Problem.** Welfare is currently a happiness scalar that drives
behavior. In a real zoo, illness *causes* welfare loss, and treating
illness is half of zookeeping. No vet department = no zoo.

**Shape.**

- New building: **Veterinary Hospital** (footprint 3×3, expensive,
  unlock-gated).
- Vets are a new staff type (lands operationally in Phase 4.2 — for now,
  hire as flat workforce).
- Animals develop **medical events** at a low base rate, modified by
  welfare, age, enrichment, and (later) genetics. Event types:
    - Routine: vaccination due, parasite check, dental.
    - Acute: injury, infection, GI upset.
    - Chronic: arthritis (geriatric), diabetes.
- Sick animals are shifted to the hospital (via 3.2) for treatment.
  Treatment costs money, takes time, affects welfare while away.
- **Quarantine** — new animal arrivals spend 30 in-game days in a
  quarantine wing of the hospital before going on exhibit.
- Death by natural causes (and rare medical complication) becomes a
  real outcome; animals have a species lifespan.

**Out of scope.**

- Surgery mini-game / Theme-Hospital-style activity (backlog —
  potentially fun but the wrong genre commitment for v1).
- Reproductive health (folds into 4.1 breeding).
- Veterinary research / drug development (backlog).

**Open design questions.**

- Frequency / severity of medical events: how aggressive before it
  feels punishing? *Tuning problem; instrument from day one.*
- Does the player make treatment decisions (yes/no, which treatment) or
  is the vet department autonomous and the player only sees outcomes?
  *Recommendation: autonomous by default, with a per-animal "high-cost
  treatment requires approval" toggle for player agency.*
- How visible should death be? Tasteful notification vs. memorial
  panel. *Recommendation: somber notification, animal moves to a
  "Memoriam" tab in the roster.*

**Engine surface needed.**

- Periodic per-entity event generator with state (vaccination due
  date, etc.). May extend the engine's effect resolver, or live
  entirely zoo-side. Spike required.

**Data files.**

- `design/tuning/medical.md` (new) — event types, base rates per
  species, treatment costs, treatment durations.
- `design/algorithms/medical_events.md` (new) — the rate-modifier
  algorithm.

---

### 3.4 — Accreditation

**Problem.** Reputation is one scalar. Real zoos answer to multiple
external bodies (AZA, USDA APHIS) on different axes. This is also the
natural home for the win/lose stakes from 1.2 — losing accreditation is
a more authentic failure state than going bankrupt.

**Shape.**

- Two named accreditation bodies (initially):
    - **Welfare board** (AZA-flavored): inspects on welfare metrics,
      enrichment, vet care, exhibit standards. Annual cycle.
    - **Regulatory inspector** (USDA-flavored): inspects on safety,
      cleanliness, recordkeeping. Quarterly.
- Each has a multi-axis score; player sees a dashboard with green /
  amber / red per axis.
- **Inspection events** trigger on schedule. Findings can include
  corrective-action timers ("fix this in 30 days or lose
  accreditation").
- Losing accreditation has cascading effects: can't acquire new
  animals from SSP (in 4.x), insurance costs rise, reputation
  penalty.
- Win condition for campaign mode: full accreditation maintained for
  a target duration. Replaces / augments the "$ + reputation" win.

**Out of scope.**

- Multiple regional accreditation bodies (EAZA, WAZA) — global
  variants are Phase 5+ backlog.

**Open design questions.**

- How visible should the inspection event itself be? Cutscene-style
  arrival of inspector NPC vs. quiet score update. *Recommendation:
  inspector NPC visits the park as a one-day event; players see them
  walk the grounds. Visible = memorable.*
- Should the player be able to bribe / contest findings? *Tempting but
  probably out of scope for v1 — adds an ethics surface we don't
  need yet.*

**Engine surface needed.**

- Calendar / scheduled-event surface. The engine has a day clock; we
  need recurring N-day and per-year events. Likely zoo-side, but
  worth a spike.

**Data files.**

- `design/tuning/accreditation.md` (new) — bodies, axes, scoring
  weights, schedules.

---

### 3.5 — Enrichment

**Problem.** Modern zoo welfare is enrichment-led. Today our welfare
model is "is food/water provided." Without enrichment, the keeper role
in Phase 4 will be hollow, and welfare-savvy players will notice
immediately.

**Shape.**

- New placeable category: **enrichment items** — puzzle feeders, scent
  posts, scratch posts, climbing structures, ball/log toys. Species-
  tagged.
- Enrichment **decays** in novelty: a parrot that's had the same toy
  for 14 days gets less welfare boost. Rotating items refreshes value.
- Keepers (Phase 4) gain an enrichment routine — placing/rotating items
  is part of their day.
- Welfare model extended: `enrichment_score` becomes an axis alongside
  food/water provision.

**Out of scope.**

- Training programs (operant conditioning sessions) — backlog candidate
  for Phase 4 or 5.
- Custom enrichment design / crafting — definitively backlog.

**Open design questions.**

- Manual rotation vs. auto-rotation by keepers — how much
  micromanagement does this introduce? *Recommendation: auto by default
  via a keeper task; manual "rotate now" button for engaged players.*
- Is enrichment visible to visitors and does it boost appeal too?
  *Recommendation: yes, modestly. Real visitors enjoy seeing animals
  interact with enrichment.*

**Engine surface needed.**

- Placeable timer/decay state. Probably zoo-side. May want engine
  support for "scheduled state mutation" if multiple systems need it
  (medical due dates, enrichment decay, accreditation timers).

**Data files.**

- `placeables.md` — new entries for enrichment items.
- `design/tuning/enrichment.md` (new) — species-compatibility table,
  novelty decay curves.

---

### 3.6 — Commissary + back-of-house infrastructure

**Problem.** Food appears by magic. Real zoos have a commissary (central
food prep facility) and other back-of-house buildings that take up
20–30% of the physical footprint. Without them, the build menu reads
like a theme park.

**Shape.**

- New buildings:
    - **Commissary** — required once N animals are placed; produces
      "feed units" consumed by feeding troughs.
    - **Maintenance shop** — required for staff repairs; affects
      breakdown rates of placeables.
    - **Hay barn** — storage for hoofstock feed; cheaper if commissary
      output is held here.
- New supply chain: commissary → service path → feeding troughs.
  Disruption (path blocked, building destroyed) starves exhibits.
- All these buildings sit in zones tagged as **back-of-house** — they
  occupy real space but don't contribute to visitor appeal.

**Out of scope.**

- Full logistics game (truck deliveries, warehousing). Keep the chain
  abstract.
- Energy / water utilities as gameplay systems (backlog — currently
  abstracted in the daily utility expense).

**Open design questions.**

- How often should the player have to *think* about the commissary?
  *Recommendation: rarely — it's an early-game build requirement and a
  late-game crisis vector, not a daily concern.*
- Does the commissary scale (one big building) or duplicate (multiple
  small)? *Recommendation: scales — keeps the back-of-house footprint
  predictable.*

**Engine surface needed.**

- Supply-chain semantics (entity produces resource consumed by other
  entities). Could be modeled with existing effect resolver, or may
  reveal a seam. Spike before committing.

**Data files.**

- `entities.md` — new buildings + back-of-house zone kind.
- `design/tuning/supply_chain.md` (new) — production/consumption rates.

---

### Phase 3 exit criteria

- [ ] An external playtester who has worked at a real zoo plays a
      30-minute session and identifies the simulation as a zoo
      (qualitative bar, but it's the bar).
- [ ] All Phase 3 systems land on the same public web build, still
      hitting the 60 fps / 100+ visitor budget.
- [ ] Save format remains forward-compatible (or a migrator ships).
- [ ] Engine reaches **v1.0 RC** — no breaking changes expected for
      Phase 4.

---

## 7. Phase 4 — Make it deep

*~3 months. Goal: the simulation has a 50-hour identity. This is what
keeps a player coming back to the same save.*

These were Phase 3 items in roadmap v2; they're better off here because
they depend on the individual-animal substrate from new Phase 3.

| # | Initiative | Brief | Depends on |
|---|---|---|---|
| 4.1 | **Breeding & generations** | Individuals pair, gestate, produce offspring; genetic kinship tracked; SSP-style coordinator gives recommendations | 3.1 (individuals), 3.3 (vet care) |
| 4.2 | **Staff agents (strings)** | Keepers organized by string (carnivore, ungulate, primate, bird); vets, registrar, curator, horticulture, education. Volunteers as cheap labor | None — but synergizes hard with 3.3 and 3.5 |
| 4.3 | **Visitor archetypes** | Families, thrill-seekers, photographers, school groups; each with appeal-match + budget profile; school groups arrive as scheduled events | None |
| 4.4 | **Day/night + opening hours** | Visitors spawn only during open hours; nocturnal species shift appeal; keepers have shifts | Engine clock surface (v0.7.x) |
| 4.5 | **Weather + seasonal arc** | Season is the macro driver (summer peak, winter trough); weather is daily noise on top. Holiday events partially backfill winter | None on top of 4.4 |
| 4.6 | **Mixed-species exhibits** | Species-pair compatibility table; well-matched mixes get welfare + appeal boost; poor mixes cause conflict events | 3.1 (individual stress tracking), 3.5 (welfare modeling) |
| 4.7 | **Education & interpretation** | Signage placeables, scheduled keeper talks, school program revenue line; education score feeds accreditation | 3.4 (accreditation) |

**Phase 4 exit criteria:**

- [ ] Median session length ≥ 2× end-of-Phase-3 baseline.
- [ ] A 90-day campaign is winnable on Standard, hard on Hard.
- [ ] Sandbox mode exists for non-campaign players.
- [ ] Engine v1.0 shipped.

---

## 8. Phase 5 — Make it reach

*~3–6 months. Goal: a public launch on Steam, itch, and web. Beyond
launch, the roadmap becomes a data-driven backlog.*

| # | Initiative | Brief |
|---|---|---|
| 5.1 | **Research tree** | Replaces linear unlocks; spend points on tech, husbandry, amenities |
| 5.2 | **Membership program** | Recurring revenue from annual memberships; ~30–50% of late-game income; tiered (family / individual / patron) |
| 5.3 | **Marketing campaigns** | Spend cash to bias spawn weights toward archetypes; complements memberships |
| 5.4 | **Donor & grants layer** | Capital giving, naming rights on exhibits, adopt-an-animal microtransactions (in-game), grant applications |
| 5.5 | **Scenario set + editor** | 6–10 hand-tuned scenarios + a basic editor; tests tuning system at scale |
| 5.6 | **Achievements + light meta** | Genre table stakes; "first elephant breeding," "10-year accreditation streak" |
| 5.7 | **Localization** | EN + 3 languages (target: ES, FR, DE or JP based on telemetry) |
| 5.8 | **Special events** | Zoo Lights, Boo at the Zoo, after-hours adult nights — scheduled multi-day events with their own economy |
| 5.9 | **Public launch** | Steam + itch + web simultaneously; press kit, trailer |

**Phase 5 exit criteria:** the game is launched. Post-launch backlog is
driven by player data.

---

## 9. Engine dependency map

The engine ships independently. **If the engine slips, we shrink zoo
scope — never patch the submodule.**

| Engine release | Zoo phase | What it unlocks | Risk |
|---|---|---|---|
| v0.5.0 *(current)* | Phase 1 | Already in place | — |
| v0.6.x | Phase 2 | Audio surface (2.1), save migration (2.5), mobile input (2.2) | **Two known seams here** |
| v0.7.x | Phase 3 | Per-instance entity state (3.1), linked private zones (3.2), scheduled events (3.4), supply-chain semantics (3.6) | **Highest-risk engine release — most seams concentrated here** |
| v0.8.x | Phase 4 | Multi-population polish (4.2), calendar surface (4.4) | |
| **v1.0** | Phase 4 → 5 gate | Stable surface for launch | Hard gate before 5.x coding |
| v1.x+ | Phase 5 | Localization plumbing, mod surface | |

**Eng team: please file engine issues *as soon as* a seam is identified
in design**, not when implementation blocks. The engine's release
cadence is the critical path for Phase 3.

---

## 10. Cross-cutting concerns

Things that touch multiple phases. The team should treat each as
durable infrastructure, not per-phase work.

### 10.1 Save format

Each phase adds entity state. We need a versioned save schema with
forward-migration from day one of Phase 2 (item 2.5). After Phase 3 lands
individual animals, save sizes will jump materially — keep an eye on
serialization cost.

### 10.2 Tuning data growth

`design/tuning/` will roughly triple in line count across Phase 3. New
files: `animals.md`, `medical.md`, `enrichment.md`, `accreditation.md`,
`supply_chain.md`. Validation: the engine's loader fails loud on
malformed input, but inter-file consistency (e.g., a `medical.md`
species ID matching one in `animals.md`) is on us. Consider a CI check.

### 10.3 Telemetry

Land in Phase 2 (item 2.4). Every Phase 3+ system should add at least
one telemetry event when it ships. We tune from data, not vibes.

### 10.4 Art pipeline

Every new building / placeable needs a sprite. Phase 3 alone adds ~10
new placeables (enrichment items, back-of-house buildings, hospital).
Design team: please batch art requests at phase boundaries — last-minute
sprite requests are the slowest part of any iteration.

### 10.5 Accessibility

Phase 2's accessibility pass (2.3) covers HUD. Each Phase 3+ system
needs to be audited at landing — new colors, new tooltips, new
keyboard paths. Build accessibility into the definition-of-done.

### 10.6 Engine seam log

Maintain `design/engine_seams.md` as a running list of suspected
seams. Each entry: date, suspected seam, who flagged it, status
(filed / deferred / closed). This is the artifact that proves the
read-only engine contract is working.

---

## 11. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Web perf miss after Phase 3 (more state, more events) | Medium | High | Perf budget is checked at every phase exit, not just 1.4 |
| Phase 3 seam load on engine v0.7.x | **High** | High | Spike each seam *during Phase 2*, so engine work runs in parallel |
| Individual animals balloon save size | Medium | Medium | Profile in 3.1 spike; design save schema for delta compression if needed |
| Vet system feels punishing or grindy | Medium | High | Heavy tuning + telemetry from day one of 3.3; design must own the playtest signal |
| Accreditation feels arbitrary | Medium | Medium | Inspector NPC visit makes it visible; clear dashboard with axis scores |
| Scope sprawl ("just one more system") | **High** | High | Items land in §13 Backlog, never in current phase. PRs must cite a roadmap item |
| Playtest signal weakens through Phase 3 | Medium | High | Phase 3 has explicit qualitative bar (zookeeper recognition); if it's not hitting, we stop and rework |
| Engine v1.0 slips past Phase 4 exit | Medium | Medium | Phase 5 *planning* can proceed; *coding* cannot |

---

## 12. Decision log

- **2026-05-25** — Roadmap v3. Inserted new Phase 3 ("Make it a zoo")
  between polish and depth, owning vet care / individuals / enrichment
  / accreditation / back-of-house / commissary. Old Phase 3 → Phase 4,
  old Phase 4 → Phase 5. Driver: zoo-ops expert review identified that
  the prior plan was a "tycoon game with animals" rather than a zoo.
- **2026-05-25** — Membership promoted from backlog to Phase 5 (5.2) as
  a load-bearing revenue stream after expert review.
- **2026-05-25** — Roadmap v2 reframed from "validation game →
  successor repo" to "this is the product." Engine read-only contract
  retained; `CLAUDE.md` §0 scope rules are superseded by this document
  and need a follow-up edit.
- **2026-05-25** — Roadmap v1 (superseded) had a graduation step into a
  new repo; dropped.

---

## 13. Backlog (parking lot)

Ideas not committed to any phase. Promote into a phase via the decision
log, never silently.

**From the zoo-ops review:**

- Animal personalities & individual behavioral traits (separate from
  3.1 records — this is the next-step depth)
- Training / operant conditioning sessions
- Surgery / vet mini-game (deliberately deferred — wrong genre)
- Climate control & life-support for tropical houses / aquariums
- Multiple regional accreditation bodies (EAZA, WAZA)
- Field conservation program — fund off-park projects for reputation
- Animal escape protocols (Code Red) as event content
- ADA / accessibility infrastructure (stroller rentals, wheelchair
  paths, sensory-friendly hours) in-world
- Reintroduction programs (release captive-bred animals into "the
  wild")

**Pre-existing backlog:**

- Steam Workshop integration
- Multiplayer / shared zoos (very speculative)
- Console ports (would require engine input rework)
- Sequel theming on the same engine (theme park, hospital, transit)
  if launch validates the engine commercially
- Educational / school edition

---

## 14. How we work (process notes)

For the dev and design team picking work up from this doc.

**Each roadmap item gets a one-pager before coding starts.** The brief
shape in Phase 3 (Problem / Shape / Out of scope / Open design
questions / Engine surface / Data files) is the template. Design owns
the one-pager; engineering reviews it before estimating.

**Spikes before commits.** Any item flagged with "engine surface
needed" gets a timeboxed spike *during the previous phase*. If the
spike reveals a seam, file the engine issue immediately so the engine
release can include the fix.

**PRs cite a roadmap item.** Title or description must reference (e.g.)
"Phase 3.3 — Veterinary system." Items not on the roadmap go to the
backlog first.

**Playtest at every phase exit.** No phase is "done" until external
testers have played the new state. Phase 3 specifically requires a
playtester with real-zoo experience for the qualitative recognition
bar.

**Telemetry is part of the definition of done.** A Phase 3+ system
without telemetry is half a system.

**Art batched at phase boundaries.** Surprise sprite requests slow
everyone down; the art pipeline plans per phase, not per ticket.
