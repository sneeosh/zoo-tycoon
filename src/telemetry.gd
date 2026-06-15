extends Node
## Opt-in telemetry (roadmap 5.3).
##
## Three exit criteria across Phases 1/3 are unmeasurable without a funnel:
## session length, day reached, win/lose, drop-off step. This records exactly
## those — but only after the player explicitly opts in (`Settings`), and
## with a plain-language privacy notice (PRIVACY_NOTICE) shown at the consent
## prompt.
##
## Where does the data go? The "decide a destination" blocker from 2.4 is
## resolved the privacy-first way: **local only**. Events append to a
## newline-delimited JSON file under user:// and mirror to the console. No
## network egress — there is no HTTP client here on purpose. A future hosted
## sink can read these files or subscribe to `event_recorded`; until that
## decision is made, nothing leaves the device, so opting in can never be a
## privacy regression.

signal event_recorded(event: StringName, props: Dictionary)

const PATH := "user://telemetry/events.jsonl"

const PRIVACY_NOTICE := \
	"Help improve the game? With your permission we record anonymous play " + \
	"events — session length, how far you get, wins and losses, and where " + \
	"new players stop. No names, no accounts, no tracking across sites. " + \
	"Data stays on this device unless you choose to share it, and you can " + \
	"turn it off any time in Settings."

var _session_id: String = ""
var _session_start_msec: int = 0
var _started: bool = false


func _ready() -> void:
	_session_id = _new_session_id()
	_session_start_msec = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://telemetry/"))
	# Day rollover is the cheapest honest "day reached" signal; the rest of
	# the funnel (tutorial steps, win/lose) is reported explicitly by the HUD.
	EventBus.day_ended.connect(_on_day_ended)


func is_enabled() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and s.get_bool(&"telemetry_opt_in")


# The single entry point. No-op unless the player opted in, so callers can
# instrument freely without gating each call site on consent.
func track(event: StringName, props: Dictionary = {}) -> void:
	if not is_enabled():
		return
	if not _started:
		_started = true
		_write({"event": "session_start", "session": _session_id})
	var record := props.duplicate(true)
	record["event"] = String(event)
	record["session"] = _session_id
	record["t_ms"] = Time.get_ticks_msec() - _session_start_msec
	_write(record)
	event_recorded.emit(event, record)


# Convenience for the session-length metric: call when a run resolves.
func track_session_length(reason: String) -> void:
	track(&"session_end", {
		"reason": reason,
		"length_ms": Time.get_ticks_msec() - _session_start_msec,
	})


func _on_day_ended(day: int) -> void:
	track(&"day_reached", {"day": day + 1})


func _write(record: Dictionary) -> void:
	record["wall"] = Time.get_datetime_string_from_system(true)
	var line := JSON.stringify(record)
	print("[telemetry] ", line)
	# Append; a failed open must never interrupt play.
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) \
		else FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)


func _new_session_id() -> String:
	# Not a fingerprint — a per-run random tag so events from one session group
	# together. Reset every launch; nothing identifies the player or device.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]
