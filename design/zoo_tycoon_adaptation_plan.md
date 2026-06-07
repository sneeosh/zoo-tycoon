# Zoo Tycoon Adaptation Plan

**Status:** Proposed. Created 2026-06-06.
**Companion to:** [`ROADMAP.md`](../ROADMAP.md) and [`design/research/zoo_tycoon_2001_reference.md`](research/zoo_tycoon_2001_reference.md).
**Owner:** Kenny Johnson.

> A concrete plan for translating the best parts of **Zoo Tycoon
> (2001)** into our current Godot build. The research dossier sets out
> what made the original tick; this document sequences which of those
> patterns we adopt, in what order, and where they slot into the
> phased roadmap. The headline feature — **guests walk only on paths**
> — is item 0 because every other Zoo-Tycoon-flavored system assumes
> it.

This plan does **not** replace the roadmap. The roadmap remains the
strategic contract (north star, phases, exit criteria). This document
is the *tactical* contract for the Zoo-Tycoon-flavored work landing
inside those phases.

---

## 1. Principles for adaptation

The 2001 game is 25 years old. We are not cloning it — we are mining
it. Five rules govern what gets adopted:

1. **Mechanical depth over visual fidelity.** Suitability percentages,
   bracketed pricing, mood bubbles, guest-type personalities — these
   are cheap to implement and carry the design weight. We adopt them
   first.
2. **Fix what the original got wrong.** Maintenance worker AI, the
   "recommendations dry up past 90%" cliff, the late-game
   homogenization into one optimal pen — we have the benefit of
   hindsight. Don't reproduce known bad patterns.
3. **Web budget is the gate.** No system ships if it can't survive the
   browser perf budget at 100+ visitors. Where the original used
   gameplay-thick simulation, we prefer cheaper aggregate models.
4. **The engine submodule is read-only.** Every adoption must be
   reachable through existing `tycoon_core` interfaces. Where it
   can't, that's an engine seam, filed and tagged — see
   [`CLAUDE.md`](../CLAUDE.md) §1.
5. **Don't slip these into the roadmap silently.** Each numbered item
   below is either tied to a roadmap phase or sits in the parking lot
   until promoted via the decision log.

---

## 2. Top-line adoption priorities

Ranked by *value delivered per unit of effort*, biased by what
unblocks the most downstream work.

| Rank | Adoption | Roadmap phase | Notes |
|---:|---|---|---|
| 0 | **Paths-only guest movement** | Phase 1 | Prerequisite for nearly everything else; current perimeter-browsing is a placeholder |
| 1 | **Per-exhibit suitability rating (0–100)** | Phase 1 | We already compute happiness; surface as a single suitability number with breakdown |
| 2 | **Guest types (Adult / Child / Family / Enthusiast)** | Phase 2 (2.x → archetypes lands here anyway) | Aligns with roadmap 3.2 but pulled forward — it's cheap and immediately makes building choice matter |
| 3 | **Guest needs system (hunger / thirst / restroom / energy)** | Phase 1 | We have hunger; expand to four needs with the "needs *also* tick negatively" twist |
| 4 | **Bracketed ticket pricing** | Phase 1 | One-day change, big design payoff |
| 5 | **Donation boxes per exhibit** | Phase 1 | Ties guest enjoyment to per-exhibit income, not just gate take |
| 6 | **Zookeeper assignment to specific exhibits** | Phase 3 (3.3) | Direct adoption; designed *better* than the original — see §5 |
| 7 | **Mood bubbles for guests (already present for animals)** | Phase 1 | Cheapest single engagement win in the original. Extend our existing system |
| 8 | **Compost Building pattern** — high-margin, zero-upkeep, "stinky" building | Phase 1 | Single building, teaches placement tradeoffs |
| 9 | **Restaurant-style all-needs building as late-game capstone** | Phase 1/2 | The economic destination once 4-needs lands |
| 10 | **Research-gated shelters + foliage, not just animals** | Phase 4 (4.1) | Slots into the research tree; deepens the unlock surface |
| 11 | **Breeding** | Phase 3 (3.5) | Already in the roadmap; the original's implementation is the reference |
| 12 | **Escape mechanics + fence strength vs. animal strength** | Phase 3 | Drama. Gates on having real fences (item 1's suitability model) |
| 13 | **Scenario set with bracketed objectives** | Phase 4 (4.3) | Already in the roadmap; the original's 12-scenario shape is the reference |
| 14 | **Animal shows** *(already shipped, see commit 70f40cf)* | — | We're ahead of the original here, but the show-tank+grandstand "exactly one tile away" constraint pattern is worth borrowing |

Items 0–9 are the **"Zoo Tycoon character pack"** — the bundle that
makes the game *feel* like the genre touchstone. Items 10–14 are
roadmap-aligned and reach further.

---

## 3. Phase-by-phase integration

Slots each adoption into the existing roadmap rather than replacing
it.

### Phase 1 — *Make it a game* (current)

**Headline addition: Zoo Tycoon character pack.** Land items 0, 1, 3,
4, 5, 7, 8, 9 from §2. None of them add new systems — they make the
systems we already have *feel like a real zoo tycoon*.

| Adopt | Effort | Notes |
|---|---|---|
| 0 — Paths-only movement | M | See §4 for the full design |
| 1 — Suitability rating | S | Surface existing happiness as a 0–100 number with a per-axis breakdown panel |
| 3 — Four guest needs | M | Hunger exists; add thirst, restroom, energy as parallel meters with the negative-spillover quirk |
| 4 — Bracketed pricing | XS | Replace continuous pricing with 4 brackets; document elasticity in tuning |
| 5 — Donation boxes | S | New per-exhibit `donation_box` accumulator + tiny UI |
| 7 — Guest mood bubbles | S | Reuse animal mood-bubble code path |
| 8 — Compost Building | XS | One placeable with `revenue_per_poo` and `view_happiness_penalty` |
| 9 — Restaurant capstone | S | One amenity that satisfies all four needs; gated by reputation |

**No new roadmap exit criteria.** This work *enables* the existing
Phase 1 exit criteria (winnable session, real stakes, onboarding) by
making the moment-to-moment feel rewarding.

### Phase 2 — *Make it sing*

Pull item 2 (**Guest types**) forward from Phase 3. Implementing them
during the audio + mobile + accessibility pass lets us tune
per-archetype reactions while the playtest gauntlet is still warm.

| Adopt | Effort | Notes |
|---|---|---|
| 2 — Guest types | M | 4 archetypes initially (Adult / Child / Family / Enthusiast), each with per-building view-happiness deltas. Telemetry (2.4) captures which archetype dominates by scenario |

### Phase 3 — *Make it deep*

Items 6, 11, 12 layer cleanly onto the welfare / breeding / staff
systems already planned.

| Adopt | Phase 3 item | Notes |
|---|---|---|
| 6 — Per-exhibit zookeeper assignment | 3.3 Staff agents | Designed better than the original — see §5 |
| 11 — Breeding | 3.5 Breeding | Original is the reference impl |
| 12 — Escape mechanics | 3.1 Welfare | Fence-strength vs. animal-strength check on welfare degradation |

### Phase 4 — *Make it reach*

| Adopt | Phase 4 item | Notes |
|---|---|---|
| 10 — Research-gated shelters/foliage | 4.1 Research tree | Adds branches to the tree beyond "more animals" |
| 13 — Scenario shapes | 4.3 Scenarios | The original's 12-scenario gating is the template |

---

## 4. Headline design: paths-only guest movement

The single biggest gap between our current build and the
Zoo-Tycoon-feel is that guests browse the perimeter rather than
walking a path network the player built. This is the prerequisite for
items 1, 3, 5, 7 in §2 — none of them are meaningfully expressive
without it.

### Goals

1. Guests move only on tiles the player has marked as path.
2. Guests can view an exhibit if they are on a path tile **within N
   tiles** of any exhibit-boundary tile (target: N=10, copying the
   original's viewing distance).
3. Donation, food purchase, restroom usage all happen from path
   tiles.
4. Paths are a placeable type — bought, painted on the grid,
   refundable.
5. The entrance is the network root. Disconnected paths still allow
   placement but visitors won't reach them.

### Non-goals (for first landing)

- Path elevation / multi-level paths.
- Path cosmetic variants beyond two materials (asphalt + cobblestone,
  +small happiness for cobble — original pattern).
- Staff-only paths (lands with item 6 in Phase 3).

### Mechanic sketch

- New `path` zone kind in tuning, with `cost_per_tile`,
  `happiness_bonus`, `material` enum.
- New A* graph over path tiles, rebuilt on path change.
- Guest behavior: at each decision tick, score reachable
  exhibits/amenities by `appeal − walking_cost`; navigate via A* on
  the path graph.
- Viewing: a guest is "viewing" exhibit X if standing on a path tile
  within Manhattan distance 10 of any of X's boundary tiles. (Cheaper
  than line-of-sight; matches the original's bag-of-tiles spirit.)
- Stuck-detection: if a guest hits a dead end with unmet needs, route
  to the nearest reachable amenity or the entrance.

### Engine implications

**Decided 2026-06-06: pathing belongs in the engine, not the zoo.**
Network-constrained agent navigation is a generic tycoon primitive
(zoo paths, theme park paths, hospital corridors, mall aisles) and
goes behind the engine's existing interface seam. Full spec in
[`engine_seam_agent_navigation.md`](./engine_seam_agent_navigation.md);
targets engine **v0.6.x**.

- Engine grows `WalkableNetwork` schema, `INetworkNavigator`
  interface with default A\* impl, and an engagement-distance helper.
- Zoo declares its `path` placeable as `walkable = true` and wires
  the visitor agent type to the navigator. No bespoke pathfinder in
  zoo code.
- Engine v0.6.x becomes a **hard gate** on commits 1–4 of §6.
  Commits 5–10 (needs, pricing, donations, suitability, mood bubbles,
  buildings) can proceed in parallel without engine work and may land
  first.

### Definition of done

- [ ] Painting a path is one click per tile, with cost preview.
- [ ] Guests provably never step on non-path, non-entrance tiles.
- [ ] Disconnected exhibits show a "no path access" warning.
- [ ] An exhibit with a path within 10 tiles draws guests; one without
  doesn't.
- [ ] Smoke test green; 100-visitor scene holds 60 fps.

---

## 5. Where we diverge from the original

A short list of places where the 2001 game's design is the reference
but we knowingly do something different:

1. **Maintenance worker assignment** — original: per-task-type only,
   which produced the famous "won't fix the T. rex fence" bug. **Ours:
   per-exhibit assignment with task-type filters,** so the player can
   say "this worker patrols carnivore row, prioritizing fences."
2. **Recommendations past 90% suitability** — original: silent above
   90%. **Ours: always show the next-most-impactful axis,** even when
   the residual gain is sub-1%. Player should never be in the
   "everything's wrong but the game won't tell me what" trap.
3. **Algorithmic animal names** — original: "Giraffe 4." **Ours:**
   curated name pools per species, with a "rename" affordance so
   players can keep their favorites.
4. **Ticket bracket count** — original: 4 brackets. **Ours: 4
   brackets to start,** but instrumented with telemetry so we can
   widen/narrow based on actual player behavior.
5. **Placement-agnostic suitability** — original: all axes except
   elevation are bag-of-tiles. **Ours: same for now,** because it's
   cheap and forgiving; revisit only if playtests say layouts feel
   "spreadsheet-y."
6. **Mood bubbles always-on** — original: always-on. **Ours: same,**
   but with a toggleable "performance mode" that switches to per-need
   aura colors for the 100-visitor case, in service of the web perf
   budget.

---

## 6. Sequencing & decision points

A short ordered list of the next ~10 commits, in order:

1. Land **path zone kind** + grid paint + cost model. (Phase 1 / item 0)
2. Land **path graph + A* visitor nav.** (Phase 1 / item 0)
3. Land **N=10 viewing distance** rule for exhibit appeal. (Phase 1 /
   item 0)
4. Land **disconnected-exhibit warning** in the HUD. (Phase 1 / item 0)
5. Land **4 guest needs** — extend hunger model to four meters with
   spillover. (Phase 1 / item 3)
6. Land **bracketed ticket pricing.** (Phase 1 / item 4)
7. Land **per-exhibit donation box** + UI. (Phase 1 / item 5)
8. Land **suitability rating + breakdown panel.** (Phase 1 / item 1)
9. Land **guest mood bubbles** (extend animal system). (Phase 1 / item 7)
10. Land **Compost Building + Restaurant capstone.** (Phase 1 / items
    8, 9)

After commit 10, re-evaluate. Phase 1's existing exit criteria
(winnable session, ≥5 playtests, smoke test green) become the gate
for moving on. Phase 2 then opens with the Guest Types adoption
(item 2) running in parallel with the planned audio + mobile work.

### Decision points to flag explicitly

- **D1 (before commit 1)** — does path-aware nav require an engine
  bump? If yes, file engine issue; either wait, or land items 3–9
  first while engine is in flight.
- **D5 (after commit 5)** — measure how often the negative-spillover
  on needs trips players. If it's frustrating without being readable,
  add a tooltip rather than removing the mechanic.
- **D8 (after commit 8)** — playtest the suitability breakdown panel.
  If players ignore it, the rating itself is doing the work and the
  panel can wait.

---

## 7. Backlog (parking lot, Zoo-Tycoon-flavored)

Items from the original that we are **not committing to** but want to
keep visible:

- **Tour guides** — narration-driven happiness boost. Cute, low ROI
  until we have audio (Phase 2).
- **Show tanks + grandstands** — already have arena/shows; revisit
  whether the "exactly one tile away" constraint pattern is worth
  formalizing.
- **Animal escapes that *eat guests*** (Dinosaur Digs–style). Big
  drama, big ESRB consequences. Decide explicitly before any dino-pack
  work.
- **Endangered-species / mythical animal tier** — the unicorn cheat
  has charm; could be a Phase 4 "fun mode" toggle.
- **Compost stink mechanic** — the original's negative view-happiness
  for nearby paths is a great spatial-tradeoff teacher; ship the
  building first, the stink radius second.
- **Tile-edge fences** rather than tile-fill fences. The original's
  edge-placed fences enabled double-walling exploits but also
  expressive pen shapes. Our current model is tile-fill; revisit only
  if pen shape becomes a constraint.
- **DLC / expansion pack model** — the original shipped two paid
  expansions on a 12-month cadence. Worth keeping in mind as a
  post-launch lifecycle.

---

## 8. Engine seam watchlist

Adoptions from §2 that we *expect* to surface engine seams, in
sequence:

| Adoption | Suspected seam | Action |
|---|---|---|
| Paths-only nav (item 0) | Engine has no network-constrained agent navigation | **Filed** as `engine_seam_agent_navigation.md`. Targets engine v0.6.x. Hard gate on §6 commits 1–4 |
| Donation boxes (item 5) | Per-placeable money sink might need a new interface | Probe before committing |
| Guest types (item 2) | Multi-archetype agent population — roadmap already calls this out as 3.3-adjacent | Already a known seam (roadmap §4) |
| Restaurant capstone (item 9) | Single building satisfying multiple needs may need a richer amenity interface | Probably reachable via existing `IPlaceableHappiness` + needs model; verify |

The rule from `CLAUDE.md` §1 stands: any seam goes to the engine
repo, never the submodule.

---

## 9. Open questions

Things worth deciding before they bite:

1. **Path tile size** — 1×1 grid tile, or sub-tile half-width like
   the original? Half-width is prettier but doubles graph cost.
2. **Path "first paint free"?** — the original's tutorial scenario
   gave free paths to soften the math. Worth doing in our onboarding?
3. **Are donation boxes visible objects** or invisible per-exhibit
   accumulators? The original made them visible and place-able.
4. **Mood bubble density** at 100 visitors — do we need per-need aura
   tinting as a fallback? Profile during item 7.
5. **Tutorial coverage** — onboarding (roadmap 1.3) needs to cover
   path painting once it lands. Re-record the welcome modal after
   commit 4.

---

## 10. Success measure

This plan succeeds if, at the end of Phase 1's playtest gauntlet, an
external tester describes the game as *"like Zoo Tycoon"* without
prompting. We are mining a 25-year-old classic for a reason: that
phrase is the most efficient marketing copy this game will ever have.

If they describe it as *"like Zoo Tycoon but ____"*, the blank is the
next plan.
