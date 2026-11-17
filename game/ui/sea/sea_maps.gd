class_name SeaMaps
extends RefCounted
## Textures for the 3D sea and sky, made in code (no image assets): a tileable
## ripple normal map and a tileable cloud and noise map. Seeded, so every run
## draws the same sea. Made once and shared.

static var _ripple: ImageTexture
static var _cloud: ImageTexture


static func ripple() -> ImageTexture:
	if _ripple == null:
		var noise := FastNoiseLite.new()
		noise.seed = 11
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 3
		var img := noise.get_seamless_image(256, 256)
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(3.0)
		img.generate_mipmaps()
		_ripple = ImageTexture.create_from_image(img)
	return _ripple


static func cloud() -> ImageTexture:
	if _cloud == null:
		var noise := FastNoiseLite.new()
		noise.seed = 23
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.012
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 5
		var img := noise.get_seamless_image(256, 256)
		img.convert(Image.FORMAT_L8)
		img.generate_mipmaps()
		_cloud = ImageTexture.create_from_image(img)
	return _cloud


## The sea surface as a fan around the angler: rings spaced geometrically
## from under the angler to the horizon, and columns spread evenly over the
## angles the view can turn to (the look along the bridge is 56 degrees off
## the water, plus half the field of view). A rectangular grid left a wedge
## of sky showing where the view turned past its edge. Vertices are dense
## close by, where waves are seen, and sparse far away.
static func build_grid(rows: int = 150, cols: int = 150, near_m: float = 0.5, far_m: float = 7000.0, half_angle_deg: float = 105.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(half_angle_deg)
	for r in rows:
		var d := near_m * pow(far_m / near_m, float(r) / float(rows - 1))
		for c in cols:
			var a := lerpf(-half, half, float(c) / float(cols - 1))
			st.add_vertex(Vector3(d * sin(a), 0.0, -d * cos(a)))
	for r in rows - 1:
		for c in cols - 1:
			var i := r * cols + c
			st.add_index(i)
			st.add_index(i + cols)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols)
			st.add_index(i + cols + 1)
	return st.commit()


static var _grain: ImageTexture
static var _grain_n: ImageTexture


## Fine grain for paving and worn paint: an albedo/roughness map and its normal map.
static func grain() -> ImageTexture:
	_make_grain()
	return _grain


static func grain_normal() -> ImageTexture:
	_make_grain()
	return _grain_n


static func _make_grain() -> void:
	if _grain != null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.16
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var img := noise.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	var bump := img.duplicate() as Image
	bump.bump_map_to_normal_map(2.5)
	bump.generate_mipmaps()
	img.adjust_bcs(1.0, 0.3, 1.0)
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	_grain_n = ImageTexture.create_from_image(bump)
