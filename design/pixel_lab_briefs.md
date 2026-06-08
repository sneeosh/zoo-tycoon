# Pixel Lab generation briefs — closing the isometric look

The iso view (`TYCOON_ISO` / the in-game **View** toggle) is code-complete for
the visual push. One art pass remains: **directional animal sprites**. The
renderer is already wired to consume them — drop the PNGs at the exact paths
below, commit them (+ the `.import` files Godot makes), flip one flag, and
they appear with no further code.

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
