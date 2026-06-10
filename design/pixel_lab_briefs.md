# Pixel Lab generation briefs — closing the isometric look

The iso view (`TYCOON_ISO` / the in-game **View** toggle) is code-complete for
the visual push. Two art passes remain: **directional animal sprites**
(Brief 2) and the **ZT1 hero objects** (Brief 3 — entrance arch, fountain,
¾-iso buildings, fence sprites). The renderer is already wired to consume
Brief 2 — drop the PNGs at the exact paths below, commit them (+ the
`.import` files Godot makes), flip one flag, and they appear with no further
code. Brief 3 items replace existing sprite files in place, so most of them
also need zero code.

Two non-negotiables across everything here:
- **Crisp pixel art** — no anti-aliased edges, no baked drop-shadow (the game
  adds its own soft shadow), transparent background.
- **Match the existing set** — open `assets/sprites/lion.png` (the *billboard*,
  not the broken `_4dir` one) for palette (warm, saturated), outline weight
  (dark, ~1 px), and chunky-quadruped proportions. New pieces must sit in the
  same world.

---

## Brief 1 — Seamless isometric ground tiles  *(superseded — skip)*

Ground is now drawn **procedurally** in the iso renderer (seamless noise
× terrain tint), so we no longer need Pixel Lab tiles for `iso_grass`,
`iso_dirt`, `iso_rock`, `iso_water`, `iso_sand`, `iso_path`. If we ever want
to swap procedural for hand-pixeled tiles, the old brief is in git history
(commit before this rewrite).

---

## Brief 2 — Directional animal sprites (`_4dir`)  ⭐ the only outstanding ask

**Goal:** every animal faces where it walks, in true ¾ iso art. The renderer
already picks the right file per heading — new species need **no code**, just
the four PNGs.

**Files:** one folder per species, four PNGs:
```
assets/sprites/<species>_4dir/north.png
assets/sprites/<species>_4dir/south.png
assets/sprites/<species>_4dir/east.png
assets/sprites/<species>_4dir/west.png
```

### Why this brief exists — the anthropomorphic failure

> ⚠️ The current `lion_4dir/` and `zebra_4dir/` art is **WRONG** — both came
> out **anthropomorphic**: a bipedal humanoid standing upright on two legs
> like a person wearing a lion/zebra costume. The directional renderer is
> therefore **disabled** (`_directional_enabled = false` in
> `src/ui/iso_preview.gd` ~line 1148) and animals fall back to the
> (correct) quadruped billboard sprites. The whole point of this brief is
> to get art that does **not** repeat that mistake.

### Anatomy — non-negotiable

The animal is a **real four-legged quadruped on all fours**, in profile/¾,
**all four feet on the ground**. Look at `assets/sprites/lion.png` — that
chunky on-all-fours pose is what we want, just rendered four times for the
four facings.

The art is **NOT**:
- standing upright on two legs
- bipedal, humanoid, or person-shaped
- wearing a costume / mascot suit
- a cartoon character with human posture

A lion looks like a lion walking. A zebra like a zebra grazing. A penguin is
the one exception — penguins really are bipedal, so a waddling upright
penguin is correct (just not a *humanoid* one).

### Size, canvas, pivot

- **92×92 px** canvas, transparent background.
- Object **centered horizontally**.
- **Feet near the bottom** of the opaque area — the renderer seats the
  sprite by its lowest opaque pixels, so floating space below the feet will
  make the animal float above the ground.
- Generous transparent margin on top/sides for tails, heads, ears.

### Facing convention — match exactly (the renderer depends on it)

| File | The animal faces… | i.e. moving toward screen… |
|---|---|---|
| `south.png` | **toward the viewer** (front ¾) | down-and-right on screen |
| `north.png` | **away from the viewer** (back ¾) | up-and-left on screen |
| `east.png`  | **screen-right** (right profile, ¾) | right-and-down |
| `west.png`  | **screen-left** (mirror of east) | left-and-up |

`west.png` may be a horizontal flip of `east.png` if that reads cleanly.

### Per-species prompts (paste into Pixel Lab one at a time)

Same template for every species — only the species name and one descriptor
line change. The shared rules are baked in so Pixel Lab can't drift.

**Shared preamble (prepend to every prompt):**

> Pixel art, 92×92 px, transparent background, crisp pixels (no
> anti-aliasing), dark ~1 px outline, warm saturated palette matching a
> classic zoo-tycoon style. The subject is a **real four-legged quadruped
> on all fours, all four feet on the ground, in a ¾ isometric view**.
> Absolutely **not** bipedal, **not** humanoid, **not** standing upright,
> **not** in a costume. Reference a real animal's silhouette. Feet at the
> bottom of the opaque area, generous transparent margin above.

Then per species, four generations (one per facing). Append exactly one of:
- *"Front ¾ view — animal faces the viewer."* → save as `south.png`
- *"Back ¾ view — animal faces away from the viewer."* → save as `north.png`
- *"Right-side profile, ¾ — animal faces screen-right."* → save as `east.png`
- *"Left-side profile, ¾ — animal faces screen-left."* (or flip `east.png`) → save as `west.png`

**Species descriptors** (append after the shared preamble, before the facing line):

| Species | Descriptor | Folder |
|---|---|---|
| Lion | Adult male lion, tawny coat, full dark mane around the head, long tail with tuft. Chunky, stocky body. | `lion_4dir/` *(REDO — currently anthropomorphic)* |
| Zebra | Adult zebra, black-and-white vertical stripes, short upright mane, horse-like body. | `zebra_4dir/` *(REDO — currently anthropomorphic)* |
| Penguin | Emperor-style penguin, **upright bipedal is correct here** — black back, white belly, orange beak. Short waddling pose. (Override the quadruped rule for this one species only.) | `penguin_4dir/` |
| Elephant | Large gray elephant, big ears, long trunk curled slightly, short tusks, thick legs. | `elephant_4dir/` |
| Tiger | Orange tiger with bold black stripes and white belly, long tail. Same chunky proportions as the lion. | `tiger_4dir/` |
| Polar bear | Large white/cream polar bear, small ears, low head carriage, heavy paws. | `polar_bear_4dir/` |
| Giraffe | Tall giraffe with reticulated brown patches on cream coat, very long neck, small ossicone horns. Neck angled forward for the side views. | `giraffe_4dir/` |
| Seal | Plump gray harbor seal, short flippers, lying/shuffling pose on land (no upright "circus seal" pose). | `seal_4dir/` |
| Monkey | Small brown monkey on all fours, long tail curled up behind, alert expression. Not a chimp standing upright. | `monkey_4dir/` |
| Flamingo | Pink flamingo — bipedal is correct (real bird anatomy), long thin legs, curved S-neck, hooked beak. Override quadruped rule. | `flamingo_4dir/` |
| Peacock | Male peacock — bipedal is correct, iridescent blue body, fanned blue-green tail visible in `south.png`, tail trailing behind in profile views. Override quadruped rule. | `peacock_4dir/` |
| Toucan | Black toucan with white throat and big orange beak — bipedal is correct, perched/standing pose. Override quadruped rule. | `toucan_4dir/` |
| Parrot | Bright green-and-red parrot — bipedal is correct, hooked beak, short tail. Override quadruped rule. | `parrot_4dir/` |

### Priority order

Most-seen first — the ¾ art reads most on the animals that fill the screen:

1. **Lion + Zebra REDO** (currently broken — fixing these unblocks the renderer)
2. **Penguin** — in the starter park, always on screen
3. Elephant, Tiger, Polar Bear — big hero animals
4. Giraffe, Seal, Monkey — newer species from the last drop
5. Flamingo, Peacock, Toucan, Parrot — birds; smaller, lower priority

### When art lands — flip the flag

Once at least one corrected set exists (lion redo is enough to verify):

1. Drop the four PNGs into `assets/sprites/<species>_4dir/`.
2. Open Godot once so it generates the `.import` files; commit those too.
3. In `src/ui/iso_preview.gd`, change `_directional_enabled = false` (~line 1148)
   to `true`. The mapping logic above it is already unit-tested and stays as-is.
4. Run with **View** toggled to iso — pick that species, watch one wander its
   pen. It should turn to face its direction of travel with no popping, no
   wrong-way frames, and crucially **not be standing on two legs**.

If any species' set looks off, the renderer per-species check
(`ResourceLoader.exists("res://assets/sprites/<species>_4dir/south.png")`)
means deleting that folder cleanly reverts that species to billboard while
leaving the others on the directional path.

---

## Brief 3 — ZT1 hero objects (the "looks like Zoo Tycoon" pack)

**Why this brief:** the 2026-06 visual push made ground, paths, fences,
guests, and dressing procedural — the park now reads bright-ZT1 without
art. What procedural drawing *can't* fake are the hero silhouettes the 2001
game is remembered by: the stone **entrance arch with the ZOO sign**, the
plaza **fountain**, and buildings with real ¾-isometric volume (thatched
kiosk roofs, the carousel-striped umbrella stand). This brief generates
those.

**Shared preamble (prepend to every prompt in this brief):**

> Pixel art for a classic 2001-style zoo tycoon game, ¾ isometric view
> (object viewed from the front-left, sun from the upper-left), crisp
> pixels, no anti-aliasing, dark ~1 px outline, warm saturated palette.
> Transparent background, **no baked drop shadow** (the game draws its
> own), no ground/grass baked into the image — the object only. The object
> sits at the BOTTOM of the canvas (feet/foundation at the lowest opaque
> pixels), generous transparent margin on top.

### 3a — Entrance arch  ⭐ highest impact

| File | Canvas | Prompt addition |
|---|---|---|
| `assets/sprites/entrance_arch.png` | 192×160 | A grand zoo entrance: a weathered gray stone archway spanning a path, with a curved emerald-green sign across the top reading "ZOO" in gold capital letters. Low stone walls flare out at both sides of the arch. Two small bronze animal statues (a deer and a bear) flank the arch on top of short stone pillars. The opening under the arch is fully transparent so guests can be seen walking through. |

**Code wiring (Kenny/Claude, after art lands):** in
`src/ui/iso_preview.gd` `_draw_sorted_objects`, the entrance currently
draws `ticket_booth` at `GATE_CELL` — swap the sprite name to
`entrance_arch` with `wmul ≈ 2.6` and keep the booth one cell to the side.

### 3b — Plaza fountain

| File | Canvas | Prompt addition |
|---|---|---|
| `assets/sprites/fountain.png` | 128×128 | A round two-tier stone fountain on an octagonal stone basin, water arcing from the top bowl into the wide lower pool, light-blue water with white spray highlights. Classic city-park style. |
| `assets/sprites/fountain_b.png` (optional) | 128×128 | Same fountain, spray at a different frame so the two can alternate for cheap animation. |

**Code wiring:** new `fountain` amenity in `design/tuning/entities.md`
(2×2, decorative appeal/happiness like the Japanese Garden pattern from
the reference dossier §7) — zoo-side tuning only, no engine change.

### 3c — Building reskins, true ¾ iso (replace in place — zero code)

Each replaces an existing billboard PNG at the same path. Match the canvas
of the current file (open it and check; most are ~92–128 px square). The
constraint that matters: same ¾ iso angle as the preamble, footprint-true
base proportions (1×1 ≈ 64 px wide base, 2×2 ≈ 128 px wide base).

| File | Footprint | Prompt addition |
|---|---|---|
| `food_stand.png` | 2×2 | A small zoo food kiosk with a **thatched straw roof**, wooden counter, burger sign, ketchup-red awning trim. |
| `drink_stand.png` | 1×1 | A tiny drink cart with a **red-and-white striped umbrella**, cooler box with cup logo. |
| `restroom.png` | 1×1 | A small tan brick restroom hut with a brown shingle roof and blue M/W door signs. |
| `gift_shop.png` | 2×2 | A small zoo gift shop with a yellow-gold thatched roof, display window with plush animals, "GIFTS" sign. |
| `restaurant.png` | 2×2 | A zoo terrace restaurant: cream walls, green tile roof, outdoor tables with umbrellas at the front edge. |
| `compost.png` | 2×2 | A rustic wooden compost shed with open front bays and a hay/soil pile, a few green stink wisps. |
| `arena.png` | 3×3 | A circular show arena: low stone ring wall, sand floor, small wooden grandstand arc at the back, festival bunting. |

### 3d — Iso fence sprite sets (upgrade from procedural)

Per `pixel_lab_isometric_spec.md` Priority B, now styled per ZT1's catalog.
Two styles first:

| Files | Canvas | Style |
|---|---|---|
| `assets/sprites/fence_wood_left.png` / `fence_wood_right.png` | 64×48 | Wood slat fence (the ZT1 default exhibit fence): two warm-brown horizontal slats on round posts. `_left` runs along the ↘ tile edge, `_right` mirrors along ↙. |
| `assets/sprites/fence_picket_left.png` / `fence_picket_right.png` | 64×48 | Low white picket fence (ZT1 uses it around flower beds and guest areas). |

The segment must tile: posts exactly at both ends, rails meeting the canvas
edges so adjacent segments connect. **Code wiring:** `_draw_fence_edge`
falls back to procedural rails today; once these exist we texture the edge
instead (small renderer change, flagged per-style).

### 3e — Exhibit habitat & enrichment objects

The exhibit-authoring layer (design/tuning/habitat.md) shipped with three
**programmatically generated placeholders** — replace them, and add foliage
variety. All are in-exhibit objects, so: same preamble, plus *"sized to sit
inside a fenced animal pen."*

| File | Canvas | Prompt addition |
|---|---|---|
| `assets/sprites/wood_shelter.png` *(replace placeholder)* | 96×96 | A small open-front wooden animal shelter / lean-to: slanted plank roof with straw on top, dark shaded interior opening facing front-left, sturdy log posts. |
| `assets/sprites/rock_cave.png` *(replace placeholder)* | 96×96 | A rocky animal den: a mound of gray granite boulders with a dark arched cave opening facing front-left, moss patches. |
| `assets/sprites/toy_ball.png` *(replace placeholder)* | 48×48 | A colorful striped beach ball animal toy, red/yellow/blue wedges, white highlight. |
| `assets/sprites/acacia.png` *(new, then re-point sprite_key)* | 92×92 | An African acacia tree: flat umbrella-shaped dark-green canopy on a slender forked trunk. |
| `assets/sprites/fern_clump.png` *(new, then re-point)* | 64×64 | A dense clump of tropical ferns, arching bright-green fronds. |

### Priority order for Brief 3

1. **3a entrance arch** — the single most iconic ZT1 read.
2. **3c food_stand + drink_stand + restroom** — the buildings guests crowd
   around all game.
3. **3b fountain** — anchors the plaza like the reference screenshots.
4. **3e shelters + acacia** — the exhibit layer's hero pieces.
5. Rest of 3c, then 3d.
