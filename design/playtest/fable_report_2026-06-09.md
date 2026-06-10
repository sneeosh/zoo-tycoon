# Playthrough Report — fable — 2026-06-09

> **Status: complete.** The chronological "Running notes" below are the
> evidence trail (three phases: cold open on a broken live build → build-loop
> exploration on a fixed local web build → full 30-day arc on a native build via
> godot-mcp). The **tidied conclusions are in [FINAL SUMMARY](#final-summary)
> at the bottom** — read that first; dip into the notes for the receipts.

## Session summary
- **Difficulty:** Standard (10k start → 20k cash + 50 rep in 30 days).
- **Outcome:** **LOSS by timeout, day 30.** Finished $24,209 cash (goal $20k —
  *beaten*) but −89 reputation (goal +50 — failed by 139). Played to the actual
  end screen.
- **Builds exercised:** broken live web (`sneeosh.github.io`), fixed local web
  (`localhost:8060`), and native via godot-mcp (the productive one).
- **How driven:** Playwright coordinate-clicking for the web builds; godot-mcp
  (structured state + deterministic time-stepping) for the native 30-day run.

---

## Running notes (chronological)

### Cold open — first 90 seconds, zero docs read
Screenshot: [fable_01_cold_open.png](./fable_01_cold_open.png)

What I genuinely thought, in order:

1. **The welcome modal copy is good.** "You're the new director. Build exhibits, lay paths so guests can reach them… see the MISSION panel on the left for your 30-day goal." In three sentences I know my role, my verbs, and where my goal lives. As a stranger, I knew what to do.
2. **Then the MISSION panel betrayed it.** The panel the modal *just pointed me at* reads: *"Reach $%s cash and %d reputation before day %d ends"*, *"Cash: $1,000 / $"*, *"Reputation: %d / %d"*, *"Day %d of %d · %d left"*. So the game tells me where the stakes are, I look, and the stakes are literally unrendered format strings. This is the worst possible place for this bug — it's the one panel the onboarding copy routes your eyes to.
3. **"Difficulty" label with nothing under it.** The modal shows a centered "Difficulty" heading and then only two buttons: "Start tutorial" / "Skip — pre-built zoo". The difficulty picker is missing (brief §5 suspected this — confirmed). A stranger reads "Difficulty" and assumes those two buttons *are* the difficulties.
4. The background zoo behind the modal is a dark green field with scattered light dots — at this dimmed state it reads as static, not a living zoo. There's a single small sprite bottom-left (the pre-built exhibit?) but nothing communicates "zoo" yet.
5. Console: **193 errors before any user input**, all `String formatting error: a number is required` at `validated_evaluate (core/variant/variant_op.h:953)` — and they keep streaming continuously (~1000 more log lines within ~30 seconds of idling). It's re-erroring on every HUD refresh tick, not once at load.
6. Viewport note: at 1280×800 the game canvas doesn't fill the window — there's a dead black band below the playfield (bottom ~80px). Status line "Welcome to your Zoo. Pick Tutorial or Skip to begin." sits at the canvas bottom edge.

First-90-seconds verdict: the *writing* onboards me; the *state of the screen* (format specifiers, missing picker, dead band) tells me I'm in a debug build. Knowing-what-to-do: yes. Trusting-the-game: no.

### Minute ~2 — the game wins itself (BLOCKER)
Screenshots: [fable_02_after_skip.png](./fable_02_after_skip.png), [fable_04_state.png](./fable_04_state.png)

Sequence: clicked **Skip — pre-built zoo** → modal closed, clock started running at 1x → I did *nothing* → at the Day 1→Day 2 rollover (~75 real seconds later) a modal appeared:

> **"Zoo of the Year!"** — *"You hit $%s and %d reputation by the end of day %d. The zoo is a success!"* — *"Final score · $%s · Rep %+d · %.1f"*

State at the time: **$1,000 cash, Rep +0, 0 guests, zero player input.** Status log below reads "Day 1 closed. Net $0 (+$0 / −$0)" immediately followed by "Zoo of the Year!".

Diagnosis from the outside: this is the *same* root cause as the format-string bug, and it's not cosmetic. The mission's parameters (cash target, rep target, day limit) are evidently never bound — every label that should print them shows raw `%s`/`%d`, and the win-condition check is comparing live values against the same unset targets (≥ 0 or null), so the first daily settlement trivially satisfies it. **The 30-day scenario cannot be played: you win on day 1 by existing.** The missing difficulty picker on the welcome modal is almost certainly the same missing-scenario-config plumbing.

- [Severity: **blocker**] Win condition fires at first day-close with no player action. Repro: load page → Skip → wait ~75s at 1x. Expected: 30-day scenario with $20k/50-rep targets. Actual: instant "Zoo of the Year!" with $1,000/0 rep.

Also noted in passing:
- The **"pre-built zoo" appears empty.** After Skip, the playfield is a bare green grid; the only structure is a tiny sprite tucked at the far bottom-left *edge* of the playfield (the entrance gate?). Milestones mention "Lion happiness ≥ 80%" implying a lion exists somewhere, but nothing on screen reads as an exhibit, path network, or animal. Either the pre-built zoo failed to spawn (related to the same config failure?) or it's so small/peripheral it's invisible. → follow up in-run.
- Status line still says *"Welcome to your Zoo. Pick Tutorial or Skip to begin."* after skipping — stale prompt.
- BUILD menu labels (Exhibit tiles / Paths / Amenities / Animals / Infrastructure) render extremely dim, like disabled buttons, with no visible prices. Unclear if they're disabled or just low-contrast. → follow up.

Plan: click **Keep playing** and assess the sandbox loop (build flow, visitors, economy, art) since the scenario layer is broken.

### Minutes 3–12 — the live build is a zombie; root cause found
Screenshots: [fable_06_build_exhibit.png](./fable_06_build_exhibit.png), [fable_09_help.png](./fable_09_help.png)

Tried to play the sandbox anyway ("Keep playing"):

- Clicked every BUILD menu entry (Exhibit tiles / Paths / Amenities / Animals / Infrastructure): **no response at all.** No submenu, no selection highlight, no ghost preview on the map. Pixel-diffed panel close-ups before/after clicking — identical.
- Left-clicked the map: nothing places, nothing selects, cash never moves.
- Clicked the **`?` help button**: it just re-opens the welcome modal with a "Got it" button. There is no controls/help reference. (UX note for later: even on a healthy build, `?` re-showing the intro is weak help.)
- `P` pause works; speed buttons work; the day counter happily advances. Days 1–6 all closed with "Net $0 (+$0 / −$0)".

Then read the console from t=0 (filtering out the format-string spam). **Root cause, 2.6 seconds after load:**

```
ERROR: res://design/tuning/balance.md: required tuning file is missing
ERROR: res://design/tuning/economy.md: required tuning file is missing
ERROR: [Zoo] ContentDB failed to load — refusing to bootstrap. Errors above.
```

And when "Skip — pre-built zoo" fired (~117s in), every prebuilt placement failed:
```
WARNING: EntityRegistry.place: unknown entity def_id 'grass_patch' (×8)
WARNING: EntityRegistry.place: unknown entity def_id 'rock_patch' (×2)
WARNING: EntityRegistry.place: unknown entity def_id 'water_patch' (×9)
WARNING: EntityRegistry.place: unknown entity def_id 'path' (×many)
```

**Everything observed so far is one bug.** The deployed web export at sneeosh.github.io is missing `design/tuning/balance.md` and `design/tuning/economy.md` → ContentDB refuses to bootstrap → no entity definitions (prebuilt zoo spawns nothing, BUILD palette is empty/disabled), no scenario parameters (MISSION text has nothing to interpolate → `%s`/`%d` spam, ~190 console errors/min as the HUD re-renders), no difficulty definitions (picker missing from welcome modal), and a win condition evaluated against unset targets (instant "Zoo of the Year!" at first day-close).

Checked the repo: **both files exist locally** (`design/tuning/balance.md`, `economy.md`) — and they are the two *oldest* files in the folder (May 25; every other tuning file is Jun 7). The web export's include filter or deploy step is dropping exactly these two. So this is a **deploy/export-preset bug**, not missing content.

- [Severity: **blocker**] Deployed web build missing 2 required tuning files → ContentDB refuses to bootstrap → game is a non-interactive zombie (can't build, can't lose, wins itself on day 1). Repro: open live URL with console open. Expected: playable game. Actual: see above. Fix direction (for Kenny, not applied): ensure `design/tuning/*.md` are all included in the web export preset / deploy artifact, and make ContentDB failure *visible to the player* (it "refuses to bootstrap" but the game soldiers on looking half-alive — a hard error screen would have made this a 10-second diagnosis instead of a 10-minute one).
- [Severity: major] Secondary console error at boot: autoload `res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd` missing from the export ("Failed to instantiate an autoload") — dev tooling leaking into the shipped build's autoload list.

**Decision: the live build cannot be playtested.** Brief §3 says use Option A unless I specifically need the local build — I specifically need it. Switching to Option B (`./play.sh`).

### Session interlude — switched to a fixed local build
Kenny rebuilt the web export locally with the missing tuning files included
(`include_filter="design/tuning/*.md"` in `export_presets.cfg`) and served it
at `http://localhost:8060/`. Verified working: $10,000 start, difficulty
picker (Easy/Standard/Hard) present, build palette populated with prices,
MISSION panel shows real numbers ("Reach $20,000 cash and 50 reputation
before day 30 ends"), **zero console errors**. The rest of this report
assesses the local build.

**Honesty note on the cold open:** my genuine first-90-seconds reaction
(above) happened on the broken live build. During setup verification I saw
the working welcome modal and a started zoo in screenshots, so my second
"first impression" below is partially contaminated — I knew the difficulty
picker existed and roughly what the prebuilt zoo looks like. Weight the
broken-build cold open as the real stranger-test of the *copy*, and the notes
below as a slightly-informed player's first real session.

### Run 2 (local build) — the build loop works, and it's good
Screenshots: [fable_20_iso.png](./fable_20_iso.png), [fable_24_elephant_placed.png](./fable_24_elephant_placed.png), [fable_28_exhibit_zoom.png](./fable_28_exhibit_zoom.png)

Standard difficulty, skipped tutorial, paused on Day 1 to explore. What worked,
in the order I discovered it:

- **Painting a region feels right.** Selected Grass Enclosure ($60 · 1×1),
  got a ghost tile under the cursor, clicked 9 cells into a 3×3 — tiles paint,
  cash ticks down per tile, each purchase logged ("Built Grass Enclosure for
  $60" ×9), and a wooden fence auto-wraps the finished region. First-try
  success, no manual needed.
- **The exhibit panel is the best UI in the game.** Clicking the region opens
  "Exhibit #3 — 9 cells — provides: grass — appeal: beauty 0.20, exotic 0.28 —
  Suitability: 40%" with the full animal roster, prices, and *unsuitable
  species greyed out* (penguin/seal/polar bear disabled for a grass pen).
  Bought a giraffe ($500): panel immediately said **"Add a Feeding Trough for
  the Giraffe — a need is unmet."** Added troughs, suitability 40%→48%; then
  **"Add more Giraffe — it's lonely (wants 2–6 together)"** (social needs!);
  added another animal, 48%→64%, appeal beauty 0.24→0.85, and then
  **"Enlarge this exhibit — the Giraffe is cramped."** The hint chain *is*
  the tutorial — it taught me terrain suitability, animal needs, social
  groups, and space pressure in four purchases. This loop is genuinely fun.
- **Discoverability gap:** the left palette also lists "Elephant" under
  Animals, but clicking it and then clicking a region does nothing visible —
  animals actually get added from the *exhibit panel*. Two entry points, one
  works, the other silently doesn't. (UX: either make palette-animal →
  click-region work, or remove animals from the palette.)
- [Severity: minor] The unlabeled number next to the clock ("4.1") changes
  over time and is never explained. (Appeal? Average satisfaction? It's the
  one HUD element I never decoded all session.)

### Run 2 — friction & bugs found while building (iso view)
Screenshots: [fable_38_cell1b.png](./fable_38_cell1b.png), [fable_42_after_esc.png](./fable_42_after_esc.png)

Per Kenny: iso is the ship view, so I built in iso. Findings:

- [Severity: major, UX] **Region adjacency is invisible in iso.** I tried to
  enlarge Exhibit #3 by clicking a cell that *looked* adjacent to the fence;
  it was diagonal, so it silently created a separate 1-cell region. The
  exhibit panel still showed "9 cells", no feedback that my $60 tile didn't
  join. A single-cell region renders as a pale unfenced diamond that doesn't
  read as "enclosure" at all. Suggest: when a tile-place would NOT merge with
  the adjacent-looking region, show it (e.g., flash the would-be region
  boundary, or color the ghost differently when it extends vs. creates).
- [Severity: major, bug?] **Right-click sell did nothing** on that stray zone
  tile — tried 3×: with tool selected, without, dead-center on the cell. No
  log entry, no refund. (HUD help says "R-click map: sell (½ refund)".)
  Possibly top-down-only, possibly broken for zone tiles, possibly an iso
  hit-test issue — flagging for Kenny to check rather than burn more cycles.
- [Severity: minor, UX] In iso, several nearby screen points snapped the
  ghost to the *same* cell — near a fence it's genuinely hard to tell which
  cell you're targeting. Fine at high zoom, ambiguous at default zoom.
  (Mouse-wheel zoom works in iso and helps a lot; nothing in the UI hints
  that it exists.)
- [Severity: minor, UX] Buying from the exhibit panel reflows the list (new
  INSIDE rows push the buy buttons down), so two quick purchases in a row can
  hit the wrong item. I bought a second Feeding Trough and a Peacock this way
  when I meant Water Trough + Giraffe. (Happy accident: peacock at 90%
  suitability beats giraffe #2 — but the reflow is still a misclick trap.)

### Run 2 — the big one: WebGL object leak kills the session after ~10 min
- [Severity: **blocker** (for long web sessions)] After ~10 minutes of play,
  the browser console threw `RangeError: Invalid array length` inside
  Emscripten's GL handle allocator — first at `_glGenVertexArrays`, then
  `_glGenTextures`. From that point, anything needing a *new* GL object
  fails silently: the **View: Top/Iso toggle stopped working** (each click =
  one more RangeError, no view change). After a page reload the toggle works
  again — confirming state exhaustion, not logic. Something allocates GL
  objects continuously without freeing (suspect: a per-frame or per-redraw
  mesh/texture rebuild — engine web-perf discipline says pooling should
  prevent exactly this). A 30-day session at 1x (~40 min) cannot survive it.
- [Severity: minor→major, UX] **Save works but gives zero feedback.** Clicking
  Save writes `saves/main.save.json` (verified in IndexedDB) — but there is
  no toast, no log line, nothing. I genuinely could not tell whether I'd
  saved. (My first "Save is broken" diagnosis was wrong — see next item.)
- [Severity: minor (humans) / major (automation)] **The top toolbar is a flow
  layout** — button positions shift as the cash/guest-count text width
  changes (Save moved ~50px between two screenshots minutes apart). Buttons
  that drift make misclicks easy and automation painful; right-align the
  button cluster or fix its position.
- [Severity: minor] Reloading the page mid-run silently dropped me into a
  fresh run (no welcome modal shown — it auto-skipped). Unsaved progress
  (giraffe exhibit) gone, no warning. Web games need a beforeunload guard or
  at least autosave-on-unload. (`autosave.save.json` exists but had only the
  run-start state.)
- Pacing note: days are ~80 real seconds at 1x; Day 1→6 passed while I was
  testing save/load. The prebuilt zoo earned $5,625→$8,178 by Day 6 with
  **zero player input** — the sandbox economy is self-sustaining, which is
  great for "watch it breathe", but reputation stayed at +0 the whole time
  (so the rep half of the win condition gates progress on something the idle
  economy doesn't produce — good design *if* the game tells you what makes
  rep move; finding out next).

### Harness switch — native build via godot-mcp (the productive pivot)
The Playwright-on-WebGL-canvas loop was burning effort on pixel-hunting, not
review (Kenny flagged this directly). Switched to running the game natively in
the Godot editor driven by **godot-mcp**: structured state reads (cash/rep/needs
as data, no OCR), deterministic game-time stepping (no 80-sec/day waiting), and
clean screenshots. One setup snag worth recording (below) — then it was the
right tool and produced the headline finding of this whole playtest.

- [Severity: minor, tooling] The repo's bundled `addons/godot_mcp` was **v2.17.0**
  while the `npx @satelliteoflove/godot-mcp` client is **v3.16.0**; the version
  skew makes the WebSocket handshake hang ("awaiting WebSocket handshake…"
  forever). Fix: replaced the addon with the 3.16.0 copy the client ships
  (`addons/godot_mcp/` is gitignored + untracked + a real dir, *not* the
  read-only engine symlink, so this is in-bounds). Worth pinning the addon to
  the client version in setup docs so the next agent doesn't lose time here.

### ★ HEADLINE FINDING — the Standard scenario is unwinnable as shipped
I played the full 30-day Standard scenario to its end-screen, reading exact
state at each step. The numbers (prebuilt park, Standard, my only intervention
was adding 3 drink stands + attempting food stands on day 7):

| Day | Cash    | Reputation | Guests |
|-----|---------|-----------|--------|
| 1   | $5,752  | 0         | 17     |
| 6   | $9,000  | **−18**   | 47     |
| 11  | $12,379 | **−45**   | 44     |
| 20  | $18,723 | **−70**   | 43     |
| 29  | $23,868 | **−89**   | 30     |
| 30  | $24,209 | **−89**   | (end)  |

End screen (verbatim): *"Time's up — Day 30 closed at $24,209 cash and −89
reputation — short of the $20,000 / 50 goal. Closer next run!"*

**Cash beat the $20k target by day ~21 and finished at $24,209. Reputation went
the opposite direction the entire game and ended at −89 — 139 points under the
+50 needed.** The cash half of the win is trivial; the reputation half is not
merely unmet, it's *deeply, monotonically negative*. Why:

1. **Reputation is an unbounded cumulative counter, no decay, no clamp.**
   (`engine/.../progression_manager.gd`: `reputation` is an `int`,
   `add_reputation(d)` is just `reputation += d`.) The zoo feeds it ±1 per
   *departing guest*: +1 if exit-mood ≥ 0.68, −1 if < 0.42, 0 between
   (`src/behaviors/visitor_behavior.gd:on_despawn`). So the win bar (≥50) is
   really "accumulate +50 net happy departures over 30 days, and never dig a
   hole you can't climb out of." There is no rating-style normalization — a bad
   opening is permanent debt.
2. **The prebuilt "Standard" park is badly under-amenitized for the crowd it
   pulls.** It ships with **1 drink stand, 1 food stand, 1 bench, 2 restrooms**
   and two small pens — but draws **47 guests by day 6**. I measured the live
   crowd at day 6: avg satisfaction 0.52, and *thirst* was the single most-
   depleted need (lowest for 27 of 47 guests). Under-served guests leave unhappy
   (<0.42) → −1 rep each → the counter craters.
3. **The slide is recoverable on the live crowd but not on the cumulative
   counter.** After I added 3 drink stands (day 7), the *live* snapshot improved
   — avg satisfaction 0.52→0.57, unhappy guests 11/47 → 5/44, thirst 0.64→0.69.
   So the loop genuinely closes: amenities → happier guests. But (a) I could
   only fix thirst — food stands are 2×2 and kept colliding with the path/foliage
   footprints, so hunger (lowest for 9–12 guests) and energy (8–12, only 1 bench)
   kept dragging departures negative; and (b) even a perfect fix can't undo the
   −45 already banked. Rep kept falling (−45→−70→−89) because hunger/energy-
   starved departures still outnumbered happy ones.

**Why this matters most:** the single most natural first action — "Skip →
pre-built zoo" and watch it run to learn the game (exactly what the welcome
modal invites) — produces a confident march to a **loss**, while the cash number
(the thing a tycoon player instinctively watches) goes *up* the whole time. A
new player gets the worst possible signal: "I'm making money, I'm clearly
winning" → surprise loss at day 30 on a stat they were never taught to manage.

- [Severity: **blocker**, Fun/Design] Standard is unwinnable without aggressive,
  *immediate* (day-1, pre-crowd) amenity building that the game never tells you
  to do. The win is gated entirely on reputation; reputation is gated on guest
  happiness; guest happiness is gated on amenity density; and the prebuilt park
  starts ~5× under the density its own crowd demands. Decision for Kenny:
  either (a) seed the prebuilt park with enough food/drink/rest to hold its
  crowd at break-even rep, (b) add reputation decay/normalization so a rough
  open isn't permanent debt, or (c) make the rep mechanic legible — a "guests
  are leaving thirsty → your rating is dropping" callout the first time net rep
  goes negative. Probably all three.
- [Severity: major, UX] **End screen miscommunicates a split result.** Finishing
  at $24,209 (over the $20k goal) but −89 rep, the screen says "short of the
  $20,000 / 50 goal" — lumping the two so the player can't see they *crushed*
  cash and *only* failed reputation. And "Closer next run!" is plainly wrong for
  −89. Show the two axes separately with a per-axis pass/fail (✓ $24,209/$20,000,
  ✗ −89/50) so the player learns what to fix.
- [Severity: minor, balance] Cash is a non-constraint on Standard — it's never
  in doubt and finishes 20% over target with near-zero management. If the
  intended tension is "money vs. welfare," money currently exerts no pressure.

### Bugs confirmed via the native harness
- [Severity: minor, confirmed-FIXED] The MISSION-panel format-string bug
  (`%s/%d`, 100+ console errors) that plagued the live web build does **not**
  reproduce in a correct build — it was purely the missing-tuning-files deploy
  bug. Native and fixed-local-web both render real numbers and throw zero
  format errors. So the brief's "known bug" is really a *deploy* bug, not a
  code bug. (Repro of the original was the broken live URL only.)
- [Severity: minor] `food_stand` is 2×2 and collides easily — placing it
  adjacent to a 1-wide path is fiddly because its footprint overruns onto the
  path or foliage. On a small starter map there are few legal 2×2 spots near
  the walkway where a food stand is actually useful. (Same root cause as the
  iso "stray tile" friction in run 2.)

### Tutorial — teaches the easy half, ignores the half that loses you the game
Ran the 4-step tutorial. The steps (verbatim from `TUTORIAL_STEPS`):
1. **Build an exhibit** — place a Grass Enclosure, tiles auto-merge.
2. **Add an animal** — click the exhibit, hit "+ Lion".
3. **Lay a path** — connect entrance to exhibit ("an exhibit with a path within
   view draws a crowd").
4. **Speed time, watch them pay** — hit 4x, watch the +$ floats.

- [Severity: **major**, UX/Design] **The tutorial teaches the non-binding
  constraint and is silent on the binding one.** All four steps are about the
  *cash* loop (build → animal → path → income) — which my 30-day run showed is
  trivially easy and finishes 20% over target untended. It never mentions
  amenities, the four guest needs, welfare, or reputation — i.e. the entire
  system that actually decides win/loss. A player finishes the tutorial having
  learned "build + path + watch money go up," then loses a scenario on a
  reputation stat the tutorial never told them exists. The tutorial should end
  on the real lesson: *guests have needs → unmet needs tank your rating →
  reputation is the win bar.* Add a 5th step: "Place a drink stand and a
  restroom on the path — watch satisfaction (and your rating) climb."
- Corroborating dev intent: `src/main.gd:2557` comments that "the starter park
  covers all four guest needs (food / drink / restroom / rest)" — with one stand
  each. The headline finding shows that one-each is ~5× short of what the park's
  own 47-guest crowd demands, so the under-provisioning reads as an honest
  *demand-scaling* oversight (designed for a small crowd, ships pulling a big
  one), not intended difficulty. Worth fixing at the source, not just the
  tutorial.

### Art — reads as a tycoon game; iso is the right call
Assessed mostly at default zoom (didn't get deep zoom on individual animal
4-dir animation before session end). What I can say:
- [Positive] **Iso reads cleanly as a tycoon diorama** — fences enclose pens
  legibly, paths are obvious, the entrance gate anchors the layout, foliage
  frames the play area without clutter. It does *not* read as a debug harness.
- [Positive] **The crowd visualization accidentally tells the story** — the ring
  of mood-bubble guests packed around two small pens visually screams "too many
  guests, too little park," which is exactly the design problem. Good art
  serving (unintentionally) as a diagnostic.
- [Severity: minor, Art] Mood bubbles are visible as a dense ring at default
  zoom but individual need-icons aren't legible without zooming — at the zoom a
  player actually watches the park from, "lots of bubbles" reads as generic
  busy-ness, not "they're thirsty." Given thirst-driven departures are the
  whole ballgame, making the *dominant unmet need* readable at default zoom
  (e.g. tint the bubble by need, or a small per-need counter in the HUD) would
  convert invisible churn into an actionable signal.
- [Positive] **Animal silhouettes read at close zoom.** In the run-2 close-ups
  ([fable_28_exhibit_zoom.png](./fable_28_exhibit_zoom.png) giraffe;
  [fable_65_hover_1.png](./fable_65_hover_1.png) penguins + a big cat) each
  species is immediately recognizable by silhouette — the giraffe's neck, the
  penguins' upright cluster. No "anthropomorphic quadruped" problem visible in
  these pen views (the known `_4dir` concern is about the character-style sprites;
  the pen animals here read fine).
- Not assessed: 4-dir *animation* quality (do walk cycles pop?) at game zoom,
  and silhouette distinguishability at the *default* (zoomed-out) zoom most play
  happens at. Flagging as open.

---

## FINAL SUMMARY

*(Tidied conclusions per the brief's skeleton. Evidence is in the chronological
notes above.)*

### The one-paragraph verdict
There is a genuinely good game in here — the build→animal→need→amenity loop is
satisfying, the exhibit panel's live suitability + unmet-need hints are the best
thing in the product, and iso reads like a real tycoon diorama. But the
**Standard scenario as shipped is unwinnable the way a new player will play it**:
the prebuilt park pulls a 47-guest crowd onto ~1 of each amenity, guests leave
thirsty/hungry, and reputation — an undecaying cumulative ±1 counter that *is*
the win bar — digs a hole (−89 by day 30) you cannot climb out of, all while
cash sails 20% past target. The tutorial trains only the cash loop and never
mentions reputation, so the player is set up to confidently lose.

### UX findings (consolidated)
- [major] Two entry points to add an animal (palette vs. exhibit panel); only
  the exhibit panel works, the palette silently no-ops.
- [major] Region adjacency is invisible in iso — a tile that looks adjacent
  makes a new orphan region instead of enlarging; no feedback.
- [major] HUD `?` button just re-opens the welcome modal — there is no controls/
  help reference anywhere.
- [minor] Save writes a file but gives zero feedback (no toast/log).
- [minor] Top toolbar is a flow layout; buttons drift as HUD text width changes.
- [minor] The unlabeled "4.1★"-ish number by the clock is never explained.
- [minor] Exhibit-panel buy list reflows on each purchase → misclick trap.

### Art findings (consolidated)
- [positive] Iso diorama reads cleanly; animal silhouettes recognizable at zoom.
- [positive] Crowd mood-bubble ring unintentionally diagrams the core problem.
- [minor] Dominant unmet need isn't legible at default zoom — make it readable.

### Fun findings (consolidated)
- [positive] The exhibit unmet-need hint chain (terrain → feeding → social →
  space) is a genuinely fun, self-teaching loop.
- [blocker] The win is gated on a stat the player isn't taught and can't recover
  once it craters; cash (the stat they *do* watch) exerts no pressure. The
  moment-to-moment building is fun; the *scenario arc* is broken.

### Bugs (consolidated, severity-ranked)
- [blocker] **Live deploy** (`sneeosh.github.io/zoo-tycoon`) ships without
  `design/tuning/*.md` → ContentDB refuses to bootstrap → non-interactive zombie
  that "wins itself" on day 1 with raw `%s/%d` everywhere. Fix committed locally
  (`include_filter="design/tuning/*.md"` in `export_presets.cfg`); needs a push.
- [blocker] **WebGL object-handle leak** in long web sessions — `RangeError:
  Invalid array length` in `_glGenVertexArrays/Textures/Buffers` after ~10 min;
  new GL allocations (e.g. the view toggle) then silently fail until reload.
- [major] `godot_mcp` autoload (`mcp_game_bridge.gd`) leaks into the *shipped*
  web export and errors at boot ("Failed to instantiate an autoload") — dev
  tooling shouldn't be in the release export.
- [major] End screen lumps a split result ("short of the $20,000 / 50 goal"
  when cash was *over* $20k) and says "Closer next run!" at −89 rep.
- [minor] `food_stand` 2×2 footprint collides easily near 1-wide paths.
- [minor, FIXED] MISSION format-string spam was purely the deploy bug above; does
  not reproduce in a correct build.
- [minor, tooling] Bundled `addons/godot_mcp` (2.17.0) vs npx client (3.16.0)
  version skew hangs the godot-mcp handshake; bumped local copy to 3.16.0.

### The "would I keep playing?" question
Honestly — yes for an evening, *if* the scenario were winnable. The build loop
pulled me: placing a pen, watching the suitability % climb as I met each animal
need, seeing guests stream in, is the exact "I built this and it's working"
hit a tycoon game lives on. I *wanted* to fix the thirsty crowd. What would stop
me opening the tab tomorrow is the current arc: I'd discover (as I did) that
doing everything right on cash still ends in a confusing loss on a hidden stat,
and "Closer next run!" at −89 would feel like the game gaslighting me. Fix the
reputation legibility + winnability and I'd play several runs.

### Top 3 recommendations for Phase 1 exit
1. **Make Standard winnable the way players actually play it** — seed the
   prebuilt park with amenity capacity that holds its own crowd at break-even
   reputation (so doing nothing is a slow loss, not a death spiral), and/or give
   reputation decay/normalization so a rough open isn't permanent debt.
2. **Teach the binding constraint** — extend the tutorial past "watch them pay"
   to "guests have needs → unmet needs drop your rating → reputation is how you
   win," and surface a first-time callout when net reputation goes negative.
3. **Fix the two deploy/runtime blockers** before any wider test — bundle the
   tuning files in the web export (committed; needs push) and stop the WebGL
   object-handle leak that bricks long web sessions.

