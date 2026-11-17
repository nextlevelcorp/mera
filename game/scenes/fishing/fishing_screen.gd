class_name FishingScreen
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
const DEBUG_MENU := "res://debug/debug_menu.gd"
const NEAR_DRAW_M := 4.6  ## drawing depth of the angler's feet; the camera cannot see nearer
## The fish body is drawn this many times its size: at true scale a 20 cm fish
## seen head-on from the shore is a few pixels across and cannot be read.
const FISH_DRAW_SCALE := 2.0
const POWER_PERIOD_S := 1.4
const SPEED_UP := 4.0

enum Phase { READY, CHARGE, FLIGHT, WAIT, FIGHT, LIFT, RESULT }

const LIFT_RISE_S := 0.8   ## landed fish: time to swing it up out of the water
const LIFT_HOLD_S := 1.8   ## then it hangs and kicks before the result shows

## Emitted by leave() with the FishingResult.
signal finished(result: Dictionary)

## The FishingRequest (Game.fishing_request) this session was started with; set before setup().
var request := {}
var _trip := Game.empty_result()

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
var _overlay: FishingOverlay
var _ui: FishingHud
## Widgets the tests and the debug menu read; they live on the HUD.
var _reel_pad: Control:
	get: return _ui.reel_pad
var _vol_slider: HSlider:
	get: return _ui.vol_slider
var _why_panel: Control:
	get: return _ui.why_panel
var _why_text: Label:
	get: return _ui.why_text
var _result_panel: Control:
	get: return _ui.result_panel
var _result_label: Label:
	get: return _ui.result_label
var _log_text: Label:
	get: return _ui.log_text
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
var _neighbours := NeighborAnglers.new(5)
var _shoals: ShoalField
var _gulls: GullFlock
var _boil_clock := 0.0
var _shoal_hint_shown := false
var _view_yaw := WaterView.BRIDGE_YAW
var _last_contact_s := -99.0   ## when a fish last touched the lure (_time)
var _strike_flash := 0.0
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

var _was_jumping := false
var _was_landing := false
var _was_kicking := false
var _steer_hint_shown := false
var _strike_queued := false

var _debug_menu: Control


func _ready() -> void:
	setup()
	add_child(DeviceGuard.new())


## Everything except the portrait guard, so tests can run it without a viewport.
## save_path empty: do not read or write a save (tests).
func setup(save_path: String = SaveFile.DEFAULT_PATH) -> void:
	if not Db.ok():
		push_error("Game data failed to load: %s" % str(Db.errors))
		return
	_db = Db.database()
	_k = Db.constants()
	Profile.open(save_path)
	save = Profile.save
	save_status = Profile.status
	save_enabled = Profile.persistent()
	if not (request.get("conditions", {}) as Dictionary).is_empty():
		conditions = request["conditions"]
	elif save_enabled:
		# Real place, real time: the slot, month and wind come from the phone's clock.
		conditions = SessionConditions.from_clock(Time.get_datetime_dict_from_system())
	if String(request.get("rig", "")) in FightSetup.TACKLES:
		rig = request["rig"]
	elif save["last_rig"] in FightSetup.TACKLES:
		rig = save["last_rig"]
	if _position_index(String(request.get("position_id", ""))) >= 0:
		position_id = request["position_id"]
	elif _position_index(save["last_position"]) >= 0:
		position_id = save["last_position"]
	else:
		position_id = _db["spot"][0]["positions"][0]["id"]
	_rng.seed = 7
	# Shoals of the hour: the same for everyone at the same place and time.
	_shoals = ShoalField.new(_k, int(conditions["month"]) * 1000 + int(Time.get_datetime_dict_from_system()["hour"]) if save_enabled else 77)
	_gulls = GullFlock.new(_shoals.shoals.size())
	_water = WaterView.new()
	add_child(_water)
	_overlay = FishingOverlay.new(self)
	add_child(_overlay)
	_ui = FishingHud.new(self)
	add_child(_ui)
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

## Shoals drift, gulls work over them, and the water boils where they feed.
func _step_shoals(delta: float) -> void:
	_shoals.advance(delta)
	_gulls.update(delta, _shoals)
	for hit: Vector2 in _gulls.take_dives():
		_fx.add_ring(hit, 0.3, 1.2, 0.7)
		_fx.splash(WaterView.project(hit, 0.0, _overlay.size), hit, 0.25)
	_boil_clock -= delta
	if _boil_clock <= 0.0:
		_boil_clock = 0.22
		for s: Dictionary in _shoals.shoals:
			var power := ShoalField.strength(s)
			if _rng.randf() < power:
				var at: Vector2 = (s["pos"] as Vector2) + Vector2.from_angle(_rng.randf() * TAU) * float(s["radius"]) * sqrt(_rng.randf()) * 0.8
				_fx.add_ring(at, 0.15, 0.5 + 0.5 * _rng.randf(), 0.5)
	if phase == Phase.READY and not _shoal_hint_shown and _time > 4.0:
		_shoal_hint_shown = true
		_toast(tr("FISH_SHOAL_HINT"), 5.0)


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
	_ui.reel_pad.visible = fight or p == Phase.WAIT   # in the wait the left thumb sets the retrieve
	_ui.drag_slider.visible = fight
	_ui.pull_button.visible = fight
	_ui.tension_label.visible = fight
	_ui.status_label.visible = p in [Phase.READY, Phase.CHARGE, Phase.FLIGHT, Phase.WAIT]
	_ui.hint_label.visible = fight and _controller != null and _controller.overmatched
	_ui.main_button.visible = p in [Phase.READY, Phase.CHARGE, Phase.WAIT]
	_ui.main_button.text = tr("FISH_STRIKE") if p == Phase.WAIT else tr("FISH_CAST")
	_ui.reel_in_button.visible = p == Phase.WAIT
	_ui.speed_button.visible = p == Phase.WAIT
	_ui.rig_button.visible = p == Phase.READY
	_ui.log_button.visible = p in [Phase.READY, Phase.RESULT]
	_ui.distance_label.visible = p in [Phase.WAIT, Phase.FIGHT]
	_ui.depth_label.visible = p == Phase.WAIT
	_ui.result_panel.visible = p == Phase.RESULT
	_ui.settings_button.visible = p in [Phase.READY, Phase.WAIT]
	if p != Phase.RESULT:
		_ui.why_panel.visible = false
	if p != Phase.READY and p != Phase.WAIT:
		_ui.settings_panel.visible = false
	if p != Phase.READY:
		_ui.rig_panel.visible = false
		_ui.log_panel.visible = false
	if p != Phase.WAIT:
		_speed_on = false
	if p == Phase.WAIT:
		_ui.reel_pressed = false
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
	_trip["casts"] = int(_trip["casts"]) + 1
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
	_wait.shoals = _shoals
	_wait.lure_x0 = -0.3
	_wait.lure_x_per_m = tan(_aim_x)
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
	var input := {"strike": _strike_queued, "jig": jig_amount(),
		"reel": FightController.reel_from_pad(_ui.reel_pressed, _ui.reel_y, _ui.reel_pad.size.y)}
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
	var overrides := {"cast_m": d, "hook_distance_m": d, "timing_quality": hooked["timing_quality"]}
	# What the player did with the lure is what the "why" view explains.
	for key: String in ["lure_depth_m", "retrieve_speed"]:
		if hooked.has(key):
			overrides[key] = hooked[key]
	_fight_ctx = _base_context(hooked["species_id"], overrides)
	_fight_ctx["play"]["fish_length_cm"] = FightController.draw_length_cm(_fight_ctx["species"], u)
	_ui.drag_ratio = clampf(float(_fight_ctx["play"]["drag_kg"]) / float(_fight_ctx["reel"]["drag_max_kg"]), 0.0, 1.0)
	_controller = FightController.new(_fight_ctx, _k, _seed_counter)
	_hud = _controller.hud()
	_fish = FishBody.new(float(_fight_ctx["play"]["fish_length_cm"]) / 100.0, _fish_world())
	_fx = SplashFx.new(_seed_counter)
	_last_state = ""
	_last_distance = -1.0
	_ui.reel_pressed = false
	_ui.pull_pressed = false
	_ui.steer = 0.0
	_was_jumping = false
	_was_landing = false
	_was_kicking = false
	_snd("splash", -6.0)
	_set_phase(Phase.FIGHT)


func current_input() -> Dictionary:
	return {
		"reel": FightController.reel_from_pad(_ui.reel_pressed, _ui.reel_y, _ui.reel_pad.size.y),
		"rod": maxf(FightController.rod_from_button(_ui.pull_pressed), float(_motion_state.get("pull", 0.0))),
		"drag_kg": FightController.drag_from_slider(_ui.drag_ratio, _controller.drag_max_kg),
		"steer": _ui.steer if _ui.pull_pressed else 0.0,
	}


## For tests and the debug menu: hold or release the two thumbs.
func set_fight_input(reel_pressed: bool, reel_y: float, pull_pressed: bool, drag_ratio: float) -> void:
	_ui.reel_pressed = reel_pressed
	_ui.reel_y = reel_y
	_ui.pull_pressed = pull_pressed
	_ui.drag_ratio = drag_ratio


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
	(_trip["events"] as Array).append({"type": outcome, "species_id": sp["id"]})
	if outcome == FightSim.OUTCOME_LANDED:
		(_trip["catches"] as Array).append({"species_id": sp["id"], "length_cm": _result["length_cm"], "weight_kg": _result["weight_kg"], "kept": true})
	elif outcome in [FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT]:
		(_trip["lost"] as Array).append({"item_id": _fight_ctx["lure"]["id"], "reason": outcome})
	if outcome == FightSim.OUTCOME_LANDED:
		_result.merge(SaveGame.record_catch(save, sp["id"], _result["length_cm"], _result["weight_kg"], Time.get_date_string_from_system()))
		_store()
		_play("landed")
		if _hud["in_landing"]:
			# The player reeled it up: it is already hanging at the rail.
			_lift_t = LIFT_RISE_S
		else:
			_lift_t = 0.0
			_lift_from = WaterView.project(_fish_world(), 0.0, _overlay.size)
			_swing = 1.1
			_swing_v = 0.0
			_fx.splash(_lift_from, _fish_world(), 0.9)
			_snd("splash", -2.0)
		_set_phase(Phase.LIFT)
		return
	if outcome == FightSim.OUTCOME_LOST_AT_EDGE:
		# It drops back into the water.
		_fx.splash(_lift_from, _fish_world(), 0.9)
		_snd("splash", -2.0)
	_show_result()
	_set_phase(Phase.RESULT)


## The landed fish is swung out of the water and hangs from the line: a
## damped pendulum (pillar 3: oscillation) kicked by the fish's own flapping.
func _step_lift(delta: float) -> void:
	_lift_t += delta
	var gravity_term := -12.0 * sin(_swing)
	var kick := 0.0
	if _landing_now():
		if _hud["kicking"]:
			kick = 16.0 * sin(_time * 9.0)
	elif _lift_t > LIFT_RISE_S:
		kick = 9.0 * sin(_lift_t * 7.3) * maxf(0.0, sin(_lift_t * 1.7))
	_swing_v += (gravity_term - 1.6 * _swing_v + kick) * delta
	_swing += _swing_v * delta
	_drip_clock -= delta
	if _drip_clock <= 0.0 and (_lift_t > LIFT_RISE_S * 0.5 or _landing_now()):
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
	var r := float(_hud["lift"]) if _landing_now() else smoothstep(0.0, LIFT_RISE_S, _lift_t)
	var mouth := _lift_from.lerp(hang, r) + Vector2(0.0, -size.y * 0.08 * sin(PI * r))
	var length_px := _lift_length_px()
	var dir := Vector2(sin(_swing), cos(_swing))
	return PackedVector2Array([mouth, mouth + dir * length_px])


## The fight's landing: the fish hangs on the line and the player reels it up.
func _landing_now() -> bool:
	return phase == Phase.FIGHT and not _hud.is_empty() and bool(_hud["in_landing"])


func _lift_length_px() -> float:
	var size := _overlay.size
	var aspect := size.x / maxf(size.y, 1.0)
	var px_per_m := size.x / ((NEAR_DRAW_M + 1.0) * aspect * WaterView.FOV)
	return clampf(float(_fight_ctx["play"]["fish_length_cm"]) / 100.0 * FISH_DRAW_SCALE * px_per_m, 40.0, 230.0)




func _fight_effects(delta: float) -> void:
	var pos := _fish_world()
	var state: String = _hud["fish_state"]
	if _fish:
		_fish.step(delta, pos, "landing" if _hud["in_landing"] else state)
	# A jump: the fish leaves the water; the player should ease the rod.
	var jumping: bool = _hud["jumping"]
	if jumping != _was_jumping:
		_fx.splash(WaterView.project(pos, 0.0, _overlay.size), pos, 1.0)
		_fx.add_ring(pos, 0.6, 2.0, 0.8)
		_snd("splash_heavy", -3.0)
		if jumping:
			Input.vibrate_handheld(40)
			_rod.kick(5.0)
		_was_jumping = jumping
	# The landing begins: the fish comes out of the water on the line.
	if _hud["in_landing"] and not _was_landing:
		_was_landing = true
		_lift_from = WaterView.project(pos, 0.0, _overlay.size)
		_swing = 0.5
		_swing_v = 0.0
		_fx.splash(_lift_from, pos, 0.8)
		_snd("splash", -3.0)
	if _hud["in_landing"]:
		_step_lift(delta)
		if _hud["kicking"] and not _was_kicking:
			_rod.kick(4.0)
			Input.vibrate_handheld(30)
		_was_kicking = _hud["kicking"]
		return
	if state == "run" and not _steer_hint_shown and float(_hud["time_s"]) > 1.0:
		_steer_hint_shown = true
		_toast(tr("FIGHT_STEER_HINT"), 4.0)
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
	var side := float(_hud.get("side_m", 0.0)) + sin(_time * 0.7) * 0.04 * d
	return Vector2(_lure_x(d) + side, NEAR_DRAW_M + d)


## Height of the fish above the water during a jump, in metres.
func _jump_height() -> float:
	if _hud.is_empty() or not _hud["jumping"]:
		return 0.0
	var total := float(_k["JUMP_S"])
	return 0.9 * sin(PI * clampf(1.0 - float(_hud["jump_left_s"]) / total, 0.0, 1.0))



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
			if _landing_now():
				return _lift_points()[0]
			return WaterView.project(_fish_world(), _jump_height(), size)
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
	var rest_tip := Vector2(size.x * (0.76 + 0.07 * (_ui.steer if phase == Phase.FIGHT and _ui.pull_pressed else 0.0)), size.y * 0.30)
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
		crank_target = 14.0 * float(_wait_state.get("retrieve_ms", 0.0)) / maxf(float(_ctx["reel"]["retrieve_m_per_s"]), 0.1)
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
	_trip["time_s"] = float(_trip["time_s"]) + delta
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
	# Getting ready the angler looks along the bridge; to cast and fish they
	# turn to the water (owner, 2026-11-16).
	_view_yaw = lerpf(_view_yaw, WaterView.BRIDGE_YAW if phase == Phase.READY else 0.0, minf(delta * 5.0, 1.0))
	_water.set_view_yaw(_view_yaw)
	_step_shoals(delta)
	if _on_bridge():
		_neighbours.update(delta)
		for e: Dictionary in _neighbours.take_events():
			_snd("splash", -24.0)   # a neighbour lifts a fish: a distant splash
	_toast_s = maxf(_toast_s - delta, 0.0)
	_ui.toast_label.visible = _toast_s > 0.0
	_fx.step(delta)
	_update_texts()
	_overlay.queue_redraw()


# ------------------------------------------------------------------ drawing





## True when the standing position is on a bridge deck (Galata): the
## foreground then shows the rail and the other anglers along it.
func _on_bridge() -> bool:
	return not _ctx.is_empty() and "bridge piers" in (_ctx["position"].get("structure_tags", []) as Array)
















# ------------------------------------------------------------------ input





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











## The catch attempt explained (PRD F10): the stage numbers behind the result
## in words the player can act on.
func _show_why() -> void:
	if _fight_ctx.is_empty() or _controller == null:
		return
	var resolved := CatchModel.resolve(_fight_ctx, _k)
	var stats := {
		"max_tension_kg": float(_hud["max_tension_kg"]), "drag_kg": float(_hud["drag_set_kg"]),
		"line_strength_kg": float(_hud["line_strength_kg"]), "distance_m": float(_hud["distance_m"]),
		"cap_applied": bool(_hud["cap_applied"]), "thrown_on_jump": bool(_hud["thrown_on_jump"]),
	}
	var lines := WhyReport.lines(resolved, _fight_ctx, tr(_fight_ctx["species"]["name_key"]), tr("SLOT_%s" % String(conditions["slot"]).to_upper()), String(_result["outcome"]), stats)
	var texts: Array[String] = []
	for l: Dictionary in lines:
		var args: Array = []
		for a: Variant in l["args"]:
			args.append(tr(a) if (typeof(a) == TYPE_STRING and (a as String).begins_with("WHY_")) else a)
		texts.append(tr(l["key"]) % args if not args.is_empty() else tr(l["key"]))
	texts.append(tr("DATA_NOTE"))
	_ui.why_text.text = "\n\n".join(texts)
	_ui.result_panel.visible = false
	_ui.why_panel.visible = true






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
	if _ui.vol_slider and not is_equal_approx(_ui.vol_slider.value, float(st["volume"])):
		_ui.vol_slider.set_value_no_signal(float(st["volume"]))
	if _ui.sens_slider and not is_equal_approx(_ui.sens_slider.value, float(st["motion_sens"])):
		_ui.sens_slider.set_value_no_signal(float(st["motion_sens"]))
	if _ui.flip_check and _ui.flip_check.button_pressed != bool(st["motion_flip"]):
		_ui.flip_check.set_pressed_no_signal(bool(st["motion_flip"]))


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
	Profile.flush()


## Leaves the fishing view: whoever opened it gets the result; opened on its
## own (tests, the old entry), it goes back to the title scene.
func leave() -> void:
	if finished.get_connections().is_empty():
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
	else:
		finished.emit(result())


## The session so far as a FishingResult (Game.empty_result).
func result() -> Dictionary:
	return _trip.duplicate(true)


func _toast(text: String, seconds: float) -> void:
	_ui.toast_label.text = text
	_toast_s = seconds
	_ui.toast_label.visible = true


func _show_result() -> void:
	var outcome: String = _result["outcome"]
	_ui.result_label.text = tr("FIGHT_%s" % outcome.to_upper())
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
	_ui.result_detail.text = "\n".join(lines)
	_ui.reel_pressed = false
	_ui.pull_pressed = false


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
	_ui.log_text.text = "\n".join(lines)


func _update_texts() -> void:
	if _ui.status_label == null or _ctx.is_empty():
		return
	_strike_flash = maxf(_strike_flash - get_process_delta_time(), 0.0)
	_ui.status_label.modulate.a = 0.0 if _ui.settings_panel.visible else 1.0
	if _ui.mon_label and _ui.settings_panel.visible:
		if _motion and _motion.available:
			_ui.mon_label.text = tr("SET_MON_TEXT") % [rad_to_deg(float(_motion_state.get("tilt", 0.0))), _motion.pitch_rate, 100.0 * float(_motion_state.get("pull", 0.0)), 100.0 * float(_motion_state.get("jig", 0.0))]
			if _strike_flash > 0.0:
				_ui.mon_label.text += "  " + tr("SET_MON_STRIKE")
			_ui.mon_pull.value = float(_motion_state.get("pull", 0.0))
			_ui.mon_jig.value = float(_motion_state.get("jig", 0.0))
		else:
			_ui.mon_label.text = tr("SET_MON_NONE")
	if _ui.motion_chip and _motion:
		var st := _motion.status()
		_ui.motion_chip.visible = st != DeviceMotion.STATUS_NONE and phase != Phase.RESULT
		_ui.motion_chip.text = tr({DeviceMotion.STATUS_ON: "MOTION_ON", DeviceMotion.STATUS_TAP: "MOTION_TAP", DeviceMotion.STATUS_DENIED: "MOTION_DENIED"}.get(st, "MOTION_ON"))
	var pos: Dictionary = _ctx["position"]
	_ui.status_label.text = tr(_db["spot"][0]["name_key"]) + " · " + tr("FISH_STATUS") % [tr("SLOT_%s" % String(conditions["slot"]).to_upper()), conditions["wind_dir"], int(conditions["wind_ms"]), tr(pos["name_key"])]
	_ui.rig_cycle.text = "%s: %s" % [tr("FIGHT_TACKLE"), tr(_ctx["rod"]["name_key"])]
	_ui.position_cycle.text = "%s: %s" % [tr("FISH_POSITION"), tr(pos["name_key"])]
	var cast_check := CatchModel.cast(_k, _ctx["rod"], _ctx["lure"], _ctx["angler"], pos, conditions, 1.0)
	_ui.rig_label.text = tr("FISH_RIG_INFO") % [tr(_ctx["lure"]["name_key"]), float(cast_check["cast_max_m"])]
	if cast_check["lure_out_of_range"]:
		_ui.rig_label.text += "\n" + tr("RIG_WARN_RANGE")
	_ui.speed_button.button_pressed = _speed_on
	match phase:
		Phase.WAIT:
			_ui.distance_label.text = "%.1f m" % float(_wait_state.get("lure_distance_m", 0.0))
			_ui.depth_label.text = tr("WAIT_HUD") % [float(_wait_state.get("depth_m", 0.0)), float(_wait_state.get("water_depth_m", 0.0)), float(_wait_state.get("retrieve_ms", 0.0))]
		Phase.FIGHT:
			_ui.tension_label.text = "%.2f / %.2f kg" % [_hud["tension_kg"], _hud["line_strength_kg"]]
			var landing: bool = _hud["in_landing"]
			_ui.drag_slider.visible = not landing
			_ui.pull_button.visible = not landing
			_ui.hint_label.visible = landing or _hud["jumping"] or _controller.overmatched
			if landing:
				_ui.hint_label.text = tr("LAND_WAIT") if _hud["kicking"] else tr("LAND_REEL")
			elif _hud["jumping"]:
				_ui.hint_label.text = tr("FIGHT_JUMP_HINT")
			else:
				_ui.hint_label.text = tr("FISH_OVERMATCHED")
			_ui.distance_label.text = "%.1f m" % _hud["distance_m"]
			_ui.drag_label.text = "%.1f kg" % _hud["drag_set_kg"]


## Text for the debug menu's "why" view (PRD F10): the last stage numbers.
func debug_info() -> String:
	var lines: Array[String] = []
	lines.append("env chop %.2f clarity %.1f light %.2f visibility %.2f" % [_env["chop"], _env["clarity_eff"], _env["light"], _env["visibility"]])
	if not _cast.is_empty():
		lines.append("cast %.1f m of %.1f max (fit %.2f, headwind %.2f)" % [_cast["cast_m"], _cast["cast_max_m"], _cast["weight_fit"], _cast["headwind"]])
	if _wait:
		lines.append("median wait here %.0f s; shoal boost x%.2f (nearest shoal %.0f m from the lure)" % [_wait.median_wait_s(), _wait.shoal_boost(), _shoals.nearest_m(_wait.lure_x0 + _wait.lure_x_per_m * _wait.lure_distance_m, _wait.lure_distance_m)])
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
