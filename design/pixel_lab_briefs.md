# Pixel Lab generation briefs — closing the isometric look

The iso view (`TYCOON_ISO` / the in-game **View** toggle) is code-complete for
the visual push — every code-only "tell" is fixed (directional animals,
scenery, gate, lamp-lit paths, chunky fences). Two art passes remain, and the
renderer is already wired (or one-line ready) to consume them. Generate, drop
the PNGs at the exact paths below, commit them (+ the `.import` files Godot
makes), and they appear with **no further code** unless noted.

Two non-negotiables across everything here:
- **Crisp pixel art** — no anti-aliased edges, no baked drop-shadow (the game
  adds its own soft shadow), transparent background.
- **Match the existing set** — open `assets/sprites/lion_4dir/south.png` and
  `assets/sprites/food_stand.png` for palette (warm, saturated), outline weight
  (dark, ~1px), and the ¾ angle. New pieces must sit in the same world.

---

## Brief 1 — Seamless isometric ground tiles  ⭐ biggest remaining jump

**Goal:** replace the flat-color diamonds with textured terrain. This is the
single largest step toward the Zoo Tycoon look.

**The hard requirement (this is why the first batch failed):** each tile is a
**2:1 diamond** that **tiles seamlessly** with copies of itself on all four
diagonal edges. The texture must bleed all the way to every edge with **NO
border, rim, frame, or outline**. Test by laying the PNG out **3×3** — you must
not be able to see where one diamond ends and the next begins. If you can see a
diamond grid, it's wrong.

**Format:** 64×32 px canvas. The diamond's four points touch the **midpoints of
the canvas edges** (top-center, right-center, bottom-center, left-center).
Everything outside the diamond is transparent.

**Keep contrast low.** These tile hundreds of times; high-contrast detail
repeats badly. Subtle tonal variation only.

| File | Surface | Notes |
|---|---|---|
| `assets/sprites/iso_grass.png` | Parkland / grass enclosure | mowed-grass texture, faint blade detail |
| `assets/sprites/iso_dirt.png` | Bare-earth enclosure floor | packed dirt, a few specks |
| `assets/sprites/iso_rock.png` | Rocky enclosure floor | gravel + scattered small stones |
| `assets/sprites/iso_water.png` | Water enclosure | calm water; the game adds an animated shimmer, so keep it still and mid-blue |
| `assets/sprites/iso_sand.png` | Aviary / beach floor | pale sand |
| `assets/sprites/iso_path.png` | Path / promenade | groomed sand or pale cobble; must also tile seamlessly |

**Optional but nice:** 2–3 variants each (`iso_grass_a/b/c.png`) so large fields
don't visibly repeat. Same seamless rule applies to every variant.

**Acceptance test:** open any tile, duplicate it into a 3×3 grid offset by
(±32, ±16) px per neighbor (the iso step) — the result must look like one
continuous surface with no visible tile boundary.

**Code note (mine):** the renderer currently draws ground as solid diamonds. When
these land I re-add a one-tile textured-diamond draw path (a few lines) — the
art is the long pole, the wire is trivial.

---

## Brief 2 — Directional animal sprites (`_4dir`)

**Goal:** every animal faces where it walks, in true ¾ iso art — like
`lion_4dir` and `zebra_4dir` already do. The renderer **already** picks the
right one per heading; new species need **no code**, just the files.

**Files:** one folder per species, four PNGs:
```
assets/sprites/<species>_4dir/north.png
assets/sprites/<species>_4dir/south.png
assets/sprites/<species>_4dir/east.png
assets/sprites/<species>_4dir/west.png
```

**Size & pivot:** **92×92** px (match `lion_4dir` exactly), transparent, object
**centered horizontally**, with the **feet near the bottom of the opaque
area** (the game seats the sprite by its lowest opaque pixels, so a floating
animal will float). Generous transparent margin.

**Facing convention — match `lion_4dir` exactly (the renderer depends on it):**
| File | The animal faces… | i.e. moving toward screen… |
|---|---|---|
| `south.png` | **toward the viewer** (front view, ¾) | down |
| `north.png` | **away** (back view, ¾) | up |
| `east.png`  | **screen-right** (profile, ¾) | right |
| `west.png`  | **screen-left** (mirror of east) | left |

(If unsure, open `lion_4dir/south.png` vs `lion_4dir/east.png` — `south` is the
face-on pose, `east` is the right-facing profile. Copy that exact orientation
logic.)

**Species still needing a set** (lion + zebra are done), in priority order —
do the most-seen first:

1. `penguin` — in the starter park, always on screen.
2. `elephant`, `tiger`, `polar_bear` — big hero animals; the ¾ art reads most.
3. `giraffe`, `seal`, `monkey` — the new species from the last art drop.
4. `flamingo`, `peacock`, `toucan`, `parrot` — birds; smaller, lower priority.

**Acceptance test:** drop a folder in, run with the **View** toggle on iso, and
watch one of that species wander its pen — it should turn to face its direction
of travel with no popping or wrong-way frames.

---

## Sequencing

1. **Ground tiles first** (Brief 1) — biggest single visual jump, and it lifts
   *every* exhibit and path at once.
2. **Penguin `_4dir`** — the one animal always on screen in the starter park.
3. The rest of the directional sets as you have cycles.

Hand me whatever lands and I'll wire/verify it the same day. After Brief 1 +
the priority directional sets, the iso view is at the Zoo-Tycoon bar and
`TYCOON_ISO` can graduate from a flag to the default.
