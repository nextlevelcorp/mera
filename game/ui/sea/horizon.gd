class_name Horizon
extends RefCounted
## The skyline each place sees (owner, 2026-11-24: "start with the skylines,
## at sea and at the new places"). game/data/map/horizons.json holds, per
## position, the land's top by compass bearing (1 degree steps), whether it is
## town and how far it is, built by tools/map/build_horizons.py from Natural
## Earth's coast and Wikidata's peaks. The sky and sea shaders read it as a
## 360 x 1 texture (sea_sky.gdshaderinc, horizon_tex).

const FILE := "res://data/map/horizons.json"
const MAX_RAD := 0.12      ## the texture's red channel at 1 (HORIZON_MAX in the shader)
const FAR_KM := 60.0       ## the texture's blue channel at 1
const DIRS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

static var _profiles := {}


## The profile of a position: {elev_mrad, dist_km, urban}, 360 entries each by
## bearing; empty when the position has none.
static func profile(position_id: String) -> Dictionary:
	if _profiles.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if raw is Dictionary:
			_profiles = (raw as Dictionary).get("profiles", {})
	return _profiles.get(position_id, {})


## The land's top in radians at a compass bearing in degrees.
static func elevation(prof: Dictionary, bearing_deg: float) -> float:
	var e: Array = prof["elev_mrad"]
	return float(e[posmod(roundi(bearing_deg), 360)]) / 1000.0


## The compass bearing of a facing ("N" .. "NW"), in radians.
static func bearing(facing: String) -> float:
	return deg_to_rad(DIRS.find(facing) * 45.0)


## The texture the shaders sample: one pixel per degree of bearing.
static func image(prof: Dictionary) -> Image:
	var img := Image.create(360, 1, false, Image.FORMAT_RGB8)
	var e: Array = prof["elev_mrad"]
	var d: Array = prof["dist_km"]
	var u: Array = prof["urban"]
	for b in 360:
		img.set_pixel(b, 0, Color(clampf(float(e[b]) / 1000.0 / MAX_RAD, 0.0, 1.0), float(u[b]), clampf(float(d[b]) / FAR_KM, 0.0, 1.0)))
	return img
