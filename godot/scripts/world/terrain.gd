extends MeshInstance3D

var biome := "desert"
var site_id := ""
var _base: PackedFloat32Array
var _xs: PackedFloat32Array
var _zs: PackedFloat32Array
var _colors: PackedColorArray
var _holes := {}
var _segments := 60
var _heightmap: Image
var _heightmap_tex: ImageTexture
var _biome_palette: Dictionary = {}
var _catalog_path := "res://assets/data/catalog.json"

func setup(next_biome: String, next_site: String) -> void:
	biome = next_biome
	site_id = next_site
	name = "Terrain"
	var grade := str(GameState.settings.get("quality", "medium"))
	var n := 36
	if grade == "medium":
		n = 60
	elif grade == "high":
		n = 84
	_segments = n
	_rebuild_full()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground.gdshader")
	mat.set_shader_parameter("sand_tex", load("res://assets/textures/sand.jpg"))
	mat.set_shader_parameter("grass_tex", load("res://assets/textures/grass.jpg"))
	mat.set_shader_parameter("rock_tex", load("res://assets/textures/rock.jpg"))
	mat.set_shader_parameter("snow_tex", load("res://assets/textures/snow.jpg"))
	var biome_id := 0.0
	if biome == "forest":
		biome_id = 1.0
	elif biome == "ice":
		biome_id = 2.0
	elif site_id.contains("canyon"):
		biome_id = 3.0
	mat.set_shader_parameter("biome_id", biome_id)
	_load_biome_palette()
	_apply_palette_to_shader(mat)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(true)

func _process(_delta: float) -> void:
	_update_lod()

func _update_lod() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist := cam.global_position.distance_to(global_position)
	var max_seg := 84
	var grade := str(GameState.settings.get("quality", "medium"))
	if grade == "low":
		max_seg = 36
	elif grade == "medium":
		max_seg = 60
	var target := max_seg
	if dist > 90.0:
		target = 12
	elif dist > 60.0:
		target = maxi(24, max_seg / 2)
	elif dist > 40.0:
		target = maxi(36, int(max_seg * 0.75))
	if target != _segments:
		_segments = target
		_rebuild_full()

func _rebuild_full() -> void:
	var n := _segments
	var size := 72.0
	var row := n + 1
	_base = PackedFloat32Array()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_colors = PackedColorArray()
	_base.resize(row * row)
	for z in row:
		for x in row:
			var wx := lerpf(-size * 0.5, size * 0.5, float(x) / float(n))
			var wz := lerpf(-size * 0.5, size * 0.5, float(z) / float(n))
			var h := sample(wx, wz)
			_xs.append(wx)
			_zs.append(wz)
			_base[z * row + x] = h
			_colors.append(Color.WHITE)
	_build_heightmap_texture()
	_rebuild()

func _build_heightmap_texture() -> void:
	var row := _segments + 1
	_heightmap = Image.create(row, row, false, Image.FORMAT_RF)
	for z in row:
		for x in row:
			var idx := z * row + x
			var h: float = _base[idx]
			_heightmap.set_pixel(x, z, Color(h, h, h))
	_heightmap_tex = ImageTexture.create_from_image(_heightmap)

func update_heightmap_at(world_pos: Vector3, delta: float) -> void:
	if _heightmap == null:
		return
	var n := _segments
	var row := n + 1
	var x := int(round((world_pos.x + 36.0) / 72.0 * float(n)))
	var z := int(round((world_pos.z + 36.0) / 72.0 * float(n)))
	x = clampi(x, 0, row - 1)
	z = clampi(z, 0, row - 1)
	var idx := z * row + x
	_base[idx] += delta
	_heightmap.set_pixel(x, z, Color(_base[idx], _base[idx], _base[idx]))
	if _heightmap_tex:
		_heightmap_tex.update(_heightmap)
	_rebuild()

func _load_biome_palette() -> void:
	_biome_palette = {
		"desert": {"sand": Color(0.86, 0.78, 0.55), "rock": Color(0.55, 0.5, 0.45), "grass": Color(0.6, 0.6, 0.4), "snow": Color(0.95, 0.95, 0.98)},
		"forest": {"sand": Color(0.6, 0.5, 0.35), "rock": Color(0.4, 0.42, 0.32), "grass": Color(0.3, 0.52, 0.22), "snow": Color(0.92, 0.94, 0.95)},
		"ice": {"sand": Color(0.75, 0.82, 0.88), "rock": Color(0.5, 0.55, 0.6), "grass": Color(0.6, 0.7, 0.72), "snow": Color(0.98, 0.99, 1.0)},
	}
	if not FileAccess.file_exists(_catalog_path):
		return
	var f := FileAccess.open(_catalog_path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	var biomes = data.get("biomes", null)
	if not (biomes is Dictionary):
		return
	var entry = biomes.get(biome, null)
	if not (entry is Dictionary):
		return
	var pal = entry.get("palette", null)
	if not (pal is Dictionary):
		return
	var out := {}
	for key in pal:
		var v = pal[key]
		if v is Array and v.size() >= 3:
			out[key] = Color(float(v[0]), float(v[1]), float(v[2]))
		elif v is String:
			out[key] = Color(v)
	if not out.is_empty():
		_biome_palette[biome] = out

func _apply_palette_to_shader(mat: ShaderMaterial) -> void:
	var pal: Dictionary = _biome_palette.get(biome, {})
	if pal.has("sand"):
		mat.set_shader_parameter("sand_tint", pal["sand"])
	if pal.has("grass"):
		mat.set_shader_parameter("grass_tint", pal["grass"])
	if pal.has("rock"):
		mat.set_shader_parameter("rock_tint", pal["rock"])
	if pal.has("snow"):
		mat.set_shader_parameter("snow_tint", pal["snow"])

func sample(x: float, z: float) -> float:
	var canyon := site_id.contains("canyon")
	var clearing := site_id.contains("clearing")
	var h := 0.0
	if biome == "ice":
		h = sin(x * 0.17) * 0.32 + cos(z * 0.14) * 0.26 + sin((x + z) * 0.06) * 0.18
	elif biome == "forest":
		h = sin(x * 0.21) * cos(z * 0.18) * 0.52 + sin(x * 0.07 + z * 0.05) * 0.3
		if clearing:
			h *= 0.4
	else:
		h = sin(x * 0.15) * 0.4 + cos(z * 0.2 + x * 0.04) * 0.3
		h += sin(x * 0.52) * cos(z * 0.46) * 0.1
		if canyon:
			h += absf(sin(x * 0.33)) * 0.48
	var rock := sin(x * 1.7 + z * 2.05) * cos(z * 1.25 - x * 0.8)
	if rock > 0.78:
		h += (rock - 0.78) * 1.6
	return h

func carve(id: String, x: float, z: float, radius: float, depth: float) -> void:
	_holes[id] = {"x": x, "z": z, "radius": radius, "depth": depth}
	_rebuild()

func _tri(st: SurfaceTool, a: int, b: int, c: int) -> void:
	for index in [a, b, c]:
		st.set_color(_colors[index])
		st.add_vertex(Vector3(_xs[index], _height_at(index), _zs[index]))

func _height_at(index: int) -> float:
	var y := _base[index]
	var x := _xs[index]
	var z := _zs[index]
	for id in _holes:
		var hole: Dictionary = _holes[id]
		var dist := Vector2(x - float(hole.x), z - float(hole.z)).length()
		var radius := float(hole.radius)
		if dist >= radius:
			continue
		var t := 1.0 - dist / radius
		y -= float(hole.depth) * t * t
	return y

func _rebuild() -> void:
	var n := _segments
	if n < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row := n + 1
	for z in n:
		for x in n:
			var a := z * row + x
			var b := a + 1
			var c := a + row
			var d := c + 1
			_tri(st, a, c, b)
			_tri(st, b, c, d)
	st.generate_normals()
	mesh = st.commit()
