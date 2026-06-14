extends Node
## Player settings, persisted to user://settings.json (roadmap 5.4).
##
## The Park Admin panel tunes the *game world*; this autoload owns the
## *player's* environment instead — volume, view, accessibility, telemetry
## consent — and, unlike anything before it, every value here survives a
## reload. On the web a tab refresh is every session, so "nothing the player
## sets persists" was the exact gap 5.4 closes.
##
## Engine-clean: pure presentation/preference state. It depends only on
## FileAccess + JSON, never on the simulation, so it loads first and a corrupt
## file degrades to defaults rather than bricking the game (5.7 resilience).

signal changed(key: StringName)

const PATH := "user://settings.json"

# DEFAULTS doubles as the schema. load_from_disk() only accepts keys present
# here and coerces each value to the default's type, so an unknown or
# malformed key in the file is ignored rather than fatal.
const DEFAULTS := {
	&"master_volume": 0.8,        # linear 0..1
	&"sfx_volume": 1.0,           # linear 0..1, under master
	&"ambient_volume": 1.0,       # linear 0..1, under master
	&"muted": false,
	&"view": "iso",               # "iso" | "top"
	&"game_speed": "1x",          # "1x" | "2x" | "4x" — restored at launch
	&"colorblind_mode": "off",    # off | deuteranopia | protanopia | tritanopia
	&"large_font": false,         # bumps the global minimum font size
	&"reduced_motion": false,     # damps cosmetic motion (cloud shadows, floats)
	&"telemetry_opt_in": false,   # off until the player explicitly consents
	&"telemetry_prompted": false, # so we ask exactly once
}

var _values: Dictionary = {}


func _ready() -> void:
	load_from_disk()


# --- Queries --------------------------------------------------------------

func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func get_bool(key: StringName) -> bool:
	return bool(get_value(key))


func get_float(key: StringName) -> float:
	return float(get_value(key))


func get_string(key: StringName) -> String:
	return String(get_value(key))


# --- Mutations ------------------------------------------------------------

# Sets a value (coerced to the schema type), persists, and emits `changed`.
# No-op when unchanged so listeners don't churn. Returns true if it wrote.
func set_value(key: StringName, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		push_warning("Settings.set_value: unknown key '%s'" % key)
		return false
	var coerced := _coerce(key, value)
	if _values.has(key) and _values[key] == coerced:
		return false
	_values[key] = coerced
	save_to_disk()
	changed.emit(key)
	return true


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	save_to_disk()
	changed.emit(&"")  # broad invalidation: listeners re-read everything


# --- Persistence ----------------------------------------------------------

# Start from defaults, then overlay only schema-known, type-coercible keys
# from the file. A missing, unreadable, or malformed file is not an error —
# the player simply gets defaults.
func load_from_disk() -> void:
	_values = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("Settings: could not read %s (error %d)" %
			[PATH, FileAccess.get_open_error()])
		return
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Settings: %s is not a JSON object — using defaults" % PATH)
		return
	for key in DEFAULTS.keys():
		var k := String(key)
		if parsed.has(k):
			_values[key] = _coerce(key, parsed[k])


func save_to_disk() -> bool:
	var out := {}
	for key in _values.keys():
		out[String(key)] = _values[key]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: could not write %s (error %d)" %
			[PATH, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(out, "\t"))
	return true


# Coerce a loaded/incoming value to the schema type. JSON gives us floats for
# all numbers and may hand us anything for a corrupt file; we never trust it.
func _coerce(key: StringName, value: Variant) -> Variant:
	var default: Variant = DEFAULTS[key]
	match typeof(default):
		TYPE_BOOL:
			return bool(value)
		TYPE_FLOAT:
			return clampf(float(value), 0.0, 1.0) if _is_unit(key) else float(value)
		TYPE_INT:
			return int(value)
		TYPE_STRING:
			return String(value)
		_:
			return value


# Volume-style keys are clamped to [0,1]; everything else floats freely.
func _is_unit(key: StringName) -> bool:
	return key in [&"master_volume", &"sfx_volume", &"ambient_volume"]
