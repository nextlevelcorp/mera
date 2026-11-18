class_name WorldScreen
extends Node2D
## The top-down world (architecture.md 4): one area (the Galata Bridge), a
## player walking with the stick under the left thumb, and the fishing
## markers on the rails. At a marker the action button fishes: the screen
## emits fish_requested with a FishingRequest and the owner (main.gd) opens
## the fishing view; resume() takes the result back. A view over WorldWalk,
## WorldArea, NpcRoster and Crowd: it holds no rules. Pixel art in a
## three-quarter view (owner, 2026-11-18: Stardew Valley style), drawn by
## WorldPainter and PixelArt.

signal fish_requested(request: Dictionary)
signal closed

const AREA_ID := "galata_bridge"
const DEBUG_MENU := "res://debug/world_debug.gd"
const STICK_RADIUS := 110.0
## The camera is close, as in Stardew Valley: three screen pixels per art
## pixel, about 27 m across at 1280 px.
const CAMERA_ZOOM := 3.0
## Slot tint over the whole world: the same conditions that light the sea.
const TINT := {
	"dawn": Color(1.0, 0.86, 0.82), "day": Color(1.0, 1.0, 1.0),
	"evening": Color(1.0, 0.76, 0.62), "night": Color(0.36, 0.42, 0.62),
}

var area: WorldArea
var walk: WorldWalk
var conditions := {}
## Where the save is read from; tests set "" to keep it in memory.
var profile_path := SaveFile.DEFAULT_PATH

var _cam: Camera2D
var _hud: CanvasLayer
var _pad: Control
var _knob: Panel
var _action: Button
var _prompt: Label
var _toast: Label
var _toast_s := 0.0
var _shop: ShopPanel
var _talk: TalkPanel
var _journal: Label
var _quests: Array = []
var _wallet: Label
var _stick := Vector2.ZERO
var _touching := false
var _time := 0.0
var _moving := false
var _audio: WorldAudio


func _ready() -> void:
	setup()


## Loads the area and builds the controls. conditions: set before for a fixed
## set (tests, the debug menu); empty gives the phone's clock.
func setup() -> void:
	var loaded := WorldArea.load_area(AREA_ID, Db.database())
	if not loaded["ok"]:
		push_error("World area failed to load: %s" % str(loaded["errors"]))
		return
	area = loaded["area"]
	Profile.open(profile_path)
	walk = WorldWalk.new(area, Db.constants())
	if conditions.is_empty():
		conditions = SessionConditions.from_clock(Time.get_datetime_dict_from_system())
	_build_art()
	var roster := NpcRoster.load_roster(area)
	if not roster["ok"]:
		push_error("NPC roster failed to load: %s" % str(roster["errors"]))
	for n: Dictionary in roster["npcs"]:
		var rec := n.duplicate()
		var c: Array = n["jacket"]
		rec["jacket_color"] = Color(c[0], c[1], c[2])
		var pal := PixelArt.palette(hash(n["id"]))
		pal["shirt"] = rec["jacket_color"].lightened(0.15)
		rec["frames"] = PixelArt.person(pal)
		_npcs.append(rec)
	var q := Quests.load_quests(roster["npcs"], Db.database(), Db.shop())
	if not q["ok"]:
		push_error("Quests failed to load: %s" % str(q["errors"]))
	_quests = q["quests"]
	apply_conditions()
	settle_npcs()
	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = int(-BACKDROP_M * area.px_per_m)
	_cam.limit_right = int(area.size_m.x * area.px_per_m)
	_cam.limit_bottom = int(area.size_m.y * area.px_per_m)
	_cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_cam.position = camera_target() * area.px_per_m
	add_child(_cam)
	if _cam.is_inside_tree():
		_cam.make_current()
	_audio = WorldAudio.new()
	add_child(_audio)
	_build_hud()
	_build_debug()


## Relights the world for the conditions' time of day: a canvas tint, the
## lamps after dark, and the passers-by of the slot.
func apply_conditions() -> void:
	_apply_art_light()
	_replan_npcs()


## Everyone gets their plan for the slot; someone who was away arrives from
## the plaza nearest their spot and walks there.
func _replan_npcs() -> void:
	var slot := String(conditions.get("slot", "day"))
	for n: Dictionary in _npcs:
		var p := NpcRoster.plan(n, slot, area)
		var st: Dictionary = _npc_state.get(n["id"], {"present": false, "phase": 0.0})
		if p["present"]:
			if not st["present"]:
				st["pos"] = NpcRoster.entry_point(p["pos"], area) if n["role"] == "angler" else p["pos"]
			st["target"] = p["pos"]
			st["fishing"] = p["fishing"]
			st["facing"] = p["facing"]
			st["position_id"] = p["position_id"]
		st["present"] = p["present"]
		_npc_state[n["id"]] = st


## Puts everyone where their plan says, at once (opening the world).
func settle_npcs() -> void:
	for id: String in _npc_state:
		var st: Dictionary = _npc_state[id]
		if st["present"]:
			st["pos"] = st["target"]


## The anglers fishing on the same side of the bridge as that marker, arrived.
func neighbours_of(marker: Dictionary) -> Array:
	var out: Array = []
	for n: Dictionary in _npcs:
		var st: Dictionary = _npc_state[n["id"]]
		if st["present"] and st["fishing"] and st["facing"] == marker["facing"] and (st["pos"] as Vector2).distance_to(st["target"]) < 0.3:
			out.append({"id": n["id"], "jacket": n["jacket_color"]})
	return out


## While the fishing view is open the world sleeps: hidden, not processed,
## and its camera off (a camera would shift every other 2D control).
func pause() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_canvas_tint.visible = false   # it would tint the fishing view's controls too
	_lights.visible = false
	_audio.fade_out()
	_hud.visible = false
	_cam.enabled = false
	_stick = Vector2.ZERO
	_touching = false


## Back from fishing: the result of the visit as a short toast.
func resume(result: Dictionary) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_canvas_tint.visible = true
	_lights.visible = true
	_audio.fade_in()
	_hud.visible = true
	_cam.enabled = true
	if _cam.is_inside_tree():
		_cam.make_current()
		_cam.reset_smoothing()
	show_toast(tr("TRIP_SUMMARY") % [int(result["casts"]), (result["catches"] as Array).size()], 4.0)


func show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast_s = seconds


## The FishingRequest for the marker in reach, or an empty dictionary.
func fishing_request() -> Dictionary:
	var m := walk.nearest_marker()
	if m.is_empty():
		return {}
	return Game.fishing_request(area.spot_id, m["position_id"], "", conditions.duplicate(), neighbours_of(m))


func fish() -> void:
	var request := fishing_request()
	if not request.is_empty():
		fish_requested.emit(request)


## The person in reach to talk to (present, standing still), or {}.
## A fishing marker nearer than them wins.
func talk_target() -> Dictionary:
	var people := {}
	for n: Dictionary in _npcs:
		var st: Dictionary = _npc_state[n["id"]]
		if st["present"] and (st["pos"] as Vector2).distance_to(st["target"]) < 0.3:
			people[n["id"]] = st["pos"]
	var reach := float(Db.constants()["INTERACT_M"])
	var id := NpcRoster.nearest(walk.pos, people, reach)
	if id == "":
		return {}
	var m := walk.nearest_marker()
	if not m.is_empty() and walk.pos.distance_to(m["pos"]) < walk.pos.distance_to(people[id]):
		return {}
	for n: Dictionary in _npcs:
		if n["id"] == id:
			return n
	return {}


## The action button: a shop in reach opens it, else someone in reach is
## talked to, else a fishing marker fishes.
func act() -> void:
	var shop := walk.nearest_shop()
	var person := talk_target()
	if not shop.is_empty():
		_shop.open(shop["id"])
	elif not person.is_empty():
		_talk.open(person)
	else:
		fish()


func _process(delta: float) -> void:
	if walk == null:
		return
	_time += delta
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	walk.step(delta, keys if keys.length() > 0.0 else _stick)
	var speed := float(Db.constants()["NPC_WALK_M_PER_S"])
	for n: Dictionary in _npcs:
		var st: Dictionary = _npc_state[n["id"]]
		if st["present"]:
			var before: Vector2 = st["pos"]
			st["pos"] = NpcRoster.walk_step(before, st["target"], delta, area, speed)
			st["phase"] = float(st["phase"]) + before.distance_to(st["pos"]) * 4.5
	var moved := walk.pos.distance_to(_last_pos)
	_moving = moved > 0.0001
	var stride := int(_walk_phase / 2.0)
	_walk_phase += moved * 4.5
	if int(_walk_phase / 2.0) != stride:
		_audio.step(walk.pos, area)   # one foot down every second walk frame
	_audio.update(delta, walk.pos, area, conditions, _time, Db.constants())
	_last_pos = walk.pos
	_cam.position = (camera_target() * area.px_per_m).round()
	var m := walk.nearest_marker()
	var shop := walk.nearest_shop()
	var person := talk_target()
	_action.visible = (not m.is_empty() or not shop.is_empty() or not person.is_empty()) and not _shop.visible and not _talk.visible
	if not shop.is_empty():
		_prompt.text = tr("SHOP_%s" % String(shop["id"]).to_upper())
		_action.text = tr("WORLD_OPEN_SHOP")
	elif not person.is_empty():
		_prompt.text = tr(person["name_key"])
		_action.text = tr("WORLD_TALK") % tr(person["name_key"])
	elif m.is_empty():
		_prompt.text = tr("WORLD_WALK_HINT")
	else:
		_prompt.text = tr(_position_name_key(m["position_id"]))
		_action.text = tr("WORLD_FISH_HERE")
	_wallet.text = "%s · %s" % [tr("MONEY_FMT") % Economy.money(Profile.save), tr("WORLD_BAG") % Inventory.fish_count(Profile.save)]
	_journal.text = journal_text()
	_toast_s = maxf(_toast_s - delta, 0.0)
	_toast.visible = _toast_s > 0.0
	queue_redraw()
	_boats.queue_redraw()


## Where the camera looks: at the player, and towards the landmarks at the
## ends of the area (the tower above Karaköy) as the player nears them.
func camera_target() -> Vector2:
	var near_top := clampf((12.0 - walk.pos.y) / 7.0, 0.0, 1.0)
	return walk.pos - Vector2(0.0, near_top * LOOK_AHEAD_M)


## The active quests' titles for the HUD, or "" with none.
func journal_text() -> String:
	var titles: Array[String] = []
	for q: Dictionary in _quests:
		if Quests.is_active(Profile.save, q["id"]):
			titles.append(tr(q["title_key"]))
	return tr("QUEST_JOURNAL") % ", ".join(titles) if not titles.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _shop.visible and not _talk.visible and _action.visible:
		act()


func _position_name_key(position_id: String) -> String:
	for p: Dictionary in Db.record("spot", area.spot_id)["positions"]:
		if p["id"] == position_id:
			return p["name_key"]
	return ""


# ------------------------------------------------------------------ drawing

## Pixel-art tiles of each walkable ground kind (PixelArt.tile).
const TILES := {"plaza": "cobble", "walkway": "paving", "road": "asphalt", "building": "asphalt"}
const WATER_SHADER := preload("res://scenes/world/world_water.gdshader")
## Lamps and windows light up from dusk.
const LIT_SLOTS := ["dawn", "evening", "night"]
const GLOW := {"dawn": 0.35, "day": 0.0, "evening": 0.7, "night": 1.0}
const PLAYER_PALETTE := 7
const GULLS := 5
## Above the Karaköy roofs the camera may look this far, so the tower shows,
## and near either end it looks ahead by up to LOOK_AHEAD_M.
const BACKDROP_M := 8.0
const LOOK_AHEAD_M := 4.0

var _canvas_tint: CanvasModulate
var _tiles := {}                     ## kind -> TextureRect
var _water_mats: Array[ShaderMaterial] = []
var _boats: Node2D                   ## ferries, drawn under the bridge deck
var _lights: CanvasLayer             ## lamp glow, outside the slot tint
var _glows: Array[Sprite2D] = []
var _walk_phase := 0.0
var _npcs: Array = []                ## NpcRoster records, with jacket_color and frames
var _npc_state := {}                 ## id -> {pos, target, present, fishing, facing, position_id, phase}
var _crowd: Array[Dictionary] = []   ## Crowd.passers_by for the slot, with frames
var _player_frames: Array[ImageTexture] = []
var _last_pos := Vector2.ZERO
var _crossings: Array[Rect2] = []


## Tiles, water, ferries' layer, lamp glow: built once after the area is loaded.
func _build_art() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := area.px_per_m
	for r: Dictionary in area.rects:
		var rect: Rect2 = r["rect"]
		if r["kind"] == "crossing":
			_crossings.append(rect)
		if r["kind"] != "water":
			continue
		var water := ColorRect.new()
		water.position = rect.position * s
		water.size = rect.size * s
		water.z_index = -3
		water.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("size_m", rect.size)
		mat.set_shader_parameter("px_per_m", s)
		# Foam only where the water meets stone, not at the edge of the map.
		mat.set_shader_parameter("foam_edges", Vector4(
			1.0 if rect.position.x > 0.01 else 0.0, 1.0 if rect.position.y > 0.01 else 0.0,
			1.0 if rect.end.x < area.size_m.x - 0.01 else 0.0, 1.0 if rect.end.y < area.size_m.y - 0.01 else 0.0))
		water.material = mat
		add_child(water)
		_water_mats.append(mat)
	_boats = Node2D.new()
	_boats.z_index = -2
	_boats.draw.connect(_draw_boats)
	add_child(_boats)
	for r: Dictionary in area.rects:
		var kind := String(r["kind"])
		if not TILES.has(kind):
			continue
		var rect: Rect2 = r["rect"]
		if kind == "road":
			# The road runs on into the city beyond both ends.
			rect = rect.grow_individual(0.0, BACKDROP_M, 0.0, BACKDROP_M)
		var ground := TextureRect.new()
		ground.texture = PixelArt.tile(TILES[kind])
		ground.stretch_mode = TextureRect.STRETCH_TILE
		ground.position = (rect.position * s).round()
		ground.size = (rect.size * s).round()
		ground.z_index = -1
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ground)
		_tiles[kind] = ground
	_canvas_tint = CanvasModulate.new()
	add_child(_canvas_tint)
	_lights = CanvasLayer.new()
	_lights.layer = 1
	_lights.follow_viewport_enabled = true
	add_child(_lights)
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 64
	glow.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.45, 0.55))
	g.set_color(1, Color(1.0, 0.8, 0.45, 0.0))
	glow.gradient = g
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for lamp: Vector2 in area.lamps:
		for side in [-0.6, 0.6]:
			var sp := Sprite2D.new()
			sp.texture = glow
			sp.material = add
			sp.position = ((lamp + Vector2(side, -3.3)) * s).round()
			sp.scale = Vector2(1.6, 1.6)
			_lights.add_child(sp)
			_glows.append(sp)
	_player_frames = PixelArt.person(_player_palette())


func _player_palette() -> Dictionary:
	var pal := PixelArt.palette(PLAYER_PALETTE)
	pal["shirt"] = Color(0.18, 0.32, 0.55)
	pal["trousers"] = Color(0.3, 0.26, 0.22)
	pal["cap"] = true
	return pal


func _apply_art_light() -> void:
	var slot := String(conditions.get("slot", "day"))
	if _canvas_tint:
		_canvas_tint.color = TINT.get(slot, Color.WHITE)
	for gl: Sprite2D in _glows:
		gl.modulate = Color(1, 1, 1, GLOW.get(slot, 0.0))
		gl.visible = float(GLOW.get(slot, 0.0)) > 0.01
	for m: ShaderMaterial in _water_mats:
		m.set_shader_parameter("light", 1.0 if slot == "day" else (0.6 if slot != "night" else 0.15))
	if area:
		_crowd = Crowd.passers_by(area, slot, hash(area.id + slot), Db.constants())
		for w: Dictionary in _crowd:
			w["frames"] = PixelArt.person(PixelArt.palette(int(w["palette"])))


func _draw_boats() -> void:
	for f: Dictionary in Crowd.ferries(area, _time, Db.constants()):
		WorldPainter.ferry(_boats, f["x"], f["y"], f["dir"], _time)


func _draw() -> void:
	if area == null:
		return
	var slot := String(conditions.get("slot", "day"))
	var k := Db.constants()
	var lit := slot in LIT_SLOTS
	var road := Rect2()
	for r: Dictionary in area.rects:
		if r["kind"] == "road":
			road = (r["rect"] as Rect2).grow_individual(0.0, BACKDROP_M, 0.0, BACKDROP_M)
	WorldPainter.road(self, road, _crossings)
	WorldPainter.far_city(self, -1.0, area.size_m.x + 1.0, -BACKDROP_M - 1.0, 0.5, hash(area.id))
	for t: Dictionary in Crowd.trams(area, _time, k):
		WorldPainter.tram(self, t["x"], t["y"], t["dir"])
	for c: Dictionary in Crowd.cars(area, _time, slot, k):
		WorldPainter.car(self, c["x"], c["y"], c["dir"], c["colour"])
	for rail: Dictionary in area.rails:
		WorldPainter.rail(self, rail["from"], rail["to"])
	var near := walk.nearest_marker()
	for m: Dictionary in area.markers:
		WorldPainter.marker(self, m["pos"], m["facing"], not near.is_empty() and near["position_id"] == m["position_id"], _time)
	# Everything that stands is drawn from the back of the screen to the front.
	var items: Array = []
	for b: Dictionary in area.rects:
		if b["kind"] == "building":
			items.append([(b["rect"] as Rect2).end.y, "building", b["rect"]])
	for sh: Dictionary in area.shops:
		items.append([(sh["pos"] as Vector2).y - 1.3, "kiosk_back", sh])
		items.append([(sh["pos"] as Vector2).y + 1.2, "kiosk_front", sh])
	for lamp: Vector2 in area.lamps:
		items.append([lamp.y, "lamp", lamp])
	for cart: Vector2 in _carts():
		items.append([cart.y, "cart", cart])
	for sign: Array in _signs():
		items.append([(sign[0] as Vector2).y, "sign", sign])
	for n: Dictionary in _npcs:
		var st: Dictionary = _npc_state[n["id"]]
		if st["present"]:
			items.append([(st["pos"] as Vector2).y, "npc", n])
	for w: Dictionary in _crowd:
		var at := Crowd.walker_at(w, _time)
		items.append([(at["pos"] as Vector2).y, "walker", [w, at]])
	items.append([walk.pos.y, "player", null])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for it: Array in items:
		_draw_item(it[1], it[2], lit)
	WorldPainter.pigeons(self, Rect2(3.0, 93.0, 11.0, 6.0), _time, 9)
	for i in GULLS:
		var a := _time * (0.18 + i * 0.03) + i * 1.7
		var centre := Vector2(7.0 if i % 2 == 0 else 53.0, 30.0 + i * 12.0)
		WorldPainter.gull(self, centre + Vector2(cos(a) * 5.0, sin(a) * 3.0), _time + i * 0.4, 3.0)


func _draw_item(kind: String, data: Variant, lit: bool) -> void:
	match kind:
		"building":
			var fp: Rect2 = data
			if fp.position.y < area.size_m.y * 0.5:
				if fp.position.x > area.size_m.x * 0.5:
					WorldPainter.galata_tower(self, Vector2(fp.position.x + 11.0, fp.position.y + 4.0))
					WorldPainter.house_row(self, fp, 1, "")
				else:
					WorldPainter.house_row(self, fp, 3, tr("WORLD_SIGN_FISH_MARKET"))
			elif fp.position.x < area.size_m.x * 0.5:
				WorldPainter.mosque(self, fp)
			else:
				WorldPainter.bazaar(self, fp, tr("WORLD_SIGN_SPICE_BAZAAR"))
		"kiosk_back":
			WorldPainter.kiosk_back(self, data["pos"], data["id"] == "fishmonger")
		"kiosk_front":
			WorldPainter.kiosk_front(self, data["pos"], data["id"] == "fishmonger", tr("SHOP_%s" % String(data["id"]).to_upper()))
		"lamp":
			WorldPainter.lamp(self, data, lit)
		"cart":
			WorldPainter.simit_cart(self, data)
		"sign":
			WorldPainter.place_sign(self, data[0], tr(data[1]))
		"npc":
			var st: Dictionary = _npc_state[data["id"]]
			var arrived: bool = (st["pos"] as Vector2).distance_to(st["target"]) < 0.3
			var face := Vector2.DOWN
			if arrived and st["fishing"]:
				face = Vector2(1.0 if st["facing"] == "E" else -1.0, 0.0)
			elif not arrived:
				face = ((st["target"] as Vector2) - (st["pos"] as Vector2)).normalized()
			if arrived and st["fishing"] and st["facing"] == "W":
				WorldPainter.rod_out(self, st["pos"], st["facing"], _time)
			WorldPainter.person(self, data["frames"], st["pos"], face, float(st["phase"]), not arrived)
			if arrived and st["fishing"] and st["facing"] == "E":
				WorldPainter.rod_out(self, st["pos"], st["facing"], _time)
		"walker":
			var at: Dictionary = data[1]
			WorldPainter.person(self, data[0]["frames"], at["pos"], at["facing"], at["phase"], true)
		"player":
			# No rod while walking: the angler carries it packed (owner, 2026-11-18).
			var f := walk.facing if walk.facing.length() > 0.01 else Vector2.DOWN
			WorldPainter.person(self, _player_frames, walk.pos, f, _walk_phase, _moving)


## Simit carts with their sellers' spots, on both squares.
func _carts() -> Array[Vector2]:
	return [Vector2(6.0, 16.0), Vector2(52.0, 95.0)]


## The place-name signs: [foot, key].
func _signs() -> Array:
	return [[Vector2(57.0, 18.5), "WORLD_SIGN_KARAKOY"], [Vector2(57.0, 92.5), "WORLD_SIGN_EMINONU"]]


# ------------------------------------------------------------------ controls

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var back := _button(tr("PROTO_BACK"), 22)
	back.custom_minimum_size = Vector2(160, 96)
	back.position = Vector2(16, 16)
	back.pressed.connect(func() -> void: closed.emit())
	_hud.add_child(back)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.offset_top = 24.0
	_prompt.offset_bottom = 60.0
	_hud.add_child(_prompt)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400.0
	_toast.offset_right = 400.0
	_toast.offset_top = 124.0
	_toast.offset_bottom = 164.0
	_toast.visible = false
	_hud.add_child(_toast)
	# The stick pad under the left thumb.
	_pad = Panel.new()
	_pad.self_modulate = Color(1, 1, 1, 0.35)
	_pad.anchor_top = 1.0
	_pad.anchor_bottom = 1.0
	_pad.offset_left = 16.0
	_pad.offset_right = 296.0
	_pad.offset_top = -296.0
	_pad.offset_bottom = -16.0
	_pad.gui_input.connect(_on_pad_input)
	_hud.add_child(_pad)
	_knob = Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color(1, 1, 1, 0.7)
	round.set_corner_radius_all(40)
	_knob.add_theme_stylebox_override("panel", round)
	_knob.size = Vector2(80, 80)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_child(_knob)
	_knob.position = _pad.size * 0.5 - _knob.size * 0.5
	_pad.resized.connect(_center_knob)
	# The action button under the right thumb, shown at a marker.
	_action = _button(tr("WORLD_FISH_HERE"), 26)
	_action.anchor_left = 1.0
	_action.anchor_right = 1.0
	_action.anchor_top = 1.0
	_action.anchor_bottom = 1.0
	_action.offset_right = -16.0
	_action.offset_left = -316.0
	_action.offset_bottom = -16.0
	_action.offset_top = -216.0
	_action.visible = false
	_action.pressed.connect(act)
	_hud.add_child(_action)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 22)
	_wallet.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_wallet.add_theme_constant_override("outline_size", 6)
	_wallet.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet.offset_left = -300.0
	_wallet.offset_right = 300.0
	_wallet.offset_top = 60.0
	_wallet.offset_bottom = 90.0
	_hud.add_child(_wallet)
	_journal = Label.new()
	_journal.add_theme_font_size_override("font_size", 20)
	_journal.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	_journal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_journal.add_theme_constant_override("outline_size", 6)
	_journal.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_journal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal.offset_left = -400.0
	_journal.offset_right = 400.0
	_journal.offset_top = 92.0
	_journal.offset_bottom = 120.0
	_hud.add_child(_journal)
	_shop = ShopPanel.new()
	_hud.add_child(_shop)
	_talk = TalkPanel.new()
	_talk.quests = _quests
	_talk.completed.connect(func(q: Dictionary) -> void: show_toast(tr("QUEST_DONE_TOAST") % tr(q["title_key"]), 4.0))
	_hud.add_child(_talk)


func _center_knob() -> void:
	if not _touching:
		_knob.position = _pad.size * 0.5 - _knob.size * 0.5


func _on_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_touching = event.pressed
		if not _touching:
			_stick = Vector2.ZERO
			_center_knob()
			return
	elif not (event is InputEventScreenDrag or event is InputEventMouseMotion) or not _touching:
		return
	var offset: Vector2 = event.position - _pad.size * 0.5
	_stick = (offset / STICK_RADIUS).limit_length(1.0)
	_knob.position = _pad.size * 0.5 + _stick * STICK_RADIUS * 0.7 - _knob.size * 0.5


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _build_debug() -> void:
	if not (OS.is_debug_build() or OS.has_feature("mera_debug")):
		return
	if not ResourceLoader.exists(DEBUG_MENU):
		return
	var menu: Control = (load(DEBUG_MENU) as GDScript).new(self)
	_hud.add_child(menu)
