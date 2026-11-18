class_name PixelArt
extends RefCounted
## Pixel art for the top-down world, made in code (owner, 2026-11-18: the 2D
## world should look like Stardew Valley; no pixel-art asset host is
## reachable, so nothing is downloaded). Ground tiles are 16 x 16 px (one
## metre); people are 16 x 24 px sprites in four directions with a three-frame
## walk, drawn part by part and outlined. Deterministic: the same palette
## gives the same sprite. Cached.

const OUTLINE := Color(0.16, 0.11, 0.13)
const SKINS: Array[Color] = [Color(0.96, 0.78, 0.62), Color(0.86, 0.63, 0.47), Color(0.66, 0.45, 0.31), Color(0.47, 0.31, 0.22)]
const HAIRS: Array[Color] = [Color(0.17, 0.12, 0.1), Color(0.35, 0.22, 0.12), Color(0.55, 0.38, 0.2), Color(0.75, 0.74, 0.72), Color(0.1, 0.1, 0.12)]
const SHIRTS: Array[Color] = [
	Color(0.85, 0.3, 0.25), Color(0.25, 0.45, 0.75), Color(0.95, 0.75, 0.3), Color(0.3, 0.6, 0.4),
	Color(0.55, 0.35, 0.65), Color(0.9, 0.9, 0.88), Color(0.2, 0.25, 0.35), Color(0.8, 0.5, 0.2),
]
const TROUSERS: Array[Color] = [Color(0.2, 0.25, 0.38), Color(0.25, 0.22, 0.2), Color(0.4, 0.4, 0.42), Color(0.15, 0.15, 0.17), Color(0.5, 0.42, 0.3)]

## Directions of the sprite rows.
enum Dir { DOWN, LEFT, RIGHT, UP }

static var _cache := {}


## A palette from a seed: skin, hair, shirt, trousers and whether there is a cap.
static func palette(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"skin": SKINS[rng.randi() % SKINS.size()], "hair": HAIRS[rng.randi() % HAIRS.size()],
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()], "trousers": TROUSERS[rng.randi() % TROUSERS.size()],
		"cap": rng.randf() < 0.4, "key": seed_value,
	}


## The frames of a person: index Dir * 3 + frame (0 standing, 1 and 2 stepping).
static func person(pal: Dictionary) -> Array[ImageTexture]:
	var key := "person:%s" % str([pal["skin"], pal["hair"], pal["shirt"], pal["trousers"], pal["cap"]])
	if _cache.has(key):
		return _cache[key]
	var frames: Array[ImageTexture] = []
	for dir in 4:
		for frame in 3:
			frames.append(ImageTexture.create_from_image(_person_image(pal, dir, frame)))
	_cache[key] = frames
	return frames


static func _person_image(pal: Dictionary, dir: int, frame: int) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = pal["skin"]
	var hair: Color = pal["hair"]
	var shirt: Color = pal["shirt"]
	var legs: Color = pal["trousers"]
	var shoe := Color(0.18, 0.14, 0.12)
	var side := dir == Dir.LEFT or dir == Dir.RIGHT
	var step := 0 if frame == 0 else (1 if frame == 1 else -1)
	# Legs and shoes: one leg forward per step.
	if side:
		img.fill_rect(Rect2i(6 + step, 18, 2, 4), legs)
		img.fill_rect(Rect2i(8 - step, 18, 2, 4), legs.darkened(0.15))
		img.fill_rect(Rect2i(6 + step, 22, 3, 1), shoe)
		img.fill_rect(Rect2i(8 - step, 22, 3, 1), shoe)
	else:
		img.fill_rect(Rect2i(5, 18, 3, 4 - maxi(step, 0)), legs)
		img.fill_rect(Rect2i(8, 18, 3, 4 - maxi(-step, 0)), legs)
		img.fill_rect(Rect2i(5, 22 - maxi(step, 0), 3, 1), shoe)
		img.fill_rect(Rect2i(8, 22 - maxi(-step, 0), 3, 1), shoe)
	# Body with a lighter front and a belt.
	var bx := 5 if side else 4
	var bw := 6 if side else 8
	img.fill_rect(Rect2i(bx, 11, bw, 7), shirt)
	img.fill_rect(Rect2i(bx + 1, 12, bw - 2, 1), shirt.lightened(0.18))
	img.fill_rect(Rect2i(bx, 17, bw, 1), shirt.darkened(0.3))
	# Arms swing opposite to the legs.
	if side:
		var ax := 7 - step
		img.fill_rect(Rect2i(ax, 12, 2, 4), shirt.darkened(0.12))
		img.fill_rect(Rect2i(ax, 16, 2, 1), skin)
	else:
		img.fill_rect(Rect2i(3, 12 + step, 1, 4), shirt.darkened(0.12))
		img.fill_rect(Rect2i(12, 12 - step, 1, 4), shirt.darkened(0.12))
		img.fill_rect(Rect2i(3, 16 + step, 1, 1), skin)
		img.fill_rect(Rect2i(12, 16 - step, 1, 1), skin)
	# Head: face, hair, eyes by direction, and maybe a cap.
	img.fill_rect(Rect2i(4, 3, 8, 8), skin)
	img.fill_rect(Rect2i(4, 2, 8, 3), hair)
	match dir:
		Dir.DOWN:
			img.fill_rect(Rect2i(4, 5, 1, 2), hair)
			img.fill_rect(Rect2i(11, 5, 1, 2), hair)
			img.set_pixel(6, 7, OUTLINE)
			img.set_pixel(9, 7, OUTLINE)
			img.set_pixel(7, 9, skin.darkened(0.2))
			img.set_pixel(8, 9, skin.darkened(0.2))
		Dir.UP:
			img.fill_rect(Rect2i(4, 3, 8, 7), hair)
		Dir.LEFT:
			img.fill_rect(Rect2i(8, 3, 4, 6), hair)
			img.set_pixel(5, 7, OUTLINE)
		Dir.RIGHT:
			img.fill_rect(Rect2i(4, 3, 4, 6), hair)
			img.set_pixel(10, 7, OUTLINE)
	if pal["cap"]:
		var cap := shirt.darkened(0.35)
		img.fill_rect(Rect2i(4, 1, 8, 3), cap)
		match dir:
			Dir.DOWN:
				img.fill_rect(Rect2i(4, 4, 8, 1), cap.darkened(0.2))
			Dir.LEFT:
				img.fill_rect(Rect2i(2, 3, 3, 1), cap.darkened(0.2))
			Dir.RIGHT:
				img.fill_rect(Rect2i(11, 3, 3, 1), cap.darkened(0.2))
	_outline(img)
	return img


## A dark outline round everything drawn, as pixel art has.
static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := []
	for y in h:
		for x in w:
			solid.append(img.get_pixel(x, y).a > 0.5)
	for y in h:
		for x in w:
			if solid[y * w + x]:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx]:
					img.set_pixel(x, y, OUTLINE)
					break


## A 16 x 16 ground tile: cobble, paving, asphalt or crossing (zebra stripe).
static func tile(kind: String) -> ImageTexture:
	var key := "tile:" + kind
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"cobble":
			img.fill(Color(0.45, 0.41, 0.38))
			# Two rows of two stones, offset like a running bond, lit from the top left.
			for row in 2:
				for col in 3:
					var x := col * 8 - (4 if row == 1 else 0)
					var c := Color(0.66, 0.6, 0.53).lerp(Color(0.72, 0.65, 0.56), rng.randf())
					for px in 7:
						for py in 7:
							var ix := x + px
							if ix >= 0 and ix < 16:
								img.set_pixel(ix, row * 8 + py, c)
					for px in 6:
						if x + px >= 0 and x + px < 16:
							img.set_pixel(x + px, row * 8, c.lightened(0.15))
							img.set_pixel(x + px, row * 8 + 6, c.darkened(0.12))
		"paving":
			img.fill(Color(0.74, 0.71, 0.66))
			for i in 16:
				img.set_pixel(i, 15, Color(0.6, 0.57, 0.53))
				img.set_pixel(7, i, Color(0.6, 0.57, 0.53))
			for i in 10:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.69, 0.66, 0.61))
		"asphalt":
			img.fill(Color(0.3, 0.3, 0.33))
			for i in 28:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.36, 0.36, 0.39) if i % 2 == 0 else Color(0.26, 0.26, 0.28))
		"crossing":
			img.fill(Color(0.3, 0.3, 0.33))
			img.fill_rect(Rect2i(0, 2, 16, 5), Color(0.9, 0.9, 0.86))
			img.fill_rect(Rect2i(0, 10, 16, 5), Color(0.9, 0.9, 0.86))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
