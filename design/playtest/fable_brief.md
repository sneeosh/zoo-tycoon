# Playtest Brief — fable

**For:** fable (Claude model running as a playtester)
**From:** Kenny Johnson
**Date:** 2026-06-09
**Repo:** zoo-tycoon (this one)
**Time budget:** ~45–60 minutes of in-game session, plus write-up

---

## 1. Mission

Play through Zoo Tycoon end-to-end (win or lose a 30-day scenario) and
return a single report covering four dimensions:

1. **UX** — does a stranger know what to do in the first 90 seconds? Where
   do they get stuck? What feels redundant?
2. **Art** — does the screen read as a tycoon game (not a debug harness)?
   Where does the art break the fantasy — clashing palettes, billboards
   that don't sell the depth, animations that pop?
3. **Fun** — is there a moment-to-moment loop that keeps pulling? Where
   does it sag? When did you actually *want* to keep playing vs. felt
   obligated?
4. **Bugs** — anything broken, visibly wrong, or that contradicts what
   the HUD says is happening.

This is **assessment, not authoring.** Do not edit code, do not commit,
do not open PRs. The deliverable is the report (§6).

---

## 2. Product context — but do the cold open FIRST

**Read nothing about the game before your cold open.** The single most
valuable thing you can produce is a genuine first-90-seconds reaction,
and you only get it once. If you read the README (how to launch, what the
game is) and `scenario.md` (the exact win/lose numbers) first, you walk
into the welcome modal already knowing you're chasing $20k + 50 rep in 30
days — you're no longer a stranger, and that signal is gone for good.

So the order is:

1. Launch and play the cold open (§4 step 1) with **zero docs read**.
   Capture your genuine first reaction.
2. *Then* come back and read the context below before continuing the run.

When you do read, you don't need the whole repo. Read, in order:

- [`README.md`](../../README.md) — what the game is, how to launch.
- [`CLAUDE.md`](../../CLAUDE.md) — engine seam discipline (so you
  understand why fixes you might suggest are scoped to `src/`, not
  `engine/`).
- [`ROADMAP.md`](../../ROADMAP.md) §1 (North Star), §2 (Where we are
  today), §3 Phase 1 (current phase exit criteria).
- [`design/tuning/scenario.md`](../tuning/scenario.md) — win/lose
  parameters per difficulty.

The North Star: *"A web-first zoo tycoon a stranger can fall into in 90
seconds and lose an evening to."* Phase 1 is **"Make it a game"** — turn
the sandbox into a session with a clear start, clear end, clear stakes.
Your playtest is initiative **1.5** of that phase.

---

## 3. How to play

### Option A — local web build (use this)

```
URL: http://localhost:8060/
```

> **Note:** The live build at `https://sneeosh.github.io/zoo-tycoon/` is
> broken — it is missing two required tuning files from its export bundle,
> so the game's ContentDB refuses to bootstrap. The local build at
> `localhost:8060` is fixed and fully functional. Use it exclusively.
> The server is already running; if it goes down, restart it with:
> `nohup python3 /tmp/zoo_server.py > /tmp/zoo_server.log 2>&1 &`

Drive it with `mcp__playwright__browser_*`. The HUD's **Pause / 1x / 2x /
4x** buttons are on-screen — click them by coordinate. `P` also toggles
pause. Left-click on the map places the selected build tool; right-click
sells.

**This is a Godot web export — the whole game is one WebGL `<canvas>`.**
That changes how you drive it:

- `browser_snapshot` (the accessibility tree) will come back essentially
  empty for anything inside the game view — there's no DOM behind the
  canvas, and the HUD buttons aren't real elements either. Don't fight
  it. **Read the game off `browser_take_screenshot`** and treat
  screenshots as your only source of truth for state.
- All interaction is **coordinate-based**: click/drag by pixel position
  on the canvas, not by selecting elements. Screenshot, locate the
  target visually, click the coordinate, screenshot again to confirm.
- The format-string bug **is fixed in the local build** — `browser_console_messages`
  should return zero errors at load. If you do see format errors, note
  which panel triggered them (§5 asks for this).
- **Viewport:** the game canvas is 1280×800 inside a 1280×800 browser
  window. Use `mcp__playwright__browser_resize` to set that size before
  you start if needed.

**Known caveat:** the deployed site title still reads *"Zoo Tycoon
(Engine Validation)"* — stale, ignore.

### Option B — local

Run `./play.sh` from the repo root (requires Godot 4.5 at
`/Users/laurendeschner/godot/Godot.app/...` or set `GODOT=<path>`).
`./play.sh --iso` opens in isometric view; default is top-down.

Use Option A unless you specifically need the local build.

---

## 4. Suggested playthrough — but feel free to deviate

The point is to surface real friction, not to follow a script. If
something pulls your attention, follow it. That said, a useful spine:

1. **First 90 seconds, cold.** Do this *before reading any docs* (§2).
   Land on the welcome modal. Pick **Skip — pre-built zoo** (don't take
   the tutorial yet). Record in your notes: *what do you think you're
   supposed to do?* Screenshot what you see.
2. **First 5 minutes — figure it out.** Place an animal, build a path,
   open a goal, hover a guest. Note every moment you had to guess.
3. **Restart, take the tutorial.** Did it teach you what you wished you
   knew in step 2? Did it teach things you'd already figured out?
4. **Pick a difficulty and play to a finish line.** Standard is the
   default (30 days, $20k cash + 50 rep). Easy is gentler if Standard
   feels punishing. **Use 4x speed** between actions or you'll burn
   real-world minutes on idle days.
5. **At end-of-game (win or lose)**, screenshot the result screen and
   note: did the ending feel earned, or arbitrary?

You may save and reload mid-run if you want to compare branches.

---

## 5. What to look for in each dimension

### UX

- The first 90 seconds — what's legible without reading text? What text
  did you actually read vs. dismiss?
- Build flow: how many clicks to place an animal in a working exhibit?
  Where does the suitability rating (0–100) help or confuse?
- HUD information density — anything you ignored for the whole run?
- Pause / speed controls — did you reach for them naturally?
- The goals panel and milestones — did they steer your play, or sit
  ignored?

### Art

- Does the top-down view read cleanly? Try the isometric view (`View:
  Top` button in HUD) — does it improve or hurt?
- Animal sprites: silhouettes distinguishable at game zoom? Do the
  4-direction sprites animate convincingly or look anthropomorphic
  (a known concern — see `iso: fall back to quadruped billboards`
  commit on `main`)?
- Guest sprites + mood bubbles — do they communicate need at a glance?
- Region overlays / suitability swatches — do they feel like a tool
  you use or visual noise?

### Fun

- The economic loop: did you feel the satisfaction of *"I built this
  and it's making money"*? Where?
- Was there a point you wanted to keep playing past the day-30 finish?
  Or a point you wanted to quit before it?
- The win condition ($20k + 50 rep in 30 days) — too tight? Trivial?
- Trait-driven guest variation, donation boxes, food/drink purchases,
  arena shows — which of these did you *notice* during play, and which
  felt invisible?

### Bugs

Anything visibly wrong. Concrete repro steps preferred (what you
clicked, what you expected, what happened). **One bug we already
know about — don't waste cycles on it, just confirm or expand:**

> **MISSION panel format-string regression.** The welcome screen and
> MISSION sidebar show raw format specifiers (`%s`, `%d`, `%u`) — e.g.
> *"Reach $%s cash and %d reputation before day %d ends"*, *"Cash:
> $1,000 / $"*, *"Day %d of %d · %ut left"*. Browser console reports
> 100+ `String formatting error: a number is required` errors before
> any user input, originating from `validated_evaluate` in
> `core/variant/variant_op.h:953`. See
> [`welcome_screen_with_format_bug.png`](./welcome_screen_with_format_bug.png)
> in this folder for a reference shot of the welcome modal in this
> state. If you can pin down which mission/goal label is the source,
> say so — but don't get stuck on it.

If you find the difficulty picker is missing from the welcome modal
(only Start tutorial / Skip buttons visible), call that out too — it
may be related.

---

## 6. Report format

Write the report into `design/playtest/fable_report_2026-06-09.md`
(this folder). **Write as you go, not from memory at the end.** A
full run driven through tool round-trips with frequent screenshots is a
long session — append each finding to the report file the moment you hit
it, so early observations don't get lost to summarization before the
write-up. Tidy into the skeleton below at the finish.

Use this skeleton:

```markdown
# Playthrough Report — fable — 2026-06-09

## Session summary
- Difficulty:
- Outcome (win/lose/abandoned + day reached):
- Wall-clock minutes played:

## UX findings
- [Severity: blocker | major | minor] Finding. Where it happened. Why it matters.

## Art findings
- ...

## Fun findings
- ...

## Bugs
- [Severity] Repro steps. Expected. Actual. Screenshot ref if any.

## The "would I keep playing?" question
One paragraph, honest. What would make you open the tab again tomorrow?

## Top 3 recommendations for Phase 1 exit
Ranked. Each one sentence — the *decision*, not the implementation.
```

Use **blocker / major / minor** severity. A blocker means a new player
quits over it. A major means they keep playing but it visibly hurts.
Minor is polish.

Save screenshots into this folder with descriptive names. Reference
them inline with relative links.

---

## 7. Out of scope

- Don't edit source, tuning, or assets. If you spot a fix, write it in
  the report — Kenny applies it.
- Don't open GitHub issues or PRs.
- Don't bump the engine submodule (`engine/` is read-only per
  `CLAUDE.md` §1).
- Don't run the test suite. This is a *playtest*, not a code review.
- Don't post anywhere external.

---

## 8. Setup confirmed before handoff

- ✅ Local web build serves at `http://localhost:8060/` — zero console
  errors, full build palette, difficulty picker, real HUD numbers.
  Verified via Playwright, 2026-06-10.
- ✅ Reference screenshot of the working welcome state saved at
  `design/playtest/setup_verify_welcome.png`.
- ✅ `play.sh` exists if you ever need the native build (Godot editor
  must be running for godot-mcp tools to work; not needed for Playwright).
- ⚠️  Live URL (`sneeosh.github.io/zoo-tycoon`) is broken — missing
  tuning files in the deployed export. **Do not use it.** The fix
  (`include_filter` in `export_presets.cfg`) is committed locally and
  will propagate to the live URL when Kenny pushes to main.
- ⚠️  Reference screenshot of the broken welcome state is saved at
  `design/playtest/welcome_screen_with_format_bug.png` — for reference
  only; you will not see this on the local build.

Have fun. Be honest. The whole point of this is that you didn't build
it — so tell us what we can't see.
