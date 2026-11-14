class_name CueSynth
extends RefCounted
## Generated sound cues (docs/design_direction.md section 4: the bite and
## landing cues are generated, not recorded). Each cue is computed sample by
## sample from a formula with a fixed seed, so the build carries no audio file
## and no licence. Labelled as generated sound, never as a recording of a place.
##
##   nibble  soft short tick: something touched the lure
##   take    sharp dry click over a low thump: a committed take, strike now
##   landed  short warm two-note confirmation

const MIX_RATE := 22050


static func make(cue: String) -> AudioStreamWAV:
	match cue:
		"nibble":
			return _to_wav(_tick(0.035, 2600.0, 0.35, 11))
		"take":
			var click := _tick(0.025, 3800.0, 0.9, 23)
			var thump := _tone([140.0], 0.12, 0.7, 0.002, 0.10)
			return _to_wav(_mix(click, thump))
		"landed":
			var a := _tone([523.25, 1046.5], 0.22, 0.45, 0.01, 0.20)
			var b := _tone([659.25, 1318.5], 0.30, 0.45, 0.01, 0.28)
			return _to_wav(_mix(a, _delay(b, 0.12)))
	return _to_wav(PackedFloat32Array())


## Filtered noise burst with an exponential decay.
static func _tick(seconds: float, brightness_hz: float, gain: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := clampf(brightness_hz / MIX_RATE, 0.01, 0.99)
	var y := 0.0
	for i in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * gain * exp(-float(i) / (n * 0.22))
	return out


## Sum of sine partials (each half as loud as the one before) with an attack
## and an exponential release.
static func _tone(freqs: Array, seconds: float, gain: float, attack_s: float, release_s: float) -> PackedFloat32Array:
	var n := int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / attack_s, 1.0) * exp(-t / maxf(release_s * 0.35, 0.001))
		var v := 0.0
		var w := 1.0
		for f: float in freqs:
			v += sin(TAU * f * t) * w
			w *= 0.5
		out[i] = v * env * gain
	return out


static func _delay(a: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * MIX_RATE))
	out.append_array(a)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(a.size(), b.size()))
	for i in out.size():
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
