class_name WorldWalk
extends RefCounted
## The player walking in a WorldArea (architecture.md 4): 8-direction-or-analog
## movement at a fixed walking speed, sliding along blocked ground, and the
## nearest fishing marker within reach. Pure and deterministic: input is a
## stick vector, time is the step. Speeds are design fills (constants.json).

var area: WorldArea
var pos: Vector2
var facing := Vector2.DOWN

var _speed: float
var _radius: float
var _reach: float


func _init(world_area: WorldArea, constants: Dictionary) -> void:
	area = world_area
	pos = area.start_m
	_speed = float(constants["WALK_M_PER_S"])
	_radius = float(constants["WALK_RADIUS_M"])
	_reach = float(constants["INTERACT_M"])


## Moves for dt seconds with the stick (length 0..1; longer is clamped).
func step(dt: float, stick: Vector2) -> void:
	var v := stick.limit_length(1.0)
	if v.length() < 0.05:
		return
	facing = v.normalized()
	var move := v * _speed * clampf(dt, 0.0, 0.1)
	# Each axis on its own, so a wall slides instead of stopping.
	var tx := pos + Vector2(move.x, 0.0)
	if not area.blocked_at(tx, _radius):
		pos = tx
	var ty := pos + Vector2(0.0, move.y)
	if not area.blocked_at(ty, _radius):
		pos = ty


## The marker within reach, nearest first, or an empty dictionary.
func nearest_marker() -> Dictionary:
	var best := {}
	var best_d := _reach
	for m: Dictionary in area.markers:
		var d := pos.distance_to(m["pos"])
		if d <= best_d:
			best_d = d
			best = m
	return best


func teleport(p: Vector2) -> void:
	pos = p
