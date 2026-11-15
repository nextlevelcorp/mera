extends Control
## The fishing loop of the 0.1 slice at the first real spot, the Galata Bridge
## (PRD F4-F11, F14): rig,
## cast, wait and read, bite and strike, fight, land, log, cast again. A thin
## view: CatchModel, WaitSim and FightController own every rule; this scene
## reads their state, draws it and sends input. Data in res://data: sourced
## values carry their source, the rest is labelled design fill.
##
## Controls, landscape, thumbs on the corners (spec 6.1):
##   ready   right: hold Cast, let go at the top of the power swing
##   wait    right: Strike; left: reel in, faster waiting
##   fight   left pad: reel (higher thumb = more effort); right: drag slider
##           (up = more drag) and Pull (rod against the fish's run)

const MAIN_SCENE := "res://scenes/main.tscn"
const DATA_DIR := "res://data"
const DEBUG_MENU := "res://debug/debug_menu.gd"
const TOUCH_MIN := 96.0
const NEAR_DRAW_M := 4.6  ## drawing depth of the angler's feet; the camera cannot see nearer
## The fish body is drawn this many times its size: at true scale a 20 cm fish
## seen head-on from the shore is a few pixels across and cannot be read.
const FISH_DRAW_SCALE := 2.0
const POWER_PERIOD_S := 1.4
const SPEED_UP := 4.0

enum Phase { READY, CHARGE, FLIGHT, WAIT, FIGHT, LIFT, RESULT }

const LIFT_RISE_S := 0.8   ## landed fish: time to swing it up out of the water
const LIFT_HOLD_S := 1.8   ## then it hangs and kicks before the result shows

var phase: int = Phase.READY
var conditions := {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}
var clarity_override := -1.0
var rig := "lrf"
var position_id := ""
var save: Dictionary
var save_status := ""
var save_enabled := true
## Set by the debug menu: the species and size draw of the next forced bite.
var forced_u := -1.0

var _db: Dictionary
var _k: Dictionary
var _env: Dictionary
var _ctx: Dictionary
var _wait: WaitSim
var _wait_state := {}
var _controller: FightController
var _hud := {}
var _fight_ctx: Dictionary
var _fish: FishBody
var _water: WaterView
var _overlay: Control
var _fx := SplashFx.new(9)
var _rng := RandomNumberGenerator.new()
var _seed_counter := 1
var _time := 0.0
var _splash_clock := 0.0
var _last_state := ""
var _last_event_count := 0
var _cast := {}
var _aim_x := 0.0
var _charge_s := 0.0
var _flight_s := 0.0
var _flight_total_s := 1.0
var _tip_kick := 0.0
var _tip_vel := 0.0
var _rod := RodSpring.new()
var _rope: VerletRope
var _end_pos := Vector2.ZERO
var _has_line := false
var _rod_back := 0.0
var _cast_motion := CastMotion.new()
var _rig := AnglerRig.new()
var _aim := 0.0
var _press_x := 0.0
var _cast_pose := 0.0
var _dangle := Vector2.ZERO
var _dangle_vel := Vector2.ZERO
var _line_rate := 0.0
var _paid_m := 0.0
var _motion_chip: Button
var _neighbours := NeighborAnglers.new(5)
var _last_contact_s := -99.0   ## when a fish last touched the lure (_time)
var _strike_flash := 0.0
var _mon_label: Label
var _mon_pull: ProgressBar
var _mon_jig: ProgressBar
var _motion: DeviceMotion
var _gesture := MotionGesture.new()
var _motion_state := {}
var _tap_jig := 0.0
var _speed_on := false
var _toast_s := 0.0
var _lift_t := 0.0
var _lift_from := Vector2.ZERO
var _swing := 0.0
var _swing_v := 0.0
var _drip_clock := 0.0
var _result := {}
var _audio: Dictionary = {}
var _sound: SoundDirector
var _last_distance := -1.0
var _stats := FrameStats.new(60.0)

var _reel_pressed := false
var _reel_y := 0.0
var _pull_pressed := false
var _drag_ratio := 0.33
var _strike_queued := false

var _reel_pad: Control
var _drag_slider: Control
var _pull_button: Button
var _main_button: Button
var _reel_in_button: Button
var _speed_button: Button
var _rig_button: Button
var _log_button: Button
var _status_label: Label
var _toast_label: Label
var _hint_label: Label
var _tension_label: Label
var _distance_label: Label
var _drag_label: Label
var _rig_panel: Control
var _rig_label: Label
var _rig_cycle: Button
var _position_cycle: Button
var _result_panel: Control
var _result_label: Label
var _result_detail: Label
var _log_panel: Control
var _why_panel: Control
var _why_text: Label
var _why_button: Button
var _settings_panel: Control
var _settings_button: Button
var _vol_slider: HSlider
var _sens_slider: HSlider
var _flip_check: CheckButton
var _log_text: Label
var _debug_menu: Control


func _ready() -> void:
	setup()
	add_child(DeviceGuard.new())


## Everything except the portrait guard, so tests can run it without a viewport.
## save_path empty: do not read or write a save (tests).
func setup(save_path: String = SaveFile.DEFAULT_PATH) -> void:
	var loaded := DataStore.load_all(DATA_DIR)
	if not loaded["ok"]:
		push_error("Game data failed to load: %s" % str(loaded["errors"]))
		return
	_db = loaded["database"]
	var errors: Array[String] = []
	_k = DataStore.load_constants(errors)
	save_enabled = save_path != ""
	var loaded_save := SaveFile.load_save(save_path) if save_enabled else SaveGame.from_data(null)
	save = loaded_save["save"]
	save_status = loaded_save["status"]
	if save["last_rig"] in FightSetup.TACKLES:
		rig = save["last_rig"]
	if _position_index(save["last_position"]) >= 0:
		position_id = save["last_position"]
	else:
		position_id = _db["spot"][0]["positions"][0]["id"]
	_rng.seed = 7
	_water = WaterView.new()
	add_child(_water)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_build_hud()
	_build_rig_panel()
	_build_result()
	_build_log()
	_build_why()
	_build_settings()
	_build_audio()
	_sound = SoundDirector.new()
	add_child(_sound)
	_motion = DeviceMotion.new()
	add_child(_motion)
	apply_conditions()
	_apply_settings()
	_build_debug()
	_set_phase(Phase.READY)
	if save_status == SaveGame.STATUS_RESET:
		_toast(tr("SAVE_RESET"), 5.0)
	elif save_status == SaveGame.STATUS_MIGRATED:
		_toast(tr("SAVE_MIGRATED"), 4.0)


# ------------------------------------------------------------------ state

## Recomputes the environment from the conditions and updates the water.
func apply_conditions() -> void:
	_ctx = _base_context(_db["spot"][0]["species"][0]["species_id"])
	_env = CatchModel.environment(_k, _ctx["spot"], _ctx["position"], conditions)
	# Neighbours get bites about as often as a bite comes here and now.
	_neighbours.set_pace(WaitSim.new(_ctx, _k, _db["species"], 15.0, 1).median_wait_s() * 1.3)
	if _water:
		if _sound:
			_sound.set_conditions(float(conditions["wind_ms"]), float(_env["chop"]))
		_water.set_conditions(conditions["slot"], clampf(float(_env["chop"]), 0.05, 1.0), float(_env["visibility"]), float(_env["light"]))
	_update_texts()


func set_rig(new_rig: String, new_position: String) -> void:
	rig = new_rig
	position_id = new_position
	SaveGame.set_rig(save, rig, position_id)
	_store()
	apply_conditions()


func _base_context(species_id: String, overrides: Dictionary = {}) -> Dictionary:
	var ctx := FightSetup.build(_db, species_id, rig, position_id, 0.5, conditions, overrides)
	if clarity_override > 0.0:
		var spot: Dictionary = (ctx["spot"] as Dictionary).duplicate()
		spot["typical_clarity"] = clarity_override
		ctx["spot"] = spot
	return ctx


func _set_phase(p: int) -> void:
	phase = p
	var fight := p == Phase.FIGHT
	_reel_pad.visible = fight
	_drag_slider.visible = fight
	_pull_button.visible = fight
	_tension_label.visible = fight
	_status_label.visible = p in [Phase.READY, Phase.CHARGE, Phase.FLIGHT, Phase.WAIT]
	_hint_label.visible = fight and _controller != null and _controller.overmatched
	_main_button.visible = p in [Phase.READY, Phase.CHARGE, Phase.WAIT]
	_main_button.text = tr("FISH_STRIKE") if p == Phase.WAIT else tr("FISH_CAST")
	_reel_in_button.visible = p == Phase.WAIT
	_speed_button.visible = p == Phase.WAIT
	_rig_button.visible = p == Phase.READY
	_log_button.visible = p in [Phase.READY, Phase.RESULT]
	_distance_label.visible = p in [Phase.WAIT, Phase.FIGHT]
	_result_panel.visible = p == Phase.RESULT
	_settings_button.visible = p in [Phase.READY, Phase.WAIT]
	if p != Phase.RESULT:
		_why_panel.visible = false
	if p != Phase.READY and p != Phase.WAIT:
		_settings_panel.visible = false
	if p != Phase.READY:
		_rig_panel.visible = false
		_log_panel.visible = false
	if p != Phase.WAIT:
		_speed_on = false
	if p == Phase.WAIT or p == Phase.FIGHT:
		_gesture.calibrated = false
	_rope = null
	_update_texts()


# ------------------------------------------------------------------ cast

func begin_charge() -> void:
	if phase != Phase.READY:
		return
	_charge_s = 0.0
	_aim = 0.0
	_set_phase(Phase.CHARGE)


## The power swing: rises to 1 and falls back, so letting go at the top is the skill.
static func power_at(charge_s: float) -> float:
	var t := fmod(charge_s / POWER_PERIOD_S, 1.0)
	return 1.0 - absf(1.0 - 2.0 * t)


func release_cast() -> void:
	if phase != Phase.CHARGE:
		return
	cast_with_power(maxf(power_at(_charge_s), 0.15), _aim)


## aim: radians from the thumb swipe (CastMotion.aim_from_drag); the skill
## error of CatchModel.cast is added on top.
func cast_with_power(power: float, aim: float = 0.0) -> void:
	_snd("cast_swish", -3.0)
	_cast_motion.release(power)
	_rod.kick(-6.0)
	_cast = CatchModel.cast(_k, _ctx["rod"], _ctx["lure"], _ctx["angler"], _ctx["position"], conditions, power)
	_cast["cast_m"] = maxf(float(_cast["cast_m"]), float(_k["WAIT_END_M"]) + 2.0)
	_aim_x = clampf(aim + _rng.randfn(0.0, float(_cast["aim_sigma_rad"])), -0.5, 0.5)
	_paid_m = 0.0
	_flight_s = 0.0
	_flight_total_s = 0.6 + float(_cast["cast_m"]) / 30.0
	_seed_counter += 1
	_set_phase(Phase.FLIGHT)


func _land_lure() -> void:
	var cast_m: float = _cast["cast_m"]
	_wait = WaitSim.new(_ctx, _k, _db["species"], cast_m, _seed_counter * 7919)
	_wait_state = _wait.snapshot()
	_last_event_count = 0
	var world := Vector2(_lure_x(cast_m), NEAR_DRAW_M + cast_m)
	_fx.splash(WaterView.project(world, 0.0, _overlay.size), world, 0.4)
	_fx.add_ring(world, 0.6, 1.4, 0.6)
	_snd("lure_drop", -4.0)
	_snd("drag_click", -18.0)   # the bail snaps shut
	_set_phase(Phase.WAIT)


func _lure_x(distance_m: float) -> float:
	return -0.3 + tan(_aim_x) * distance_m


# ------------------------------------------------------------------ wait and bite

func strike() -> void:
	if phase == Phase.WAIT:
		_strike_queued = true


func reel_in() -> void:
	if phase == Phase.WAIT:
		_set_phase(Phase.READY)


## Debug menu: a committed take by this species; u < 0 draws the size.
func force_bite(species_id: String, u: float = -1.0) -> void:
	forced_u = u
	if phase in [Phase.READY, Phase.CHARGE]:
		cast_with_power(0.7)
		_flight_s = _flight_total_s
		_land_lure()
	if phase == Phase.WAIT:
		_wait.force_take(species_id)


func _step_wait(delta: float) -> void:
	var input := {"strike": _strike_queued, "jig": jig_amount()}
	_strike_queued = false
	_wait_state = _wait.advance(delta, input, SPEED_UP if _speed_on else 1.0)
	for i in range(_last_event_count, _wait.events.size()):
		_on_wait_event(_wait.events[i])
	_last_event_count = _wait.events.size()
	if _wait_state["phase"] == WaitSim.PHASE_HOOKED:
		_start_fight(_wait_state["hooked"])
	elif _wait_state["phase"] == WaitSim.PHASE_RETRIEVED:
		_toast(tr("FISH_RETRIEVED"), 2.5)
		_set_phase(Phase.READY)


## How hard the lure is being worked: phone twitches, or taps on the water
## for players without motion sensors.
func jig_amount() -> float:
	return maxf(float(_motion_state.get("jig", 0.0)), _tap_jig)


func _on_wait_event(e: Dictionary) -> void:
	var world := Vector2(_lure_x(float(e["lure_distance_m"])), NEAR_DRAW_M + float(e["lure_distance_m"]))
	match e["event"]:
		"nibble":
			_last_contact_s = _time
			_tip_vel -= 6.0
			_rod.kick(1.5)
			_fx.add_ring(world, 0.35, 0.8, 0.35)
			_play("nibble")
		"take":
			_last_contact_s = _time
			_tip_vel -= 22.0
			_rod.kick(6.0)
			_fx.add_ring(world, 0.7, 1.2, 0.9)
			_fx.splash(WaterView.project(world, 0.0, _overlay.size), world, 0.35)
			_play("take")
			Input.vibrate_handheld(60)
			_speed_on = false
		"take_missed":
			_toast(tr("FISH_TAKE_MISSED"), 1.8)
		"hook_failed":
			_toast(tr("FISH_HOOK_FAILED"), 1.8)
		"strike_empty":
			_tip_vel += 10.0
			_toast(tr("FISH_STRIKE_EMPTY"), 1.2)


# ------------------------------------------------------------------ fight

func _start_fight(hooked: Dictionary) -> void:
	var u: float = forced_u if forced_u >= 0.0 else float(hooked["u"])
	forced_u = -1.0
	var d: float = hooked["distance_m"]
	_fight_ctx = _base_context(hooked["species_id"], {"cast_m": d, "hook_distance_m": d, "timing_quality": hooked["timing_quality"]})
	_fight_ctx["play"]["fish_length_cm"] = FightController.draw_length_cm(_fight_ctx["species"], u)
	_drag_ratio = clampf(float(_fight_ctx["play"]["drag_kg"]) / float(_fight_ctx["reel"]["drag_max_kg"]), 0.0, 1.0)
	_controller = FightController.new(_fight_ctx, _k, _seed_counter)
	_hud = _controller.hud()
	_fish = FishBody.new(float(_fight_ctx["play"]["fish_length_cm"]) / 100.0, _fish_world())
	_fx = SplashFx.new(_seed_counter)
	_last_state = ""
	_last_distance = -1.0
	_reel_pressed = false
	_pull_pressed = false
	_snd("splash", -6.0)
	_set_phase(Phase.FIGHT)


func current_input() -> Dictionary:
	return {
		"reel": FightController.reel_from_pad(_reel_pressed, _reel_y, _reel_pad.size.y),
		"rod": maxf(FightController.rod_from_button(_pull_pressed), float(_motion_state.get("pull", 0.0))),
		"drag_kg": FightController.drag_from_slider(_drag_ratio, _controller.drag_max_kg),
	}


## For tests and the debug menu: hold or release the two thumbs.
func set_fight_input(reel_pressed: bool, reel_y: float, pull_pressed: bool, drag_ratio: float) -> void:
	_reel_pressed = reel_pressed
	_reel_y = reel_y
	_pull_pressed = pull_pressed
	_drag_ratio = drag_ratio


func _step_fight(delta: float) -> void:
	_hud = _controller.advance(delta, current_input())
	var d := float(_hud["distance_m"])
	if delta > 0.0 and _last_distance >= 0.0:
		_line_rate = (d - _last_distance) / delta
		if _sound:
			_sound.set_reel(_line_rate, _hud["outcome"] == "")
			_sound.set_tension(float(_hud["tension_ratio"]))
	_last_distance = d
	_fight_effects(delta)
	if _hud["outcome"] != "":
		_finish_fight()


func _finish_fight() -> void:
	if _sound:
		_sound.set_reel(0.0, false)
	var outcome: String = _hud["outcome"]
	var sp: Dictionary = _fight_ctx["species"]
	_result = {"outcome": outcome, "species_id": sp["id"], "length_cm": float(_fight_ctx["play"]["fish_length_cm"]), "weight_kg": _controller.sim.weight_kg}
	if outcome == FightSim.OUTCOME_LANDED:
		_result.merge(SaveGame.record_catch(save, sp["id"], _result["length_cm"], _result["weight_kg"], Time.get_date_string_from_system()))
		_store()
		_play("landed")
		_lift_t = 0.0
		_lift_from = WaterView.project(_fish_world(), 0.0, _overlay.size)
		_swing = 1.1
		_swing_v = 0.0
		_fx.splash(_lift_from, _fish_world(), 0.9)
		_snd("splash", -2.0)
		_set_phase(Phase.LIFT)
		return
	_show_result()
	_set_phase(Phase.RESULT)


## The landed fish is swung out of the water and hangs from the line: a
## damped pendulum (pillar 3: oscillation) kicked by the fish's own flapping.
func _step_lift(delta: float) -> void:
	_lift_t += delta
	var gravity_term := -12.0 * sin(_swing)
	var kick := 0.0
	if _lift_t > LIFT_RISE_S:
		kick = 9.0 * sin(_lift_t * 7.3) * maxf(0.0, sin(_lift_t * 1.7))
	_swing_v += (gravity_term - 1.6 * _swing_v + kick) * delta
	_swing += _swing_v * delta
	_drip_clock -= delta
	if _drip_clock <= 0.0 and _lift_t > LIFT_RISE_S * 0.5:
		_drip_clock = 0.18
		var tail := _lift_points()[1]
		_fx.splash(tail, _fish_world(), 0.12)
	if phase == Phase.LIFT and _lift_t >= LIFT_RISE_S + LIFT_HOLD_S:
		_show_result()
		_set_phase(Phase.RESULT)


## Screen position of the hook (fish's mouth) and of the tail while lifted.
func _lift_points() -> PackedVector2Array:
	var size := _overlay.size
	var tip := _rod.tip()
	var hang := tip + Vector2(0.0, size.y * 0.30)
	var r := smoothstep(0.0, LIFT_RISE_S, _lift_t)
	var mouth := _lift_from.lerp(hang, r) + Vector2(0.0, -size.y * 0.08 * sin(PI * r))
	var length_px := _lift_length_px()
	var dir := Vector2(sin(_swing), cos(_swing))
	return PackedVector2Array([mouth, mouth + dir * length_px])


func _lift_length_px() -> float:
	var size := _overlay.size
	var aspect := size.x / maxf(size.y, 1.0)
	var px_per_m := size.x / ((NEAR_DRAW_M + 1.0) * aspect * WaterView.FOV)
	return clampf(float(_fight_ctx["play"]["fish_length_cm"]) / 100.0 * FISH_DRAW_SCALE * px_per_m, 40.0, 230.0)


func _draw_lifted_fish(tip: Vector2) -> void:
	var pts := _lift_points()
	var mouth: Vector2 = pts[0]
	var length_px := _lift_length_px()
	var dir := (pts[1] - mouth).normalized()
	var side := Vector2(-dir.y, dir.x)
	var flap := 0.18 if _lift_t > LIFT_RISE_S else 0.05
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var spine := PackedVector2Array()
	for i in FishBody.SEGMENTS:
		var s := float(i) / float(FishBody.SEGMENTS - 1)
		var sway := sin(_time * 11.0 - s * 4.0) * flap * length_px * s * s
		spine.append(mouth + dir * s * length_px + side * sway)
	for i in spine.size():
		var s := float(i) / float(spine.size() - 1)
		var a: Vector2 = spine[maxi(i - 1, 0)]
		var b: Vector2 = spine[mini(i + 1, spine.size() - 1)]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var w := FishBody.half_width(s) * length_px * 1.3
		left.append(spine[i] + n * w)
		right.append(spine[i] - n * w)
	var tail: Vector2 = spine[spine.size() - 1]
	var back := (tail - spine[spine.size() - 2]).normalized()
	var across := Vector2(-back.y, back.x)
	var fin := length_px * 0.16
	var outline := PackedVector2Array()
	outline.append_array(left)
	outline.append(tail + back * fin + across * fin * 0.8)
	outline.append(tail + back * fin * 0.35)
	outline.append(tail + back * fin - across * fin * 0.8)
	right.reverse()
	outline.append_array(right)
	if Geometry2D.triangulate_polygon(outline).size() > 0:
		_overlay.draw_colored_polygon(outline, Color(0.62, 0.68, 0.72))
	outline.append(outline[0])
	_overlay.draw_polyline(outline, Color(0.12, 0.15, 0.18), 2.0, true)
	# Dark back along the spine and an eye near the mouth.
	_overlay.draw_polyline(spine.slice(0, spine.size() - 1), Color(0.2, 0.25, 0.3, 0.8), maxf(length_px * 0.05, 2.0), true)
	_overlay.draw_circle(mouth + dir * length_px * 0.06 + side * length_px * 0.03, maxf(length_px * 0.018, 2.0), Color(0.05, 0.05, 0.05))


func _fight_effects(delta: float) -> void:
	var pos := _fish_world()
	var state: String = _hud["fish_state"]
	if _fish:
		_fish.step(delta, pos, "landing" if _hud["in_landing"] else state)
	if state != _last_state:
		if state == "run":
			_fx.add_ring(pos, 0.5, 1.6, 0.5)
			_rod.kick(4.0)
		_last_state = state
	_splash_clock -= delta
	if _splash_clock <= 0.0 and (state == "thrash" or (_hud["in_landing"] and state != "rest")):
		_splash_clock = 0.45
		_fx.splash(WaterView.project(pos, 0.0, _overlay.size), pos, 0.7)
		_snd("splash_heavy", -8.0)
		_rod.kick(2.5 if int(_time * 7.0) % 2 == 0 else -2.5)


## Where the fish is on the water: out along the line by the simulation's
## distance (plus the drawing offset), drifting sideways with its state.
func _fish_world() -> Vector2:
	var d := float(_hud.get("distance_m", 0.0))
	var side := sin(_time * 0.7) * 0.12 * d + (0.08 * d if _hud.get("fish_state", "") == "run" else 0.0)
	return Vector2(_lure_x(d) + side, NEAR_DRAW_M + d)



# ------------------------------------------------------------------ physics of the view

## Phone motion (owner request 2026-11-14): a flick back strikes in the wait,
## tilting back pulls the rod in the fight, small twitches work the lure.
func _update_motion(delta: float) -> void:
	_motion_state = {}
	if _motion == null or not _motion.available:
		return
	_motion_state = _gesture.add_sample(delta, _motion.pitch_rate, _motion.pitch)
	if _motion_state["strike"]:
		_strike_flash = 0.6
	if phase == Phase.WAIT and _motion_state["strike"]:
		# A flick strikes when a fish is on or just touched the lure; with
		# nothing there it just twitches the lure (no 'nothing there' penalty).
		var contact: bool = _wait_state.get("phase", "") == WaitSim.PHASE_TAKE or _time - _last_contact_s < 1.2
		if contact:
			strike()
		else:
			_tap_jig = minf(_tap_jig + 0.6, 1.0)
			_rod.kick(-2.0)
	if phase == Phase.FIGHT and _motion_state["strike"]:
		_rod.kick(-5.0)


## Taps on the water during the wait twitch the lure: the touch version of
## working it with the phone.
func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.WAIT:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_tap_jig = minf(_tap_jig + 0.35, 1.0)
		_rod.kick(-1.2)


## Wind across the screen in px/s^2: the part of the wind blowing from the
## left or right of where the angler faces, with gusts (pillar 3: noise).
func wind_accel() -> float:
	if _ctx.is_empty():
		return 0.0
	var dirs := CatchModel.WIND_DIRECTIONS
	var from_deg := dirs.find(String(conditions["wind_dir"])) * 45.0
	var facing_deg := dirs.find(String(_ctx["position"]["facing"])) * 45.0
	var to_rad := deg_to_rad(from_deg + 180.0)
	var right_rad := deg_to_rad(facing_deg + 90.0)
	var lateral := cos(to_rad - right_rad)
	var gust := 0.75 + 0.2 * sin(_time * 0.83) + 0.15 * sin(_time * 2.31 + 1.7) + 0.08 * sin(_time * 5.7)
	return lateral * float(conditions["wind_ms"]) * 22.0 * gust


## Where the line ends on screen for the current phase.
func _line_end(size: Vector2) -> Vector2:
	match phase:
		Phase.READY, Phase.CHARGE:
			return _dangle
		Phase.FLIGHT:
			var s := clampf(_flight_s / _flight_total_s, 0.0, 1.0)
			var d := float(_cast["cast_m"]) * s
			var h := 4.0 * float(_cast["cast_m"]) * 0.25 * s * (1.0 - s) + 2.0 * (1.0 - s)
			return WaterView.project(Vector2(_lure_x(d), NEAR_DRAW_M + d), h, size)
		Phase.WAIT:
			var dw := float(_wait_state.get("lure_distance_m", 0.0))
			return WaterView.project(Vector2(_lure_x(dw), NEAR_DRAW_M + dw), 0.03 * sin(_time * 2.1), size)
		Phase.FIGHT:
			return WaterView.project(_fish_world(), 0.0, size)
		Phase.LIFT, Phase.RESULT:
			if _lifted():
				return _lift_points()[0]
			if not _hud.is_empty():
				return WaterView.project(_fish_world(), 0.0, size)
	return Vector2.ZERO


func _lifted() -> bool:
	return phase == Phase.LIFT or (phase == Phase.RESULT and _result.get("outcome", "") == FightSim.OUTCOME_LANDED)


func _line_present() -> bool:
	match phase:
		Phase.READY, Phase.CHARGE, Phase.FLIGHT, Phase.WAIT, Phase.FIGHT, Phase.LIFT:
			return true
		Phase.RESULT:
			var o: String = _result.get("outcome", "")
			return o == FightSim.OUTCOME_LANDED
	return false


## Steps the spring rod and the Verlet line once per frame. The load on the
## rod tip points along the line; its size comes from the simulation (fight
## tension, a take, a hanging fish); wind pushes the line sideways.
func _step_rod_and_line(delta: float) -> void:
	if _overlay == null:
		return
	var size := _overlay.size
	if size.x < 2.0:
		return
	# Breathing: the whole rig rises and falls slowly (pillar 3: oscillation).
	var breath := Vector2(sin(_time * 0.9) * 1.5, sin(_time * TAU * 0.25) * 3.0)
	var butt := Vector2(size.x * 0.66, size.y * 0.95) + breath
	var rest_tip := Vector2(size.x * 0.76, size.y * 0.30)
	var base := (rest_tip - butt).angle()
	var length := butt.distance_to(rest_tip)
	# The cast swing: back over the shoulder while charging, a forward snap on release.
	if phase == Phase.CHARGE:
		_cast_motion.charge(delta, power_at(_charge_s))
	else:
		_cast_motion.settle(delta)
	# Seen from the angler: winding up turns the rod upright and past the
	# head, so the tip leaves the top of the screen; the forward snap points
	# it away over the water, so it looks shorter and drops towards the horizon.
	var back_share := clampf(_cast_motion.angle / CastMotion.WINDUP_MAX, 0.0, 1.0)
	var fwd_share := clampf(-_cast_motion.angle / 0.6, 0.0, 1.0)
	base = lerpf(base, -PI * 0.5 - 0.08, back_share) + 0.18 * fwd_share
	length *= (1.0 + 0.4 * back_share) * (1.0 - 0.3 * fwd_share)
	# Pulling the rod back (button or phone) raises it towards upright.
	var back := 0.0
	match phase:
		Phase.FIGHT:
			back = float(current_input()["rod"])
		Phase.READY, Phase.WAIT:
			# The rod follows the phone's tilt, so the mapping is visible at once.
			back = 0.8 * float(_motion_state.get("pull", 0.0))
	_rod_back = lerpf(_rod_back, back, minf(delta * 10.0, 1.0))
	base -= 0.45 * _rod_back
	var tip := _rod.tip() if _rod.tip() != Vector2.ZERO else rest_tip
	# Before the cast the lure hangs from the tip and swings like a pendulum.
	var hang := tip + Vector2(0.0, 52.0)
	if _dangle == Vector2.ZERO:
		_dangle = hang
	_dangle_vel += ((hang - _dangle) * 45.0 - _dangle_vel * 3.5 + Vector2(wind_accel() * 0.3, 0.0)) * minf(delta, 0.1)
	_dangle += _dangle_vel * minf(delta, 0.1)
	_has_line = _line_present()
	_end_pos = _line_end(size) if _has_line else Vector2.ZERO
	var dir := (_end_pos - tip).normalized() if _has_line else Vector2.DOWN
	var amount := 0.03
	match phase:
		Phase.READY, Phase.CHARGE:
			amount = 0.04
		Phase.WAIT:
			amount = 0.06 + 0.5 * clampf(_tip_kick, 0.0, 1.2)
		Phase.FIGHT:
			amount = clampf(float(_hud.get("tension_ratio", 0.0)), 0.0, 1.3)
		Phase.LIFT, Phase.RESULT:
			amount = 0.7 if _lifted() else 0.03
		Phase.FLIGHT:
			amount = 0.05
	var load := dir * amount + Vector2(wind_accel() * 0.0004, 0.0)
	_rod.step(delta, butt, base, length, load)
	tip = _rod.tip()
	# Line paid out from the open spool during the flight.
	var line_out := 0.0
	if phase == Phase.FLIGHT:
		var paid := CastMotion.paid_out(_flight_s, _flight_total_s, float(_cast["cast_m"]))
		line_out = (paid - _paid_m) / maxf(delta, 0.001)
		_paid_m = paid
	elif phase == Phase.FIGHT:
		line_out = maxf(_line_rate, 0.0)
	var crank_target := 0.0
	if phase == Phase.FIGHT:
		crank_target = 14.0 * float(current_input()["reel"])
	elif phase == Phase.WAIT and _wait_state.get("phase", "") == WaitSim.PHASE_FISHING:
		crank_target = 3.0 * (SPEED_UP if _speed_on else 1.0)
	_cast_pose = lerpf(_cast_pose, 1.0 if phase in [Phase.CHARGE, Phase.FLIGHT] else 0.0, minf(delta * 6.0, 1.0))
	_rig.light = float(_env.get("light", 0.6))
	_rig.tension = clampf(float(_hud.get("tension_ratio", 0.0)), 0.0, 1.2) if phase == Phase.FIGHT else 0.0
	_rig.bail_open = phase == Phase.FLIGHT or phase == Phase.CHARGE
	_rig.cast_pose = _cast_pose
	_rig.update(delta, crank_target, line_out)
	# Line: taut when tension is high, sagging and wind-blown when slack.
	if not _has_line:
		_rope = null
		return
	var dist := tip.distance_to(_end_pos)
	var slack := 1.02
	match phase:
		Phase.READY, Phase.CHARGE:
			slack = 1.0
		Phase.WAIT:
			# An angler keeps the line nearly tight; wind gives it a slight belly.
			slack = 1.006 - 0.004 * clampf(_tip_kick, 0.0, 1.0) + 0.00015 * absf(wind_accel())
		Phase.FIGHT:
			slack = lerpf(1.015, 1.0, clampf(float(_hud.get("tension_ratio", 0.0)) * 2.5, 0.0, 1.0))
		Phase.FLIGHT:
			# Line leaves the spool faster than the lure pulls it straight: a loose belly early on.
			slack = 1.0 + 0.03 * (1.0 - clampf(_flight_s / maxf(_flight_total_s, 0.001), 0.0, 1.0))
		Phase.LIFT, Phase.RESULT:
			slack = 1.004
	if _rope == null:
		_rope = VerletRope.new(tip, _end_pos, 18, slack)
	_rope.set_total_length(dist * slack)
	_rope.step(delta, tip, _end_pos, Vector2(wind_accel(), 160.0))


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_time += delta
	_stats.add(delta)
	_update_motion(delta)
	match phase:
		Phase.CHARGE:
			_charge_s += delta
		Phase.FLIGHT:
			_flight_s += delta
			if _flight_s >= _flight_total_s:
				_land_lure()
		Phase.WAIT:
			_step_wait(delta)
		Phase.FIGHT:
			_step_fight(delta)
		Phase.LIFT:
			_step_lift(delta)
		Phase.RESULT:
			if _result.get("outcome", "") == FightSim.OUTCOME_LANDED:
				_step_lift(delta)
	# Rod tip as a damped spring: kicks from nibbles and takes settle by themselves.
	var target := 0.0
	if phase == Phase.WAIT and _wait_state.get("phase", "") == WaitSim.PHASE_TAKE:
		target = 0.9
	_tip_vel += ((target - _tip_kick) * 60.0 - _tip_vel * 9.0) * delta
	_tip_kick += _tip_vel * delta
	_tap_jig = maxf(_tap_jig - delta * 0.8, 0.0)
	_step_rod_and_line(delta)
	if _on_bridge():
		_neighbours.update(delta)
		for e: Dictionary in _neighbours.take_events():
			_snd("splash", -24.0)   # a neighbour lifts a fish: a distant splash
	_toast_s = maxf(_toast_s - delta, 0.0)
	_toast_label.visible = _toast_s > 0.0
	_fx.step(delta)
	_update_texts()
	_overlay.queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw_overlay() -> void:
	var size := _overlay.size
	for ring: Dictionary in _fx.rings:
		var world: Vector2 = ring["world"]
		var r := SplashFx.ring_radius(ring)
		var centre := WaterView.project(world, 0.0, size)
		var aspect := size.x / maxf(size.y, 1.0)
		var rx := r / (maxf(world.y, 0.5) * aspect * WaterView.FOV) * size.x
		var ry := WaterView.CAM_HEIGHT * r / (world.y * world.y * WaterView.FOV) * size.y
		_ellipse(centre, rx, ry, Color(1, 1, 1, 0.55 * SplashFx.ring_alpha(ring)))
	var tip := _rod.tip()
	match phase:
		Phase.READY, Phase.CHARGE:
			_draw_line(false)
			_overlay.draw_circle(_end_pos, 4.0, Color(0.95, 0.75, 0.3))
			if phase == Phase.CHARGE:
				_draw_aim_marker(size)
		Phase.FLIGHT:
			_draw_line(false)
			_overlay.draw_circle(_end_pos, 4.0, Color(0.95, 0.75, 0.3))
		Phase.WAIT:
			_draw_line(false)
			_overlay.draw_circle(_end_pos, 3.0, Color(0.95, 0.75, 0.3))
		Phase.FIGHT, Phase.RESULT:
			if _lifted():
				_draw_line(false)
				_draw_lifted_fish(tip)
			elif not _hud.is_empty():
				_draw_fight(size)
		Phase.LIFT:
			_draw_line(false)
			_draw_lifted_fish(tip)
	for p: Dictionary in _fx.particles:
		_overlay.draw_circle(p["pos"], p["size"], Color(0.92, 0.96, 1.0, 0.85 * float(p["life"]) / float(p["max_life"])))
	if _on_bridge():
		_draw_bridge(size)
	_rig.draw(_overlay, _rod.points(), size)
	if phase == Phase.FIGHT or (phase == Phase.RESULT and not _hud.is_empty()):
		_draw_tension_bar(size)
	if phase == Phase.CHARGE:
		_draw_power(size)


func _draw_fight(size: Vector2) -> void:
	var outcome: String = _hud["outcome"]
	var line_gone := outcome == FightSim.OUTCOME_LINE_BREAK or outcome == FightSim.OUTCOME_LEADER_CUT
	var pos := _fish_world()
	if not line_gone and phase == Phase.FIGHT:
		_draw_line(float(_hud["strain_ratio"]) > 0.0)
	if _hud["fish_visible"] and not line_gone and _fish:
		var pts := PackedVector2Array()
		for w: Vector2 in _fish.outline():
			pts.append(WaterView.project(_fish.head + (w - _fish.head) * FISH_DRAW_SCALE, 0.0, size))
		var shade := Color(0.05, 0.08, 0.1, 0.55 + 0.3 * float(_env.get("visibility", 0.5)))
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			_overlay.draw_colored_polygon(pts, shade)
		else:
			_overlay.draw_polyline(pts, shade, 3.0, true)


## True when the standing position is on a bridge deck (Galata): the
## foreground then shows the rail and the other anglers along it.
func _on_bridge() -> bool:
	return not _ctx.is_empty() and "bridge piers" in (_ctx["position"].get("structure_tags", []) as Array)


## Bridge foreground: deck edge, a steel rail with posts, a lamp standard and
## the rods of neighbouring anglers. Drawn shapes only (design direction:
## art option A); darker with less light.
func _draw_bridge(size: Vector2) -> void:
	var light := float(_env.get("light", 0.6))
	var steel := Color(0.16, 0.18, 0.2).lerp(Color(0.04, 0.05, 0.06), 1.0 - light)
	var deck := Color(0.32, 0.31, 0.3).lerp(Color(0.08, 0.08, 0.09), 1.0 - light)
	var rail_y := size.y * 0.80
	var deck_y := size.y * 0.90
	# At dusk and night the lamps lay a broken streak of light on the water.
	var lamp_glow := 1.0 - light
	if lamp_glow > 0.2:
		var lx := size.x * 0.27 + 30.0   # under the right-hand lamp head
		for j in 14:
			var t := float(j) / 13.0
			var y := lerpf(size.y * 0.42, rail_y - 8.0, t)
			var wobble := sin(_time * 1.7 + j * 1.3) * (4.0 + 10.0 * t)
			var w := lerpf(3.0, 22.0, t) * (0.6 + 0.4 * sin(_time * 2.3 + j * 2.1))
			_overlay.draw_rect(Rect2(lx + wobble - w * 0.5, y, w, 2.0 + 3.0 * t), Color(1.0, 0.82, 0.5, (0.3 + 0.5 * lamp_glow) * (1.0 - 0.3 * t)))
	_overlay.draw_rect(Rect2(0, deck_y, size.x, size.y - deck_y), deck)
	_overlay.draw_rect(Rect2(0, deck_y, size.x, 4), deck.lightened(0.15))
	# Other anglers along the rail, fishing too (Zengin 2009: hundreds a day).
	_neighbours.draw(_overlay, size, rail_y, light, _time)
	# Rail: top bar, mid bar, posts.
	_overlay.draw_rect(Rect2(0, rail_y - 6, size.x, 12), steel)
	_overlay.draw_rect(Rect2(0, rail_y + size.y * 0.045, size.x, 6), steel)
	var post_gap := 110.0
	var x := fmod(post_gap * 0.5, post_gap)
	while x < size.x:
		_overlay.draw_rect(Rect2(x - 4, rail_y - 6, 8, deck_y - rail_y + 6), steel)
		x += post_gap
	# Lamp standard at the left.
	var lamp_x := size.x * 0.27
	_overlay.draw_rect(Rect2(lamp_x - 6, size.y * 0.18, 12, deck_y - size.y * 0.18), steel)
	_overlay.draw_rect(Rect2(lamp_x - 34, size.y * 0.16, 68, 10), steel)
	var glow := 1.0 - light
	if glow > 0.2:
		for side in [-1.0, 1.0]:
			_overlay.draw_circle(Vector2(lamp_x + side * 30.0, size.y * 0.18), 9.0, Color(1.0, 0.85, 0.55, 0.4 + 0.5 * glow))


## The line along the Verlet rope; warm-coloured and thicker while straining.
## The line as a thin thread: thicker and clearer near the rod, finer and
## fainter far out (distance), with the odd glint where the sun catches it.
## Warm and thicker while it strains.
func _draw_line(strained: bool) -> void:
	if _rope == null:
		return
	var pts := _rope.points
	var n := pts.size() - 1
	var light := float(_env.get("light", 0.6))
	var base := Color(1.0, 0.86, 0.58) if strained else Color(0.84, 0.91, 1.0).lerp(Color(1.0, 0.82, 0.62), 0.5 * (1.0 - light))
	for i in n:
		var t := float(i) / n
		var w := lerpf(1.7, 0.6, pow(t, 0.7)) * (1.4 if strained else 1.0)
		var col := base
		col.a = lerpf(0.85, 0.35, pow(t, 0.9))
		var ph := sin(_time * 2.7 + i * 1.9)
		if ph > 0.92:
			col = col.lerp(Color(1, 1, 1, 1), (ph - 0.92) / 0.08 * (0.35 + 0.65 * light))
		_overlay.draw_line(pts[i], pts[i + 1], col, w, true)
	# Where the line meets the water: a small ripple, so it reads as cutting the surface.
	if _has_line and (phase == Phase.WAIT or phase == Phase.FIGHT):
		_ring_at(_end_pos, 5.0 + 2.0 * sin(_time * 3.1), Color(1, 1, 1, 0.3))


## While charging: where the lure would land at the current power and aim
## (the skill error is not shown; it is added at release).
func _draw_aim_marker(size: Vector2) -> void:
	var c := CatchModel.cast(_k, _ctx["rod"], _ctx["lure"], _ctx["angler"], _ctx["position"], conditions, maxf(power_at(_charge_s), 0.15))
	var d := maxf(float(c["cast_m"]), float(_k["WAIT_END_M"]) + 2.0)
	var world := Vector2(-0.3 + tan(_aim) * d, NEAR_DRAW_M + d)
	var centre := WaterView.project(world, 0.0, size)
	var aspect := size.x / maxf(size.y, 1.0)
	var rx := 0.8 / (world.y * aspect * WaterView.FOV) * size.x
	var ry := WaterView.CAM_HEIGHT * 0.8 / (world.y * world.y * WaterView.FOV) * size.y
	_ellipse(centre, maxf(rx, 6.0), maxf(ry, 2.0), Color(1, 1, 1, 0.6))
	_ellipse(centre, maxf(rx, 6.0) * 0.4, maxf(ry, 2.0) * 0.4, Color(1, 1, 1, 0.45))


func _ring_at(centre: Vector2, r: float, color: Color) -> void:
	_overlay.draw_set_transform(centre, 0.0, Vector2(1.0, 0.3))
	_overlay.draw_arc(Vector2.ZERO, r, 0.0, TAU, 14, color, 1.0, true)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx < 0.5 or color.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	_overlay.draw_polyline(points, color, 1.2, true)


## Cast power: a vertical gauge beside the Cast button; the marker swings up
## and down and the top band is the best release.
func _draw_power(size: Vector2) -> void:
	var x := size.x - 290.0
	var y0 := size.y - 300.0
	var h := 260.0
	var p := power_at(_charge_s)
	_overlay.draw_rect(Rect2(x - 3, y0 - 3, 34, h + 6), Color(0, 0, 0, 0.55))
	_overlay.draw_rect(Rect2(x, y0, 28, h), Color(0.12, 0.14, 0.18, 0.9))
	_overlay.draw_rect(Rect2(x, y0, 28, h * 0.1), Color(0.55, 0.85, 0.6))
	_overlay.draw_rect(Rect2(x, y0 + h * (1.0 - p), 28, h * p), Color(0.95, 0.8, 0.35, 0.8))
	_overlay.draw_rect(Rect2(x - 8, y0 + h * (1.0 - p) - 3, 44, 6), Color(1, 1, 1))


## Tension against the line's strength. Shape, not colour, tells the danger:
## a tick at the strain threshold, a thick block at the break point, and the
## numbers in kilograms (PRD F8, F18).
func _draw_tension_bar(size: Vector2) -> void:
	var w := minf(size.x * 0.46, 600.0)
	var h := 40.0
	var x := (size.x - w) * 0.5
	var y := 26.0
	var ratio: float = clampf(float(_hud["tension_ratio"]), 0.0, 1.0)
	_overlay.draw_rect(Rect2(x - 3, y - 3, w + 6, h + 6), Color(0, 0, 0, 0.55))
	_overlay.draw_rect(Rect2(x, y, w, h), Color(0.12, 0.14, 0.18, 0.9))
	var fill := Color(0.55, 0.85, 0.6) if ratio < 0.6 else (Color(0.95, 0.8, 0.35) if ratio < 0.8 else Color(0.95, 0.4, 0.3))
	_overlay.draw_rect(Rect2(x, y, w * ratio, h), fill)
	var thr := float(_hud["strain_threshold_ratio"])
	_overlay.draw_line(Vector2(x + w * thr, y - 8), Vector2(x + w * thr, y + h + 8), Color(1, 1, 1), 3.0)
	_overlay.draw_rect(Rect2(x + w - 8, y - 8, 8, h + 16), Color(1, 1, 1))
	var drag_ratio: float = clampf(float(_hud["drag_set_kg"]) / float(_hud["line_strength_kg"]), 0.0, 1.0)
	var nx := x + w * drag_ratio
	_overlay.draw_colored_polygon(PackedVector2Array([Vector2(nx, y + h + 3), Vector2(nx - 9, y + h + 18), Vector2(nx + 9, y + h + 18)]), Color(1, 1, 1))
	var strain: float = clampf(float(_hud["strain_ratio"]), 0.0, 1.0)
	if strain > 0.0:
		_overlay.draw_rect(Rect2(x, y - 14, w * strain, 6), Color(1.0, 0.35, 0.25))


# ------------------------------------------------------------------ input

func _on_reel_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_reel_pressed = event.pressed
		_reel_y = event.position.y
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _reel_pressed:
			_reel_y = event.position.y


func _on_drag_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	var moving: bool = (event is InputEventScreenDrag) or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if down or moving:
		_drag_ratio = clampf(1.0 - event.position.y / maxf(_drag_slider.size.y, 1.0), 0.0, 1.0)


func _on_main_down() -> void:
	if _motion:
		_motion.request_permission()
	if phase == Phase.READY:
		begin_charge()
	elif phase == Phase.WAIT:
		strike()


## Thumb travel sideways while holding Cast aims the cast.
func _on_main_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_press_x = event.position.x
	elif phase == Phase.CHARGE and (event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))):
		_aim = CastMotion.aim_from_drag(event.position.x - _press_x, _overlay.size.x if _overlay else 1280.0)


func _on_main_up() -> void:
	if phase == Phase.CHARGE:
		release_cast()


# ------------------------------------------------------------------ UI

func _build_hud() -> void:
	var back := _button(tr("PROTO_BACK"), 22, func() -> void: get_tree().change_scene_to_file.call_deferred(MAIN_SCENE))
	back.custom_minimum_size = Vector2(160, TOUCH_MIN)
	back.position = Vector2(16, 16)
	add_child(back)

	_status_label = _label(20)
	add_child(_status_label)
	_status_label.position = Vector2(192, 20)
	_status_label.size = Vector2(700, 30)

	# Motion status: shown only where the browser can send motion. A tap on it
	# (like any tap) lets iPhone Safari ask for permission.
	_motion_chip = _button("", 16, func() -> void:
		if _motion:
			_motion.request_permission())
	_motion_chip.anchor_left = 1.0
	_motion_chip.anchor_right = 1.0
	_motion_chip.offset_left = -360.0
	_motion_chip.offset_right = -16.0
	_motion_chip.offset_top = 100.0
	_motion_chip.offset_bottom = 150.0
	_motion_chip.custom_minimum_size = Vector2(0, 54)
	_motion_chip.clip_text = true
	_motion_chip.visible = false
	add_child(_motion_chip)

	_tension_label = _label(24)
	add_child(_tension_label)
	_top_center(_tension_label, 98.0, 32.0)
	_tension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance_label = _label(30)
	add_child(_distance_label)
	_top_center(_distance_label, 132.0, 40.0)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label = _label(30)
	add_child(_toast_label)
	_top_center(_toast_label, 200.0, 44.0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	_hint_label = _label(22)
	add_child(_hint_label)
	_top_center(_hint_label, 176.0, 32.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = tr("FISH_OVERMATCHED")
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_hint_label.visible = false

	# Fight controls.
	_reel_pad = _pad(tr("FIGHT_REEL"))
	_place_bottom(_reel_pad, false, Vector2(260, 300), 16.0)
	_reel_pad.gui_input.connect(_on_reel_input)
	_drag_slider = _pad(tr("FIGHT_DRAG"))
	_place_bottom(_drag_slider, true, Vector2(120, 300), 230.0)
	_drag_slider.gui_input.connect(_on_drag_input)
	_drag_label = _label(22)
	_drag_slider.add_child(_drag_label)
	_drag_label.set_anchors_preset(Control.PRESET_CENTER)
	_drag_label.offset_left = -60.0
	_drag_label.offset_right = 60.0
	_drag_label.offset_top = -14.0
	_drag_label.offset_bottom = 14.0
	_drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pull_button = _button(tr("FIGHT_PULL"), 28, Callable())
	_place_bottom(_pull_button, true, Vector2(200, 200), 16.0)
	_pull_button.button_down.connect(func() -> void: _pull_pressed = true)
	_pull_button.button_up.connect(func() -> void: _pull_pressed = false)
	# A second finger does not emulate a mouse, so listen to raw touch as well.
	_pull_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_pull_pressed = event.pressed)
	add_child(_pull_button)

	# Cast / strike: the same right-corner button.
	_main_button = _button(tr("FISH_CAST"), 32, Callable())
	_place_bottom(_main_button, true, Vector2(220, 200), 16.0)
	_main_button.button_down.connect(_on_main_down)
	_main_button.button_up.connect(_on_main_up)
	_main_button.gui_input.connect(_on_main_input)
	add_child(_main_button)

	# Wait controls on the left.
	_reel_in_button = _button(tr("FISH_REEL_IN"), 24, reel_in)
	_place_bottom(_reel_in_button, false, Vector2(200, TOUCH_MIN), 16.0)
	add_child(_reel_in_button)
	_speed_button = _button(tr("FISH_SPEED"), 24, func() -> void: _speed_on = not _speed_on)
	_speed_button.toggle_mode = true
	_place_bottom(_speed_button, false, Vector2(200, TOUCH_MIN), 16.0)
	_speed_button.offset_bottom -= TOUCH_MIN + 16.0
	_speed_button.offset_top -= TOUCH_MIN + 16.0
	add_child(_speed_button)

	# Ready controls on the left.
	_rig_button = _button(tr("FISH_RIG"), 24, func() -> void:
		_log_panel.visible = false
		_rig_panel.visible = not _rig_panel.visible)
	_place_bottom(_rig_button, false, Vector2(200, TOUCH_MIN), 16.0)
	add_child(_rig_button)
	_log_button = _button(tr("FISH_LOG"), 24, func() -> void:
		_rig_panel.visible = false
		_log_panel.visible = not _log_panel.visible
		_update_log())
	_place_bottom(_log_button, false, Vector2(200, TOUCH_MIN), 16.0)
	_log_button.offset_bottom -= TOUCH_MIN + 16.0
	_log_button.offset_top -= TOUCH_MIN + 16.0
	add_child(_log_button)


func _build_rig_panel() -> void:
	var box := _panel(Vector2(560, 0))
	_rig_panel = box.get_parent()
	_rig_panel.visible = false
	var title := _plain_label(tr("FISH_RIG"), 30)
	box.add_child(title)
	_rig_cycle = _button("", 24, func() -> void:
		set_rig(FightSetup.TACKLES[(FightSetup.TACKLES.find(rig) + 1) % FightSetup.TACKLES.size()], position_id))
	box.add_child(_rig_cycle)
	_position_cycle = _button("", 24, func() -> void:
		var positions: Array = _db["spot"][0]["positions"]
		set_rig(rig, positions[(_position_index(position_id) + 1) % positions.size()]["id"]))
	box.add_child(_position_cycle)
	_rig_label = _plain_label("", 18)
	_rig_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_rig_label)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: _rig_panel.visible = false))


func _build_result() -> void:
	var box := _panel(Vector2(600, 0))
	_result_panel = box.get_parent()
	_result_panel.visible = false
	_result_label = _plain_label("", 40)
	box.add_child(_result_label)
	_result_detail = _plain_label("", 22)
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_result_detail)
	_why_button = _button(tr("WHY_BUTTON"), 24, _show_why)
	box.add_child(_why_button)
	var again := _button(tr("FISH_CAST_AGAIN"), 28, func() -> void:
		_hud = {}
		_set_phase(Phase.READY))
	again.custom_minimum_size = Vector2(0, 110)
	box.add_child(again)


func _build_log() -> void:
	var box := _panel(Vector2(700, 0))
	_log_panel = box.get_parent()
	_log_panel.visible = false
	box.add_child(_plain_label(tr("LOG_TITLE"), 30))
	_log_text = _plain_label("", 20)
	_log_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_log_text)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: _log_panel.visible = false))


func _build_why() -> void:
	var box := _panel(Vector2(780, 0))
	_why_panel = box.get_parent()
	_why_panel.visible = false
	box.add_child(_plain_label(tr("WHY_TITLE"), 30))
	_why_text = _plain_label("", 18)
	_why_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_why_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_why_text)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void:
		_why_panel.visible = false
		_result_panel.visible = true))


## The catch attempt explained (PRD F10): the stage numbers behind the result
## in words the player can act on.
func _show_why() -> void:
	if _fight_ctx.is_empty() or _controller == null:
		return
	var resolved := CatchModel.resolve(_fight_ctx, _k)
	var stats := {
		"max_tension_kg": float(_hud["max_tension_kg"]), "drag_kg": float(_hud["drag_set_kg"]),
		"line_strength_kg": float(_hud["line_strength_kg"]), "distance_m": float(_hud["distance_m"]),
		"cap_applied": bool(_hud["cap_applied"]),
	}
	var lines := WhyReport.lines(resolved, _fight_ctx, tr(_fight_ctx["species"]["name_key"]), tr("SLOT_%s" % String(conditions["slot"]).to_upper()), String(_result["outcome"]), stats)
	var texts: Array[String] = []
	for l: Dictionary in lines:
		var args: Array = []
		for a: Variant in l["args"]:
			args.append(tr(a) if (typeof(a) == TYPE_STRING and (a as String).begins_with("WHY_")) else a)
		texts.append(tr(l["key"]) % args if not args.is_empty() else tr(l["key"]))
	texts.append(tr("DATA_NOTE"))
	_why_text.text = "\n\n".join(texts)
	_result_panel.visible = false
	_why_panel.visible = true


func _build_settings() -> void:
	_settings_button = _button(tr("SET_BUTTON"), 20, func() -> void:
		_rig_panel.visible = false
		_log_panel.visible = false
		_settings_panel.visible = not _settings_panel.visible)
	_settings_button.anchor_left = 1.0
	_settings_button.anchor_right = 1.0
	_settings_button.offset_left = -296.0
	_settings_button.offset_right = -156.0
	_settings_button.offset_top = 16.0
	_settings_button.offset_bottom = 88.0
	_settings_button.custom_minimum_size = Vector2(0, 72)
	add_child(_settings_button)
	var box := _panel(Vector2(640, 0))
	_settings_panel = box.get_parent()
	_settings_panel.visible = false
	box.add_child(_plain_label(tr("SET_TITLE"), 30))
	box.add_child(_plain_label(tr("SET_VOLUME"), 20))
	_vol_slider = _slider(0.0, 1.0, 0.05, func(v: float) -> void: _change_setting("volume", v))
	box.add_child(_vol_slider)
	box.add_child(_plain_label(tr("SET_MOTION"), 20))
	_sens_slider = _slider(0.5, 2.0, 0.1, func(v: float) -> void: _change_setting("motion_sens", v))
	box.add_child(_sens_slider)
	# Live view of what the phone reports, so a wrong reading can be seen.
	_mon_label = _plain_label("", 16)
	_mon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mon_label)
	_mon_pull = ProgressBar.new()
	_mon_pull.max_value = 1.0
	_mon_pull.show_percentage = false
	_mon_pull.custom_minimum_size = Vector2(0, 16)
	box.add_child(_mon_pull)
	_mon_jig = ProgressBar.new()
	_mon_jig.max_value = 1.0
	_mon_jig.show_percentage = false
	_mon_jig.custom_minimum_size = Vector2(0, 16)
	box.add_child(_mon_jig)
	box.add_child(_button(tr("SET_RECENTER"), 20, func() -> void: _gesture.calibrated = false))
	var help := _plain_label(tr("SET_MOTION_HELP"), 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	_flip_check = CheckButton.new()
	_flip_check.text = tr("SET_INVERT")
	_flip_check.add_theme_font_size_override("font_size", 22)
	_flip_check.custom_minimum_size = Vector2(0, TOUCH_MIN * 0.8)
	_flip_check.toggled.connect(func(on: bool) -> void:
		_change_setting("motion_flip", on)
		_store())
	box.add_child(_flip_check)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: _settings_panel.visible = false))


func _slider(lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(0, 56)
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool) -> void: _store())
	return s


func _change_setting(key: String, value: Variant) -> void:
	SaveGame.set_setting(save, key, value)
	_apply_settings()


## Puts the saved settings to work: sound volume, motion sensitivity and
## direction. Also moves the controls to the saved values.
func _apply_settings() -> void:
	var st := SaveGame.settings_of(save)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(st["volume"]), 0.0001)))
	_gesture.sensitivity = float(st["motion_sens"])
	if _motion:
		_motion.set_flip(bool(st["motion_flip"]))
	if _vol_slider and not is_equal_approx(_vol_slider.value, float(st["volume"])):
		_vol_slider.set_value_no_signal(float(st["volume"]))
	if _sens_slider and not is_equal_approx(_sens_slider.value, float(st["motion_sens"])):
		_sens_slider.set_value_no_signal(float(st["motion_sens"]))
	if _flip_check and _flip_check.button_pressed != bool(st["motion_flip"]):
		_flip_check.set_pressed_no_signal(bool(st["motion_flip"]))


func _build_audio() -> void:
	for cue: String in ["nibble", "take", "landed"]:
		var player := AudioStreamPlayer.new()
		player.stream = CueSynth.make(cue)
		add_child(player)
		_audio[cue] = player


func _build_debug() -> void:
	if not (OS.is_debug_build() or OS.has_feature("mera_debug")):
		return
	if not ResourceLoader.exists(DEBUG_MENU):
		return
	var script: GDScript = load(DEBUG_MENU)
	_debug_menu = script.new(self)
	add_child(_debug_menu)


func _play(cue: String) -> void:
	var player: AudioStreamPlayer = _audio.get(cue)
	if player and player.is_inside_tree():
		player.play()


func _snd(name_id: String, volume_db: float) -> void:
	if _sound:
		_sound.play(name_id, volume_db)


func _store() -> void:
	if save_enabled:
		SaveFile.store(save)


func _toast(text: String, seconds: float) -> void:
	_toast_label.text = text
	_toast_s = seconds
	_toast_label.visible = true


func _show_result() -> void:
	var outcome: String = _result["outcome"]
	_result_label.text = tr("FIGHT_%s" % outcome.to_upper())
	var lines: Array[String] = []
	if outcome == FightSim.OUTCOME_LANDED:
		lines.append(tr("FISH_CATCH") % [tr(_fight_ctx["species"]["name_key"]), _result["length_cm"], _result["weight_kg"]])
		if _result.get("first", false):
			lines.append(tr("FISH_FIRST"))
		elif _result.get("length_record", false) or _result.get("weight_record", false):
			lines.append(tr("FISH_RECORD"))
		var rule: Dictionary = _fight_ctx["species"].get("regulation", {})
		if rule.has("min_length_cm") and float(_result["length_cm"]) < float(rule["min_length_cm"]):
			lines.append(tr("FISH_UNDERSIZE") % float(rule["min_length_cm"]))
	lines.append(tr("FIGHT_DETAIL") % [_hud["time_s"], _hud["max_tension_kg"], _hud["line_strength_kg"]])
	if _hud["cap_applied"]:
		lines.append(tr("FIGHT_CAP"))
	lines.append(tr("DATA_NOTE"))
	_result_detail.text = "\n".join(lines)
	_reel_pressed = false
	_pull_pressed = false


func _update_log() -> void:
	var lines: Array[String] = []
	for entry: Dictionary in _db["spot"][0]["species"]:
		var id: String = entry["species_id"]
		var species_name := tr(_species_by_id(id)["name_key"])
		if save["log"].has(id):
			var e: Dictionary = save["log"][id]
			lines.append(tr("LOG_ROW") % [species_name, int(e["count"]), float(e["best_length_cm"]), float(e["best_weight_kg"]), e["first_seen"]])
		else:
			lines.append(tr("LOG_EMPTY_ROW") % species_name)
	lines.append("")
	lines.append(tr("DATA_NOTE"))
	_log_text.text = "\n".join(lines)


func _update_texts() -> void:
	if _status_label == null or _ctx.is_empty():
		return
	_strike_flash = maxf(_strike_flash - get_process_delta_time(), 0.0)
	_status_label.modulate.a = 0.0 if _settings_panel.visible else 1.0
	if _mon_label and _settings_panel.visible:
		if _motion and _motion.available:
			_mon_label.text = tr("SET_MON_TEXT") % [rad_to_deg(float(_motion_state.get("tilt", 0.0))), _motion.pitch_rate, 100.0 * float(_motion_state.get("pull", 0.0)), 100.0 * float(_motion_state.get("jig", 0.0))]
			if _strike_flash > 0.0:
				_mon_label.text += "  " + tr("SET_MON_STRIKE")
			_mon_pull.value = float(_motion_state.get("pull", 0.0))
			_mon_jig.value = float(_motion_state.get("jig", 0.0))
		else:
			_mon_label.text = tr("SET_MON_NONE")
	if _motion_chip and _motion:
		var st := _motion.status()
		_motion_chip.visible = st != DeviceMotion.STATUS_NONE and phase != Phase.RESULT
		_motion_chip.text = tr({DeviceMotion.STATUS_ON: "MOTION_ON", DeviceMotion.STATUS_TAP: "MOTION_TAP", DeviceMotion.STATUS_DENIED: "MOTION_DENIED"}.get(st, "MOTION_ON"))
	var pos: Dictionary = _ctx["position"]
	_status_label.text = tr(_db["spot"][0]["name_key"]) + " · " + tr("FISH_STATUS") % [tr("SLOT_%s" % String(conditions["slot"]).to_upper()), conditions["wind_dir"], int(conditions["wind_ms"]), tr(pos["name_key"])]
	_rig_cycle.text = "%s: %s" % [tr("FIGHT_TACKLE"), tr(_ctx["rod"]["name_key"])]
	_position_cycle.text = "%s: %s" % [tr("FISH_POSITION"), tr(pos["name_key"])]
	var cast_check := CatchModel.cast(_k, _ctx["rod"], _ctx["lure"], _ctx["angler"], pos, conditions, 1.0)
	_rig_label.text = tr("FISH_RIG_INFO") % [tr(_ctx["lure"]["name_key"]), float(cast_check["cast_max_m"])]
	if cast_check["lure_out_of_range"]:
		_rig_label.text += "\n" + tr("RIG_WARN_RANGE")
	_speed_button.button_pressed = _speed_on
	match phase:
		Phase.WAIT:
			_distance_label.text = "%.1f m" % float(_wait_state.get("lure_distance_m", 0.0))
		Phase.FIGHT:
			_tension_label.text = "%.2f / %.2f kg" % [_hud["tension_kg"], _hud["line_strength_kg"]]
			_distance_label.text = "%.1f m" % _hud["distance_m"]
			_drag_label.text = "%.1f kg" % _hud["drag_set_kg"]


## Text for the debug menu's "why" view (PRD F10): the last stage numbers.
func debug_info() -> String:
	var lines: Array[String] = []
	lines.append("env chop %.2f clarity %.1f light %.2f visibility %.2f" % [_env["chop"], _env["clarity_eff"], _env["light"], _env["visibility"]])
	if not _cast.is_empty():
		lines.append("cast %.1f m of %.1f max (fit %.2f, headwind %.2f)" % [_cast["cast_m"], _cast["cast_max_m"], _cast["weight_fit"], _cast["headwind"]])
	if _wait:
		lines.append("median wait here %.0f s" % _wait.median_wait_s())
		for e: Dictionary in _wait.events.slice(maxi(_wait.events.size() - 4, 0)):
			lines.append("%.1fs %s %s" % [e["time_s"], e["event"], e.get("species_id", "")])
		var last_take := {}
		for e: Dictionary in _wait.events:
			if e["event"] == "take":
				last_take = e
		if not last_take.is_empty():
			var st: Dictionary = last_take["stages"]
			lines.append("take %s: depth %.1f presence %.2f attraction %.2f commit %.2f window %.2fs" % [last_take["species_id"], st["water_depth_m"], st["presence"]["presence"], st["attraction"]["attraction"], st["commit"]["commit"], last_take["window_s"]])
	if _controller:
		var s := _controller.sim
		lines.append("fight W %.2f kg Fmax %.2f line %.2f hook_hold %.2f landing_q %.2f" % [s.weight_kg, s.f_max, s.b_eff, s.hook_hold, s.landing_q])
		lines.append("estimated fight %.0f s%s" % [_controller.estimated_fight_s, " (over the 90 s cap)" if _controller.overmatched else ""])
	if _motion and _motion.available:
		lines.append("motion pitch %.0f deg rate %.1f rad/s pull %.2f jig %.2f (%s)" % [rad_to_deg(_motion.pitch), _motion.pitch_rate, float(_motion_state.get("pull", 0.0)), float(_motion_state.get("jig", 0.0)), _motion.permission])
	else:
		lines.append("motion: no sensor data (%s); tap water to jig: %.2f" % [_motion.permission if _motion else "-", _tap_jig])
	lines.append("wind across screen %.0f px/s2; rod bend %.2f rad" % [wind_accel(), _rod.total_bend()])
	lines.append("fps avg %.0f, worst 1%% %.0f over %.0f s" % [_stats.average_fps(), _stats.low_1pct_fps(), _stats.seconds()])
	return "\n".join(lines)


func _species_by_id(id: String) -> Dictionary:
	for sp: Dictionary in _db["species"]:
		if sp["id"] == id:
			return sp
	return {}


func _position_index(id: String) -> int:
	var positions: Array = _db["spot"][0]["positions"]
	for i in positions.size():
		if positions[i]["id"] == id:
			return i
	return -1


# ------------------------------------------------------------------ widgets

func _place_bottom(control: Control, right_side: bool, control_size: Vector2, dx: float) -> void:
	var edge := 1.0 if right_side else 0.0
	control.anchor_left = edge
	control.anchor_right = edge
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	if right_side:
		control.offset_right = -dx
		control.offset_left = -dx - control_size.x
	else:
		control.offset_left = dx
		control.offset_right = dx + control_size.x
	control.offset_bottom = -16.0
	control.offset_top = -16.0 - control_size.y


func _top_center(control: Control, y: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.offset_left = -300.0
	control.offset_right = 300.0
	control.offset_top = y
	control.offset_bottom = y + height


func _pad(caption: String) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := _label(24)
	label.text = caption
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 8.0
	label.offset_bottom = 38.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	panel.self_modulate = Color(1, 1, 1, 0.45)
	add_child(panel)
	return panel


## A centred panel; returns its VBox (the panel is the VBox's parent).
func _panel(min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = min_size
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _button(text: String, font_size: int, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, TOUCH_MIN * 0.8)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _plain_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
