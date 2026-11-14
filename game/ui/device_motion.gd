class_name DeviceMotion
extends Node
## Reads the phone's motion sensors for MotionGesture. On the web build it
## listens to the browser's devicemotion event through JavaScriptBridge (part
## of Godot, no extra library); iPhone Safari only sends the event after the
## player allows it, which must be asked from a tap (request_permission). On
## native builds it reads Input's gravity and gyroscope. Nothing is stored or
## sent anywhere: the values only drive the rod.

const G := 9.81

const JS_SETUP := """
(function () {
  if (window.meraMotion) { return; }
  var m = window.meraMotion = { seen: false, permission: 'unknown', gx: 0, gy: 0, gz: 0, gamma: 0 };
  window.addEventListener('devicemotion', function (e) {
    var g = e.accelerationIncludingGravity || {};
    var r = e.rotationRate || {};
    if (g.z === null || g.z === undefined) { return; }
    m.gx = g.x || 0; m.gy = g.y || 0; m.gz = g.z || 0;
    m.gamma = r.gamma || 0;
    m.seen = true;
  });
  m.request = function () {
    if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
      DeviceMotionEvent.requestPermission().then(function (s) { m.permission = s; }).catch(function () { m.permission = 'denied'; });
    } else {
      m.permission = 'granted';
    }
  };
})();
"""

var available := false
var pitch := 0.0
var pitch_rate := 0.0
var permission := "unknown"
## Some browsers report gravity with the opposite sign; the debug menu flips it.
var invert := false

var _web := false
var _js: JavaScriptObject
var _last_pitch := 0.0
var _has_last := false


func _ready() -> void:
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval(JS_SETUP, true)
		_js = JavaScriptBridge.get_interface("meraMotion")


## Call from a tap or press handler: iPhone Safari only shows its prompt then.
func request_permission() -> void:
	if _web and _js:
		_js.request()


func _process(delta: float) -> void:
	var gz := 0.0
	var spin := 0.0
	if _web and _js:
		available = bool(_js.seen)
		permission = String(_js.permission)
		if not available:
			return
		gz = float(_js.gz)
		spin = deg_to_rad(float(_js.gamma))
	else:
		var gravity := Input.get_gravity()
		available = gravity.length() > 0.1
		if not available:
			return
		gz = -gravity.z
		spin = Input.get_gyroscope().y
	pitch = asin(clampf((-gz if invert else gz) / G, -1.0, 1.0))
	# Gyro speed gives the size of a flick, the change in pitch its direction,
	# so the reading does not depend on which way the phone is turned.
	var direction := 0.0
	if _has_last and delta > 0.0:
		direction = signf(pitch - _last_pitch)
	pitch_rate = absf(spin) * direction
	_last_pitch = pitch
	_has_last = true
