# Research: graphics tactics from open-source games

**Question:** what rendering techniques from established open-source park/sim
games could push our isometric look toward Zoo Tycoon — especially **art-free**
ones, since art generation is our current bottleneck?

**Licensing guardrail (engine `CLAUDE.md` §8):** we *study* OpenRCT2 (GPLv3),
OpenTTD (GPLv2), Wesnoth (GPLv2), and Factorio (proprietary) for **patterns and
math only** — we never copy their code. Everything below is a technique to
re-implement cleanly in our own `src/ui/iso_preview.gd`, not a port.

---

## TL;DR — the high-leverage, art-free wins

| Tactic | Source | Fixes | Effort | Art? |
|---|---|---|---|---|
| **Procedural ground *shader*** (FBM noise → grass/dirt/water) | Godot water/grass shaders | the flat-color diamonds — **without** the Brief-1 art pass | M | **none** |
| **Terrain edge transitions** (soft fringes where grass meets water/dirt) | Wesnoth, Factorio | hard diamond boundaries between surfaces | L–M | **none** |
| **Night lamp glow + lit windows** (additive radial glows during dusk) | OpenRCT2 light sources | dead, flat night; sells "alive after dark" | L | **none** |
| **Contact AO + cast shadows** (darken object/fence bases, project shadows) | iso pixel-art practice | billboards/fences that don't feel grounded | L | **none** |
| **Ordered (Bayer) dithering** for tints/blends | pixel-art practice | smooth-alpha gradients that break the pixel look | L | **none** |
| Animated water (color-cycle / caustics) | OpenRCT2/OpenTTD palette cycling | static-ish pools | L–M | none |
| Sprite atlas / draw batching | OpenRCT2 OpenGL renderer | web perf at high object counts | M | none |

The top four are all art-free and directly attack the remaining "tells" — they
could close most of the visual gap **without** waiting on the Pixel Lab passes.

---

## The techniques, mapped to our code

### 1. Procedural ground via a fragment shader  ⭐ (art-free alternative to Brief 1)
Godot community water/grass shaders generate texture from **fractal Brownian
motion over noise** entirely on the GPU ([2D procedural water][water],
[stylized grass][grass]). Instead of (or before) seamless tile art, draw the
iso ground as **one big polygon on a child `CanvasItem` with a `ShaderMaterial`**
that textures grass/dirt/rock/water procedurally in iso-space, with animated
water built in. No seams (it's continuous), no art, web-friendly (one draw).
- **Maps to:** replace `_draw_ground` / `_draw_region_fills` solid diamonds with
  a shaded ground layer; pass each cell's terrain type via a small lookup
  texture or vertex colors.
- **Caveat:** Godot has no built-in shader noise ([proposal #2443][noise]) — bake
  a `NoiseTexture2D` and sample it. This is the single biggest art-free jump.

### 2. Terrain edge transitions (Wesnoth fringes / Factorio masks)
Wesnoth draws **separate transition images around each tile per adjacency**, with
flags so only one fringe is drawn per shared edge ([Terraingraphicswml][wes]).
Factorio does it at runtime with **a shared greyscale alpha mask multiplied into
the texture** — one mask reused for every "X→water" transition ([FFF-214][fff]).
- **Maps to (procedural, no art):** in `_draw_region_fills`, after filling a
  water/dirt diamond, for each edge adjacent to *grass*, draw a short
  feathered/dithered fringe in the blend color. Kills the hard "sticker" edge of
  pools and dirt pens. Cheap and high-impact.

### 3. Night lighting with light sources (OpenRCT2)
OpenRCT2: "light-producing items such as lamps emit a glow during nighttime and
rainstorms," driven by the day/night palette cycle ([options][rct-opt],
[light sprites][rct-light]). Godot's native route is `CanvasModulate` (darken) +
`Light2D` in Add mode ([2D lights][godot-light]).
- **Maps to (immediate-mode, cheap):** during our existing dusk tint
  (`_draw_day_night`), draw **additive warm radial gradients** at each
  `lamp_post` cell and at building doorways, alpha scaled by the darkness factor.
  We already know lamp positions (`_rebuild_scenery`). Turns the flat blue night
  into a lamplit park. (Avoid OpenRCT2's known flicker bug — keep glows steady.)

### 4. Contact AO, grounding & cast shadows (iso pixel-art practice)
Pros darken where forms meet the ground and **lighten/remove outlines at the
contact line** so objects sit *in* the world, not on it; the standard flat-plane
cast shadow is a parallelogram projected from the base at a fixed light angle
([Pixel Parmesan][pp], [SLYNYRD][sly]).
- **Maps to:** (a) under `_draw_billboard`, replace the plain ellipse with a
  soft AO blob + a short projected cast shadow at a consistent sun angle; (b) in
  `_fill_diamond`, darken the *down* edges of each tile a hair for ambient
  occlusion; (c) at fence/building bases, add a 1–2px dark contact band.

### 5. Ordered (Bayer) dithering for tints & blends
Pixel artists use **4×4 ordered/Bayer dithering** to imply shading and to break
toon-band boundaries instead of smooth alpha ([dithering tips][dith]).
- **Maps to:** our dusk overlay and the new edge fringes currently use smooth
  alpha, which looks "modern" not "pixel." A tiny Bayer-threshold shader (or a
  precomputed 4×4 pattern texture tiled over the overlay) makes night and
  transitions read as pixel art. Small, cohesive win.

### 6. Animated water (OpenRCT2 / OpenTTD palette cycling)
Both cycle the palette to animate water cheaply ([color cycling][ottd]). We do
shimmer lines today; folding water into the ground shader (#1) gives real
animated caustics, or we color-cycle the water fill in `_region_floor_color`.

### 7. Sprite atlas + draw batching (OpenRCT2 OpenGL renderer)
OpenRCT2 batches ~99% of draws (sprites) into queued, atlased draw calls
([OpenGL renderer][rct-gl]). Godot 4 already auto-batches 2D canvas items, but if
our per-frame billboard/scenery count climbs, packing sprites into one atlas
keeps it one draw call. Perf insurance, not a visual change — revisit if profiling
flags it.

---

## Recommended next moves (all art-free)

1. **Night lamp glows** (#3) — biggest "wow" for the least code; we already track
   lamp positions and have the dusk pass.
2. **Terrain edge fringes** (#2) — removes the pool/dirt "sticker" edges.
3. **Contact AO + cast shadows** (#4) — grounds every billboard and fence.
4. **Procedural ground shader** (#1) — the real fix for flat ground; bigger lift,
   but it makes the Brief-1 art pass *optional*.
5. Dithering pass (#5) once the above land, to unify the look as pixel art.

If we do 1–4, the only thing the art passes still add is *bespoke* terrain/animal
detail — the structural "this isn't Zoo Tycoon" reads are gone in code.

---

## Sources
- OpenRCT2 — [OpenGL renderer (atlas batching)](https://github.com/OpenRCT2/OpenRCT2/wiki/OpenGL-renderer), [lighting options](https://docs.openrct2.io/en/latest/setup/options.html), [light sprites at night](https://forums.openrct2.org/topic/956-light-sprites-during-night-timeraining/)
- OpenTTD — [palette color cycling](https://github.com/OpenTTD/OpenTTD/issues/5056)
- Battle for Wesnoth — [Terraingraphicswml (transition rules)](https://wiki.wesnoth.org/Terraingraphicswml), [Tiles Tutorial](https://wiki.wesnoth.org/Tiles_Tutorial)
- Factorio — [FFF-214 Concrete rendering (alpha-mask transitions)](https://www.factorio.com/blog/post/fff-214), [FFF-199 tile transitions](https://forums.factorio.com/viewtopic.php?t=50897); autotiling survey: [Beyond Basic Autotiling](https://www.boristhebrave.com/2021/09/12/beyond-basic-autotiling/)
- Godot — [2D procedural water shader][water], [stylized grass shader][grass], [shader noise proposal][noise], [2D lights & shadows][godot-light]
- Isometric pixel-art practice — [Pixel Parmesan: fundamentals][pp], [SLYNYRD pixelblog][sly], [dithering tips][dith]

[water]: https://godotshaders.com/shader/perlin-procedural-water/
[grass]: https://godotshaders.com/shader/stylized-grass-with-wind-and-deformation/
[noise]: https://github.com/godotengine/godot-proposals/issues/2443
[godot-light]: https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
[wes]: https://wiki.wesnoth.org/Terraingraphicswml
[fff]: https://www.factorio.com/blog/post/fff-214
[rct-opt]: https://docs.openrct2.io/en/latest/setup/options.html
[rct-light]: https://forums.openrct2.org/topic/956-light-sprites-during-night-timeraining/
[rct-gl]: https://github.com/OpenRCT2/OpenRCT2/wiki/OpenGL-renderer
[ottd]: https://github.com/OpenTTD/OpenTTD/issues/5056
[pp]: https://pixelparmesan.com/blog/fundamentals-of-isometric-pixel-art
[sly]: https://www.slynyrd.com/blog/2022/11/28/pixelblog-41-isometric-pixel-art
[dith]: https://dotmatrixmaster.com/pixelart-shading-techniques-beginners-tips-and-tricks/
