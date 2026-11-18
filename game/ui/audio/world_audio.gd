class_name WorldAudio
extends Node
## The sound of the top-down world (roadmap R13): the place heard from where
## the player stands. Beds on the Ambience bus: the sea (louder near the
## water, the same CC0 wave recordings as the fishing view), the wind (from
## the conditions, the same loop) and the city (a generated traffic rumble,
## louder near the road, quieter at night). Events on the Effects bus: the
## tram's bell as it comes near, a ferry's horn as it passes under the
## bridge, gull cries over the water, and footsteps that follow the walk
## (brighter on cobbles). The world screen feeds it each frame; it holds no
## rule. Fades in and out when the view changes, so the sea carries on into
## the fishing view, whose own beds take over.

const FADE_S := 0.6
const CITY_BY_SLOT := {"dawn": 0.5, "day": 1.0, "evening": 0.85, "night": 0.35}
const BELL_NEAR_M := 14.0
const BELL_GAP_S := 9.0
const HORN_NEAR_M := 10.0
const HORN_GAP_S := 30.0

var _sea: Array[AudioStreamPlayer] = []
var _wind: AudioStreamPlayer
var _city: AudioStreamPlayer
var _fx := {}
var _rng := RandomNumberGenerator.new()
var _fade := 0.0
var _fade_to := 1.0
var _wave_clock := 1.0
var _gull_clock := 5.0
var _bell_clock := 0.0
var _horn_clock := 10.0
var levels := {"sea": 0.0, "wind": 0.0, "city": 0.0}


func _ready() -> void:
	# Keeps fading while the world sleeps behind the fishing view.
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBuses.ensure()
	_rng.seed = 13
	for w: String in SoundDirector.WAVES:
		_sea.append(_player(load("%s/%s.ogg" % [SoundDirector.AUDIO_DIR, w]), AudioBuses.AMBIENCE))
	var wind: AudioStream = (load("%s/wind_loop.ogg" % SoundDirector.AUDIO_DIR) as AudioStreamOggVorbis).duplicate()
	(wind as AudioStreamOggVorbis).loop = true
	_wind = _player(wind, AudioBuses.AMBIENCE)
	_city = _player(CueSynth.make("traffic"), AudioBuses.AMBIENCE)
	for cue: String in ["tram_bell", "ferry_horn", "gull", "step", "step_stone"]:
		_fx[cue] = _player(CueSynth.make(cue), AudioBuses.EFFECTS)
	_wind.volume_db = -80.0
	_city.volume_db = -80.0
	_wind.play()
	_city.play()


## How loud each bed is at pos (0..1): the sea by the distance to open
## water, the city by the distance to the road and the time of day, the wind
## from its speed. Pure, for the tests.
static func bed_levels(pos: Vector2, area: WorldArea, slot: String, wind_ms: float) -> Dictionary:
	var to_water := INF
	var to_road := INF
	for r: Dictionary in area.rects:
		var d := _distance(pos, r["rect"])
		if r["kind"] == "water":
			to_water = minf(to_water, d)
		elif r["kind"] == "road":
			to_road = minf(to_road, d)
	return {
		"sea": clampf(1.0 - to_water / 14.0, 0.12, 1.0),
		"city": clampf(1.0 - to_road / 22.0, 0.15, 1.0) * float(CITY_BY_SLOT.get(slot, 1.0)),
		"wind": clampf(0.08 + wind_ms / 12.0, 0.05, 0.9),
	}


## The step sound for the ground at pos: cobbles ring brighter than paving.
static func step_sound(pos: Vector2, area: WorldArea) -> String:
	for r: Dictionary in area.rects:
		if r["kind"] == "plaza" and (r["rect"] as Rect2).has_point(pos):
			return "step_stone"
	return "step"


## A tram is near enough to ring when its nearer end is this close in y.
static func tram_near(tram: Dictionary, pos: Vector2) -> bool:
	var front := float(tram["y"])
	var back := front - float(tram["dir"]) * Crowd.TRAM_LENGTH_M
	return minf(absf(front - pos.y), absf(back - pos.y)) < BELL_NEAR_M or (pos.y - front) * (pos.y - back) < 0.0


static func _distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


## Called each frame by the world screen.
func update(delta: float, pos: Vector2, area: WorldArea, conditions: Dictionary, time_s: float, k: Dictionary) -> void:
	levels = bed_levels(pos, area, String(conditions.get("slot", "day")), float(conditions.get("wind_ms", 3.0)))
	var gain := _fade
	_wave_clock -= delta
	if _wave_clock <= 0.0:
		_wave_clock = _rng.randf_range(2.0, 4.5)
		var p: AudioStreamPlayer = _sea[_rng.randi_range(0, _sea.size() - 1)]
		p.volume_db = linear_to_db(maxf(levels["sea"] * 0.7 * gain, 0.0001))
		p.pitch_scale = _rng.randf_range(0.9, 1.1)
		p.play()
	_gull_clock -= delta
	if _gull_clock <= 0.0:
		_gull_clock = _rng.randf_range(6.0, 14.0)
		_shot("gull", levels["sea"] * 0.5 * gain, _rng.randf_range(0.85, 1.15))
	_bell_clock -= delta
	if _bell_clock <= 0.0:
		for t: Dictionary in Crowd.trams(area, time_s, k):
			if tram_near(t, pos):
				_bell_clock = BELL_GAP_S
				_shot("tram_bell", 0.6 * gain, 1.0)
				break
	_horn_clock -= delta
	if _horn_clock <= 0.0:
		for f: Dictionary in Crowd.ferries(area, time_s, k):
			if absf(float(f["x"]) - area.size_m.x * 0.5) < HORN_NEAR_M:
				_horn_clock = HORN_GAP_S
				_shot("ferry_horn", clampf(1.0 - absf(float(f["y"]) - pos.y) / 60.0, 0.2, 0.8) * gain, 1.0)
				break


func _process(delta: float) -> void:
	_fade = move_toward(_fade, _fade_to, delta / FADE_S)
	if _wind:
		_wind.volume_db = linear_to_db(maxf(float(levels["wind"]) * _fade, 0.0001))
		_city.volume_db = linear_to_db(maxf(float(levels["city"]) * 0.55 * _fade, 0.0001))
		_wind.stream_paused = _fade <= 0.0
		_city.stream_paused = _fade <= 0.0


## A footstep on the ground at pos.
func step(pos: Vector2, area: WorldArea) -> void:
	_shot(step_sound(pos, area), 0.35 * _fade, _rng.randf_range(0.9, 1.1))


func fade_out() -> void:
	_fade_to = 0.0


func fade_in() -> void:
	_fade_to = 1.0


func _shot(cue: String, linear: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _fx.get(cue)
	if p and p.is_inside_tree() and linear > 0.01:
		p.volume_db = linear_to_db(linear)
		p.pitch_scale = pitch
		p.play()


func _player(stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	add_child(p)
	return p
