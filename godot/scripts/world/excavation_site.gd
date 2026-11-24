extends Node3D
class_name ExcavationSite

const TERRAIN_SIZE := 72.0

signal fossil_found(part_id)
signal site_generated

var site_id := ""
var biome := "desert"
var seed_value := 0
var layers: Array = []
var fossil_parts: Array = []
var connection_graph: Dictionary = {}

var _heightmap: Image
var _heightmap_tex: ImageTexture
var _dig_mask: Image
var _dig_mask_tex: ImageTexture
var _base_heights: PackedFloat32Array
var _segments := 60
var _row := 61
var _xs: PackedFloat32Array
var _zs: PackedFloat32Array
var _mesh_inst: MeshInstance3D
var _fossils_root: Node3D
var _rng := RandomNumberGenerator.new()
var _noise_offset := Vector2.ZERO

func generate_site(p_site_id: String, p_biome: String, p_seed_value: int = 0) -> void:
	site_id = p_site_id
	biome = p_biome
	seed_value = p_seed_value
	if seed_value == 0:
		seed_value = hash(p_site_id + "|" + p_biome)
	_rng.seed = seed_value
	_noise_offset = Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
	_generate_layers()
	_generate_heightmap()
	_build_mesh()
	_place_fossils()
	site_generated.emit()

func _generate_layers() -> void:
	layers.clear()
	var palette := _biome_palette()
	var count: int = _rng.randi_range(4, 6)
	for i in count:
		layers.append(palette[i])

func _biome_palette() -> Array:
	var grass := {"name": "grass", "hardness": 0.3, "color": Color(0.32, 0.55, 0.24), "thickness": 0.3, "fossil_probability": 0.0}
	var humus := {"name": "humus", "hardness": 0.45, "color": Color(0.45, 0.32, 0.2), "thickness": 0.6, "fossil_probability": 0.15}
	var clay := {"name": "clay", "hardness": 0.7, "color": Color(0.62, 0.42, 0.3), "thickness": 0.9, "fossil_probability": 0.3}
	var sand := {"name": "sand", "hardness": 0.55, "color": Color(0.83, 0.74, 0.52), "thickness": 1.2, "fossil_probability": 0.25}
	var rock := {"name": "rock", "hardness": 1.0, "color": Color(0.42, 0.4, 0.38), "thickness": 1.6, "fossil_probability": 0.4}
	var fossil := {"name": "fossil", "hardness": 0.9, "color": Color(0.74, 0.68, 0.5), "thickness": 0.8, "fossil_probability": 0.8}
	if biome == "forest":
		grass["color"] = Color(0.28, 0.5, 0.2)
		humus["color"] = Color(0.38, 0.28, 0.18)
	elif biome == "ice":
		grass["color"] = Color(0.78, 0.86, 0.9)
		humus["color"] = Color(0.62, 0.66, 0.7)
		clay["color"] = Color(0.55, 0.6, 0.7)
	return [grass, humus, clay, sand, rock, fossil]

func _generate_heightmap() -> void:
	var n := _segments
	_row = n + 1
	_heightmap = Image.create(_row, _row, false, Image.FORMAT_RF)
	_dig_mask = Image.create(_row, _row, false, Image.FORMAT_RF)
	_base_heights = PackedFloat32Array()
	_base_heights.resize(_row * _row)
	_xs = PackedFloat32Array()
	_zs = PackedFloat32Array()
	var size := TERRAIN_SIZE
	for z in _row:
		for x in _row:
			var wx := lerpf(-size * 0.5, size * 0.5, float(x) / float(n))
			var wz := lerpf(-size * 0.5, size * 0.5, float(z) / float(n))
			var h := _sample_height(wx, wz)
			_base_heights[z * _row + x] = h
			_xs.append(wx)
			_zs.append(wz)
			_heightmap.set_pixel(x, z, Color(h, h, h))
			_dig_mask.set_pixel(x, z, Color(0, 0, 0))
	_heightmap_tex = ImageTexture.create_from_image(_heightmap)
	_dig_mask_tex = ImageTexture.create_from_image(_dig_mask)

func _build_mesh() -> void:
	if _mesh_inst:
		_mesh_inst.queue_free()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "ExcavationMesh"
	add_child(_mesh_inst)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _segments
	for z in n:
		for x in n:
			var a := z * _row + x
			var b := a + 1
			var c := a + _row
			var d := c + 1
			_emit_tri(st, a, c, b)
			_emit_tri(st, b, c, d)
	st.generate_normals()
	_mesh_inst.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/excavation.gdshader")
	_apply_shader_params(mat)
	_mesh_inst.material_override = mat
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _emit_tri(st: SurfaceTool, a: int, b: int, c: int) -> void:
	var row := float(_row)
	for idx in [a, b, c]:
		var x: float = _xs[idx]
		var z: float = _zs[idx]
		var xi: int = idx % _row
		var zi: int = idx / _row
		st.set_uv(Vector2((float(xi) + 0.5) / row, (float(zi) + 0.5) / row))
		st.add_vertex(Vector3(x, 0.0, z))

func _apply_shader_params(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("heightmap", _heightmap_tex)
	mat.set_shader_parameter("dig_mask", _dig_mask_tex)
	mat.set_shader_parameter("terrain_size", TERRAIN_SIZE)
	mat.set_shader_parameter("heightmap_size", float(_row))
	var colors := PackedColorArray()
	var props := PackedFloat32Array()
	for i in 6:
		if i < layers.size():
			var layer: Dictionary = layers[i]
			colors.append(layer.get("color", Color.BLACK))
			props.append(layer.get("hardness", 1.0))
		else:
			colors.append(Color.BLACK)
			props.append(1.0)
	mat.set_shader_parameter("layer_colors", colors)
	mat.set_shader_parameter("layer_props", props)
	mat.set_shader_parameter("layer_count", layers.size())
	var tex_paths := [
		"res://assets/textures/sand.jpg",
		"res://assets/textures/grass.jpg",
		"res://assets/textures/rock.jpg",
		"res://assets/textures/snow.jpg",
		"res://assets/textures/sand.jpg",
		"res://assets/textures/rock.jpg",
	]
	for i in 6:
		var p: String = tex_paths[i]
		if ResourceLoader.exists(p):
			mat.set_shader_parameter("layer_texture_%d" % i, load(p))

func dig_at(world_pos: Vector3, tool: String, force: float) -> Dictionary:
	var local := to_local(world_pos)
	var gx := int(round((local.x + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments)))
	var gz := int(round((local.z + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments)))
	if gx < 0 or gx >= _row or gz < 0 or gz >= _row:
		return {"removed": 0.0, "fossil": null, "layer": ""}
	var gi := gz * _row + gx
	var current_h := _base_heights[gi]
	var depth := current_h - local.y
	if depth < 0.0:
		return {"removed": 0.0, "fossil": null, "layer": ""}
	var layer: Dictionary = _layer_at_depth(depth)
	var hardness := float(layer.get("hardness", 1.0))
	var tool_power := _tool_power(tool)
	var removed := clampf(force * tool_power / maxf(hardness, 0.1), 0.01, 2.5)
	removed = minf(removed, maxf(depth, 0.05))
	_base_heights[gi] = current_h - removed
	_heightmap.set_pixel(gx, gz, Color(_base_heights[gi], _base_heights[gi], _base_heights[gi]))
	_dig_mask.set_pixel(gx, gz, Color(1, 1, 1))
	_heightmap_tex.update(_heightmap)
	_dig_mask_tex.update(_dig_mask)
	var fossil_hit := _check_fossil_hit(local, depth, layer)
	return {"removed": removed, "fossil": fossil_hit, "layer": layer.get("name", "")}

func _layer_at_depth(depth: float) -> Dictionary:
	var acc := 0.0
	for layer in layers:
		acc += float(layer.get("thickness", 1.0))
		if depth <= acc:
			return layer
	if layers.is_empty():
		return {"name": "unknown", "hardness": 1.0}
	return layers[layers.size() - 1]

func _tool_power(tool: String) -> float:
	match tool:
		"shovel":
			return 1.0
		"pickaxe":
			return 0.85
		"brush":
			return 0.35
		"drill":
			return 1.4
		_:
			return 0.6

func _sample_height(x: float, z: float) -> float:
	var sx := x + _noise_offset.x
	var sz := z + _noise_offset.y
	var canyon := site_id.contains("canyon")
	var clearing := site_id.contains("clearing")
	var h := 0.0
	if biome == "ice":
		h = sin(sx * 0.17) * 0.32 + cos(sz * 0.14) * 0.26 + sin((sx + sz) * 0.06) * 0.18
	elif biome == "forest":
		h = sin(sx * 0.21) * cos(sz * 0.18) * 0.52 + sin(sx * 0.07 + sz * 0.05) * 0.3
		if clearing:
			h *= 0.4
	else:
		h = sin(sx * 0.15) * 0.4 + cos(sz * 0.2 + sx * 0.04) * 0.3
		h += sin(sx * 0.52) * cos(sz * 0.46) * 0.1
		if canyon:
			h += absf(sin(sx * 0.33)) * 0.48
	var rock := sin(sx * 1.7 + sz * 2.05) * cos(sz * 1.25 - sx * 0.8)
	if rock > 0.78:
		h += (rock - 0.78) * 1.6
	return h

func get_surface_height(x: float, z: float) -> float:
	var gx := clampi(int(round((x + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments))), 0, _row - 1)
	var gz := clampi(int(round((z + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments))), 0, _row - 1)
	return _base_heights[gz * _row + gx]

func _place_fossils() -> void:
	if _fossils_root:
		_fossils_root.queue_free()
	_fossils_root = Node3D.new()
	_fossils_root.name = "Fossils"
	add_child(_fossils_root)
	fossil_parts.clear()
	connection_graph.clear()
	var bone_count := _rng.randi_range(6, 10)
	for i in bone_count:
		_spawn_bone(i)

func _spawn_bone(idx: int) -> void:
	var part_id := "bone_%d" % idx
	var x := _rng.randf_range(-TERRAIN_SIZE * 0.35, TERRAIN_SIZE * 0.35)
	var z := _rng.randf_range(-TERRAIN_SIZE * 0.35, TERRAIN_SIZE * 0.35)
	var gx := clampi(int(round((x + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments))), 0, _row - 1)
	var gz := clampi(int(round((z + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * float(_segments))), 0, _row - 1)
	var top := _base_heights[gz * _row + gx]
	var layer_depth := _rng.randf_range(0.5, 3.5)
	var bone := RigidBody3D.new()
	bone.name = part_id
	bone.freeze = true
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.08
	cap.height = _rng.randf_range(0.3, 0.6)
	shape.shape = cap
	bone.add_child(shape)
	var mesh_inst := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = cap.radius
	capsule_mesh.height = cap.height
	mesh_inst.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.88, 0.76)
	mesh_inst.material_override = mat
	bone.add_child(mesh_inst)
	bone.rotation = Vector3(0, _rng.randf_range(0, TAU), _rng.randf_range(-0.3, 0.3))
	bone.position = Vector3(x, top - layer_depth, z)
	_fossils_root.add_child(bone)
	var part := {
		"id": part_id,
		"node": bone,
		"layer_depth": layer_depth,
		"position": bone.position,
		"connections": [],
		"extracted": false,
		"gx": gx,
		"gz": gz,
	}
	fossil_parts.append(part)
	_build_connections(idx)

func _build_connections(idx: int) -> void:
	if idx == 0:
		return
	var part: Dictionary = fossil_parts[idx]
	var best_id := -1
	var best_dist := INF
	for j in idx:
		var other: Dictionary = fossil_parts[j]
		var d: float = (part["position"] as Vector3).distance_to(other["position"] as Vector3)
		if d < best_dist and d < 2.5:
			best_dist = d
			best_id = j
	if best_id >= 0:
		var other_part: Dictionary = fossil_parts[best_id]
		var list_a: Array = part["connections"]
		list_a.append(other_part["id"])
		var list_b: Array = other_part["connections"]
		list_b.append(part["id"])
	connection_graph[part["id"]] = part["connections"]

func _check_fossil_hit(local_pos: Vector3, depth: float, layer: Dictionary) -> Variant:
	var prob := float(layer.get("fossil_probability", 0.0))
	if prob <= 0.0:
		return null
	for part in fossil_parts:
		if bool(part["extracted"]):
			continue
		var p: Vector3 = part["position"]
		if p.distance_to(local_pos) < 0.7 and absf(depth - float(part["layer_depth"])) < 0.6:
			if _rng.randf() < prob * 0.5:
				return part["id"]
	return null

func extract_fossil(part_id: String) -> void:
	for part in fossil_parts:
		if part["id"] == part_id and not bool(part["extracted"]):
			part["extracted"] = true
			var node = part["node"]
			if node is RigidBody3D:
				node.freeze = false
				node.gravity_scale = 1.0
				node.apply_central_impulse(Vector3(_rng.randf_range(-0.2, 0.2), 1.2, _rng.randf_range(-0.2, 0.2)))
			fossil_found.emit(part_id)
			return

func is_connection_complete() -> bool:
	if fossil_parts.is_empty():
		return false
	for part in fossil_parts:
		if not bool(part["extracted"]):
			return false
	return true

func get_connection_graph() -> Dictionary:
	return connection_graph.duplicate(true)
