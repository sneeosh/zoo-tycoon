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

The renderer currently fills tiles with flat tinted diamonds. Replacing those
with proper isometric ground textures is ~80% of the visual jump.

### Priority A — isometric ground tiles (diamond, **64×32**, seamless)

Each is a single diamond that fills a 64×32 canvas (the four points touch the
mid-points of the canvas edges), transparent outside the diamond, and **tiles
seamlessly** with copies of itself on all four diagonal edges (no border/frame
— same rule as the top-down seamless tiles, but diamond-shaped).

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

To promote iso from prototype to the real renderer:

1. **Inverse projection** (screen → cell) for click-to-place, hover inspector,
   and build preview in iso. (Math is straightforward; just not wired yet.)
2. **Port the visual systems** already in the top-down view: day/night tint,
   weather, water shimmer, mood bubbles, money-float toasts, the "no path
   access" ⚠ and sick ✚ markers, pen ground-cover.
3. **Textured ground** once the iso tiles above land (drop-in).
4. **Tune** camera origin/zoom and depth-sort tie-breaks.

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
