extends Node3D

var data := {}
var site_id := ""
var bone_id := ""
var layer_index := 0
var progress := 0.0
var damage := 0.0
var collected := false
var clue := ""
var mound: MeshInstance3D
var hole: MeshInstance3D
var dust: CPUParticles3D
var mist: CPUParticles3D
var marker: Node3D
var birds: Node3D
var _wrong_lock := 0.0
var _puff_wait := 0.0

func setup(site: String, spot: Dictionary) -> void:
	site_id = site
	data = spot
	bone_id = str(spot.bone)
	clue = str(spot.clue)
	var pos: Array = spot.pos
	position = Vector3(float(pos[0]), 0.0, float(pos[1]))
	var saved := GameState.bone_state(site_id, bone_id)
	collected = bool(saved.collected)
	damage = float(saved.damage)
	layer_index = int(saved.layer)
	progress = float(saved.progress)
	_build()
	_refresh()

func current_layer() -> Dictionary:
	var layers: Array = data.get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return {}
	return layers[layer_index]

func soil_id() -> String:
	return str(current_layer().get("soil", ""))

func _process(delta: float) -> void:
	if _wrong_lock > 0.0:
		_wrong_lock -= delta
	if birds:
		birds.rotation.x = sin(Time.get_ticks_msec() / 220.0) * 0.35
		birds.position.y = 0.55 + abs(sin(Time.get_ticks_msec() / 380.0)) * 0.08
	if marker:
		marker.visible = bool(GameState.settings.colorblind) or collected

func use_tool(tool_id: String) -> Dictionary:
	if collected:
		return {"type": "done"}
	if _wrong_lock > 0.0:
		return {"type": "lock"}
	var layer := current_layer()
	if layer.is_empty():
		return {"type": "done"}
	if tool_id != str(layer.tool):
		_wrong_lock = 0.7
		var soil := Catalog.soil(str(layer.soil))
		if bool(soil.get("fragile", false)):
			damage = min(damage + 0.34, 1.0)
			GameState.note_progress(site_id, bone_id, layer_index, progress, damage)
			GameState.buzz(30)
			Sfx.play("crack", 1.0)
			return {"type": "fragile", "damage": damage}
		Sfx.play("wrong")
		GameState.buzz(12)
		return {"type": "wrong"}
	return {"type": "ok"}

func hold(delta: float) -> Dictionary:
	if collected:
		return {"type": "done"}
	var layer := current_layer()
	if layer.is_empty():
		return {"type": "done"}
	var seconds: float = maxf(float(layer.get("seconds", 1.5)), 0.4)
	progress += delta / seconds
	_puff_wait -= delta
	if _puff_wait <= 0.0:
		_puff_wait = 0.18
		_puff(str(layer.tool))
	if progress < 1.0:
		_refresh()
		return {"type": "dig", "progress": progress}
	progress = 0.0
	layer_index += 1
	var layers: Array = data.layers
	if layer_index >= layers.size():
		collected = true
		GameState.collect_bone(site_id, bone_id, damage)
		GameState.buzz(22)
		Sfx.play("collect")
		_refresh()
		return {"type": "collected", "damage": damage}
	GameState.note_progress(site_id, bone_id, layer_index, progress, damage)
	Sfx.play("ui", 1.15)
	_refresh()
	return {"type": "next"}

func _puff(tool_id: String) -> void:
	if tool_id == "brush":
		Sfx.play("brush", randf_range(0.9, 1.1))
		_burst(dust)
	elif tool_id == "spray":
		Sfx.play("spray", randf_range(0.95, 1.05))
		_burst(mist)
	elif tool_id == "pickaxe":
		Sfx.play("pick")
		_burst(dust)
	elif tool_id == "chisel":
		Sfx.play("chisel")
		_burst(dust)
	else:
		Sfx.play("dig", randf_range(0.92, 1.08))
		_burst(dust)

func _burst(particles: CPUParticles3D) -> void:
	if particles == null:
		return
	particles.restart()
	particles.emitting = true

func _refresh() -> void:
	var layers: Array = data.get("layers", [])
	var total := 0.0
	if layers.size() > 0:
		total = (float(layer_index) + progress) / float(layers.size())
	if collected:
		total = 1.0
	if mound:
		mound.scale = Vector3(1.0, max(0.15, 0.55 - total * 0.4), 1.0)
		mound.visible = not collected
	if hole:
		hole.scale = Vector3(0.4 + total * 0.8, 0.15 + total * 0.7, 0.4 + total * 0.8)
		hole.visible = total > 0.05 or collected

func _build() -> void:
	var tint := Color(0.62, 0.42, 0.28)
	mound = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 0.7
	mound.mesh = sphere
	mound.position = Vector3(0, 0.12, 0)
	mound.scale = Vector3(1.15, 0.38, 1.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.darkened(0.08)
	mat.roughness = 1.0
	mound.material_override = mat
	add_child(mound)
	hole = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.28
	cyl.height = 0.35
	hole.mesh = cyl
	hole.position = Vector3(0, 0.02, 0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.28, 0.18, 0.12)
	dark.roughness = 1.0
	hole.material_override = dark
	add_child(hole)
	dust = _particles(Color(0.72, 0.55, 0.36), 18)
	mist = _particles(Color(0.65, 0.82, 0.95), 14)
	add_child(dust)
	add_child(mist)
	_clue_visual()
	_marker()

func _particles(color: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	p.mesh.surface_set_material(0, mat)
	p.amount = amount
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 50.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -3.5, 0)
	p.position = Vector3(0, 0.2, 0)
	return p

func _clue_visual() -> void:
	match clue:
		"bone_tip":
			var tip := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.22, 0.08)
			tip.mesh = box
			tip.position = Vector3(0.05, 0.28, 0.02)
			tip.rotation_degrees = Vector3(18, 20, 8)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.9, 0.78)
			tip.material_override = mat
			add_child(tip)
		"bump":
			mound.scale = Vector3(1.2, 0.62, 1.15)
		"soil_tint":
			var mat := mound.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.55, 0.36, 0.24)
		"birds":
			birds = Node3D.new()
			birds.position = Vector3(0.15, 0.55, 0.1)
			_bird(birds, Vector3(-0.12, 0, 0))
			_bird(birds, Vector3(0.14, 0.02, 0.05))
			add_child(birds)
		"sparkle":
			var spark := CPUParticles3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.035
			mesh.height = 0.07
			spark.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.95, 0.7)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.5)
			mat.emission_energy_multiplier = 1.4
			spark.mesh.surface_set_material(0, mat)
			spark.amount = 8
			spark.lifetime = 1.2
			spark.emitting = true
			spark.direction = Vector3(0, 1, 0)
			spark.spread = 30
			spark.initial_velocity_min = 0.15
			spark.initial_velocity_max = 0.4
			spark.gravity = Vector3(0, 0.2, 0)
			spark.position = Vector3(0, 0.35, 0)
			add_child(spark)
		"cracks":
			for i in 3:
				var crack := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.35, 0.02, 0.03)
				crack.mesh = box
				crack.position = Vector3(0, 0.2, 0)
				crack.rotation_degrees = Vector3(0, float(i) * 55.0, 0)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.32, 0.2, 0.14)
				crack.material_override = mat
				add_child(crack)
		"footprint":
			for side in [-0.12, 0.12]:
				var pad := MeshInstance3D.new()
				var oval := SphereMesh.new()
				oval.radius = 0.1
				oval.height = 0.12
				pad.mesh = oval
				pad.position = Vector3(side, 0.16, 0.05)
				pad.scale = Vector3(0.7, 0.15, 1.1)
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.4, 0.26, 0.16)
				pad.material_override = mat
				add_child(pad)

func _bird(parent: Node3D, pos: Vector3) -> void:
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	body.mesh = mesh
	body.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.35)
	body.material_override = mat
	parent.add_child(body)
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.025
	cone.height = 0.08
	beak.mesh = cone
	beak.position = pos + Vector3(0, 0.0, -0.1)
	beak.rotation_degrees = Vector3(90, 0, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.9, 0.45, 0.2)
	beak.material_override = bmat
	parent.add_child(beak)

func _marker() -> void:
	marker = Node3D.new()
	marker.position = Vector3(0, 0.9, 0)
	var clue_info := Catalog.clue(clue)
	var shape := str(clue_info.get("shape", "flag"))
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.7, 0.04)
	pole.mesh = box
	pole.position = Vector3(0, 0.1, 0)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.1, 0.1, 0.12)
	pole.material_override = black
	marker.add_child(pole)
	var icon := MeshInstance3D.new()
	var mesh: Mesh = SphereMesh.new()
	if shape == "mound" or shape == "print":
		mesh = BoxMesh.new()
	elif shape == "zig" or shape == "bone":
		mesh = CylinderMesh.new()
	elif shape == "star":
		mesh = PrismMesh.new()
	icon.mesh = mesh
	icon.position = Vector3(0, 0.55, 0)
	icon.scale = Vector3(0.22, 0.22, 0.22)
	var hi := StandardMaterial3D.new()
	hi.albedo_color = Color(1.0, 0.86, 0.2)
	hi.emission_enabled = true
	hi.emission = Color(1.0, 0.8, 0.2)
	hi.emission_energy_multiplier = 0.4
	icon.material_override = hi
	marker.add_child(icon)
	add_child(marker)
	marker.visible = bool(GameState.settings.colorblind)
