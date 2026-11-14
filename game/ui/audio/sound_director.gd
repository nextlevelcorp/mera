class_name SoundDirector
extends Node
## Plays the recorded sounds of the slice (CC0 files in res://audio, listed in
## docs/reference_docs.md) and follows the simulation:
##   wind loop     volume from the wind speed
##   waves         single waves at random, more often and louder with chop
##   gusts         now and then when the wind is 5 m/s or more
##   reel loop     line coming in: slower with less effort
##   drag clicker  line going out against the drag: faster and louder with speed
##   rod creak     tension above 75 % of the line's strength, now and then
##   one-shots     cast swish, lure landing, splashes, line zip on a fast run
## Visual only in the sense of pillar 4: calm sounds while waiting, the reel
## takes over in the fight. The browser starts audio after the first tap.

const AUDIO_DIR := "res://audio"
const WAVES: Array[String] = ["wave_01", "wave_02", "wave_03", "wave_04"]
const ONE_SHOTS: Array[String] = ["lure_drop", "splash", "splash_heavy", "wind_gust", "cast_swish", "rod_creak", "line_zip"]
const CREAK_SHARE := 0.75
const ZIP_SPEED_M_S := 1.2

var _wind: AudioStreamPlayer
var _reel: AudioStreamPlayer
var _drag: AudioStreamPlayer
var _drag_target_db := -80.0
var _drag_target_pitch := 1.0
var _creak_clock := 0.0
var _zip_clock := 0.0
var _waves: Array[AudioStreamPlayer] = []
var _shots := {}
var _rng := RandomNumberGenerator.new()
var _wind_ms := 3.0
var _chop := 0.3
var _wave_clock := 1.0
var _gust_clock := 8.0
var _reel_target_db := -80.0
var _reel_target_pitch := 1.0


func _ready() -> void:
	_rng.seed = 11
	_wind = _player(_load("wind_loop"), true)
	_reel = _player(_load("reel_loop"), true)
	_reel.volume_db = -80.0
	_drag = _player(_load("drag_click"), true)
	_drag.volume_db = -80.0
	for w: String in WAVES:
		_waves.append(_player(_load(w), false))
	for s: String in ONE_SHOTS:
		_shots[s] = _player(_load(s), false)
	_wind.play()
	set_conditions(_wind_ms, _chop)


func set_conditions(wind_ms: float, chop: float) -> void:
	_wind_ms = wind_ms
	_chop = clampf(chop, 0.0, 1.0)
	if _wind:
		_wind.volume_db = linear_to_db(clampf(0.08 + wind_ms / 12.0, 0.05, 0.9))


## line_rate_m_s: positive while line goes out, negative while it comes in;
## 0 or fight over silences the reel.
func set_reel(line_rate_m_s: float, active: bool) -> void:
	_reel_target_db = -80.0
	_drag_target_db = -80.0
	if not active or absf(line_rate_m_s) < 0.02:
		return
	if line_rate_m_s > 0.0:
		# Line going out: the drag clicks, faster as the fish takes line faster.
		_drag_target_db = linear_to_db(clampf(0.35 + line_rate_m_s * 0.35, 0.3, 1.0))
		_drag_target_pitch = clampf(0.9 + line_rate_m_s * 0.35, 0.9, 2.0)
		if line_rate_m_s >= ZIP_SPEED_M_S and _zip_clock <= 0.0:
			_zip_clock = 2.5
			play("line_zip", linear_to_db(0.6))
	else:
		_reel_target_db = linear_to_db(clampf(0.2 + -line_rate_m_s * 0.25, 0.15, 0.6))
		_reel_target_pitch = clampf(0.75 + -line_rate_m_s * 0.1, 0.75, 1.0)


## tension_ratio: tension over line strength. The rod creaks when it is high.
func set_tension(tension_ratio: float) -> void:
	if tension_ratio >= CREAK_SHARE and _creak_clock <= 0.0:
		_creak_clock = _rng.randf_range(1.6, 3.0)
		play("rod_creak", linear_to_db(clampf((tension_ratio - 0.5) * 1.6, 0.3, 0.9)))


func play(name_id: String, volume_db: float = 0.0) -> void:
	var p: AudioStreamPlayer = _shots.get(name_id)
	if p and p.is_inside_tree():
		p.volume_db = volume_db
		p.pitch_scale = _rng.randf_range(0.92, 1.08)
		p.play()


func _process(delta: float) -> void:
	_wave_clock -= delta
	if _wave_clock <= 0.0:
		_wave_clock = lerpf(4.5, 1.2, _chop) * _rng.randf_range(0.6, 1.4)
		var p: AudioStreamPlayer = _waves[_rng.randi_range(0, _waves.size() - 1)]
		p.volume_db = linear_to_db(clampf(0.25 + 0.6 * _chop, 0.2, 0.9))
		p.pitch_scale = _rng.randf_range(0.9, 1.1)
		p.play()
	_gust_clock -= delta
	if _gust_clock <= 0.0:
		_gust_clock = _rng.randf_range(9.0, 20.0)
		if _wind_ms >= 5.0:
			play("wind_gust", linear_to_db(clampf(_wind_ms / 12.0, 0.3, 0.9)))
	_creak_clock -= delta
	_zip_clock -= delta
	# Ease the reel towards its target so the sound follows the line smoothly.
	var k := minf(delta * 8.0, 1.0)
	_drag.volume_db = lerpf(_drag.volume_db, _drag_target_db, k)
	_drag.pitch_scale = lerpf(_drag.pitch_scale, _drag_target_pitch, k)
	if _drag.volume_db > -60.0 and not _drag.playing:
		_drag.play()
	elif _drag.volume_db <= -70.0 and _drag.playing:
		_drag.stop()
	_reel.volume_db = lerpf(_reel.volume_db, _reel_target_db, k)
	_reel.pitch_scale = lerpf(_reel.pitch_scale, _reel_target_pitch, k)
	if _reel.volume_db > -60.0 and not _reel.playing:
		_reel.play()
	elif _reel.volume_db <= -70.0 and _reel.playing:
		_reel.stop()


func _load(name_id: String) -> AudioStream:
	var path := "%s/%s.ogg" % [AUDIO_DIR, name_id]
	if not ResourceLoader.exists(path):
		push_warning("Missing sound %s" % path)
		return null
	return load(path)


func _player(stream: AudioStream, looping: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if stream is AudioStreamOggVorbis and looping:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	p.stream = stream
	add_child(p)
	return p
