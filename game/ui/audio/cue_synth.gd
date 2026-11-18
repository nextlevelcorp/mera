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
## World layer (R13), made the same way, so no recording or licence is needed:
##   tram_bell   two bright strikes of a bell, as a tram warns walkers
##   ferry_horn  a long low two-tone horn
##   gull        a falling cry
##   step        a short low scuff of a shoe (step_stone is brighter)
##   traffic     a three-second rumble of distant traffic, looped

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
		"tram_bell":
			var ding := _tone([1318.5, 2637.0, 3520.0], 0.5, 0.35, 0.002, 0.45)
			return _to_wav(_mix(ding, _delay(ding, 0.28)))
		"ferry_horn":
			return _to_wav(_horn(1.8, [110.0, 138.6], 0.35))
		"gull":
			return _to_wav(_chirp(0.45, 2300.0, 1200.0, 0.25))
		"step":
			return _to_wav(_tick(0.06, 700.0, 0.5, 31))
		"step_stone":
			return _to_wav(_tick(0.05, 1500.0, 0.45, 37))
		"traffic":
			var wav := _to_wav(_rumble(3.0, 0.5, 41))
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(3.0 * MIX_RATE)
			return wav
	return _to_wav(PackedFloat32Array())


## A horn: rich partials (odd harmonics) with a slow swell and fade.
static func _horn(seconds: float, freqs: Array, gain: float) -> PackedFloat32Array:
	var n := int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.25, 1.0) * minf((seconds - t) / 0.4, 1.0)
		var v := 0.0
		for f: float in freqs:
			for h in [1.0, 3.0, 5.0]:
				v += sin(TAU * f * h * t) / h
		out[i] = v * env * gain * 0.4
	return out


## A falling cry: the pitch slides down, with a quick tremolo.
static func _chirp(seconds: float, f_start: float, f_end: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var s := t / seconds
		phase += TAU * lerpf(f_start, f_end, s * s) / MIX_RATE
		var env := minf(t / 0.02, 1.0) * (1.0 - s) * (0.6 + 0.4 * sin(TAU * 18.0 * t))
		out[i] = (sin(phase) + 0.3 * sin(2.0 * phase)) * env * gain
	return out


## Low rumble: brown noise, faded into its own start over the last 0.3 s so
## the loop has no seam.
static func _rumble(seconds: float, gain: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(seconds * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y = clampf(y * 0.995 + rng.randf_range(-1.0, 1.0) * 0.06, -1.0, 1.0)
		out[i] = y * gain
	var fade := int(0.3 * MIX_RATE)
	for i in fade:
		var k := float(i) / fade
		out[n - fade + i] = lerpf(out[n - fade + i], out[i], k)
	return out


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
