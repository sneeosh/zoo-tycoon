extends Node
## String catalog / i18n (roadmap 6.4).
##
## Strings are hardcoded all over the HUD today; retrofitting localization
## after launch is brutal, so we stand up the catalog *now* and ship EN-only.
## `I18n.t("key")` returns the template for the active locale; callers keep
## applying `%`/`.format()` themselves, so migrating a call site is a
## mechanical "wrap the literal in t()" with no behavior change.
##
## Catalog format: assets/i18n/strings.json = { "<locale>": { key: text } }.
## A JSON map (not a markdown table) because UI copy contains `=`, `|`, and
## newlines the tuning parser reserves. Missing keys fall back to the English
## entry, then to the key itself, so a gap shows up as a visible key, never a
## crash.
##
## Engine-clean: pure data + lookup, no engine surface.

const CATALOG_PATH := "res://assets/i18n/strings.json"
const FALLBACK_LOCALE := "en"

var _catalog: Dictionary = {}     # locale -> { key: text }
var _locale: String = "en"
var _missing: Dictionary = {}     # keys already warned about (debug, once each)


func _ready() -> void:
	_load_catalog()


func set_locale(locale: String) -> void:
	_locale = locale


func available_locales() -> Array:
	return _catalog.keys()


# Look up `key` in the active locale, then English, then return the key.
func t(key: String) -> String:
	var loc: Dictionary = _catalog.get(_locale, {})
	if loc.has(key):
		return String(loc[key])
	var fb: Dictionary = _catalog.get(FALLBACK_LOCALE, {})
	if fb.has(key):
		return String(fb[key])
	if OS.is_debug_build() and not _missing.has(key):
		_missing[key] = true
		push_warning("[i18n] missing string '%s'" % key)
	return key


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("[i18n] catalog missing at %s" % CATALOG_PATH)
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		push_error("[i18n] could not open %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_catalog = parsed
	else:
		push_error("[i18n] %s is not a JSON object" % CATALOG_PATH)
