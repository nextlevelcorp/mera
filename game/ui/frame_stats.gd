class_name FrameStats
extends RefCounted
## Rolling frame-time statistics for the performance budget
## (docs/design_direction.md): average fps and the fps of the worst 1% of
## frames over the last `window_s` seconds.

var window_s: float
var _deltas: Array[float] = []
var _total := 0.0


func _init(window_seconds: float = 60.0) -> void:
	window_s = window_seconds


func add(delta: float) -> void:
	if delta <= 0.0:
		return
	_deltas.append(delta)
	_total += delta
	while _total > window_s and _deltas.size() > 1:
		_total -= _deltas.pop_front()


func reset() -> void:
	_deltas.clear()
	_total = 0.0


func seconds() -> float:
	return _total


func frames() -> int:
	return _deltas.size()


func average_fps() -> float:
	return _deltas.size() / _total if _total > 0.0 else 0.0


## fps of the slowest 1% of frames (at least one frame).
func low_1pct_fps() -> float:
	if _deltas.is_empty():
		return 0.0
	var sorted := _deltas.duplicate()
	sorted.sort()
	var count: int = maxi(1, int(ceil(sorted.size() * 0.01)))
	var sum := 0.0
	for i in count:
		sum += sorted[sorted.size() - 1 - i]
	return count / sum
