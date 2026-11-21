class_name CastMotion
extends RefCounted
## The rod's swing during a cast, as a damped spring (pillar 3: springs and
## oscillation). While the Cast button is held the rod is drawn back over the
## shoulder as power rises; on release it snaps forward, overshoots and
## settles. Also the line paid out from the spool during the flight, and the
## thumb aim. Visual and input mapping only: the cast distance comes from
## CatchModel.cast. Deterministic, no nodes.

const WINDUP_MAX := 1.3        ## rad the rod swings back at full power
const WINDUP_STIFFNESS := 60.0
const SETTLE_STIFFNESS := 90.0
const DAMPING := 0.32          ## share of critical damping
const SNAP_SPEED := 9.0        ## rad/s forward at release, plus power share
const SNAP_POWER := 10.0
const AIM_MAX := 0.5           ## rad of aim either side (about 29 degrees; R19)
const AIM_SPAN := 0.3          ## share of screen width for a full aim swipe

## Rod swing relative to its rest pose: positive is back, negative forward.
var angle := 0.0
var velocity := 0.0


## While the button is held: the rod follows the power swing back.
func charge(dt: float, power: float) -> void:
	_spring(dt, WINDUP_MAX * clampf(power, 0.0, 1.0), WINDUP_STIFFNESS)


## The release: a forward snap whose speed grows with power.
func release(power: float) -> void:
	velocity = -(SNAP_SPEED + SNAP_POWER * clampf(power, 0.0, 1.0))


## After release, and at rest: the rod springs back to its rest pose.
func settle(dt: float) -> void:
	_spring(dt, 0.0, SETTLE_STIFFNESS)


## Line off the spool during the flight: fast at first, slowing as the lure
## drops (ease-out); all of it is out when the lure lands.
static func paid_out(flight_s: float, flight_total_s: float, cast_m: float) -> float:
	var s := clampf(flight_s / maxf(flight_total_s, 0.001), 0.0, 1.0)
	return cast_m * (1.0 - (1.0 - s) * (1.0 - s))


## Thumb travel while holding Cast (pixels, right is positive) to an aim
## angle in radians, clamped to AIM_MAX either side.
static func aim_from_drag(dx: float, screen_width: float) -> float:
	return clampf(dx / maxf(screen_width * AIM_SPAN, 1.0), -1.0, 1.0) * AIM_MAX


## Where the aim gauge sits, under the left thumb (owner, 2026-11-21: "on the
## left, not in the middle, so the thumb can use it"), in design pixels.
const GAUGE_CENTRE_X := 250.0
const GAUGE_HALF_W := 130.0


## Aim from the left thumb on the gauge: its centre is straight out, its ends
## AIM_MAX to either side; beyond the ends the aim stays at the end.
static func aim_from_gauge(x: float) -> float:
	return clampf((x - GAUGE_CENTRE_X) / GAUGE_HALF_W, -1.0, 1.0) * AIM_MAX


func _spring(dt: float, target: float, k: float) -> void:
	var steps := clampi(ceili(maxf(dt, 0.0) / 0.005), 1, 40)
	var h := minf(dt, 0.2) / steps
	var c := 2.0 * sqrt(k) * DAMPING
	for _i in steps:
		velocity += ((target - angle) * k - velocity * c) * h
		angle += velocity * h
