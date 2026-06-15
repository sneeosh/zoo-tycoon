extends RefCounted
class_name Palette
## Colorblind-aware semantic colors (roadmap 5.5 accessibility).
##
## Rather than *simulate* a deficiency, we pick a palette whose hues stay
## distinguishable under the common deficiencies, and pair every color with a
## glyph elsewhere in the UI (✚ sick flag, ✓/✗ axis marks) so meaning never
## rides on color alone. The mode is a player setting persisted in `Settings`.
##
## Pure static helper — no engine surface, no node. Callers ask for a semantic
## role ("good", "warn", "bad", "info") and get a Color for the active mode.

# Default (full-color) roles. Greens-vs-reds, the classic tycoon palette.
const _DEFAULT := {
	"good": Color("#83c779"),
	"warn": Color("#f4d35e"),
	"bad":  Color("#e76f51"),
	"info": Color("#5aa9e6"),
	"mute": Color("#97a387"),
}

# Deuteranopia/protanopia (red-green): lean on blue↔orange↔yellow, which stay
# separable. "good" shifts to a teal-blue, "bad" to a strong orange.
const _RG := {
	"good": Color("#3a9bd5"),  # blue reads as "fine"
	"warn": Color("#f0c419"),  # high-chroma yellow
	"bad":  Color("#e8702a"),  # orange, distinct from yellow by lightness
	"info": Color("#9b8bd6"),
	"mute": Color("#9aa39a"),
}

# Tritanopia (blue-yellow): avoid the blue↔yellow confusion; use green↔magenta.
const _BY := {
	"good": Color("#4caf6e"),
	"warn": Color("#d98ccf"),
	"bad":  Color("#d1495b"),
	"info": Color("#11999e"),
	"mute": Color("#9aa39a"),
}


static func _table() -> Dictionary:
	var mode := "off"
	# Settings is an autoload; guard so the helper is usable in isolation/tests.
	var s := Engine.get_main_loop()
	if s is SceneTree and (s as SceneTree).root.has_node("Settings"):
		mode = (s as SceneTree).root.get_node("Settings").get_string(&"colorblind_mode")
	match mode:
		"deuteranopia", "protanopia":
			return _RG
		"tritanopia":
			return _BY
		_:
			return _DEFAULT


static func role(name: String) -> Color:
	return _table().get(name, _DEFAULT.get(name, Color.WHITE))


# Welfare / happiness 0..1 → good/warn/bad, colorblind-aware. Mirrors the
# thresholds main.gd's _happiness_color used before this helper existed.
static func welfare(value: float) -> Color:
	if value >= 0.66:
		return role("good")
	if value >= 0.4:
		return role("warn")
	return role("bad")
