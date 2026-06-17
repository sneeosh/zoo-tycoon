# Zoo Tycoon — Product Roadmap

**Status:** Living document. Last updated 2026-06-14.
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

Built on **engine v0.6.1** (zones + placeables + sprite set + a walkable
navigation network). The economic loop is live and honest:

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

Since this section was first written, **most of Phases 1–4 has landed
ahead of schedule** (see the decision log): audio, save versioning +
migration, difficulty scenarios, marketing campaigns, all six Phase 3
deep systems (welfare, guest archetypes, staff, day/night, breeding,
weather/seasons), a touch input first-pass, a selectable land-plot
system, an isometric art pass, and a GitHub Pages deploy pipeline. The
simulation is feature-rich. **76 GUT tests green.**

**Strengths:** loop is real, the systems interact honestly, art reads as
a tycoon (not a debug harness), engine has held under heavy feature
pressure with the only seam (animal welfare → spawn balance) cleanly
filed against the engine rather than patched in place.

**Gaps that block a *launch* (not a "real game" feeling — we have that):**
the *product wrapper* around the simulation is thin. We have never
verified the public build is actually live, fast, and crash-free in a
real browser over a long session; no human has playtested it; there is
no telemetry, so the launch funnel is blind; player settings (volume,
mute, view) don't survive a reload; there is no accessibility pass, no
finished portrait/mobile HUD, no research tree, no achievements, no
localization, and only the single 30-day scenario. These are sequenced
in the new **Phase 5 (Make it shippable)** and **Phase 6 (Make it
stick)** below.

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
| 1.1 ⚙️ | **Web export, hosted publicly** | Engine is web-first. If it can't ship to a browser, nothing downstream matters |
| 1.2 ✅ | **Win + lose conditions** — "Hit $20k cash and 50 reputation in 30 days," and "bankruptcy = game over"; surfaced in goals panel | Sandboxes don't make memories. A finish line creates the moment-to-moment urgency the economy needs |
| 1.3 ✅ | **Onboarding** — guided first 60s; build a region, place an animal, watch a visitor pay | Welcome modal is passive. Browser-tab attention is brutal |
| 1.4 ⚙️ | **Performance budget pass** — 60 fps on a mid-2022 laptop browser with 100+ visitors | Web perf is the differentiator; if we miss the budget, every later phase suffers |
| 1.5 ⬜ | **First playtest gauntlet** — 5+ external testers, recorded sessions | Until someone who didn't build it plays it, we don't know what we built |

*Legend: ✅ shipped · ⚙️ partially landed / needs verification · ⬜ not started.*

**Exit criteria:**

- [ ] Public URL loads in <5s, plays to win or lose without crash. *(Deploy
      pipeline built — `.github/workflows/deploy.yml` → GitHub Pages — but
      never verified live or over a long browser session. Closed in 5.1.)*
- [ ] ≥5 external playtest sessions logged with notes. *(Only automated
      Fable end-to-end runs so far; no humans. Closed in 5.2.)*
- [x] Smoke test green. *(76 GUT tests passing.)*
- [x] No new uncaptured engine seams. *(The one seam — welfare → spawn
      balance — is filed: `design/animals_as_agents_spec.md`.)*

---

### Phase 2 — **Make it sing** *(weeks 5–10)*

Phase 1 is silent and desktop-only. Phase 2 is where the game starts to
feel alive on the platforms players actually use.

| # | Initiative | Why | Engine impact |
|---|---|---|---|
| 2.1 ✅ | **Audio integration** — SFX on purchase / visitor leave / day rollover, one ambient loop, master volume | Sound is half the tycoon-game feeling. We have none | ~~Likely engine v0.6 seam~~ — **no seam**; audio is presentation, shipped zoo-side |
| 2.2 ⚙️ | **Mobile / touch input** — pinch-zoom, drag-pan, tap-to-place, portrait HUD | Most web traffic is mobile. Desktop-only "web" is half an export | Input routing in `tycoon_core` UI layer. *(Tap/pan/pinch landed; **portrait HUD still open** → 5.6.)* |
| 2.3 ⬜ | **Accessibility pass** — colorblind-safe auras, min font size, keyboard nav | Public-build hygiene; also a forcing function for engine UI primitives | Theme / palette plumbing. *(→ 5.5.)* |
| 2.4 ⬜ | **Telemetry** — opt-in analytics: session length, day reached, win/lose, drop-off step | We can't tune what we can't measure | Event bus completeness. *(Blocked on a data-destination decision → 5.3.)* |
| 2.5 ✅ | **Save format migration** — write a save on v0.5, load it on v0.6, prove forward-compat | Saves are where tycoon games die. Catch this seam at v0.6, not v1.0 | Versioned payload (`SAVE_VERSION`, now v3) + legacy-load test; done zoo-side |
| 2.6 ✅ | **Difficulty scenarios** — Easy / Standard / Hard via tuning overlays | First test of variant configs without forking | Tuning loader composition |

**Exit criteria:**

- [ ] Audio + touch shipped, accessibility audit passed. *(Audio ✅ and
      touch ✅ shipped; accessibility ⬜ pending → 5.5.)*
- [ ] ≥20 external playtest sessions, "would you play again" ≥ 60%. *(No
      human sessions yet → 5.2.)*
- [x] Engine seams from 2.1/2.5 resolved or formally deferred. *(2.1 had
      no seam; 2.5 solved with save versioning.)*

---

### Phase 3 — **Make it deep** *(months 3–6)*

Now the simulation actually starts to be a *zoo*. This is where the
game finds its 50-hour identity. Each item below is a system, not a
feature — they interact, and that's the point.

| # | System | What it adds | Depends on |
|---|---|---|---|
| 3.1 ✅ | **Animal welfare** — happiness from existing model drives behavior, illness, death; welfare alerts in HUD | Animals become more than props; player attention pivots from layout to care | None — extends existing `IPlaceableHappiness` |
| 3.2 ✅ | **Visitor archetypes** — families, thrill-seekers, photographers, school groups; each with its own appeal-match profile | Single visitor type makes the appeal axes feel academic. Archetypes make exhibit-mix decisions matter | Adult / Child / Family / Enthusiast shipped via weighted `AgentType` |
| 3.3 ✅ | **Staff agents** — zookeepers, vendors, mechanics; second agent population | Tests engine multi-population claim; gives the player labor to manage | Shipped as a welfare/wage **effect layer**; not yet a *walking* population (→ animals-as-agents, 6.6) |
| 3.4 ✅ | **Day/night + opening hours** — visitors spawn only during open hours; nocturnal animals shift appeal | Pacing. A flat 240-tick day is identical every day | SimClock-derived; nocturnal-appeal-by-time deferred to an engine clock hook |
| 3.5 ✅ | **Breeding & generations** — animals pair, produce offspring, age out; rare-genome milestones | The depth hook. Players who care about animals stay for breeding | Welfare (3.1) must land first |
| 3.6 ✅ | **Weather + seasons** — modifies spawn and welfare; cosmetic + functional | Variety, plus another forcing function on the simulation's robustness | Daily roll × season, both scaling demand |

**Exit criteria:**

- [x] All six systems shipped behind the same web build. *(3.1–3.6 all
      landed — see the 2026-06-07 decision-log entry.)*
- [ ] Median session length doubles vs. end of Phase 2. *(Unmeasurable
      until telemetry lands → 5.3.)*
- [x] 30-day campaign is winnable on Standard, hard on Hard, and a
      sandbox mode exists for players who just want to build. *(Winnability
      locked by an 8-day arc test; "Keep playing" sandbox continuation
      exists. Hard-mode difficulty wants a human-tuned pass in 5.2.)*
- [ ] Engine reaches **v1.0** — stable surface, no expected breaking
      changes. *(Engine is at v0.6.1; v1.0 still gates the editor/research
      surfaces in Phase 6.)*

---

### Phase 4 — **Make it reach** *(months 6–12)*

The game exists. Phase 4 is about getting it in front of people and
giving it legs after launch.

> **Status (2026-06-14):** the simulation arrived ahead of the product
> wrapper, so Phase 4 has been **re-sequenced**. Marketing (4.2) shipped
> early. The remaining reach items (4.1, 4.3, 4.4, 4.5) and the launch
> itself (4.6) now live in **Phase 6 — Make it stick**, gated behind the
> new **Phase 5 — Make it shippable**. This table is kept for history;
> the live plan for these items is in §3 Phases 5–6 below.

| # | Initiative | Why |
|---|---|---|
| 4.1 ➡️6.1 | **Research tree** — replaces the linear unlock chain; spend points on tech, husbandry, amenities | Meta-progression. Gives long sessions a vector other than "more cash" |
| 4.2 ✅ | **Marketing campaigns** — spend cash to bias spawn weights toward archetypes | Closes the loop between investment and visitor mix — a classic tycoon move. *(Shipped 2026-06-07.)* |
| 4.3 ➡️6.3 | **Scenario set + editor** — 6–10 hand-tuned scenarios plus a basic editor | Replayability; community content tests tuning at scale |
| 4.4 ➡️6.2 | **Achievements + light meta** | Standard table stakes for tycoon-genre retention |
| 4.5 ➡️6.4 | **Localization** — EN + 3 languages | Web reach is global. Most of our audience isn't anglophone |
| 4.6 ➡️6.8 | **Public launch** — Steam, itch.io, web simultaneously; press kit; trailer | The moment we earn back the runway |

**Exit criteria:** the game is launched. Beyond launch, the roadmap
becomes a backlog driven by player data, not by phases.

---

### Phase 5 — **Make it shippable** *(the launch-readiness gate)*

We built the systems before we built the product around them. Phases 1–3
(and most of 2 and 4) shipped early, so the simulation is rich — but
"the systems exist" is not "a stranger can find it, play it on their
phone, and come back tomorrow." **Phase 5 adds no simulation system.** It
hardens, wraps, and *proves* what we already have. This is the honest
gate between a feature-complete sandbox and a launchable product — and
the place several long-deferred Phase 1/2 exit criteria finally close.

Two buckets: **A — prove it ships**, **B — wrap the sim for strangers.**

| # | Initiative | Why | Closes |
|---|---|---|---|
| 5.1 | **Prove the public build** — confirm the Pages deploy is live at a real URL, cold-loads <5s, and survives a *long* browser session without the WebGL object-handle exhaustion the 1.4 static-layer split was meant to fix but never re-verified in-browser. Desktop + mobile Safari/Chrome smoke | We have a deploy pipeline and a perf *theory*; we have never watched a stranger's tab stay alive for 30 in-game days. Until we have, the platform claim is unproven | 1.1, 1.4 |
| 5.2 | **Real human playtests** — ≥5 external testers on the live URL, recorded, with a first-session funnel log | Automated Fable runs find balance bugs; they can't tell us where a human quits in the first 90 seconds. This is the actual Phase 1/2 go/no-go | 1.5, P2 gate |
| 5.3 | **Telemetry + privacy notice** — decide where data goes, then ship opt-in events: session length, day reached, win/lose, drop-off step; plus a privacy notice | We cannot tune a launch funnel blind, and three exit criteria (1.x, 3.x) are unmeasurable without it | 2.4 |
| 5.4 | **Settings, options & pause menu** — a real settings surface (not the Park Admin panel): master / SFX / ambient volume, mute, view toggle, accessibility prefs — **persisted to `user://`** so they survive a reload | Today nothing the player sets survives a refresh; on the web that's every session. Table-stakes polish | new |
| 5.5 | **Accessibility pass** — colorblind-safe appeal auras & welfare flags, a minimum font size, full keyboard nav + focus order | Public-build hygiene; also the forcing function for engine UI primitives we flagged at 2.3 | 2.3 |
| 5.6 | **Mobile / portrait HUD** — finish the portrait layout the touch first-pass left open; reflow the build menu and stat bar for a phone held upright | Most web traffic is a phone in portrait. Tap-to-place without a portrait HUD is half a mobile build | 2.2 |
| 5.7 | **QA / bug-bash hardening** — a dedicated stability pass: long-session memory, save-corruption resilience & a clear "save failed" state, graceful handling of a malformed/old save, and an About / version / credits screen | Tycoon games die on saves and on the one crash that eats an evening's zoo. Find them before strangers do | new |

**Exit criteria (this is the real launch gate):**

- [ ] Live public URL, verified <5s cold load, no crash across a full
      win *and* a full lose session, on desktop **and** a real phone.
- [ ] ≥5 recorded external playtests; "would you play again" ≥ 60%.
- [ ] Telemetry live behind opt-in + a privacy notice; first-session
      funnel visible.
- [ ] Accessibility audit passed; **every** player setting persists
      across a reload.
- [ ] Smoke suite green; no new uncaptured engine seams.

---

### Phase 6 — **Make it stick** *(depth, reach & launch)*

Phase 5 makes the game launchable; Phase 6 gives a launched game reasons
to be reopened, and then ships it. It absorbs the still-unbuilt Phase 4
reach items and adds the retention hooks a zoo game actually lives on.
**Do not start Phase 6 until Phase 5's gate is met.** Items marked ⚙️
still wait on the engine cadence in §4.

| # | System / Initiative | What it adds | Was |
|---|---|---|---|
| 6.1 | **Research / husbandry tree** — spend earned points on tech, husbandry, amenities; replaces the linear unlock chain | A long-session vector other than "more cash"; the meta-progression spine | 4.1 |
| 6.2 | **Achievements + light meta** — milestones across welfare, breeding, attendance, money | Genre table stakes for retention; gives playtests something to chase | 4.4 |
| 6.3 | **Scenario set + editor** ⚙️ — 6–10 hand-tuned scenarios (rescue zoo, frozen climate, tight-budget) plus a basic editor | Replayability past the single 30-day arc; community content stress-tests tuning | 4.3 |
| 6.4 | **Localization / i18n extraction** — extract every hardcoded string into a catalog now; EN-only at launch is fine | Strings are hardcoded today; retrofitting i18n after launch is brutal. Do the extraction early even if we ship one language | 4.5 |
| 6.5 | **Content breadth + emotional hooks** — more species / amenities / décor, and the hooks a zoo lives on: **name your animals**, a **lineage / family-tree view** on top of breeding, and a **photo / share mode** for virality | 12 species and an unnamed crowd is a tech demo; named animals you bred across generations are a *zoo*. Also the cheapest marketing we have | new |
| 6.6 | **Animals-as-agents** ⚙️ — promote animals from static `Placement` records to real engine `Agent`s (the parked 2026-06-07 spec) so welfare is *watchable*, not a hidden meter | Makes the welfare/breeding depth legible on screen; the payoff of Phase 3's investment | new (spec'd) |
| 6.7 | **Audio depth** — beyond the single ambient loop: layered SFX, a small music set, day/season-aware ambience | One loop reads as a prototype; a launch needs a soundscape | new |
| 6.8 | **Public launch** — Steam + itch.io + web simultaneously; store pages, press kit, trailer, landing page, launch-day privacy/legal | The finish line. Everything above earns the right to do this once, well | 4.6 |
| 6.9 | **Make the day-to-day sing** — the fun cluster: emergent **events / park stories** (incl. the **escaped-animal crisis**), a short-term **contracts** drip, **zoo identity** (name your zoo + star attraction), light **economic levers** (sponsorship / loan), and **hand-tuned scenarios** | The systems are deep but read as meters; this is the layer that turns the honest simulation into *stories you stay up for*. Engine-clean, so it doesn't wait on v1.0 | new (PM sweep 2026-06-17) |

**Exit criteria:** the game is launched on all three storefronts with a
research vector, achievements, ≥6 scenarios, an i18n-ready string
catalog, named/breedable animals, and a soundscape. Beyond launch the
roadmap becomes a player-data-driven backlog, not a phase plan.

---

## 4. Engine dependency map

The engine ships independently. This roadmap depends on its cadence —
if the engine slips, we **shrink zoo scope**, never patch the submodule.

| Engine release | Needed for | Notes |
|---|---|---|
| ~~v0.5.0~~ | Phase 1 | Shipped |
| **v0.6.1 *(current)*** | Audio (2.1, no seam), mobile input (2.2), save migration (2.5), **agent navigation on a constrained network** (paths-only) | Navigation landed (`WalkableNetwork`, `INetworkNavigator`); fixed an engine `ContentDB` walkable-parse bug along the way. Seam spec: [`design/engine_seam_agent_navigation.md`](./design/engine_seam_agent_navigation.md). **Open item:** the commit/tag still needs pushing to the engine remote + a CHANGELOG |
| v0.6.x | **`AgentType.drives_spawn_balance` flag** for animals-as-agents (6.6) | Filed seam — animal welfare must not leak into guest spawn demand: [`design/animals_as_agents_spec.md`](./design/animals_as_agents_spec.md) |
| **Phase 5 is engine-clean** | Deploy proof, telemetry, settings, a11y, portrait HUD, QA (5.1–5.7) | The launch-readiness gate needs **no engine work** — it's all product wrapper. Don't let an engine slip stall it |
| v0.7.x | Nocturnal-appeal-by-time clock hook (3.4 polish), weather event hooks (3.6 polish) | Deferred effects, not blockers |
| **v1.0** | Stable surface for the Phase 6 **research tree (6.1)** and **scenario editor (6.3)** | Hard gate before that editor surface; the rest of Phase 6 can proceed without it |
| v1.x+ | Post-launch reach work | |

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

- **2026-06-17** — **PM fun sweep: opened 6.9 "Make the day-to-day sing";
  shipped the emergent-events system (incl. the escaped-animal crisis).** A
  product review found the roadmap rich on *systems depth* (Phase 3/6) and
  *launch wrapper* (Phase 5) but thin on the layer between them — the
  moment-to-moment "why is this fun right now". The only goal vector is the
  30-day win bar, and the deep simulation reads as meters, not stories. Opened
  **6.9** as the engine-clean fun cluster and built its marquee item first:
  **(A) Emergent events / "park stories"** — a once-a-day weighted roll
  (`design/tuning/events.md`, compiled by `src/events_config.gd`, rolled in
  `ZooBootstrap` on a dedicated fixed-seed RNG so it never perturbs the tuned
  weather/breeding/spawn sequence) that fires a one-off event with instant
  cash/reputation and/or multi-day demand effects, narrated in the HUD log + a
  toast (`park_event` signal → `main.gd`). Effects compose with the existing
  economy (Ledger, the reputation drift, the spawn-rate curve) — nothing fake.
  **(B) The escaped-animal crisis** lands as a `requires: sick_animal` event
  (escape + inspection-failure), so the welfare meter finally has teeth: a
  crisis can only befall a zoo already neglecting care, dramatic without being
  unfair. Events are gated by `min_day`/`cooldown`/world state, round-trip
  through save **v4→v5** (`active_events` + cooldown clock; older saves default
  to none-in-flight), and ship with `tests/test_events.gd`.
  **(C) Contracts** — *also shipped this sweep:* a rotating slate of
  rewarded short-term objectives (`design/tuning/contracts.md` +
  `src/contracts_config.gd`, slate/payout in `ZooBootstrap`), the steady pull
  the single win bar lacks. `active_slots` (3) contracts are dealt from the
  pool, reviewed at day close; a fulfilled one pays cash + reputation through
  the normal Ledger/reputation paths and the next pool entry refills its slot.
  Metrics (animals / species / exhibits / births / revenue / reputation /
  balance) are all read from live state — no new surface. Surfaced as a live
  **CONTRACTS** HUD panel (progress ticks as you build) + a completion
  log line/toast; round-trips through save **v5→v6** (`active_contracts`,
  `completed_contracts`, `run_births`; older saves get a fresh deal on load);
  `tests/test_contracts.gd` covers the config, metrics, payout + refill, and
  the save payload. *Verification gap, stated honestly:* this environment has
  **no Godot binary** (and the engine submodule isn't checked out), so the GUT
  suite (now ~115 tests) and a boot/web-export pass were **not** run here —
  needs a headless `gut` run before merge. No engine edits — submodule
  untouched. **The rest of 6.9 is written up and sequenced, not yet built:**
  **(D) Zoo identity** — name your zoo + a surfaced "star attraction"
  (top-donation exhibit) for earned pride; small but high-charm. **(E)
  Economic levers** — a sponsorship (cash now for a branding/appeal cost) and a
  loan (bridge a rough open — directly answers the "rough open is a permanent
  hole" theme the reputation rework fought), the genre's "interesting
  decisions". **(F) Hand-tuned scenarios** — 2–3 tuning-overlay scenarios
  (rescue zoo, tight-budget, frozen climate) for replayability *now*, ahead of
  the v1.0-gated editor (6.3), reusing the difficulty-overlay pattern.
  Recommended next: **(D) Zoo identity** — cheap, high-charm, and it makes the
  named-animals work (6.5) pay off at the park level. **Guardrail:** none of
  6.9 jumps the Phase 5 launch gate — it lands as retention polish behind it,
  per §5's scope-sprawl risk.
- **2026-06-16** — **Animals-as-agents (6.6) shipped; engine bumped to
  v0.7.0.** The filed seam landed: engine **v0.7.0** adds the additive
  `AgentType.drives_spawn_balance` flag (default true), so a non-customer
  population can be kept out of the guest spawn-demand curve. Bumped the
  submodule to it and built the parked spec
  ([`design/animals_as_agents_spec.md`](./design/animals_as_agents_spec.md))
  entirely zoo-side: an `animal` AgentType (spawn_weight 0,
  drives_spawn_balance false) with food/water needs; `AnimalBehavior`
  (free-roam, seek troughs, herd drift, contained to the enclosure — no
  pathfinding) on a dedicated RNG so it never perturbs the tuned
  visitor/weather/breeding sequence; `AnimalSatisfactionModel` (welfare =
  weakest-link of food/water/social/space, excluded from spawn balance);
  a 1:1 Placement↔Agent lifecycle via a reconcile pass on placement/region
  signals (player placement, breeding births, neglect/old-age deaths all
  bind/unbind with no call-site changes); save **v4** round-trips animal roam
  state; and both renderers now draw animals at the sim's real position
  (the old sine-wander is a pre-bind fallback). The day-end care model
  (habitat + keepers) stays the survival authority for illness/death/breeding;
  this adds the continuous, watchable welfare on top — unifying the two is a
  tunable follow-up. Verified by running Godot 4.5.1 headless: **97/97 GUT
  green**, clean boot, clean web export. *Note:* engine documents v0.7.0 in its
  CHANGELOG but hasn't pushed a git **tag**, so the submodule pins the commit.
- **2026-06-14 (b)** — **Phase 5/6 engine-clean build-out: settings,
  telemetry, achievements, i18n, accessibility, naming/lineage, audio depth,
  portrait reflow.** Worked the *codeable* remainder of Phases 5–6, all
  engine-clean, **verified by actually running Godot 4.5.1 headless** (GUT
  **89/89 green**, clean game boot, and a successful web export that packs the
  new i18n/achievements/audio). Shipped: **5.3 Telemetry** — opt-in,
  **local-only** event log (session length / day reached / win-lose /
  tutorial drop-off) + a privacy notice; the "where does data go" blocker is
  resolved privacy-first (no network egress). **5.4 Settings/pause menu** —
  new `Settings` autoload persists volume mix, view, speed, and accessibility
  prefs to `user://settings.json`; a real settings modal (⚙ / Esc) that
  pauses the sim; **every player setting now survives a reload** (the net-new
  gap). **5.5 Accessibility** — colorblind-safe welfare/appeal colors
  (`Palette`), a larger-text UI zoom, Esc/1/2/4 keyboard controls. **5.6
  Portrait** — the build panel is collapsible and auto-hides on a narrow
  viewport (full portrait polish still wants in-browser iteration, gated with
  5.1). **5.7 hardening** — loud save-failed/load-failed banners, a wired
  `load_failed` handler, and an About/version/credits screen. **6.2
  Achievements** — 12 milestones from `design/tuning/achievements.md`,
  progress persisted as a cross-game profile, toast + list UI. **6.4 i18n** —
  string catalog (`assets/i18n/strings.json`) + `I18n.t()` with English
  fallback; new surfaces routed through it, the rest a mechanical follow-up.
  **6.5 Emotional hooks** — animals carry an individual **name** (+ generation
  + parent), breeding threads lineage, a **🐾 lineage view** renames them
  inline, births announce the newborn by name, and **📷 photo mode** saves a
  PNG. Save payload v3→v4 with forward migration. **6.7 Audio depth** —
  day/night/rain ambience variants + a calm music bed, selected by world
  state. *Deliberately not done (blocked, not skipped):* **5.1** live-URL
  verification & **5.2** human playtests (need a real browser + external
  testers — no display here); **6.1** research tree & **6.3** scenario editor
  (hard-gated on **engine v1.0**); **6.6** animals-as-agents (needs the filed
  `AgentType.drives_spawn_balance` engine seam); **6.8** launch (storefront
  work). No engine edits — submodule untouched.
- **2026-06-14** — **Launch-readiness sweep: added Phase 5 (Make it
  shippable) + Phase 6 (Make it stick); checked off what's shipped.** A
  code audit confirmed the simulation has run ahead of the product: audio,
  save versioning + migration, difficulty, marketing, all six Phase 3
  systems, a touch first-pass, land plots, the iso art pass, and a Pages
  deploy pipeline are all in code (76 GUT tests green). What's *missing
  before launch* is not another system — it's the wrapper around the one
  we have. **New Phase 5 (engine-clean gate):** prove the public build is
  actually live/fast/crash-free over a long session (5.1, closes 1.1/1.4),
  real human playtests (5.2, closes 1.5), telemetry + privacy (5.3, closes
  2.4), a real settings/pause menu with **`user://`-persisted prefs** (5.4,
  net-new — nothing the player sets survives a reload today), accessibility
  (5.5, closes 2.3), the still-open portrait HUD (5.6, closes the 2.2
  remainder), and a QA/bug-bash hardening pass with save-corruption
  resilience + an about/credits screen (5.7, net-new). **New Phase 6**
  absorbs the unbuilt Phase 4 reach items (research tree → 6.1, achievements
  → 6.2, scenarios+editor → 6.3, localization → 6.4, launch → 6.8) and adds
  the retention hooks a zoo lives on: content breadth + **name-your-animals
  / lineage view / photo-share** (6.5), the parked **animals-as-agents**
  spec (6.6), and **audio depth** (6.7). Phase 4's table is kept for history
  with ➡️ pointers; exit-criteria boxes across Phases 1–3 are now ticked
  honestly — smoke/seams/Phase-3-systems ✅; deploy-verify, human playtests,
  telemetry-gated metrics, and engine v1.0 explicitly **not** yet. No engine
  or code changes in this entry — roadmap only.
- **2026-06-12 (c)** — **Zoo land types: selectable plots (climate × size ×
  price) + sell-to-relocate.** New game now picks a land plot on the
  welcome screen (`design/tuning/zoo_types.md`): each plot is a climate
  (biases the daily weather roll and scales demand), a buildable grid
  size, and a purchase price paid from the difficulty's starting cash.
  Park Admin grows a "Land & relocation" section that sells the whole
  zoo (75% of land price + the standard ½ sell-back on buildings and
  animals, posted through the engine's normal refund paths) to fund a
  move to a different plot. Consequences: the world size and gate cell
  are now runtime state on `ZooBootstrap` (`plot_size()` / `gate_cell()`)
  — nothing may hardcode 32×18 / (0,17) anymore; the top-down view gained
  fit-to-plot tile scaling (it has no camera); the iso lawn now matches
  the buildable plot exactly (it was 28 cols vs the buildable 32 — a
  latent bug); save payload bumped to v3 (`zoo_type`, older saves resolve
  to the free default plot). The default plot is free and identical to
  the old hardcoded world, so the canonical Standard winnability arc is
  untouched. *Same day:* catalog expanded from 4 to 12 plots across 9
  climates (one — Crownleaf Estate — priced beyond any starting bankroll
  on purpose, a relocation goal), both plot selectors became wrapping
  flow containers so the catalog can keep growing, and the system is
  documented as data-driven: `design/zoo_types_guide.md` describes every
  type and the authoring rules for adding new ones by editing
  `design/tuning/zoo_types.md` alone (the loader rejects bad rows —
  duplicate ids, unknown climates, sub-16×18 plots — loudly).
- **2026-06-12 (b)** — **Art-direction pass: iso is the shipping default,
  and the park now sits in a world.** (1) **Default view flipped to
  isometric** — it's where all the art investment lives; the top-down view
  stays reachable via the **View** toggle and `TYCOON_TOPDOWN=1` (the old
  `TYCOON_ISO` var is retired). (2) **World framing**: horizon-gradient
  backdrop, a forest-floor apron fading out from the lawn (4 gradient
  quads, not per-cell — pan-redraw stays cheap), and a depth-sorted
  silhouette treeline ringing the bounds with a clearing at the gate. The
  playable diamond no longer floats on void. (3) **Lawn life**:
  low-frequency meadow patches + faint mowing bands so big lawns read as
  parkland, not one flat fill. (4) **Water depth**: concentric depth
  shading per pool cell under the existing shimmer/foam. (5) **Golden
  hour**: a warm amber wash leads the night tint in and out at dawn/dusk;
  lamp glows unchanged. (6) **Cloud shadows** drift across the park by
  day (a handful of circles/frame). All view-layer, all art-free, engine
  untouched; before/after captures in `design/playtest/art_pass_*`.
  Suite stays 64 green. Remaining art asks tracked in
  `design/pixel_lab_briefs.md` (Brief 2 directional animals, Brief 3 hero
  objects) — sprites, not 3D; Blender models would need a render-to-pixel
  pipeline we don't have, so crisp ¾-iso PNGs remain the format.
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
- Animal genetics depth (coat patterns, traits, lineage trees) *(the
  lineage/family-tree view promoted into Phase 6.5; deeper genetics stays
  parked here)*
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
