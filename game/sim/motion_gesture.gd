class_name MotionGesture
extends RefCounted
## Turns phone motion into the player's rod input (owner request 2026-11-14;
## PRD P2 "gyro rod angle" brought forward). Pure and deterministic: the scene
## feeds samples, this returns what they mean. No nodes, no clock.
##
## Sample, per frame:
##   pitch       radians; grows as the top of the phone tips back towards the
##               player (from gravity: asin(z / g), the screen turning upwards)
##   pitch_rate  radians per second around the screen's horizontal axis,
##               positive while tipping back
##
## Result:
##   strike  a fast flick back (the strike in the wait, a hard pull in the fight)
##   pull    0..1, how far and how fast the rod is being pulled back now
##   jig     0..1, small repeated twitches: working the lure to tempt a fish
##
## Thresholds are design fills, tuned on the owner's phone later.

const STRIKE_RATE := 4.0          ## rad/s (about 230 deg/s) for a flick to count
const STRIKE_COOLDOWN_S := 0.6
const PULL_DEADZONE := 0.08       ## rad of tilt ignored around the rest pose
const PULL_FULL := 0.6            ## rad of tilt (about 35 deg) for a full pull
const PULL_RATE_SHARE := 0.5      ## how much tipping speed adds to the pull
const JIG_FULL_RATE := 2.0        ## rad/s mean twitch speed for a full jig
const JIG_SMOOTH_S := 0.6         ## time constant of the jig average
const REST_FOLLOW_S := 5.0        ## the rest pose follows slow drift forwards

var neutral := 0.0
var calibrated := false
var _cooldown := 0.0
var _jig_avg := 0.0


## The pose the player holds right now becomes the rest pose.
func calibrate(pitch: float) -> void:
	neutral = pitch
	calibrated = true
	_jig_avg = 0.0


func add_sample(dt: float, pitch_rate: float, pitch: float) -> Dictionary:
	if not calibrated:
		calibrate(pitch)
	dt = maxf(dt, 0.0)
	_cooldown = maxf(_cooldown - dt, 0.0)
	var strike := false
	if pitch_rate >= STRIKE_RATE and _cooldown <= 0.0:
		strike = true
		_cooldown = STRIKE_COOLDOWN_S
	var rel := pitch - neutral
	# A phone that settles further forward than the rest pose becomes the new
	# rest pose, so a tired arm does not leave a pull switched on.
	if rel < 0.0:
		neutral += rel * minf(dt / REST_FOLLOW_S, 1.0)
	var angle_pull := clampf((rel - PULL_DEADZONE) / (PULL_FULL - PULL_DEADZONE), 0.0, 1.0)
	var rate_pull := PULL_RATE_SHARE * clampf(pitch_rate / STRIKE_RATE, 0.0, 1.0)
	var pull := clampf(angle_pull + rate_pull, 0.0, 1.0)
	# Jig: average twitch speed below the strike threshold.
	var twitch := minf(absf(pitch_rate), STRIKE_RATE)
	_jig_avg += (twitch - _jig_avg) * minf(dt / JIG_SMOOTH_S, 1.0)
	var jig := clampf(_jig_avg / JIG_FULL_RATE, 0.0, 1.0)
	return {"strike": strike, "strike_speed": pitch_rate if strike else 0.0, "pull": pull, "jig": jig, "tilt": rel}
