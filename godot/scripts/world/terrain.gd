extends MeshInstance3D

var biome := "desert"
var site_id := ""
var _base: PackedFloat32Array
var _xs: PackedFloat32Array
var _zs: PackedFloat32Array
var _colors: PackedColorArray
var _holes := {}
var _segments := 60

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
	var size := 72.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_base = PackedFloat32Array()
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	_colors = PackedColorArray()
	for z in n + 1:
		for x in n + 1:
			var wx := lerpf(-size * 0.5, size * 0.5, float(x) / float(n))
			var wz := lerpf(-size * 0.5, size * 0.5, float(z) / float(n))
			var h := sample(wx, wz)
			_xs.append(wx)
			_zs.append(wz)
			_base.append(h)
			_colors.append(Color.WHITE)
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
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
