extends RefCounted

const Actor := preload("res://scripts/dino/dino_actor.gd")

static func build(dino: Dictionary, mode: String) -> Node3D:
	var id := str(dino.get("id", ""))
	var glb := "res://assets/models/%s.glb" % id if mode == "living" else "res://assets/models/%s_skeleton.glb" % id
	if ResourceLoader.exists(glb):
		var packed = load(glb)
		if packed is PackedScene:
			var imported := (packed as PackedScene).instantiate() as Node3D
			if imported != null:
				imported.set_script(Actor)
				var parts := {}
				if mode != "living":
					_index_bones(imported, parts)
				imported.set("parts", parts)
				imported.set("mode", mode)
				imported.set("anim", "idle" if mode == "living" else "ghost")
				return imported
	return _build_procedural(dino, mode)

static func _index_bones(node: Node, parts: Dictionary) -> void:
	if node is MeshInstance3D and "__" in str(node.name):
		var mesh := node as MeshInstance3D
		var bone_id := str(node.name).split("__")[0]
		var fossil := _fossil()
		var ghost := _ghost()
		mesh.set_meta("bone_id", bone_id)
		mesh.set_meta("fossil_mat", fossil)
		mesh.set_meta("ghost_mat", ghost)
		mesh.set_meta("live_mat", fossil)
		mesh.set_meta("base_rot", mesh.rotation)
		mesh.material_override = ghost
		parts[str(node.name)] = mesh
	for child in node.get_children():
		_index_bones(child, parts)

static func _build_procedural(dino: Dictionary, mode: String) -> Node3D:
	var spec: Dictionary = dino.get("build", {})
	var pal: Dictionary = dino.get("palette", {})
	var root := Node3D.new()
	root.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	var parts := {}
	var ids := {}
	for bone in dino.get("bones", []):
		ids[str(bone.id)] = true
	var body_mat := _pbr(Color.html(str(pal.get("body", "#88aa66"))))
	var belly_mat := _pbr(Color.html(str(pal.get("belly", "#f4e3bc"))))
	var accent_mat := _pbr(Color.html(str(pal.get("accent", "#e07a3d"))))
	var horn_mat := _pbr(Color.html(str(pal.get("horn", "#f3ead4"))), 0.42, 0.04)
	var fossil := _fossil()
	var ghost := _ghost()
	var body: Array = spec.get("body", [1, 1, 1])
	var bw := float(body[0])
	var bh := float(body[1])
	var bl := float(body[2])
	var capsule := CapsuleMesh.new()
	capsule.radius = max(bh * 0.42, 0.12)
	capsule.height = max(bl, capsule.radius * 2.1)
	_mesh(root, parts, "body", "torso", capsule, Vector3(0, bh * 0.95, 0), Vector3(90, 0, 0), Vector3(max(bw / max(bh, 0.2), 0.4), 1, 1), body_mat, fossil, ghost)
	var belly := SphereMesh.new()
	belly.radius = bh * 0.34
	belly.height = bh * 0.7
	_mesh(root, parts, "belly", "torso", belly, Vector3(0, bh * 0.7, 0.05), Vector3.ZERO, Vector3(bw * 0.55, 0.62, bl * 0.28), belly_mat, fossil, ghost)

	var chain := int(spec.get("neckChain", 1))
	var neck_len := float(spec.get("neck", 0.4))
	var neck_up := float(spec.get("neckUp", 0.2))
	var neck_bone := "neck" if ids.has("neck") else "torso"
	var neck_start := Vector3(0, bh * 1.05, -bl * 0.42)
	var head_r := float(spec.get("head", 0.4))
	for i in chain:
		var t := float(i + 1) / float(chain)
		var pos := neck_start + Vector3(0, neck_up * t * max(bh, 0.4), -neck_len * t * 1.7)
		var seg := SphereMesh.new()
		seg.radius = lerpf(bh * 0.26, head_r * 0.55, t)
		seg.height = seg.radius * 2.05
		_mesh(root, parts, "neck_%d" % i, neck_bone, seg, pos, Vector3.ZERO, Vector3.ONE, body_mat, fossil, ghost)
	var head_pos := neck_start + Vector3(0, neck_up * max(bh, 0.4), -neck_len * 1.7)
	var head := SphereMesh.new()
	head.radius = head_r
	head.height = head_r * 2.0
	_mesh(root, parts, "head", "skull", head, head_pos, Vector3.ZERO, Vector3(1.0, 0.88, 1.12), body_mat, fossil, ghost)
	var snout_len := float(spec.get("snout", 0.3))
	var snout := SphereMesh.new()
	snout.radius = head_r * 0.52
	snout.height = head_r * 1.05
	_mesh(root, parts, "snout", "skull", snout, head_pos + Vector3(0, -head_r * 0.12, -head_r - snout_len * 0.25), Vector3.ZERO, Vector3(0.75, 0.5, 1.35), body_mat, fossil, ghost)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(head_r * 0.7, head_r * 0.2, snout_len + head_r * 0.45)
	_mesh(root, parts, "jaw", "skull", jaw, head_pos + Vector3(0, -head_r * 0.42, -head_r * 0.45), Vector3.ZERO, Vector3.ONE, belly_mat, fossil, ghost)
	_eyes(root, parts, fossil, ghost, head_pos, head_r)
	if bool(spec.get("teeth", false)):
		var tooth := BoxMesh.new()
		tooth.size = Vector3(head_r * 0.08, head_r * 0.18, head_r * 0.08)
		for i in 4:
			var x := lerpf(-head_r * 0.22, head_r * 0.22, float(i) / 3.0)
			_mesh(root, parts, "tooth_%d" % i, "skull", tooth, head_pos + Vector3(x, -head_r * 0.25, -head_r * 1.05), Vector3.ZERO, Vector3.ONE, horn_mat, fossil, ghost)
	if float(spec.get("frill", 0.0)) > 0.0:
		var fr := SphereMesh.new()
		fr.radius = float(spec.frill) * head_r
		fr.height = fr.radius * 2.0
		var frill_bone := "frill" if ids.has("frill") else "skull"
		_mesh(root, parts, "frill", frill_bone, fr, head_pos + Vector3(0, head_r * 0.15, head_r * 0.45), Vector3(16, 0, 0), Vector3(1.35, 1.45, 0.16), accent_mat, fossil, ghost)
	if int(spec.get("horns", 0)) > 0:
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.02
		horn_mesh.bottom_radius = head_r * 0.12
		horn_mesh.height = head_r * 0.85
		_mesh(root, parts, "horn_nose", "skull", horn_mesh, head_pos + Vector3(0, 0.02, -head_r * 1.2), Vector3(75, 0, 0), Vector3.ONE, horn_mat, fossil, ghost)
		if int(spec.horns) >= 3:
			_mesh(root, parts, "horn_l", "skull", horn_mesh, head_pos + Vector3(-head_r * 0.42, head_r * 0.5, -head_r * 0.15), Vector3(-25, 0, 16), Vector3(1, 1.25, 1), horn_mat, fossil, ghost)
			_mesh(root, parts, "horn_r", "skull", horn_mesh, head_pos + Vector3(head_r * 0.42, head_r * 0.5, -head_r * 0.15), Vector3(-25, 0, -16), Vector3(1, 1.25, 1), horn_mat, fossil, ghost)
	if bool(spec.get("noseBump", false)):
		var bump := SphereMesh.new()
		bump.radius = head_r * 0.28
		bump.height = bump.radius * 2.0
		_mesh(root, parts, "nose", "skull", bump, head_pos + Vector3(0, head_r * 0.32, -head_r * 0.35), Vector3.ZERO, Vector3.ONE, accent_mat, fossil, ghost)

	var tail_len := float(spec.get("tail", 1.0))
	for i in 3:
		var seg := CapsuleMesh.new()
		var rad := lerpf(bh * 0.26, bh * 0.07, float(i) / 2.0)
		seg.radius = max(rad, 0.05)
		seg.height = max(tail_len * 0.42, seg.radius * 2.1)
		var z := bl * 0.42 + float(i) * tail_len * 0.36
		_mesh(root, parts, "tail_%d" % i, "tail", seg, Vector3(0, bh * 0.9 + float(i) * 0.08, z), Vector3(80 - float(i) * 10.0, 0, 0), Vector3.ONE, body_mat, fossil, ghost)
	var spikes := int(spec.get("spikes", 0))
	for i in spikes:
		var spike := CylinderMesh.new()
		spike.top_radius = 0.015
		spike.bottom_radius = 0.07
		spike.height = 0.36
		var side := -1.0 if i % 2 == 0 else 1.0
		_mesh(root, parts, "spike_%d" % i, "tail", spike, Vector3(side * 0.18, bh * 1.02, bl * 0.55 + float(i) * 0.16), Vector3(0, 0, side * 70.0), Vector3.ONE, accent_mat, fossil, ghost)
	var plates := int(spec.get("plates", 0))
	if plates > 0:
		var plate_bone := "plates" if ids.has("plates") else "torso"
		for i in plates:
			var plate := PrismMesh.new()
			var h: float = 0.62 - absf(float(i) - float(plates) * 0.5) * 0.05
			plate.size = Vector3(0.08, max(h, 0.28), 0.38)
			var z := lerpf(-bl * 0.25, bl * 0.4, float(i) / float(max(plates - 1, 1)))
			var side := 0.1 if i % 2 == 0 else -0.1
			_mesh(root, parts, "plate_%d" % i, plate_bone, plate, Vector3(side, bh * 1.42, z), Vector3.ZERO, Vector3.ONE, accent_mat, fossil, ghost)

	var leg_h := float(spec.get("legs", 0.7))
	var front := float(spec.get("frontLeg", 1.0))
	if str(spec.get("stance", "quad")) == "quad":
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_fl", Vector3(-bw * 0.32, leg_h * front, -bl * 0.28), leg_h * front, "leg_l")
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_fr", Vector3(bw * 0.32, leg_h * front, -bl * 0.28), leg_h * front, "leg_r")
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_bl", Vector3(-bw * 0.3, leg_h * 0.92, bl * 0.28), leg_h * 0.92, "leg_l")
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_br", Vector3(bw * 0.3, leg_h * 0.92, bl * 0.28), leg_h * 0.92, "leg_r")
	else:
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_l", Vector3(-bw * 0.22, leg_h, bl * 0.08), leg_h, "leg_l")
		_leg(root, parts, fossil, ghost, body_mat, horn_mat, "leg_r", Vector3(bw * 0.22, leg_h, bl * 0.08), leg_h, "leg_r")
		if bool(spec.get("claw", false)):
			_claw(root, parts, fossil, ghost, horn_mat, Vector3(-bw * 0.22, 0.05, bl * 0.08 - 0.2), "leg_l")
			_claw(root, parts, fossil, ghost, horn_mat, Vector3(bw * 0.22, 0.05, bl * 0.08 - 0.2), "leg_r")
	var arm_s := float(spec.get("arms", 0.0))
	if arm_s > 0.05:
		var arm_bone := "arm" if ids.has("arm") else "torso"
		_arm(root, parts, fossil, ghost, body_mat, "arm_l", Vector3(-bw * 0.48, bh * 0.95, -bl * 0.32), arm_s, arm_bone)
		_arm(root, parts, fossil, ghost, body_mat, "arm_r", Vector3(bw * 0.48, bh * 0.95, -bl * 0.32), arm_s, arm_bone)
		if float(spec.get("feathers", 0.0)) > 0.0:
			var feather := SphereMesh.new()
			feather.radius = 0.16
			feather.height = 0.32
			_mesh(root, parts, "feather_l", arm_bone, feather, Vector3(-bw * 0.62, bh * 1.05, -bl * 0.15), Vector3.ZERO, Vector3(1.3, 0.35, 0.7), accent_mat, fossil, ghost)
			_mesh(root, parts, "feather_r", arm_bone, feather, Vector3(bw * 0.62, bh * 1.05, -bl * 0.15), Vector3.ZERO, Vector3(1.3, 0.35, 0.7), accent_mat, fossil, ghost)

	root.set_script(Actor)
	root.set("parts", parts)
	root.set("mode", mode)
	root.set("anim", "ghost" if mode == "ghost" else "idle")
	for key in parts:
		var node: Node3D = parts[key]
		_apply_mode(node, mode)
	return root

static func _apply_mode(node: Node3D, mode: String) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mode == "ghost":
			mesh.material_override = mesh.get_meta("ghost_mat")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif mode == "fossil":
			mesh.material_override = mesh.get_meta("fossil_mat")
		else:
			mesh.material_override = mesh.get_meta("live_mat")
	for child in node.get_children():
		if child is Node3D:
			_apply_mode(child, mode)

static func _leg(root: Node3D, parts: Dictionary, fossil: Material, ghost: Material, color: Material, hoof: Material, name: String, hip: Vector3, height: float, bone_id: String) -> void:
	var pivot := Node3D.new()
	pivot.position = hip
	pivot.set_meta("part", name)
	pivot.set_meta("bone_id", bone_id)
	pivot.set_meta("base_rot", Vector3.ZERO)
	root.add_child(pivot)
	parts[name] = pivot
	var rad := 0.1 + height * 0.08
	var cap := CapsuleMesh.new()
	cap.radius = rad
	cap.height = max(height, rad * 2.1)
	_mesh(pivot, parts, name + "_bone", bone_id, cap, Vector3(0, -height * 0.45, 0), Vector3.ZERO, Vector3.ONE, color, fossil, ghost)
	var foot := SphereMesh.new()
	foot.radius = rad * 1.2
	foot.height = rad * 1.4
	_mesh(pivot, parts, name + "_foot", bone_id, foot, Vector3(0, -height + rad * 0.45, -rad * 0.3), Vector3.ZERO, Vector3(1.1, 0.55, 1.35), hoof, fossil, ghost)

static func _arm(root: Node3D, parts: Dictionary, fossil: Material, ghost: Material, color: Material, name: String, shoulder: Vector3, length: float, bone_id: String) -> void:
	var pivot := Node3D.new()
	pivot.position = shoulder
	pivot.set_meta("part", name)
	pivot.set_meta("bone_id", bone_id)
	pivot.set_meta("base_rot", Vector3.ZERO)
	root.add_child(pivot)
	parts[name] = pivot
	var cap := CapsuleMesh.new()
	cap.radius = 0.06 + length * 0.08
	cap.height = max(0.25 + length * 0.55, cap.radius * 2.1)
	_mesh(pivot, parts, name + "_bone", bone_id, cap, Vector3(0, -cap.height * 0.35, -0.05), Vector3(18, 0, 0), Vector3.ONE, color, fossil, ghost)

static func _claw(root: Node3D, parts: Dictionary, fossil: Material, ghost: Material, color: Material, pos: Vector3, bone_id: String) -> void:
	var claw := CylinderMesh.new()
	claw.top_radius = 0.01
	claw.bottom_radius = 0.045
	claw.height = 0.22
	_mesh(root, parts, "claw_" + bone_id, bone_id, claw, pos, Vector3(80, 0, 0), Vector3.ONE, color, fossil, ghost)

static func _eyes(root: Node3D, parts: Dictionary, fossil: Material, ghost: Material, head_pos: Vector3, head_r: float) -> void:
	var white := _pbr(Color(0.98, 0.98, 0.97), 0.2, 0.0)
	var pupil := _pbr(Color(0.12, 0.1, 0.12), 0.15, 0.0)
	var eye := SphereMesh.new()
	eye.radius = head_r * 0.2
	eye.height = eye.radius * 2.0
	var dot := SphereMesh.new()
	dot.radius = head_r * 0.09
	dot.height = dot.radius * 2.0
	_mesh(root, parts, "eye_l", "skull", eye, head_pos + Vector3(-head_r * 0.4, head_r * 0.16, -head_r * 0.7), Vector3.ZERO, Vector3.ONE, white, fossil, ghost)
	_mesh(root, parts, "eye_r", "skull", eye, head_pos + Vector3(head_r * 0.4, head_r * 0.16, -head_r * 0.7), Vector3.ZERO, Vector3.ONE, white, fossil, ghost)
	_mesh(root, parts, "pupil_l", "skull", dot, head_pos + Vector3(-head_r * 0.46, head_r * 0.14, -head_r * 0.86), Vector3.ZERO, Vector3.ONE, pupil, fossil, ghost)
	_mesh(root, parts, "pupil_r", "skull", dot, head_pos + Vector3(head_r * 0.46, head_r * 0.14, -head_r * 0.86), Vector3.ZERO, Vector3.ONE, pupil, fossil, ghost)

static func _mesh(parent: Node3D, parts: Dictionary, part_name: String, bone_id: String, mesh: Mesh, pos: Vector3, rot_deg: Vector3, scl: Vector3, live: Material, fossil: Material, ghost: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.set_meta("part", part_name)
	mi.set_meta("bone_id", bone_id)
	mi.set_meta("base_rot", mi.rotation)
	mi.set_meta("live_mat", live)
	mi.set_meta("fossil_mat", fossil.duplicate())
	mi.set_meta("ghost_mat", ghost.duplicate())
	parent.add_child(mi)
	parts[part_name] = mi
	return mi

static func _pbr(color: Color, rough := 0.62, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat

static func _fossil() -> StandardMaterial3D:
	var mat := _pbr(Color(0.95, 0.89, 0.76), 0.74, 0.02)
	return mat

static func _ghost() -> StandardMaterial3D:
	var mat := _pbr(Color(0.93, 0.91, 0.84, 0.4), 0.35, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
