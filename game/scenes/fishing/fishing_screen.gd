extends Control
## The fishing loop of the 0.1 slice on demo data (PRD F4-F11, F14): rig,
## cast, wait and read, bite and strike, fight, land, log, cast again. A thin
## view: CatchModel, WaitSim and FightController own every rule; this scene
## reads their state, draws it and sends input. Demo data in res://data/demo
## is design fill, not a real place or real fish.
##
## Controls, landscape, thumbs on the corners (spec 6.1):
##   ready   right: hold Cast, let go at the top of the power swing
##   wait    right: Strike; left: reel in, faster waiting
##   fight   left pad: reel (higher thumb = more effort); right: drag slider
##           (up = more drag) and Pull (rod against the fish's run)

const MAIN_SCENE := "res://scenes/main.tscn"
const DEMO_DIR := "res://data/demo"
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
var position_id := "pier_end"
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
var _log_text: Label
var _debug_menu: Control


func _ready() -> void:
	setup()
	add_child(DeviceGuard.new())


## Everything except the portrait guard, so tests can run it without a viewport.
## save_path empty: do not read or write a save (tests).
func setup(save_path: String = SaveFile.DEFAULT_PATH) -> void:
	var loaded := DataStore.load_all(DEMO_DIR)
	if not loaded["ok"]:
		push_error("Demo data failed to load: %s" % str(loaded["errors"]))
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
	_build_audio()
	_sound = SoundDirector.new()
	add_child(_sound)
	apply_conditions()
	_build_debug()
	_set_phase(Phase.READY)
	if save_status == SaveGame.STATUS_RESET:
		_toast(tr("SAVE_RESET"), 5.0)
	elif save_status == SaveGame.STATUS_MIGRATED:
		_toast(tr("SAVE_MIGRATED"), 4.0)


# ------------------------------------------------------------------ state

## Recomputes the environment from the conditions and updates the water.
func apply_conditions() -> void:
	_ctx = _base_context("istavrit")
	_env = CatchModel.environment(_k, _ctx["spot"], _ctx["position"], conditions)
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
	if p != Phase.READY:
		_rig_panel.visible = false
		_log_panel.visible = false
	if p != Phase.WAIT:
		_speed_on = false
	_update_texts()


# ------------------------------------------------------------------ cast

func begin_charge() -> void:
	if phase != Phase.READY:
		return
	_charge_s = 0.0
	_set_phase(Phase.CHARGE)


## The power swing: rises to 1 and falls back, so letting go at the top is the skill.
static func power_at(charge_s: float) -> float:
	var t := fmod(charge_s / POWER_PERIOD_S, 1.0)
	return 1.0 - absf(1.0 - 2.0 * t)


func release_cast() -> void:
	if phase != Phase.CHARGE:
		return
	cast_with_power(maxf(power_at(_charge_s), 0.15))


func cast_with_power(power: float) -> void:
	_cast = CatchModel.cast(_k, _ctx["rod"], _ctx["lure"], _ctx["angler"], _ctx["position"], conditions, power)
	_cast["cast_m"] = maxf(float(_cast["cast_m"]), float(_k["WAIT_END_M"]) + 2.0)
	_aim_x = clampf(_rng.randfn(0.0, float(_cast["aim_sigma_rad"])), -0.5, 0.5)
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
	var input := {"strike": _strike_queued}
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


func _on_wait_event(e: Dictionary) -> void:
	var world := Vector2(_lure_x(float(e["lure_distance_m"])), NEAR_DRAW_M + float(e["lure_distance_m"]))
	match e["event"]:
		"nibble":
			_tip_vel -= 6.0
			_fx.add_ring(world, 0.35, 0.8, 0.35)
			_play("nibble")
		"take":
			_tip_vel -= 22.0
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
		"rod": FightController.rod_from_button(_pull_pressed),
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
	if _sound and delta > 0.0 and _last_distance >= 0.0:
		_sound.set_reel((d - _last_distance) / delta, _hud["outcome"] == "")
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
	var tip := _rod_tip(0.7)
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
	_overlay.draw_line(tip, mouth, Color(1, 1, 1, 0.9), 1.5, true)
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
		_last_state = state
	_splash_clock -= delta
	if _splash_clock <= 0.0 and (state == "thrash" or (_hud["in_landing"] and state != "rest")):
		_splash_clock = 0.45
		_fx.splash(WaterView.project(pos, 0.0, _overlay.size), pos, 0.7)
		_snd("splash_heavy", -8.0)


## Where the fish is on the water: out along the line by the simulation's
## distance (plus the drawing offset), drifting sideways with its state.
func _fish_world() -> Vector2:
	var d := float(_hud.get("distance_m", 0.0))
	var side := sin(_time * 0.7) * 0.12 * d + (0.08 * d if _hud.get("fish_state", "") == "run" else 0.0)
	return Vector2(_lure_x(d) + side, NEAR_DRAW_M + d)


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	_time += delta
	_stats.add(delta)
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
	var bend := 0.0
	var lifted: bool = phase == Phase.LIFT or (phase == Phase.RESULT and _result.get("outcome", "") == FightSim.OUTCOME_LANDED)
	match phase:
		Phase.FIGHT, Phase.RESULT:
			bend = clampf(float(_hud.get("tension_ratio", 0.0)), 0.0, 1.2)
		Phase.LIFT:
			bend = 0.7
		Phase.WAIT:
			bend = clampf(_tip_kick, -0.2, 1.2)
		Phase.CHARGE:
			bend = -0.25 * power_at(_charge_s)
	var tip := _rod_tip(bend)
	match phase:
		Phase.FLIGHT:
			var s := clampf(_flight_s / _flight_total_s, 0.0, 1.0)
			var d := float(_cast["cast_m"]) * s
			var h := 4.0 * float(_cast["cast_m"]) * 0.25 * s * (1.0 - s) + 2.0 * (1.0 - s)
			var lure := WaterView.project(Vector2(_lure_x(d), NEAR_DRAW_M + d), h, size)
			_draw_line_to(tip, lure, 0.6, false)
			_overlay.draw_circle(lure, 4.0, Color(0.95, 0.75, 0.3))
		Phase.WAIT:
			var dw := float(_wait_state.get("lure_distance_m", 0.0))
			var lure := WaterView.project(Vector2(_lure_x(dw), NEAR_DRAW_M + dw), 0.03 * sin(_time * 2.1), size)
			_draw_line_to(tip, lure, clampf(bend, 0.0, 1.0) * 0.6, false)
			_overlay.draw_circle(lure, 3.0, Color(0.95, 0.75, 0.3))
		Phase.FIGHT, Phase.RESULT:
			if lifted:
				_draw_lifted_fish(_rod_tip(0.7))
			elif not _hud.is_empty():
				_draw_fight(size, tip, bend)
		Phase.LIFT:
			_draw_lifted_fish(tip)
	for p: Dictionary in _fx.particles:
		_overlay.draw_circle(p["pos"], p["size"], Color(0.92, 0.96, 1.0, 0.85 * float(p["life"]) / float(p["max_life"])))
	_draw_rod(size, _rod_tip(0.7) if lifted else tip, 0.7 if lifted else bend)
	if phase == Phase.FIGHT or (phase == Phase.RESULT and not _hud.is_empty()):
		_draw_tension_bar(size)
	if phase == Phase.CHARGE:
		_draw_power(size)


func _draw_fight(size: Vector2, tip: Vector2, ratio: float) -> void:
	var outcome: String = _hud["outcome"]
	var line_gone := outcome == FightSim.OUTCOME_LINE_BREAK or outcome == FightSim.OUTCOME_LEADER_CUT
	var pos := _fish_world()
	var fish_screen := WaterView.project(pos, 0.0, size)
	if not line_gone:
		_draw_line_to(tip, fish_screen, ratio, float(_hud["strain_ratio"]) > 0.0)
	if _hud["fish_visible"] and not line_gone and _fish:
		var pts := PackedVector2Array()
		for w: Vector2 in _fish.outline():
			pts.append(WaterView.project(_fish.head + (w - _fish.head) * FISH_DRAW_SCALE, 0.0, size))
		var shade := Color(0.05, 0.08, 0.1, 0.55 + 0.3 * float(_env.get("visibility", 0.5)))
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			_overlay.draw_colored_polygon(pts, shade)
		else:
			_overlay.draw_polyline(pts, shade, 3.0, true)


func _rod_tip(bend: float) -> Vector2:
	var size := _overlay.size
	return Vector2(size.x * (0.74 - 0.10 * bend), size.y * (0.32 + 0.12 * bend))


func _draw_rod(size: Vector2, tip: Vector2, bend: float) -> void:
	var butt := Vector2(size.x * 0.97, size.y * 1.02)
	var mid := butt.lerp(tip, 0.55) + Vector2(-0.04 * size.x * bend, 0.0)
	_overlay.draw_polyline(PackedVector2Array([butt, mid, tip]), Color(0.1, 0.1, 0.12), 7.0, true)


func _draw_line_to(tip: Vector2, end: Vector2, ratio: float, strained: bool) -> void:
	var points := PackedVector2Array()
	var sag := Vector2(0.0, 46.0 * clampf(1.0 - ratio * 1.6, 0.0, 1.0))
	for i in 25:
		var t := i / 24.0
		points.append(tip.lerp(end, t) + sag * sin(t * PI))
	_overlay.draw_polyline(points, Color(1.0, 0.85, 0.5, 0.95) if strained else Color(1, 1, 1, 0.85), 2.0 if strained else 1.5, true)


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
	if phase == Phase.READY:
		begin_charge()
	elif phase == Phase.WAIT:
		strike()


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
	lines.append(tr("FIGHT_DETAIL") % [_hud["time_s"], _hud["max_tension_kg"], _hud["line_strength_kg"]])
	if _hud["cap_applied"]:
		lines.append(tr("FIGHT_CAP"))
	lines.append(tr("FIGHT_NOTE"))
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
	lines.append(tr("FIGHT_NOTE"))
	_log_text.text = "\n".join(lines)


func _update_texts() -> void:
	if _status_label == null or _ctx.is_empty():
		return
	var pos: Dictionary = _ctx["position"]
	_status_label.text = tr("FISH_STATUS") % [tr("SLOT_%s" % String(conditions["slot"]).to_upper()), conditions["wind_dir"], int(conditions["wind_ms"]), tr(pos["name_key"])]
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
