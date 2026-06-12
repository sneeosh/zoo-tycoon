extends Node
class_name ZooAudio
# Zoo-side audio (roadmap 2.1): SFX wired to engine/zoo signals, one ambient
# park loop, and a master volume. Sound is presentation — like the renderers
# it lives entirely in game code; the engine needs no audio surface for this.
# (The roadmap flagged 2.1 as a "likely engine seam"; it isn't — nothing here
# touches engine internals, it only listens to the same signals the HUD does.)
#
# Assets are synthesized at BUILD time by tools/generate_audio.py and
# committed (CLAUDE.md §5 / engine web-perf discipline: no runtime asset
# generation). Each SFX is a short, soft chime; everything is throttled so a
# 4× day with 50 guests reads as a gentle till-bell, not a slot machine.

const AUDIO_DIR := "res://assets/audio/"
const SOUNDS: Array[StringName] = [&"purchase", &"place", &"verdict_happy",
	&"verdict_unhappy", &"day_chime", &"alert", &"birth", &"win", &"lose"]
# Per-sound minimum interval, seconds. Money events fire constantly at 4×.
const THROTTLE := {
	&"purchase": 0.20,
	&"place": 0.10,
	&"verdict_happy": 0.35,
	&"verdict_unhappy": 0.35,
}
const DEFAULT_THROTTLE := 0.08

var muted: bool = false
var master_volume: float = 0.8   # linear 0..1, applied to the Master bus

var _players: Dictionary = {}      # StringName -> AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _last_played: Dictionary = {}  # StringName -> msec


func _ready() -> void:
	for sound_name in SOUNDS:
		var stream := _load_stream(sound_name)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		add_child(p)
		_players[sound_name] = p
	# Ambient park loop — forced looping at runtime so the import settings
	# can stay default.
	var amb := _load_stream(&"ambient_park")
	if amb is AudioStreamWAV:
		amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
		amb.loop_begin = 0
		amb.loop_end = amb.data.size() / 2   # 16-bit mono: 2 bytes per frame
	if amb != null:
		_ambient = AudioStreamPlayer.new()
		_ambient.stream = amb
		_ambient.volume_db = -10.0   # a bed, not a presence
		add_child(_ambient)
		_ambient.play()
	_apply_volume()

	# SFX wiring — the same signals the HUD narrates from.
	ZooBootstrap.money_floated.connect(func(_amt, _pos): play(&"purchase"))
	ZooBootstrap.guest_departed.connect(func(verdict: int, _pos):
		if verdict > 0:
			play(&"verdict_happy")
		elif verdict < 0:
			play(&"verdict_unhappy"))
	EventBus.day_settled.connect(func(_d, _i, _e): play(&"day_chime"))
	EventBus.entity_placed.connect(func(_id): play(&"place"))
	ZooBootstrap.animal_welfare_alert.connect(func(_rid, _idx, kind: String, _n):
		if kind == "sick" or kind == "died":
			play(&"alert"))
	ZooBootstrap.animal_born.connect(func(_rid, _sp, _n, _rare): play(&"birth"))


func play(sound_name: StringName) -> void:
	if muted:
		return
	var p: AudioStreamPlayer = _players.get(sound_name)
	if p == null:
		return
	var now := Time.get_ticks_msec()
	var min_gap: float = THROTTLE.get(sound_name, DEFAULT_THROTTLE)
	if now - int(_last_played.get(sound_name, -10000)) < int(min_gap * 1000.0):
		return
	_last_played[sound_name] = now
	p.play()


func set_muted(m: bool) -> void:
	muted = m
	if _ambient != null:
		_ambient.stream_paused = m
	_apply_volume()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, muted or master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


func _load_stream(sound_name: StringName) -> AudioStream:
	var path := "%s%s.wav" % [AUDIO_DIR, sound_name]
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res if res is AudioStream else null
