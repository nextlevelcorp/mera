class_name BoatDrift
extends RefCounted
## Fishing from a drifting boat (roadmap R23, owner decision D7 and
## 2026-11-23: "drift first, simple and realistic"). The boat drifts
## downwind at a speed that grows with the wind (BOAT_DRIFT_PER_WIND, capped
## at BOAT_DRIFT_MAX_MS), so the water under it changes as it goes out along
## the boat position's depth profile. A lure is dropped straight down
## (BOAT_DROP_M from the hull); the drift pulls the line aslant, so a sinker
## settles where its own sink rate and the drift balance: the deepest it can
## reach is the line's length times cos(atan(drift / sink)). Drifting covers
## ground and passes more fish: interest rises with drift up to
## BOAT_DRIFT_GAIN at BOAT_DRIFT_REF_MS. All constants are design fills. Pure.


static func is_boat(position: Dictionary) -> bool:
	return String(position.get("stage", "")) == "boat"


## Drift speed in m/s for a wind in m/s.
static func drift_ms(k: Dictionary, wind_ms: float) -> float:
	return clampf(float(k["BOAT_DRIFT_PER_WIND"]) * wind_ms, 0.0, float(k["BOAT_DRIFT_MAX_MS"]))


## How much of the line hangs down (1 straight down, less as the drift drags it).
static func line_cos(drift: float, sink_m_per_s: float) -> float:
	if drift <= 0.0:
		return 1.0
	return cos(atan(drift / maxf(sink_m_per_s, 0.01)))


## The interest multiplier for the ground the drift covers.
static func ground_gain(k: Dictionary, drift: float) -> float:
	return 1.0 + float(k["BOAT_DRIFT_GAIN"]) * clampf(drift / float(k["BOAT_DRIFT_REF_MS"]), 0.0, 1.0)
