class_name DeviceMotion
extends Node
## Reads the phone's motion sensors for MotionGesture. On the web build it
## listens to the browser's devicemotion event through JavaScriptBridge (part
## of Godot, no extra library). iPhone Safari only sends the event after the
## player allows it, and only accepts that request from inside a real browser
## touch or click event; Godot handles input later in its own frame loop, so
## the request is made by a document-level touch listener in JS_SETUP. On
## native builds it reads Input's gravity and gyroscope. Nothing is stored or
## sent anywhere: the values only drive the rod.

const G := 9.81

const STATUS_ON := "on"
const STATUS_TAP := "tap"          ## the browser needs a tap to allow motion
const STATUS_DENIED := "denied"
const STATUS_NONE := "none"        ## no sensor (desktop, or no events yet)

const JS_SETUP := """
(function () {
  if (window.meraMotion) { return; }
  var hasApi = typeof DeviceMotionEvent !== 'undefined';
  var needsAsk = hasApi && typeof DeviceMotionEvent.requestPermission === 'function';
  var ua = navigator.userAgent || '';
  var ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var m = window.meraMotion = {
    seen: false, gx: 0, gy: 0, gz: 0, gamma: 0, ios: ios, api: hasApi,
    permission: needsAsk ? 'prompt' : (hasApi ? 'granted' : 'unsupported')
  };
  window.addEventListener('devicemotion', function (e) {
    var g = e.accelerationIncludingGravity || {};
    var r = e.rotationRate || {};
    if (g.z === null || g.z === undefined) { return; }
    m.gx = g.x || 0; m.gy = g.y || 0; m.gz = g.z || 0;
    m.gamma = r.gamma || 0;
    m.seen = true;
  });
  // Must run inside the browser's own touch or click handler (user activation).
  function ask() {
    if (!needsAsk || m.permission === 'granted' || m.permission === 'asking') { return; }
    m.permission = 'asking';
    try {
      DeviceMotionEvent.requestPermission().then(function (s) { m.permission = s; })
        .catch(function () { m.permission = 'denied'; });
    } catch (err) { m.permission = 'denied'; }
  }
  document.addEventListener('touchend', ask, { capture: true, passive: true });
  document.addEventListener('click', ask, { capture: true, passive: true });
  m.request = ask;
})();
"""

var available := false
var pitch := 0.0
var pitch_rate := 0.0
var permission := "unknown"
var ios := false
var supported := false
## Some browsers report gravity with the opposite sign (iPhone Safari does);
## set from the browser on start, and flippable from the debug menu.
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
		if _js:
			ios = bool(_js.ios)
			supported = bool(_js.api)
			invert = ios


## Kept for completeness: the real request happens in the JS touch listener.
func request_permission() -> void:
	if _web and _js:
		_js.request()


## What the motion chip shows.
func status() -> String:
	if available:
		return STATUS_ON
	if permission == "denied":
		return STATUS_DENIED
	if permission == "prompt" or permission == "asking":
		return STATUS_TAP
	return STATUS_NONE


## Tilt of the screen towards the sky, from gravity along the screen normal.
static func pitch_from_gravity(gz: float, inverted: bool) -> float:
	return asin(clampf((-gz if inverted else gz) / G, -1.0, 1.0))


## Gyro speed gives the size of a flick; the change in pitch gives its
## direction, so the reading does not depend on which way the phone is turned.
static func signed_rate(spin: float, pitch_change: float) -> float:
	return absf(spin) * signf(pitch_change)


func _process(delta: float) -> void:
	var gz := 0.0
	var spin := 0.0
	if _web and _js:
		permission = String(_js.permission)
		available = bool(_js.seen)
		if not available:
			return
		gz = float(_js.gz)
		spin = deg_to_rad(float(_js.gamma))
	else:
		var gravity := Input.get_gravity()
		available = gravity.length() > 0.1
		supported = available
		if not available:
			return
		gz = -gravity.z
		spin = Input.get_gyroscope().y
	pitch = pitch_from_gravity(gz, invert)
	pitch_rate = signed_rate(spin, pitch - _last_pitch) if (_has_last and delta > 0.0) else 0.0
	_last_pitch = pitch
	_has_last = true
