class_name SessionConditions
extends RefCounted
## The conditions of a play session from the phone's local clock and calendar
## (pillar 1: real places at real times; docs/data_model.md section 7: wind
## comes from a date seed and a design-fill distribution per spot). Pure and
## deterministic: the same date and hour give the same wind for everyone.
## Slot hours and the wind distribution are design fills (Istanbul: NE
## "poyraz" and SW "lodos" prevail).

const WIND_WEIGHTS := {"N": 0.12, "NE": 0.26, "E": 0.05, "SE": 0.06, "S": 0.12, "SW": 0.25, "W": 0.06, "NW": 0.08}


## Time-of-day slot from the local hour: dawn 5-7, day 8-16, evening 17-19, night otherwise.
static func slot_for_hour(hour: int) -> String:
	if hour >= 5 and hour < 8:
		return "dawn"
	if hour >= 8 and hour < 17:
		return "day"
	if hour >= 17 and hour < 20:
		return "evening"
	return "night"


## datetime: Time.get_datetime_dict_from_system() (year, month, day, hour).
static func from_clock(datetime: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(datetime["year"]) * 1000000 + int(datetime["month"]) * 10000 + int(datetime["day"]) * 100 + int(datetime["hour"])
	var dir := _pick_direction(rng.randf())
	var speed := clampf(rng.randfn(3.5, 2.2), 0.5, 12.0)
	return {"slot": slot_for_hour(int(datetime["hour"])), "month": int(datetime["month"]), "wind_dir": dir, "wind_ms": snappedf(speed, 0.5)}


static func _pick_direction(u: float) -> String:
	var acc := 0.0
	for d: String in CatchModel.WIND_DIRECTIONS:
		acc += float(WIND_WEIGHTS[d])
		if u <= acc:
			return d
	return "NE"
