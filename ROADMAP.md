# Zoo Tycoon — Product Roadmap

**Status:** Living document. Last updated 2026-06-07.
**Owner:** Kenny Johnson (PM + Eng).

> **This is the Zoo Tycoon repo.** It started as the engine's validation
> game and is now the home of the real product. The engine submodule
> stays read-only (see [`CLAUDE.md`](./CLAUDE.md) §1) — that contract
> still holds — but the scope rules in §0 are superseded by this
> document. We are building a full tycoon here, in place.

---

## 1. North Star

> **A web-first zoo tycoon that a stranger can fall into in 90 seconds
> and lose an evening to — built on a clean engine seam so each new
> system (welfare, breeding, staff, weather) plugs in without
> destabilizing the rest.**

Three durable principles, in priority order:

1. **Read & play fast.** Browser tab, 60 fps, no install. If a system
   can't survive the web budget, it doesn't ship.
2. **The simulation is honest.** No fake numbers, no scripted spawns.
   Every visible behavior is a consequence of the model — that's what
   makes a tycoon game keep giving for 50 hours.
3. **Engine submodule is read-only.** Every gameplay capability we want
   is reached through `tycoon_core` interfaces. Seam leaks are filed
   against the engine and bumped via tag — never patched in place.
   This is the same discipline that got us here.

---

## 2. Where we are today

Built on **engine v0.5.0** (zones + placeables + sprite set). The
economic loop is live and honest:

- Build regions from zone tiles → drop animals/infrastructure inside →
  appeal is computed from placements → visitors arrive, browse, buy
  food, leave with a satisfaction score → daily settlement closes books.
- 8 animals, 4 zone kinds, 6 amenities (food / drink / restroom / bench /
  compost / restaurant) plus the arena, 1 visitor agent type with **four
  needs** (hunger / thirst / restroom / energy, with an eat→restroom
  spillover) + trait-driven variation.
- Honest gate economy: **bracketed ticket pricing** with demand
  elasticity, **per-exhibit donation boxes**, food/drink purchases, arena
  show revenue, daily settlement.
- HUD covers save/load, financial reports, region management with a
  **0–100 suitability rating + always-on recommendation**, hover
  inspector, reputation, goals panel, welcome modal, win/lose end-game,
  and **need-aware guest mood bubbles**.

**Strengths:** loop is real, art reads as a tycoon (not a debug
harness), engine has held under feature pressure with no seam leaks.

**Gaps that block a "real game" feeling:** no sound, no mobile input, no
staff, no breeding, no time-of-day, no scenarios. *(Guest archetypes and
animal welfare have since landed — see the decision log.)*

---

## 3. Phase plan

Four phases, gated. Don't start phase N+1 until N's exit criteria are
met. Each phase ships a public web build.

### Phase 1 — **Make it a game** *(now → ~4 weeks)*

The current build is a beautiful sandbox. Phase 1 turns it into a
session: clear start, clear end, clear stakes. Nothing in this phase
adds new systems — it makes the systems we have *legible*.

| # | Initiative | Why |
|---|---|---|
| 1.1 | **Web export, hosted publicly** | Engine is web-first. If it can't ship to a browser, nothing downstream matters |
| 1.2 | **Win + lose conditions** — "Hit $20k cash and 50 reputation in 30 days," and "bankruptcy = game over"; surfaced in goals panel | Sandboxes don't make memories. A finish line creates the moment-to-moment urgency the economy needs |
| 1.3 | **Onboarding** — guided first 60s; build a region, place an animal, watch a visitor pay | Welcome modal is passive. Browser-tab attention is brutal |
| 1.4 | **Performance budget pass** — 60 fps on a mid-2022 laptop browser with 100+ visitors | Web perf is the differentiator; if we miss the budget, every later phase suffers |
| 1.5 | **First playtest gauntlet** — 5+ external testers, recorded sessions | Until someone who didn't build it plays it, we don't know what we built |

**Exit criteria:**

- [ ] Public URL loads in <5s, plays to win or lose without crash.
- [ ] ≥5 external playtest sessions logged with notes.
- [ ] Smoke test green.
- [ ] No new uncaptured engine seams.

---

### Phase 2 — **Make it sing** *(weeks 5–10)*

Phase 1 is silent and desktop-only. Phase 2 is where the game starts to
feel alive on the platforms players actually use.

| # | Initiative | Why | Engine impact |
|---|---|---|---|
| 2.1 | **Audio integration** — SFX on purchase / visitor leave / day rollover, one ambient loop, master volume | Sound is half the tycoon-game feeling. We have none | **Likely engine v0.6 seam** — no audio surface today |
| 2.2 | **Mobile / touch input** — pinch-zoom, drag-pan, tap-to-place, portrait HUD | Most web traffic is mobile. Desktop-only "web" is half an export | Input routing in `tycoon_core` UI layer |
| 2.3 | **Accessibility pass** — colorblind-safe auras, min font size, keyboard nav | Public-build hygiene; also a forcing function for engine UI primitives | Theme / palette plumbing |
| 2.4 | **Telemetry** — opt-in analytics: session length, day reached, win/lose, drop-off step | We can't tune what we can't measure | Event bus completeness |
| 2.5 | **Save format migration** — write a save on v0.5, load it on v0.6, prove forward-compat | Saves are where tycoon games die. Catch this seam at v0.6, not v1.0 | **Likely engine seam** — no migration story today |
| 2.6 | **Difficulty scenarios** — Easy / Standard / Hard via tuning overlays | First test of variant configs without forking | Tuning loader composition |

**Exit criteria:**

- [ ] Audio + touch shipped, accessibility audit passed.
- [ ] ≥20 external playtest sessions, "would you play again" ≥ 60%.
- [ ] Engine seams from 2.1/2.5 resolved or formally deferred.

---

### Phase 3 — **Make it deep** *(months 3–6)*

Now the simulation actually starts to be a *zoo*. This is where the
game finds its 50-hour identity. Each item below is a system, not a
feature — they interact, and that's the point.

| # | System | What it adds | Depends on |
|---|---|---|---|
| 3.1 | **Animal welfare** — happiness from existing model drives behavior, illness, death; welfare alerts in HUD | Animals become more than props; player attention pivots from layout to care | None — extends existing `IPlaceableHappiness` |
| 3.2 | **Visitor archetypes** — families, thrill-seekers, photographers, school groups; each with its own appeal-match profile | Single visitor type makes the appeal axes feel academic. Archetypes make exhibit-mix decisions matter | Engine archetype support (likely already present via `AgentType`) |
| 3.3 | **Staff agents** — zookeepers, vendors, mechanics; second agent population | Tests engine multi-population claim; gives the player labor to manage | **Engine** must cleanly support N populations |
| 3.4 | **Day/night + opening hours** — visitors spawn only during open hours; nocturnal animals shift appeal | Pacing. A flat 240-tick day is identical every day | Engine clock/calendar surface |
| 3.5 | **Breeding & generations** — animals pair, produce offspring, age out; rare-genome milestones | The depth hook. Players who care about animals stay for breeding | Welfare (3.1) must land first |
| 3.6 | **Weather + seasons** — modifies spawn and welfare; cosmetic + functional | Variety, plus another forcing function on the simulation's robustness | Engine event hooks |

**Exit criteria:**

- [ ] All six systems shipped behind the same web build.
- [ ] Median session length doubles vs. end of Phase 2.
- [ ] 30-day campaign is winnable on Standard, hard on Hard, and a
      sandbox mode exists for players who just want to build.
- [ ] Engine reaches **v1.0** — stable surface, no expected breaking
      changes for Phase 4.

---

### Phase 4 — **Make it reach** *(months 6–12)*

The game exists. Phase 4 is about getting it in front of people and
giving it legs after launch.

| # | Initiative | Why |
|---|---|---|
| 4.1 | **Research tree** — replaces the linear unlock chain; spend points on tech, husbandry, amenities | Meta-progression. Gives long sessions a vector other than "more cash" |
| 4.2 | **Marketing campaigns** — spend cash to bias spawn weights toward archetypes | Closes the loop between investment and visitor mix — a classic tycoon move |
| 4.3 | **Scenario set + editor** — 6–10 hand-tuned scenarios plus a basic editor | Replayability; community content tests tuning at scale |
| 4.4 | **Achievements + light meta** | Standard table stakes for tycoon-genre retention |
| 4.5 | **Localization** — EN + 3 languages | Web reach is global. Most of our audience isn't anglophone |
| 4.6 | **Public launch** — Steam, itch.io, web simultaneously; press kit; trailer | The moment we earn back the runway |

**Exit criteria:** the game is launched. Beyond launch, the roadmap
becomes a backlog driven by player data, not by phases.

---

## 4. Engine dependency map

The engine ships independently. This roadmap depends on its cadence —
if the engine slips, we **shrink zoo scope**, never patch the submodule.

| Engine release | Needed for | Notes |
|---|---|---|
| v0.5.0 *(current)* | Phase 1 | Already shipped |
| v0.6.x | Audio (2.1), mobile input (2.2), save migration (2.5), **agent navigation on a constrained network** (Phase 1, paths-only) | The audio + migration surfaces are the riskiest known seams. Navigation seam spec: [`design/engine_seam_agent_navigation.md`](./design/engine_seam_agent_navigation.md) |
| v0.7.x | Day/night clock (3.4), event hooks for weather (3.6) | |
| v0.8.x | Multi-agent population polish (3.3) | |
| **v1.0** | Stable surface for Phase 4 | Hard gate before research tree / scenario editor work |
| v1.x+ | Phase 4 reach work | |

**Operating rule:** any time a phase item requires engine work, we cut
a real engine issue and wait for the tag. Silent submodule edits are
the failure mode the whole architecture exists to prevent.

---

## 5. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Web export misses the perf budget | Medium | High — invalidates the platform claim | Land 1.4 as a gate on 1.1, not a follow-on |
| Welfare + breeding blow up the simulation cost | Medium | High | Profile each system on landing; both have natural off-switches (welfare can degrade to cosmetic, breeding to disabled) |
| Engine v1.0 slips past Phase 3 exit | Medium | Medium | Phase 4 *planning* can begin without v1.0; *coding* cannot |
| Audio / migration reveal deep engine seams | Medium | Medium | Sequenced early in Phase 2 precisely to surface this on a small surface, not a big one |
| Scope sprawl ("just one more system before launch") | High | High | Each phase has hard exit criteria. New ideas land in §7 Backlog, not in the current phase |
| Playtest signal is mid through Phase 2 | Medium | High — informs whether to even start Phase 3 | Phase 2 exit gate is a real go/no-go, not a formality. If signal is weak we re-evaluate the *shape* of Phase 3, not push forward on momentum |

---

## 6. Decision log (running)

- **2026-06-12** — **Roadmap sweep: perf static-layer split (1.4), audio
  (2.1), touch first-pass (2.2), save versioning (2.5), winnability
  regression test (toward 1.5).** (1) The iso view's static world layers
  (lawn, exhibit floors + fringes, path pavers, scatter — ~600 textured
  polygons) moved into `IsoBackground`, redrawing only on world/camera
  change, mirroring the top-down `MapBackground` split. This is the fps
  budget work *and* the prime suspect for the playtest's WebGL
  object-handle exhaustion; needs re-verification in a long browser
  session. (2) **Audio shipped zoo-side** — the "likely engine seam"
  flagged for 2.1 doesn't exist; sound is presentation like the renderers.
  SFX + ambient loop are synthesized at build time
  (`tools/generate_audio.py`) and committed; `src/audio.gd` wires them to
  the same signals the HUD uses; mute in the top bar, volume in Park
  Admin. (3) **Touch**: emulated-mouse taps drive the HUD; the iso view
  adds tap-on-release placement (a pinch can't accidentally build),
  one-finger pan, two-finger pinch-zoom. Portrait HUD still open.
  (4) **Save payloads are versioned** (`ZooBootstrap.SAVE_VERSION`, v1
  loads forward). (5) The starter park moved to `src/starter_park.gd` and
  an 8-day untended arc test locks the winnability fix (rep never below
  −25; turnaround reaches +50 in-window). *Status notes:* the engine
  walkable-fix commit `a80350a` **is now on the engine remote** (earlier
  "needs pushing" note is stale) but **no v0.6.x tag exists there** —
  tagging + CHANGELOG is engine-repo maintainer work. The live-deploy fix
  (tuning files in the export include filter) is complete on the branch
  and goes live when it merges to `main`. Deliberately not started:
  telemetry (2.4, needs a where-does-data-go decision), accessibility
  audit (2.3), portrait HUD, external playtests (humans required), and
  all Phase 3 deepening/Phase 4 work (gated per this roadmap). Suite
  62 → 64 green.
- **2026-06-11** — **Playability pass: reputation became a rating, and the
  game now teaches its binding constraint.** Direct response to the
  2026-06-09 playtest ([report](./design/playtest/fable_report_2026-06-09.md)),
  whose headline finding was that Standard was unwinnable as players actually
  play it: reputation (the real win bar) was an unbounded ±1-per-departure
  counter — a rough opening was permanent debt (−89 by day 30) — and nothing
  taught or surfaced the mechanic. Changes, all zoo-side: **(1) reputation
  rework** — departures accumulate into a daily guest verdict and reputation
  *drifts toward it* (`## Reputation` in `design/tuning/scenario.md`,
  settled in `ZooBootstrap`); recoverable after a bad open, must be sustained
  to stay high; instant events (death penalty, rare birth) still land on top
  and fade. **(2) Teach it** — 5th tutorial step (place drink stand +
  restroom; unmet needs sink the rating), a one-shot coaching callout the
  first time the daily verdict goes negative (names the most-failed need and
  its amenity), a daily verdict line in the log, and a rep tooltip + target
  in the top bar. **(3) See it** — park-wide unmet-needs strip in the HUD
  ("12 thirsty · 4 hungry"), ☺/☹ departure floats at the gate, per-axis
  ✓/✗ end screen (no more "short of the goal" when cash finished over
  target). **(4) Starter park** re-amenitized for the crowd it actually
  pulls (2 food / 3 drink / 2 restrooms / 3 benches — was 1/1/2/1).
  **(5) UX/bug sweep** — zone-tile ghost now says "extends Exhibit #N vs new
  exhibit" (the iso orphan-tile trap), exhibit panel ADD list moved above
  INSIDE (reflow misclick), child/family/enthusiast guests now render in
  top-down (were invisible), top-bar stats stopped drifting the buttons,
  "Appeal" star labeled, `?` help gained a controls reference, and the
  gitignored `godot_mcp` autoload no longer ships in the export (boot
  errors in CI/web builds). Suite 55 → 62 green.
- **2026-06-07** — **Animals-as-agents direction set (spec authored, not yet
  scheduled).** Decided to pursue promoting animals from static `Placement`
  records to real engine `Agent`s — moving, needs-driven individuals — so their
  movement is a consequence of the model, not a renderer trick (North Star
  principle 2). Full design contract:
  [`design/animals_as_agents_spec.md`](./design/animals_as_agents_spec.md).
  Key findings: it's **overwhelmingly zoo-side** on the existing agent system
  (new `animal` `AgentType` with `spawn_weight 0`, `AnimalBehavior` free-roam
  state machine — **no pathfinding needed**, welfare-as-needs, Placement↔Agent
  lifecycle binding, save/load persistence). **One engine seam filed:**
  `AgentPool.compute_aggregate_satisfaction()` averages over *all* agents and
  drives the visitor spawn curve, so animal welfare would leak into guest
  demand (a hungry lion suppressing arrivals). Proposed additive
  `AgentType.drives_spawn_balance` flag, **target engine v0.6.x** — *not*
  patched in place. **Sequencing:** depends on that engine bump; slots
  naturally as a Phase 3 deepening of the welfare/breeding systems (it makes
  welfare continuous and watchable) but is **parked pending the post-playtest
  go/no-go** — promote into a phase then, don't start the engine work before.
  *Interim:* both renderers amble animals via a presentational sine-wander
  (top-down already did; iso added today) — explicitly a stopgap the spec
  deletes once the sim owns the position.
- **2026-06-07** — **Marketing campaigns (4.2).** Spend cash to promote a
  guest archetype for a few days (spawn-weight boost), closing the
  investment→visitor-mix loop the archetypes opened. Run from the gate
  admin panel; persists through save/load. *(Pulled forward from Phase 4 —
  it's small and synergistic; the broader Phase 4 reach work still waits on
  engine v1.0.)*
- **2026-06-07** — **Difficulty scenarios (2.6) + a save/load fix.**
  **Difficulty** (Easy / Standard / Hard) as a scenario overlay — overrides
  the win bar, opening cash, and a global demand multiplier; picked at the
  welcome screen, shown live in the MISSION panel. **Save/load was found
  broken** (the engine persists entities + ledger but not region placements,
  and doesn't rebuild regions on load → loading produced an empty park).
  Fixed zoo-side via `register_game_state_provider`: placements + their
  welfare/age state and all zoo settings now round-trip intact (proven by a
  new test). That's an engine gap (RegionRegistry has no `save_state`)
  worked around in zoo code — a candidate to push upstream. Suite 33 → 37.

- **2026-06-07** — **All six Phase 3 systems landed early** (3.1–3.6), all
  engine-clean: **welfare** (care-driven health/illness/death), **guest
  archetypes** (Adult/Child/Family/Enthusiast — preferences, decay, traits,
  spend), **staff** (hire zookeepers → daily welfare vs. wages), **day/night
  + opening hours** (SimClock-derived; HUD clock + dusk tint), **breeding &
  generations** (well-kept pairs breed, space-capped; aging + old-age
  death + rare-birth milestones), and **weather + seasons** (daily roll ×
  season, both scaling guest demand). Two effects are intentionally deferred
  to future engine hooks: nocturnal-appeal-by-time and per-animal
  climate/welfare. Staff is a robust effect layer (not yet a walking
  population). Test suite grew 8 → 33, all green. *(Pulled forward ahead of
  the Phase 2 exit gate; the playtest is the go/no-go.)*
  **Guest archetypes** — Adult / Child / Family / Enthusiast, each a
  weighted `AgentType` sharing one behavior but differing in appeal
  preferences (so exhibit mix decides the crowd), need-decay, traits, and
  spend (Family 2.2× … Child 0.5×, so the mix shows in the books). Tinted
  by type on the map. **Animal welfare** — a care-driven welfare meter per
  animal: poor exhibits erode it (scaling appeal down), low welfare →
  sick, zero → death + reputation hit; surfaced as panel %/sick flag, a
  map ✚, and log alerts. Both are zoo-side (no engine changes). One minor
  seam noted: `RegionRegistry.remove_placement` always half-refunds, so a
  death's refund is negated in zoo code. Zoo 25/25.
- **2026-06-07** — **Paths-only guest movement landed (engine v0.6.0 →
  v0.6.1).** Bumped the engine to its new navigation surface
  (`WalkableNetwork`, `INetworkNavigator` + default A\*,
  `NavigationRegistry`, engagement-distance helper) and wired the zoo onto
  it: a walkable `path` tile (paint-to-place), guests route the network
  toward exhibits/amenities and view from a path cell within the
  engagement distance, and a "no path access" warning flags unreachable
  exhibits. Path-first with a free-roam fallback (no network / off-network
  / unreachable) — the sanctioned rollout step, so the economic loop still
  works with zero paths. **Found + fixed an engine bug along the way:**
  v0.6.0's `ContentDB` parsed the `walkable` columns inside the optional
  `useful_life_days` block, so no tile ever registered as walkable; fixed
  at the source per [`CLAUDE.md`](./CLAUDE.md) §1 (engine **v0.6.1**, commit
  `4040ef6`) — writeup + durable patch in
  [`design/engine_patches/`](./design/engine_patches/). The engine
  commit/tag still needs pushing to the engine remote (this session lacked
  credentials). Engine 295/295; zoo 20/20.
- **2026-06-07** — **Landed the Zoo Tycoon character pack (minus paths).**
  Shipped adaptation-plan §6 commits 5–10 entirely in zoo code, engine
  submodule untouched: four guest needs (hunger / thirst / restroom /
  energy) with the eat→restroom spillover; bracketed ticket pricing with
  demand elasticity; per-exhibit donation boxes; a 0–100 suitability
  rating with an always-on "next most impactful" recommendation;
  need-aware guest mood bubbles; and the Compost Building + reputation-
  gated Restaurant capstone (which also switches on the engine's dormant
  unlock machinery in the build UI). New game-side tuning lives in
  `design/tuning/services.md`. **Paths-only guest movement (commits 1–4)
  was deliberately not attempted** — it is gated on engine **v0.6.x** per
  [`design/engine_seam_agent_navigation.md`](./design/engine_seam_agent_navigation.md)
  and the engine submodule is read-only ([`CLAUDE.md`](./CLAUDE.md) §1);
  it stays the top Zoo-Tycoon-flavored priority the moment that tag
  lands. Smoke test 17/17.
- **2026-06-06** — **Agent navigation on a constrained network is
  engine work, not zoo work.** Every tycoon on this engine needs
  network-walking agents (zoo paths, hospital corridors, mall
  aisles), so the capability belongs behind the engine seam. Filed as
  [`design/engine_seam_agent_navigation.md`](./design/engine_seam_agent_navigation.md),
  targeting engine **v0.6.x**. Hard gate on the first four
  paths-only commits in the adaptation plan; the rest of the
  Zoo Tycoon character pack can land in parallel without it.
- **2026-06-06** — Adopted the **Zoo Tycoon Adaptation Plan**
  ([`design/zoo_tycoon_adaptation_plan.md`](./design/zoo_tycoon_adaptation_plan.md)).
  Pulls a ranked bundle of patterns from the 2001 game into the
  existing phases without replacing them. Headline: **paths-only
  guest movement** becomes a Phase 1 prerequisite; the
  "Zoo Tycoon character pack" (4 needs, bracketed pricing, donations,
  suitability rating, guest mood bubbles, Compost Building,
  Restaurant capstone) lands in Phase 1 alongside it. Guest types
  pull forward into Phase 2; welfare/staff/breeding adoptions stay
  in Phase 3 as planned. Research dossier:
  [`design/research/zoo_tycoon_2001_reference.md`](./design/research/zoo_tycoon_2001_reference.md).
- **2026-05-25** — Roadmap v2. Reframed from "validation game →
  successor repo" to "this *is* the product." Engine read-only contract
  retained; `CLAUDE.md` §0 scope rules are superseded by this document
  and need a follow-up edit to reflect that.
- **2026-05-25** — Roadmap v1 (superseded) had a graduation step into
  a new repo; dropped because we always intended this to be the real
  game.

---

## 7. Backlog (parking lot)

Ideas that aren't committed to any phase. Promote into a phase via the
decision log, don't slip them in silently.

- Steam Workshop integration
- Multiplayer / shared zoos (very speculative)
- Animal genetics depth (coat patterns, traits, lineage trees)
- Educational mode / school edition
- Mod support beyond scenarios
- Console ports (would require engine input rework)
- Sequel theming on the same engine (theme park, hospital, transit)
  — only if Phase 4 launch validates the engine commercially

---

## 8. What this roadmap deliberately does not include

- Dated Gantt charts. Cadences are weeks; dates lie with a single
  builder.
- Monetization plan. Distinct decision, not yet ripe.
- Engine-internal milestones. Those live in
  `engine/docs/build-plan.md`.
- Marketing strategy beyond launch (4.6).
