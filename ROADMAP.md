# Zoo Tycoon — Product Roadmap

**Status:** Living document. Last updated 2026-05-25.
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
- 5 animals, 4 zone kinds, 2 amenities, 1 visitor agent type with
  hunger + trait-driven variation.
- HUD covers save/load, financial reports, region management, hover
  inspector, reputation, goals panel, welcome modal, mood bubbles.

**Strengths:** loop is real, art reads as a tycoon (not a debug
harness), engine has held under feature pressure with no seam leaks.

**Gaps that block a "real game" feeling:** no sound, no win condition,
no failure state, no mobile input, no staff, single visitor archetype,
single visitor need, no welfare/breeding, no time-of-day, no scenarios,
no public build.

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
