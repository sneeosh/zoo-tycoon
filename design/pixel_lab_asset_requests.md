# Pixel Lab Asset Requests — Zoo Tycoon

**Purpose:** the sprite art the game is missing (or reusing as a stand-in).
Generate these in Pixel Lab and drop the PNGs into `assets/sprites/`. The
game already renders fine without them (it falls back to clean colored
objects), so this is pure visual polish — do them in priority order.

---

## How sprites are used (read first)

- **Top-down zoo, pixel-art.** The map is a 36-px tile grid seen from
  above with a slight ¾ tilt (animals/buildings face the camera a little).
  Match the existing art so new pieces sit in the same world.
- **One PNG per object, transparent background.** The filename must match the
  object's `sprite_key` (see each row below). The engine draws the PNG into
  the object's footprint on the grid.
- **Where they go:** `assets/sprites/<name>.png`. Godot auto-imports on next
  open / CI build — no manual import step. Keep them **crisp pixel art**
  (no anti-aliased edges, no drop-shadow baked in — the game adds its own
  shadow).
- **Sizing convention** (from the existing set): a 1×1-tile object ≈ **64×64**
  px (small creatures 32×32), a 2×2 ≈ **128×128**, a 3×3 ≈ **192×192**.
  Square canvas, object centered, generous transparent margin.

**Style anchors already in the game** (open these for reference):
`food_stand.png` (a red-and-white striped market stall), `restroom.png`
(blue-roof hut), `lion.png` / `zebra.png` / `elephant.png` (chunky 64-px
animals), `parrot.png` / `penguin.png` (32-px birds), `entrance_gate.png`
(stone arch with a "ZOO" sign), `feeding_trough.png` / `water_trough.png`.
Palette is warm and saturated with dark outlines.

---

## Priority 1 — replace the fallback boxes (most visible)

These currently render as plain colored tiles with a letter. Real art here
is the biggest win.

| File to create | Object | Footprint | Size | What it should look like |
|---|---|---|---|---|
| `bench.png` | Park Bench | 1×1 | 64×64 | A wooden slatted park bench (seat + back + legs), warm brown, top-down ¾. Small. |
| `compost.png` | Compost Building | 2×2 | 128×128 | A rustic compost/shed structure — open wooden bin with dark soil/mulch, maybe a wheelbarrow. Reads as "useful but stinky." Muted browns/greens, a few flies optional. |
| `arena.png` | Arena | 3×3 | 192×192 | A small show arena / grandstand: a circular stage with tiered bench seating around it, sandy floor. Reads as a performance venue. |
| `donation_box.png` | Donation Box | 1×1 (placeable) | 64×64 | A small clear/▢ donation box on a post with a coin slot, a coin or two visible. Tiny. Sits *inside* an exhibit. |

## Priority 2 — dedicated art (currently aliased/reused)

These work today by borrowing another sprite. Dedicated art makes them
distinct. **After adding the PNG, update the tuning `sprite_key`** (notes in
the last column).

| File to create | Object | Footprint | Size | Looks like / tuning change |
|---|---|---|---|---|
| `drink_stand.png` | Drink Stand | 1×1 | 64×64 | A drinks kiosk (cups, a soda/juice dispenser, bright awning — distinct from the food stall). Then in `design/tuning/entities.md` set `drink_stand`'s `sprite_key` back to **`drink_stand`** (it's currently `food_stand`). |
| `restaurant.png` | Restaurant | 2×2 | 128×128 | A sit-down eatery — bigger than a stall: a small building with tables/umbrellas out front. Then set `restaurant`'s `sprite_key` to **`restaurant`** (currently `food_stand`). |
| `flamingo.png` | Flamingo | 1×1 (placeable) | 64×64 | A pink flamingo, long legs, curved neck. Then in `design/tuning/placeables.md` set `flamingo`'s `sprite_key` to **`flamingo`** (currently `parrot`). |
| `toucan.png` | Toucan | 1×1 (placeable) | 64×64 | A black toucan with a big orange beak. Set `toucan` `sprite_key` → **`toucan`** (currently `parrot`). |
| `peacock.png` | Peacock | 1×1 (placeable) | 64×64 | A peacock with a fanned blue-green tail. Set `peacock` `sprite_key` → **`peacock`** (currently `parrot`). |

## Priority 3 — nice-to-have

| File(s) | Object | Size | Notes |
|---|---|---|---|
| `visitor_child.png`, `visitor_family.png`, `visitor_enthusiast.png` | Guest archetypes | 32×32 | Today every guest uses `visitor.png` tinted by color (adult=neutral, child=orange, family=green, enthusiast=purple). Dedicated silhouettes (a small child, a family group, an enthusiast with a camera) would make the crowd readable. If added, I'll wire the renderer to pick per archetype. |
| `path.png` | Path tile | 64×64 | Optional — paths are currently drawn procedurally as a groomed sand surface and look fine. A seamless/tileable cobble or boardwalk texture could replace it; needs to tile cleanly edge-to-edge. |

---

## After you generate them

1. Drop the PNGs into `assets/sprites/` with the **exact filenames** above.
2. For the Priority-2 items, make the small `sprite_key` edits noted in the
   table (one word each in `design/tuning/entities.md` /
   `design/tuning/placeables.md`).
3. Commit the PNGs (and the `.png.import` files Godot generates next to them).
4. That's it — the game picks them up automatically; no code changes needed
   (except the optional archetype-visitor wiring, which I'll handle).

If anything's ambiguous, the single most useful style reference is
`assets/sprites/food_stand.png` — match its outline weight, saturation, and
¾-top-down angle and everything will sit together.
