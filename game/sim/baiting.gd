class_name Baiting
extends RefCounted
## Baiting the hook by hand (roadmap R20, owner decision D9): a short
## hand-skill task whenever the rig or the bait changes or the bait is gone.
## Each kind of bait has its own two or three steps; in each a needle swings
## across a bar and the player taps when it is inside the step's zone. The
## accuracy of the taps gives the baiting quality 0..1, which the session uses:
## a well-baited hook holds on the cast and against a nibbling fish and looks
## natural (CatchModel attraction), a live fish tires more slowly. Pure.

const ZONES: Array[float] = [0.5, 0.3, 0.7]

## Steps per kind: [step key, zone half-width (share of the bar), needle speed (bar sweeps per second)].
const STEPS := {
	"live": [["BAIT_STEP_LIVE_HOLD", 0.22, 0.9], ["BAIT_STEP_LIVE_SPOT", 0.12, 1.1], ["BAIT_STEP_LIVE_HOOK", 0.1, 1.4]],
	"shrimp": [["BAIT_STEP_SHRIMP_PEEL", 0.22, 0.9], ["BAIT_STEP_SHRIMP_THREAD", 0.15, 1.1], ["BAIT_STEP_SHRIMP_HIDE", 0.1, 1.3]],
	"soft_plastic": [["BAIT_STEP_SOFT_LINE_UP", 0.18, 1.0], ["BAIT_STEP_SOFT_THREAD", 0.13, 1.2], ["BAIT_STEP_SOFT_STRAIGHT", 0.1, 1.2]],
	"minnow": [["BAIT_STEP_SNAP_OPEN", 0.2, 1.0], ["BAIT_STEP_SNAP_CLIP", 0.11, 1.3]],
	"sabiki": [["BAIT_STEP_SABIKI_UNWIND", 0.18, 1.0], ["BAIT_STEP_SABIKI_WEIGHT", 0.13, 1.2]],
}


## The kind of baiting a lure-shaped record needs.
static func kind_of(lure: Dictionary, bait_record: Dictionary = {}) -> String:
	if Presentation.is_float(lure):
		return "live" if bait_record.has("from_species") else "shrimp"
	var t := String(lure.get("type", ""))
	if t == "sabiki":
		return "sabiki"
	if t == "soft_plastic":
		return "soft_plastic"
	return "minnow"


static func steps(kind: String) -> Array:
	return STEPS.get(kind, STEPS["minnow"])


## Where the needle is (0..1) t seconds into a step at this speed: it sweeps
## from the left edge to the right and back.
static func needle(t: float, speed: float) -> float:
	var s := fmod(maxf(t, 0.0) * speed, 2.0)
	return s if s <= 1.0 else 2.0 - s


static func zone_centre(step_index: int) -> float:
	return ZONES[step_index % ZONES.size()]


## 1 at the zone's centre, falling to 0 at its edge and beyond.
static func accuracy(x: float, centre: float, half_width: float) -> float:
	return clampf(1.0 - absf(x - centre) / maxf(half_width, 0.001), 0.0, 1.0)


## The baiting quality from the taps' accuracies.
static func quality(accuracies: Array) -> float:
	if accuracies.is_empty():
		return 0.0
	var total := 0.0
	for a: float in accuracies:
		total += a
	return total / accuracies.size()


## The word the result shows: good, fair or poor.
static func rating_key(q: float) -> String:
	if q >= 0.75:
		return "BAIT_RESULT_GOOD"
	if q >= 0.4:
		return "BAIT_RESULT_FAIR"
	return "BAIT_RESULT_POOR"
