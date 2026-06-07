# Isometric Direction — validation, plan, and Pixel Lab art spec

**Status:** Prototype validated 2026-06-07. Isometric renderer exists behind
the `TYCOON_ISO` env var (`src/ui/iso_preview.gd`); the shipping build stays
top-down for now.

---

## What the prototype proved

- **The simulation is projection-agnostic.** The iso renderer reads the exact
  same `EntityRegistry` / `RegionRegistry` / `AgentPool` as the top-down view.
  Going isometric is a **rendering + art** change — **zero gameplay rewrite**.
- **Fenced pens with height read as real enclosures** — the genre look — using
  a 2:1 diamond grid and a fence drawn with vertical posts/rails.
- **The existing top-down sprites work as upright "billboards."** The lion,
  penguins, and buildings stand on the iso ground and look fine. So we do
  **not** need to redraw every animal/building for a first iso pass. The main
  art gap is the **ground**.

(Render it yourself: `TYCOON_ISO=1` then run the game, or the screenshot
harness `TYCOON_ISO=1 TYCOON_SHOT=/tmp/iso.png:300`.)

---

## The art that actually moves the needle (Pixel Lab)

> **Update 2026-06-07 — the ground now renders procedurally, so the grid is
> fixed without art.** The first cut of `iso_grass/dirt/rock/water/path.png`
> baked a dark soil rim into every diamond edge, so tiling them painted a
> visible grid (confirmed by a 3×3 tiling test). The renderer no longer tiles
> those PNGs: ground, paths, and enclosure floors are drawn as solid,
> per-cell-varied diamonds with scattered foliage (the same seamless technique
> the top-down view uses). Adjacent solid diamonds share edges exactly, so
> there is no lattice. **Priority A below is now optional polish, not a
> blocker** — and if textured tiles ever come back they MUST be truly seamless
> (see the hard requirement in the table).

### Priority A — isometric ground tiles (diamond, **64×32**, seamless) — OPTIONAL

The procedural ground looks clean already; textured tiles are only worth it if
they're a clear upgrade. **The one non-negotiable rule: zero border.** Each is a
single diamond that fills a 64×32 canvas (the four points touch the mid-points
of the canvas edges), transparent outside the diamond, and **tiles seamlessly**
on all four diagonal edges — the texture must bleed all the way to every edge
with **no darker rim, frame, or outline**. Verify by tiling the PNG 3×3: you
must not be able to see where one diamond ends and the next begins. (The first
batch failed exactly this test — the dark bottom-edge rim is what produced the
grid.)

| File | Surface |
|---|---|
| `iso_grass.png` | Parkland / general grass |
| `iso_dirt.png` | Enclosure floor (bare earth) |
| `iso_rock.png` | Rocky enclosure floor |
| `iso_water.png` | Water (the game adds an animated shimmer on top) |
| `iso_path.png` | Path / pavement |

A handful of **variants** each (e.g. `iso_grass_a/b/c`) avoids obvious
repetition — optional but nice.

### Priority B — isometric fence (optional; procedural fence works for now)

A short fence segment with height, drawn for the two iso edge directions:

| File | What |
|---|---|
| `iso_fence_left.png` | A run of fence along the "↘" (down-right) tile edge, ~64 wide × ~40 tall, posts + rails, transparent. |
| `iso_fence_right.png` | The mirror, along the "↙" (down-left) edge. |
| `iso_gate.png` | A gate piece for the entrance. |

### Priority C — dedicated iso art for hero objects (later)

The billboarded top-down sprites are fine to ship. Eventually, true ¾ iso art
for the **buildings** (food stall, restroom, restaurant, shelter, arena) and a
few **signature animals** would sharpen it — but this is polish, not a blocker.

**Sizing/style:** match the existing palette and outline weight. Diamond tiles
are 64×32. Object/building art that replaces a billboard should be drawn at the
same ¾ iso angle and sized to its footprint (1×1 ≈ 64×64, 2×2 ≈ 128×96).

---

## The code work remaining (mine, not yours)

Progress so far (2026-06-07): iso is now a **real interactive view**, not a
prototype.

- [x] **Inverse projection + interaction.** `_screen_to_cell` round-trips tile
      centres (tested); `_gui_input` emits placement/remove; a build preview
      draws footprint diamonds (entities) / region highlight (placeables) + a
      hover outline. Both views now share `BaseMapView`, so `main.gd` drives
      them through one path. (`tests/test_iso_view.gd`.)
- [x] **Camera:** fit-to-view on resize, mouse-wheel zoom about the cursor,
      middle-drag pan — one view `Transform2D`, projection math untouched.
      (Cursor-anchored zoom is tested.)
- [x] **Visual ports done:** day/night tint, "no path access" ⚠ warning,
      water shimmer, money-float toasts, sick ✚ marker.
- [ ] **Visual ports remaining:** guest mood bubbles (the big one — need
      legibility), hover inspector card, weather overlay.
- [ ] **Depth-sort tie-breaks** for edge cases (object vs. fence on the same
      cell) could use tuning.
- [ ] **Textured ground** stays optional — procedural ground already reads
      cleanly with no grid; only swap in tiles if they're seamless and a clear
      upgrade (drop-in).

Once mood bubbles + the hover inspector land, iso is at functional parity with
top-down and the `TYCOON_ISO` flag could become a player-facing toggle.

None of this touches the simulation — it's all in the view layer. Estimate:
the inverse-projection + interaction is the main chunk; the rest is porting
draw code that already exists.

---

## Recommended phasing

1. **Now / playtest:** ship **top-down** (it's polished and complete).
2. **Art track (you, Pixel Lab):** generate the **Priority-A iso ground
   tiles** — that's the single biggest lever and unblocks a good-looking iso.
3. **Code track (me):** wire iso interaction + port the visual systems behind
   the flag, so when the tiles arrive we flip `TYCOON_ISO` on and iterate.
4. **Flip the default** once iso reaches parity and looks better than top-down.

Bottom line: isometric is the right look and it's **feasible without a rewrite
or a full art redo** — the prototype already reads like Zoo Tycoon with
placeholder art. The ground tiles are the thing to make first.
