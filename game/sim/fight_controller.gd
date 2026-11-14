class_name FightController
extends RefCounted
## Drives a FightSim from frame time and player input and turns its state into
## what the fight screen shows. No nodes. Frame-rate independent: whatever the
## frame time, the simulation advances in fixed 30 Hz steps, so the same seed
## and the same input give the same fight on a 30 fps and a 144 fps phone.
##
## The screen never receives the fish's energy: the player reads the fish from
## tension, line-out, rod bend and splashes (spec 5.1).

const MAX_FRAME_S := 0.25

var sim: FightSim
var visible_at_m: float
var drag_max_kg: float
var max_tension_kg := 0.0
## PRD F19: the closed-form estimate says this fight would run past the 90 s
## cap on this tackle, so the player is told the fish is too big for it.
var overmatched := false
## Estimated fight length without the cap, for the "why" view.
var estimated_fight_s := 0.0

var _k: Dictionary
var _accum := 0.0
var _last_input := {"reel": 0.0, "rod": 0.0, "drag_kg": 0.0}


func _init(ctx: Dictionary, k: Dictionary, seed_value: int) -> void:
	_k = k
	var resolved := CatchModel.resolve(ctx, k)
	sim = FightSim.new(ctx, k, resolved["hook"]["hook"], seed_value)
	visible_at_m = float(resolved["landing"]["visible_at_m"])
	drag_max_kg = float(ctx["reel"]["drag_max_kg"])
	overmatched = bool(resolved["fight"]["cap_applied"])
	estimated_fight_s = float(resolved["fight"]["t_fight"])


## Advances by frame_s with the current input and returns the HUD state.
func advance(frame_s: float, input: Dictionary) -> Dictionary:
	_last_input = input
	_accum += minf(maxf(frame_s, 0.0), MAX_FRAME_S)
	while _accum >= FightSim.DT and not sim.is_over():
		var state := sim.step(input)
		max_tension_kg = maxf(max_tension_kg, float(state["tension_kg"]))
		_accum -= FightSim.DT
	if sim.is_over():
		_accum = 0.0
	return hud()


func hud() -> Dictionary:
	var s := sim.snapshot()
	var strength: float = float(s["line_strength_kg"])
	return {
		"tension_kg": s["tension_kg"], "line_strength_kg": strength,
		"tension_ratio": float(s["tension_kg"]) / strength,
		"strain_ratio": float(s["strain_s"]) / float(_k["STRAIN_LIMIT_S"]),
		"strain_threshold_ratio": float(_k["STRAIN_SHARE"]),
		"distance_m": s["distance_m"],
		"fish_visible": float(s["distance_m"]) <= visible_at_m or s["in_landing"],
		"in_landing": s["in_landing"],
		"fish_state": s["fish_state"], "time_s": s["time_s"],
		"outcome": s["outcome"], "cap_applied": s["cap_applied"],
		"max_tension_kg": max_tension_kg, "drag_set_kg": float(_last_input.get("drag_kg", 0.0)),
	}


## Left pad: held, and how high the thumb is on the pad sets the reel effort.
## pad_y is measured from the top of the pad.
static func reel_from_pad(pressed: bool, pad_y: float, pad_height: float) -> float:
	if not pressed or pad_height <= 0.0:
		return 0.0
	return clampf(1.0 - pad_y / pad_height, 0.0, 1.0)


## Right slider: 0 at the bottom, 1 at the top, mapped to the reel's drag range.
static func drag_from_slider(slider_ratio: float, drag_max: float) -> float:
	return clampf(slider_ratio, 0.0, 1.0) * drag_max


## Right pad: pulling the rod tip against the fish's run.
static func rod_from_button(pressed: bool) -> float:
	return 1.0 if pressed else 0.0


## A fish length for a species, small fish common, big fish rare (data_model.md 5.5).
static func draw_length_cm(species: Dictionary, u: float) -> float:
	var lo: float = float(species["length_min_cm"])
	var hi: float = float(species["length_max_cm"])
	return lo + (hi - lo) * u * u
