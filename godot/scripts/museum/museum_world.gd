extends Node3D

signal request_back
signal request_reveal
signal request_dig

const Ui := preload("res://scripts/ui/ui_kit.gd")
const DinoBuilder := preload("res://scripts/dino/dino_builder.gd")
const FossilAssembly := preload("res://scripts/museum/fossil_assembly.gd")

var site_id := ""
var dino: Node3D
var cam: Camera3D
var dragging := ""
var drag_pos := Vector2.ZERO
var proxy: MeshInstance3D
var assembly
var visitors := []
var _status: Label
var _hint_label: Label
var _progress_label: Label
var _life_button: Button
var _cards := {}

class Visitor:
	extends Node3D
	var target := Vector3.ZERO
	var speed := 0.9
	var obstacles: Array = []
	var bounds := 5.5
	var _t := 0.0

	func _ready() -> void:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 1.1
		body.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.42, 0.55)
		mat.roughness = 0.7
		body.material_override = mat
		body.position = Vector3(0, 0.55, 0)
		add_child(body)
		_pick()

	func _pick() -> void:
		target = Vector3(randf_range(-bounds, bounds), 0.0, randf_range(-2.6, 3.0))

	func _process(delta: float) -> void:
		_t += delta
		var to := target - position
		to.y = 0.0
		if to.length() < 0.3 or _t > 9.0:
			_t = 0.0
			_pick()
			return
		var dir := to.normalized()
		for o in obstacles:
			var center: Vector3 = o[0]
			var radius: float = o[1]
			var away := position - center
			away.y = 0.0
			var d := away.length()
			if d < radius + 0.7 and d > 0.001:
				var push := (1.0 - d / (radius + 0.7)) * 2.2
				dir = (dir + away.normalized() * push).normalized()
		position += dir * speed * delta
		rotation.y = atan2(dir.x, dir.z)

func _ready() -> void:
	add_to_group("locale_refresh")
	_room()
	var info := Catalog.dino(str(Catalog.site(site_id).dino))
	dino = DinoBuilder.build(info, "ghost")
	dino.position = Vector3(0, 0.15, 0)
	dino.rotation_degrees = Vector3(0, 28, 0)
	dino.scale *= 1.15
	add_child(dino)
	_apply_saved()
	_build_assembly()
	_build_exhibits()
	cam = Camera3D.new()
	cam.position = Vector3(0.2, 2.3, 6.4)
	cam.fov = 42
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0))
	proxy = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.08
	cap.height = 0.36
	proxy.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.89, 0.76)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.6)
	mat.emission_energy_multiplier = 0.3
	proxy.material_override = mat
	proxy.visible = false
	add_child(proxy)
	_hud()

func _process(_delta: float) -> void:
	if dragging != "" and cam:
		var origin := cam.project_ray_origin(drag_pos)
		var dir := cam.project_ray_normal(drag_pos)
		proxy.global_position = origin + dir * 3.2
		proxy.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if dragging == "":
		return
	if event is InputEventMouseMotion:
		drag_pos = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		drag_pos = (event as InputEventScreenDrag).position
	elif (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed):
		var pos := drag_pos
		if event is InputEventMouseButton:
			pos = (event as InputEventMouseButton).position
		elif event is InputEventScreenTouch:
			pos = (event as InputEventScreenTouch).position
		_drop(pos)

func _drop(_screen_pos: Vector2) -> void:
	var bone := dragging
	dragging = ""
	proxy.visible = false
	if bone == "" or cam == null or assembly == null:
		return
	var state := GameState.bone_state(site_id, bone)
	if not bool(state.collected):
		_status.text = Locale.t("need_bones")
		return
	var target := assembly.nearest_socket(proxy.global_position)
	if target == bone and assembly.try_snap(bone, proxy.global_position):
		_place(bone)
		return
	if target != "" or _near_any_socket(proxy.global_position):
		_status.text = Locale.t("snap_no")
		Sfx.play("wrong", 1.2)
		GameState.buzz(12)

func _place(bone_id: String) -> void:
	var state := GameState.bone_state(site_id, bone_id)
	if not bool(state.collected):
		_status.text = Locale.t("need_bones")
		return
	GameState.place_bone(site_id, bone_id)
	dino.call("set_bone_visual", bone_id, "fossil", float(state.damage))
	Sfx.play("snap")
	GameState.buzz(16)
	_status.text = Locale.t("snap_ok")
	_refresh_cards()
	_update_progress()
	if GameState.all_placed(site_id):
		_status.text = Locale.t("all_placed")
		Sfx.play("star")
		_life_button.disabled = false
		Ui.paint(_life_button, "good")

func _apply_saved() -> void:
	var info := Catalog.site(site_id)
	for spot in info.get("spots", []):
		var bone_id := str(spot.bone)
		var state := GameState.bone_state(site_id, bone_id)
		if bool(state.placed):
			dino.call("set_bone_visual", bone_id, "fossil", float(state.damage))
		else:
			dino.call("set_bone_visual", bone_id, "ghost")

func _hint() -> void:
	var info := Catalog.site(site_id)
	var dino_id := str(info.dino)
	for spot in info.get("spots", []):
		var bone_id := str(spot.bone)
		var state := GameState.bone_state(site_id, bone_id)
		if bool(state.placed):
			continue
		var name := Locale.pick(Catalog.bone(dino_id, bone_id))
		if not bool(state.collected):
			_status.text = Locale.t("hint_buried")
			dino.set("hint_bone", "")
			return
		_status.text = Locale.t("hint_bone", {"name": name})
		dino.set("hint_bone", bone_id)
		Voice.speak(_status.text)
		return
	_status.text = Locale.t("all_placed")

func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	Ui.fill(root)
	layer.add_child(root)
	var top := Ui.label(Locale.pick(Catalog.dino(str(Catalog.site(site_id).dino)).name), 40)
	top.position = Vector2(28, 16)
	root.add_child(top)
	_hint_label = Ui.label(Locale.t("drag_help"), 22)
	_hint_label.position = Vector2(28, 64)
	_hint_label.size = Vector2(900, 40)
	root.add_child(_hint_label)
	var back := Ui.button(Locale.t("back"), "cream")
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -200
	back.offset_top = 16
	back.offset_right = -24
	back.offset_bottom = 84
	back.pressed.connect(func(): request_back.emit())
	root.add_child(back)
	var dig := Ui.button(Locale.t("resume_dig"), "teal")
	dig.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dig.offset_left = -430
	dig.offset_top = 16
	dig.offset_right = -214
	dig.offset_bottom = 84
	dig.pressed.connect(func(): request_dig.emit())
	root.add_child(dig)
	_status = Ui.label("", 28)
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -360
	_status.offset_top = 110
	_status.offset_right = 360
	_status.offset_bottom = 170
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)
	_progress_label = Ui.label("", 24)
	_progress_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress_label.offset_left = -360
	_progress_label.offset_top = 172
	_progress_label.offset_right = 360
	_progress_label.offset_bottom = 210
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_progress_label)
	var tray := HBoxContainer.new()
	tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray.offset_top = -150
	tray.offset_bottom = -24
	tray.offset_left = 24
	tray.offset_right = -240
	tray.add_theme_constant_override("separation", 10)
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tray)
	var info := Catalog.site(site_id)
	var dino_id := str(info.dino)
	for spot in info.spots:
		var bone_id := str(spot.bone)
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 100)
		card.focus_mode = Control.FOCUS_NONE
		card.text = Locale.pick(Catalog.bone(dino_id, bone_id))
		var captured := bone_id
		card.button_down.connect(func(): _begin_drag(captured))
		tray.add_child(card)
		_cards[bone_id] = card
	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	side.offset_left = -220
	side.offset_top = -220
	side.offset_right = -24
	side.offset_bottom = -24
	side.add_theme_constant_override("separation", 10)
	root.add_child(side)
	var hint := Ui.button(Locale.t("hint"), "sun")
	hint.pressed.connect(_hint)
	side.add_child(hint)
	_life_button = Ui.button(Locale.t("bring_life"), "good")
	_life_button.pressed.connect(func(): request_reveal.emit())
	side.add_child(_life_button)
	_refresh_cards()

func _begin_drag(bone_id: String) -> void:
	var state := GameState.bone_state(site_id, bone_id)
	if not bool(state.collected):
		_status.text = Locale.t("need_bones")
		Sfx.play("wrong")
		return
	if bool(state.placed):
		_status.text = Locale.t("placed")
		return
	dragging = bone_id
	drag_pos = get_viewport().get_mouse_position()
	Sfx.play("ui")

func _refresh_cards() -> void:
	var ready := GameState.all_placed(site_id)
	_life_button.disabled = not ready
	Ui.paint(_life_button, "good" if ready else "cream")
	var info := Catalog.site(site_id)
	for spot in info.spots:
		var bone_id := str(spot.bone)
		var card: Button = _cards[bone_id]
		var state := GameState.bone_state(site_id, bone_id)
		if bool(state.placed):
			card.text = "%s\n%s" % [Locale.pick(Catalog.bone(str(info.dino), bone_id)), Locale.t("placed")]
			Ui.paint(card, "good")
		elif bool(state.collected):
			card.text = Locale.pick(Catalog.bone(str(info.dino), bone_id))
			Ui.paint(card, "primary")
		else:
			card.text = "%s\n%s" % [Locale.pick(Catalog.bone(str(info.dino), bone_id)), Locale.t("not_found")]
			Ui.paint(card, "cream")
			card.modulate = Color(1, 1, 1, 0.55)

func refresh_locale() -> void:
	if _hint_label:
		_hint_label.text = Locale.t("drag_help")
	_refresh_cards()
	_update_progress()

func _build_assembly() -> void:
	assembly = FossilAssembly.new()
	assembly.name = "AssemblyArea"
	add_child(assembly)
	assembly.fossil_completed.connect(_on_fossil_completed)
	var info := Catalog.site(site_id)
	for spot in info.get("spots", []):
		var bone_id := str(spot.bone)
		var node := _find_part(bone_id)
		if node:
			assembly.register_socket(bone_id, node.global_transform)
		var state := GameState.bone_state(site_id, bone_id)
		if bool(state.placed):
			assembly.snap_to_socket(bone_id)
	_update_progress()

func _find_part(bone_id: String) -> Node3D:
	if dino == null:
		return null
	var parts = dino.get("parts")
	if not (parts is Dictionary):
		return null
	for key in parts:
		var node: Node3D = parts[key]
		if str(node.get_meta("bone_id", "")) == bone_id:
			return node
	return null

func _near_any_socket(world_pos: Vector3) -> bool:
	if assembly == null:
		return false
	for bone_id in assembly.bone_sockets:
		var xform: Transform3D = assembly.bone_sockets[bone_id]
		if world_pos.distance_to(xform.origin) < 0.5:
			return true
	return false

func _update_progress() -> void:
	if assembly == null:
		return
	var ratio: float = assembly.progress_ratio
	if _progress_label:
		var word := Locale.t("progress")
		if word == "progress":
			word = "İlerleme"
		_progress_label.text = "%s: %d%%" % [word, int(round(ratio * 100.0))]
	if dino and dino.has_method("set_completion"):
		dino.call("set_completion", ratio)

func _on_fossil_completed(_dino_id: String) -> void:
	if dino and dino.has_method("set_completion"):
		dino.call("set_completion", 1.0)
	if dino and dino.has_method("set_state"):
		dino.call("set_state", "IDLE_LIVING")
	if _status:
		_status.text = Locale.t("all_placed")
	Sfx.play("star")
	_spawn_visitors()

func _build_exhibits() -> void:
	var cases := Node3D.new()
	cases.name = "DisplayCases"
	add_child(cases)
	for i in 3:
		var case_m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.1, 1.4, 1.1)
		case_m.mesh = box
		case_m.position = Vector3(-4.2 + i * 1.6, 0.7, -3.2)
		case_m.material_override = _mat(Color("bfe3e0"), 0.25)
		cases.add_child(case_m)
	var panels := Node3D.new()
	panels.name = "InfoPanels"
	add_child(panels)
	var info := Catalog.dino(str(Catalog.site(site_id).dino))
	var title := Label3D.new()
	title.text = Locale.pick(info.name)
	title.font_size = 96
	title.pixel_size = 0.004
	title.position = Vector3(0, 3.1, -4.2)
	title.modulate = Color("2b2118")
	panels.add_child(title)
	var sub := Label3D.new()
	sub.text = Locale.t("drag_help")
	sub.font_size = 48
	sub.pixel_size = 0.004
	sub.position = Vector3(0, 2.6, -4.2)
	sub.modulate = Color("5a4a3a")
	panels.add_child(sub)

func _spawn_visitors() -> void:
	if not visitors.is_empty():
		return
	var obstacles := [[Vector3(0, 0, 0), 1.7]]
	for i in 3:
		var v := Visitor.new()
		v.name = "Visitor%d" % i
		v.position = Vector3(-3.0 + i * 3.0, 0.0, 2.6)
		v.obstacles = obstacles
		add_child(v)
		visitors.append(v)

func _room() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.13, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.48, 0.4)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	var fx := bool(GameState.settings.effects) and str(GameState.settings.get("quality", "medium")) != "low"
	env.glow_enabled = fx
	env.glow_intensity = 0.35
	env.ssao_enabled = fx
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.1
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 20, 0)
	sun.light_energy = 0.35
	sun.shadow_enabled = false
	add_child(sun)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.2, 4.3, 1.5)
	spot.rotation_degrees = Vector3(-78, 0, 0)
	spot.light_color = Color(1.0, 0.93, 0.78)
	spot.light_energy = 8.0
	spot.spot_range = 12.0
	spot.spot_angle = 32.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = str(GameState.settings.get("quality", "medium")) != "low"
	add_child(spot)
	spot.look_at(Vector3(0, 0.9, 0))
	var floor_m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 14)
	floor_m.mesh = plane
	var floor_mat := _mat(Color("c9844a"), 0.16)
	floor_mat.metallic = 0.14
	floor_mat.clearcoat_enabled = true
	floor_mat.clearcoat = 0.7
	floor_mat.clearcoat_roughness = 0.22
	floor_m.material_override = floor_mat
	add_child(floor_m)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(16, 6, 0.4)
	wall.mesh = box
	wall.position = Vector3(0, 3, -4.5)
	wall.material_override = _mat(Color("f6efe2"), 0.9)
	add_child(wall)
	var rug := MeshInstance3D.new()
	var rug_mesh := BoxMesh.new()
	rug_mesh.size = Vector3(6.5, 0.06, 3.2)
	rug.mesh = rug_mesh
	rug.position = Vector3(0, 0.04, 0.4)
	rug.material_override = _mat(Color("1f7a8c"), 0.8)
	add_child(rug)

func _mat(color: Color, rough := 0.7) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat
