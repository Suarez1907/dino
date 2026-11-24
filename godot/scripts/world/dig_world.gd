extends Node3D

signal request_menu
signal request_museum
signal request_passport

const SpotScript := preload("res://scripts/world/dig_spot.gd")
const JoyScript := preload("res://scripts/ui/joystick.gd")
const Ui := preload("res://scripts/ui/ui_kit.gd")
const Badge := preload("res://scripts/ui/icon_badge.gd")
const DinoBuilder := preload("res://scripts/dino/dino_builder.gd")

var site_id := ""
var spectator := false
var spots: Array = []
var player: CharacterBody3D
var joy_dir := Vector2.ZERO
var tool_id := "shovel"
var dig_hold := false
var detector_cd := 0.0
var near = null
var cam: Camera3D
var cam_yaw := 0.0
var tutorial_step := 0
var _moved := 0.0
var _toast := ""
var _toast_time := 0.0
var _near_museum := false
var env: Environment
var _terrain: MeshInstance3D

var _site_label: Label
var _soil_title: Label
var _soil_feel: Label
var _soil_bar: ProgressBar
var _toast_label: Label
var _tutorial_label: Label
var _tutorial_panel: PanelContainer
var _soil_panel: PanelContainer
var _badge: Control
var _detector_button: Button
var _tool_buttons := {}
var _museum_banner: Button
var _photo_btn: Button
var _photo_mode := false
var _arrow: MeshInstance3D
var _pati: Node3D
var _holding_wrong := false

func _ready() -> void:
	add_to_group("locale_refresh")
	_build_environment()
	_build_ground()
	_build_props()
	_build_spots()
	if not spectator:
		_build_player()
		_build_pati()
		_build_hud()
		if site().get("tutorial", false) and not GameState.tutorial_done:
			tutorial_step = 0
			Voice.speak(Locale.t("t0"))
		else:
			tutorial_step = 99
	else:
		_build_vista_dino()

func site() -> Dictionary:
	return Catalog.site(site_id)

func _process(delta: float) -> void:
	if spectator:
		cam_yaw += delta * 0.15
		var pivot := Vector3(0, 1.2, 2)
		cam.global_position = pivot + Vector3(sin(cam_yaw) * 9.0, 4.2, cos(cam_yaw) * 9.0)
		cam.look_at(pivot)
		return
	detector_cd = max(detector_cd - delta, 0.0)
	_follow_camera(delta)
	_follow_pati(delta)
	_update_near()
	_update_hud()
	_update_tutorial(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast_label:
			_toast_label.text = ""
	if bool(GameState.settings.guide_arrow) or tutorial_step in [2, 3, 4, 5]:
		_point_arrow()
	elif _arrow:
		_arrow.visible = false

func _physics_process(delta: float) -> void:
	if spectator or player == null:
		return
	var wish := joy_dir
	var keys := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keys.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keys.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keys.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keys.y += 1.0
	if keys.length() > 0.1:
		wish = keys
	for i in 6:
		if Input.is_key_pressed(KEY_1 + i):
			_select_tool(str(Catalog.catalog.tools[i].id))
	var basis := cam.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var dir := right * wish.x + forward * -wish.y
	if dir.length() > 1.0:
		dir = dir.normalized()
	player.velocity.y = 0.0
	player.velocity.x = dir.x * 4.6
	player.velocity.z = dir.z * 4.6
	player.move_and_slide()
	if _terrain and _terrain.has_method("sample"):
		player.global_position.y = _terrain.sample(player.global_position.x, player.global_position.z)
	if dir.length() > 0.15:
		var target := atan2(dir.x, dir.z)
		player.rotation.y = lerp_angle(player.rotation.y, target, 1.0 - exp(-8.0 * delta))
		_moved += dir.length() * delta
	var digging: bool = (dig_hold or Input.is_key_pressed(KEY_SPACE)) and near != null and not bool(near.collected)
	if digging:
		if not _holding_wrong:
			var result: Dictionary = near.use_tool(tool_id)
			if result.type == "ok":
				_holding_wrong = false
			elif result.type == "fragile":
				_say(Locale.t("fragile_hit"))
				_holding_wrong = true
				dig_hold = false
			elif result.type == "wrong":
				_say(Locale.t("wrong_tool"))
				_holding_wrong = true
				dig_hold = false
			elif result.type == "lock":
				_holding_wrong = true
		if not _holding_wrong:
			var step: Dictionary = near.hold(delta)
			if step.type == "collected":
				_on_collected(float(step.damage))
				_holding_wrong = false
			elif step.type == "next":
				_say(Locale.t("layer_done"))
				_holding_wrong = false
				if tutorial_step == 4:
					tutorial_step = 5
	else:
		_holding_wrong = false
	if Input.is_key_pressed(KEY_R) and detector_cd <= 0.0:
		_detect()

func _on_collected(damage: float) -> void:
	if damage <= 0.01:
		_say(Locale.t("bone_safe"))
	else:
		_say(Locale.t("bone_cracked"))
	if tutorial_step <= 6:
		tutorial_step = 6
		GameState.tutorial_done = true
		GameState.mark_dirty()
		Voice.speak(Locale.t("t6"))

func _say(text: String) -> void:
	_toast = text
	_toast_time = 2.8
	if _toast_label:
		_toast_label.text = text

func _update_near() -> void:
	var best = null
	var best_d := 1.85
	for spot in spots:
		if spot.collected:
			continue
		var d := player.global_position.distance_to(spot.global_position)
		if d < best_d:
			best = spot
			best_d = d
	near = best
	var tent: Array = site().get("tent", [-6, 0])
	var tent_pos := Vector3(float(tent[0]), 0, float(tent[1]))
	_near_museum = player.global_position.distance_to(tent_pos) < 2.4

func _update_hud() -> void:
	if _soil_panel == null:
		return
	_soil_panel.visible = near != null and not near.collected and not _photo_mode
	if _museum_banner:
		_museum_banner.visible = _near_museum and not _photo_mode
	if near != null and not near.collected:
		var soil := Catalog.soil(near.soil_id())
		_soil_title.text = Locale.pick(soil.get("name", near.soil_id()))
		var feel := str(soil.get("feel", "soft"))
		_soil_feel.text = Locale.t("feel_" + feel)
		_soil_bar.value = near.progress * 100.0
		if _badge:
			_badge.kind = str(soil.get("icon", "pile"))
			_badge.queue_redraw()
	if _detector_button:
		if detector_cd > 0.0:
			_detector_button.text = "%s %ds" % [Locale.t("detector"), int(ceil(detector_cd))]
		else:
			_detector_button.text = Locale.t("detector")
	if _site_label:
		var stars := GameState.site_stars(site_id)
		_site_label.text = "%s  %s" % [Locale.pick(site().name), "★".repeat(stars)]

func _update_tutorial(_delta: float) -> void:
	if _tutorial_panel == null:
		return
	var show := tutorial_step >= 0 and tutorial_step <= 6
	_tutorial_panel.visible = show
	if not show:
		return
	_tutorial_label.text = Locale.t("t%d" % tutorial_step)
	if tutorial_step == 0 and _moved > 0.4:
		tutorial_step = 1
	elif tutorial_step == 1 and _moved > 1.2:
		tutorial_step = 2
	elif tutorial_step == 2 and near != null and str(near.bone_id) == "skull":
		tutorial_step = 3
	elif tutorial_step == 3 and tool_id == "shovel" and near != null:
		tutorial_step = 4
	elif tutorial_step == 5 and tool_id == "brush":
		pass

func _point_arrow() -> void:
	if _arrow == null or player == null:
		return
	var target: Node3D = null
	var best := 9999.0
	for spot in spots:
		if spot.collected:
			continue
		if tutorial_step in [2, 3, 4, 5] and str(spot.bone_id) != "skull":
			continue
		var d := player.global_position.distance_to(spot.global_position)
		if d < best:
			best = d
			target = spot
	if target == null:
		_arrow.visible = false
		return
	_arrow.visible = true
	_arrow.global_position = target.global_position + Vector3(0, 1.6 + sin(Time.get_ticks_msec() / 300.0) * 0.12, 0)

func _follow_camera(delta: float) -> void:
	var focus := player.global_position + Vector3(0, 1.1, 0)
	var offset := Vector3(sin(cam_yaw) * 6.4, 3.5, cos(cam_yaw) * 6.4)
	var desired := player.global_position + offset
	var from := focus
	var space := get_world_3d().direct_space_state
	if space:
		var query := PhysicsRayQueryParameters3D.create(from, desired)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + (from - desired).normalized() * 0.45
	cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-4.0 * delta))
	cam.look_at(focus)

func _follow_pati(delta: float) -> void:
	if _pati == null:
		return
	var dest := player.global_position + Vector3(-1.15, 0, 0.85)
	_pati.global_position = _pati.global_position.lerp(dest, 1.0 - exp(-2.4 * delta))
	var flat := dest - _pati.global_position
	flat.y = 0
	if flat.length() > 0.05:
		_pati.rotation.y = lerp_angle(_pati.rotation.y, atan2(flat.x, flat.z), 1.0 - exp(-6.0 * delta))

func _select_tool(id: String) -> void:
	tool_id = id
	_holding_wrong = false
	Sfx.play("ui", 1.2)
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		Ui.paint(btn, "primary" if key == tool_id else "cream")
	if tutorial_step == 3 and id == "shovel":
		tutorial_step = 4

func _detect() -> void:
	if detector_cd > 0.0:
		_say(Locale.t("detector_cool"))
		return
	detector_cd = 8.0
	Sfx.play("ping")
	GameState.buzz(16)
	var found := 0
	for spot in spots:
		if spot.collected:
			continue
		var d := player.global_position.distance_to(spot.global_position)
		if d < 12.0:
			found += 1
			_ring(spot.global_position, d)
	_say(Locale.t("detector_ping") if found > 0 else Locale.t("detector_none"))

func _ring(pos: Vector3, distance: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 0.4
	torus.bottom_radius = 0.4
	torus.height = 0.05
	ring.mesh = torus
	ring.position = pos + Vector3(0, 0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.85, 0.95, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.8
	ring.material_override = mat
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3(6, 1, 6), 1.1)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.1)
	tween.tween_callback(ring.queue_free)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var biome := str(site().get("biome", "desert"))
	if biome == "forest":
		sky_mat.sky_top_color = Color(0.45, 0.72, 0.9)
		sky_mat.sky_horizon_color = Color(0.78, 0.9, 0.72)
		sky_mat.ground_horizon_color = Color(0.45, 0.58, 0.36)
		sky_mat.ground_bottom_color = Color(0.25, 0.36, 0.2)
	elif biome == "ice":
		sky_mat.sky_top_color = Color(0.55, 0.75, 0.95)
		sky_mat.sky_horizon_color = Color(0.9, 0.96, 1.0)
		sky_mat.ground_horizon_color = Color(0.8, 0.9, 0.96)
		sky_mat.ground_bottom_color = Color(0.65, 0.78, 0.88)
	else:
		sky_mat.sky_top_color = Color(0.45, 0.72, 0.95)
		sky_mat.sky_horizon_color = Color(1.0, 0.82, 0.58)
		sky_mat.ground_horizon_color = Color(0.86, 0.66, 0.38)
		sky_mat.ground_bottom_color = Color(0.62, 0.42, 0.24)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	var grade := str(GameState.settings.get("quality", "medium"))
	var fx := bool(GameState.settings.effects) and grade != "low"
	env.glow_enabled = fx
	env.glow_intensity = 0.42 if grade == "high" else 0.28
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = fx
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.35 if grade == "high" else 0.9
	env.ssao_power = 1.4
	env.ssao_detail = 0.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.01 if grade == "low" else 0.018
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_aerial_perspective = 0.35
	if grade == "high" and fx and str(RenderingServer.get_current_rendering_method()) == "forward_plus":
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.006
		env.volumetric_fog_albedo = Color(1.0, 0.88, 0.68)
	if grade != "low" and ResourceLoader.exists("res://assets/textures/sky.hdr"):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load("res://assets/textures/sky.hdr")
		pano.energy_multiplier = 0.9
		sky.sky_material = pano
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35
	sun.shadow_enabled = grade != "low"
	sun.shadow_blur = 2.2 if grade == "high" else 1.2
	sun.light_volumetric_fog_energy = 1.6 if grade == "high" else 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color(0.7, 0.82, 1.0)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)
	cam = Camera3D.new()
	cam.fov = 52
	add_child(cam)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 2, 80)
	shape.shape = box
	shape.position = Vector3(0, -12, 0)
	body.add_child(shape)
	add_child(body)
	var terrain := MeshInstance3D.new()
	terrain.set_script(load("res://scripts/world/terrain.gd"))
	add_child(terrain)
	terrain.setup(str(site().get("biome", "desert")), site_id)
	_terrain = terrain

func _on_ground(point: Vector3) -> Vector3:
	if _terrain and _terrain.has_method("sample"):
		point.y = _terrain.sample(point.x, point.z)
	return point

func _crate(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.55, 0.7)
	mesh.mesh = box
	mesh.position = at + Vector3(0, 0.28, 0)
	mesh.material_override = _mat(Color("8a5a32"), 0.84)
	add_child(mesh)

func _fence(at: Vector3) -> void:
	for i in 5:
		var post := MeshInstance3D.new()
		var cap := CylinderMesh.new()
		cap.top_radius = 0.05
		cap.bottom_radius = 0.06
		cap.height = 0.9
		post.mesh = cap
		post.position = at + Vector3(float(i) * 0.85, 0.45, 0)
		post.material_override = _mat(Color("a56b3c"), 0.86)
		add_child(post)
	var rail := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(3.5, 0.06, 0.06)
	rail.mesh = bar
	rail.position = at + Vector3(1.7, 0.7, 0)
	rail.material_override = _mat(Color("a56b3c"), 0.86)
	add_child(rail)

func _grid(at: Vector3) -> void:
	for i in 3:
		for j in 3:
			var post := MeshInstance3D.new()
			var cap := CylinderMesh.new()
			cap.top_radius = 0.03
			cap.bottom_radius = 0.03
			cap.height = 0.42
			post.mesh = cap
			post.position = at + Vector3(float(i) * 0.75, 0.2, float(j) * 0.75)
			post.material_override = _mat(Color("f2e2b0"), 0.7)
			add_child(post)

func _build_props() -> void:
	var biome := str(site().get("biome", "desert"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(site_id)
	var count := 14
	var grade := str(GameState.settings.get("quality", "medium"))
	if grade == "low":
		count = 8
	elif grade == "high":
		count = 22
	for i in count:
		var p := Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-6, 18))
		if Vector2(p.x, p.z).length() < 2.4:
			continue
		p = _on_ground(p)
		if biome == "forest":
			_tree(p, rng.randf_range(0.8, 1.4))
		elif biome == "ice":
			_crystal(p, rng.randf_range(0.6, 1.5))
		else:
			if i % 2 == 0:
				_cactus(p, rng.randf_range(0.7, 1.3))
			else:
				_rock(p, rng.randf_range(0.4, 1.1), Color("b88858"))
	var tent_pos_a: Array = site().get("tent", [-6, 0])
	var tent_p := _on_ground(Vector3(float(tent_pos_a[0]), 0, float(tent_pos_a[1])))
	_tent(tent_p)
	_crate(_on_ground(tent_p + Vector3(2.2, 0, 0.6)))
	_crate(_on_ground(tent_p + Vector3(2.6, 0, 1.4)))
	if grade != "low":
		_fence(_on_ground(tent_p + Vector3(-1.2, 0, 3.0)))
		_grid(_on_ground(Vector3(4.4, 0, 6.2)))

func _build_spots() -> void:
	for spot_data in site().get("spots", []):
		var spot := Node3D.new()
		spot.set_script(SpotScript)
		add_child(spot)
		spot.setup(site_id, spot_data)
		if _terrain:
			spot.position.y = _terrain.sample(spot.position.x, spot.position.z)
			if spot.has_method("_refresh"):
				spot.call("_refresh")
		spots.append(spot)

func _build_player() -> void:
	player = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.15
	shape.shape = cap
	shape.position = Vector3(0, 0.7, 0)
	player.add_child(shape)
	var spawn: Array = site().get("spawn", [0, 2])
	var spawn_y := 0.1
	if _terrain:
		spawn_y = _terrain.sample(float(spawn[0]), float(spawn[1]))
	player.position = Vector3(float(spawn[0]), spawn_y, float(spawn[1]))
	_explorer_mesh(player)
	add_child(player)
	cam.global_position = player.global_position + Vector3(0, 3.5, 6.4)
	cam.look_at(player.global_position + Vector3(0, 1, 0))

func _explorer_mesh(parent: Node3D) -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 0.85
	body.mesh = cap
	body.position = Vector3(0, 0.72, 0)
	body.material_override = _mat(Color("3d7ea6"))
	parent.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	head.mesh = sphere
	head.position = Vector3(0, 1.22, 0)
	head.material_override = _mat(Color("f2c7a2"))
	parent.add_child(head)
	var hat := MeshInstance3D.new()
	var brim := CylinderMesh.new()
	brim.top_radius = 0.12
	brim.bottom_radius = 0.28
	brim.height = 0.16
	hat.mesh = brim
	hat.position = Vector3(0, 1.42, 0)
	hat.material_override = _mat(Color("f2c14e"))
	parent.add_child(hat)
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.32, 0.16)
	pack.mesh = box
	pack.position = Vector3(0, 0.85, 0.26)
	pack.material_override = _mat(Color("8a5a3a"))
	parent.add_child(pack)

func _build_pati() -> void:
	_pati = Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.16
	cap.height = 0.42
	body.mesh = cap
	body.position = Vector3(0, 0.28, 0)
	body.rotation_degrees = Vector3(90, 0, 0)
	body.material_override = _mat(Color("f08a3c"))
	_pati.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	head.mesh = sphere
	head.position = Vector3(0, 0.38, -0.18)
	head.material_override = _mat(Color("f6b15a"))
	_pati.add_child(head)
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.07
	for x in [-0.05, 0.05]:
		var e := MeshInstance3D.new()
		e.mesh = eye
		e.position = Vector3(x, 0.42, -0.28)
		e.material_override = _mat(Color(0.12, 0.1, 0.1))
		_pati.add_child(e)
	_pati.position = player.position + Vector3(-1.2, 0, 0.8)
	add_child(_pati)

func _build_vista_dino() -> void:
	var dino := DinoBuilder.build(Catalog.dino(str(site().dino)), "living")
	dino.position = Vector3(1.5, 0, 4)
	dino.rotation_degrees = Vector3(0, 25, 0)
	add_child(dino)
	cam.global_position = Vector3(6, 4.2, 10)
	cam.look_at(Vector3(0, 1.2, 2))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	Ui.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_site_label = Ui.label("", 30)
	_site_label.position = Vector2(28, 18)
	_site_label.size = Vector2(760, 48)
	root.add_child(_site_label)
	var menu := Ui.button(Locale.t("menu"), "cream")
	menu.custom_minimum_size = Vector2(160, 64)
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -190
	menu.offset_top = 16
	menu.offset_right = -24
	menu.offset_bottom = 80
	menu.pressed.connect(func(): request_menu.emit())
	root.add_child(menu)
	var pass_btn := Ui.button(Locale.t("passport"), "teal")
	pass_btn.custom_minimum_size = Vector2(200, 64)
	pass_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pass_btn.offset_left = -410
	pass_btn.offset_top = 16
	pass_btn.offset_right = -200
	pass_btn.offset_bottom = 80
	pass_btn.pressed.connect(func(): request_passport.emit())
	root.add_child(pass_btn)
	var joy := Control.new()
	joy.set_script(JoyScript)
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.offset_left = 28
	joy.offset_top = -230
	joy.offset_right = 210
	joy.offset_bottom = -36
	joy.moved.connect(func(v): joy_dir = v)
	root.add_child(joy)
	var tools := GridContainer.new()
	tools.columns = 3
	tools.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.offset_left = -430
	tools.offset_top = -250
	tools.offset_right = -150
	tools.offset_bottom = -28
	tools.add_theme_constant_override("h_separation", 8)
	tools.add_theme_constant_override("v_separation", 8)
	root.add_child(tools)
	for tool in Catalog.catalog.tools:
		var id := str(tool.id)
		var btn := Ui.button(Locale.pick(tool), "primary" if id == tool_id else "cream")
		btn.custom_minimum_size = Vector2(86, 64)
		btn.pressed.connect(_select_tool.bind(id))
		tools.add_child(btn)
		_tool_buttons[id] = btn
	var dig := Ui.button(Locale.t("dig"), "primary")
	dig.custom_minimum_size = Vector2(120, 120)
	dig.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dig.offset_left = -140
	dig.offset_top = -168
	dig.offset_right = -20
	dig.offset_bottom = -28
	dig.button_down.connect(func():
		dig_hold = true
		_holding_wrong = false
	)
	dig.button_up.connect(func(): dig_hold = false)
	root.add_child(dig)
	_detector_button = Ui.button(Locale.t("detector"), "teal")
	_detector_button.custom_minimum_size = Vector2(150, 64)
	_detector_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_detector_button.offset_left = -300
	_detector_button.offset_top = -250
	_detector_button.offset_right = -140
	_detector_button.offset_bottom = -180
	_detector_button.pressed.connect(_detect)
	root.add_child(_detector_button)
	_photo_btn = Ui.button("📷", "sun")
	_photo_btn.custom_minimum_size = Vector2(120, 56)
	_photo_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_photo_btn.offset_left = 28
	_photo_btn.offset_top = -300
	_photo_btn.offset_right = 172
	_photo_btn.offset_bottom = -236
	_photo_btn.pressed.connect(_toggle_photo)
	root.add_child(_photo_btn)
	_soil_panel = PanelContainer.new()
	_soil_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_soil_panel.offset_left = -520
	_soil_panel.offset_top = -390
	_soil_panel.offset_right = -150
	_soil_panel.offset_bottom = -260
	_soil_panel.visible = false
	var box := HBoxContainer.new()
	_soil_panel.add_child(box)
	_badge = Control.new()
	_badge.set_script(Badge)
	_badge.custom_minimum_size = Vector2(64, 64)
	box.add_child(_badge)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(col)
	_soil_title = Ui.label("", 28)
	_soil_feel = Ui.label("", 22)
	_soil_bar = ProgressBar.new()
	_soil_bar.max_value = 100
	_soil_bar.custom_minimum_size = Vector2(0, 18)
	_soil_bar.show_percentage = false
	col.add_child(_soil_title)
	col.add_child(_soil_feel)
	col.add_child(_soil_bar)
	var hint := Ui.button(Locale.t("hint"), "sun")
	hint.custom_minimum_size = Vector2(120, 56)
	hint.pressed.connect(_hint)
	col.add_child(hint)
	root.add_child(_soil_panel)
	_museum_banner = Ui.button(Locale.t("enter_museum"), "good")
	_museum_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_museum_banner.offset_left = -160
	_museum_banner.offset_top = -120
	_museum_banner.offset_right = 160
	_museum_banner.offset_bottom = -40
	_museum_banner.visible = false
	_museum_banner.pressed.connect(func(): request_museum.emit())
	root.add_child(_museum_banner)
	_toast_label = Ui.label("", 30)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -420
	_toast_label.offset_top = 90
	_toast_label.offset_right = 420
	_toast_label.offset_bottom = 180
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast_label)
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial_panel.offset_left = -460
	_tutorial_panel.offset_top = 188
	_tutorial_panel.offset_right = 460
	_tutorial_panel.offset_bottom = 320
	var trow := HBoxContainer.new()
	_tutorial_panel.add_child(trow)
	var pati := Ui.label(Locale.t("pati_name"), 28)
	trow.add_child(pati)
	_tutorial_label = Ui.label("", 26)
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(_tutorial_label)
	var skip := Ui.button(Locale.t("tutorial_skip"), "cream")
	skip.custom_minimum_size = Vector2(120, 56)
	skip.pressed.connect(func():
		tutorial_step = 99
		GameState.tutorial_done = true
		GameState.mark_dirty()
		_tutorial_panel.visible = false
	)
	trow.add_child(skip)
	root.add_child(_tutorial_panel)
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.18
	cone.height = 0.35
	_arrow.mesh = cone
	_arrow.material_override = _mat(Color("f2c14e"))
	add_child(_arrow)
	refresh_locale()

func _hint() -> void:
	if near == null:
		_say(Locale.t("far_spot"))
		return
	var soil := Catalog.soil(near.soil_id())
	_say(Locale.pick(soil.get("hint", "")))
	Voice.speak(Locale.pick(soil.get("hint", "")))

func _toggle_photo() -> void:
	_photo_mode = not _photo_mode
	if _site_label:
		_site_label.visible = not _photo_mode
	if _photo_btn:
		_photo_btn.text = "📷 ✓" if _photo_mode else "📷"
	if _museum_banner:
		_museum_banner.visible = false

func refresh_locale() -> void:
	if _tool_buttons.is_empty():
		return
	for tool in Catalog.catalog.tools:
		var id := str(tool.id)
		if _tool_buttons.has(id):
			_tool_buttons[id].text = Locale.pick(tool)

func _tree(pos: Vector3, scale: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * scale
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.18
	cyl.height = 1.1
	trunk.mesh = cyl
	trunk.position = Vector3(0, 0.55, 0)
	trunk.material_override = _mat(Color("7a4e32"))
	n.add_child(trunk)
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.3
	crown.mesh = sphere
	crown.position = Vector3(0, 1.45, 0)
	crown.material_override = _mat(Color("3f8f4e"))
	n.add_child(crown)
	add_child(n)

func _cactus(pos: Vector3, scale: float) -> void:
	var n := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.16
	cap.height = 1.3
	n.mesh = cap
	n.position = pos + Vector3(0, 0.65, 0)
	n.scale = Vector3.ONE * scale
	n.material_override = _mat(Color("6ea85a"))
	add_child(n)

func _rock(pos: Vector3, scale: float, color: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.7
	n.mesh = mesh
	n.position = pos + Vector3(0, 0.2, 0)
	n.scale = Vector3(scale, scale * 0.6, scale)
	n.material_override = _mat(color)
	add_child(n)

func _crystal(pos: Vector3, scale: float) -> void:
	var n := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.35, 1.1, 0.35)
	n.mesh = mesh
	n.position = pos + Vector3(0, 0.5, 0)
	n.scale = Vector3.ONE * scale
	var mat := _mat(Color("d5f1ff"))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.78
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.25
	n.material_override = mat
	add_child(n)

func _tent(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	var cloth := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.5
	cone.height = 1.7
	cloth.mesh = cone
	cloth.position = Vector3(0, 0.85, 0)
	cloth.material_override = _mat(Color("e07a3d"))
	n.add_child(cloth)
	var flag := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.28, 0.05)
	flag.mesh = box
	flag.position = Vector3(0.35, 1.85, 0)
	flag.material_override = _mat(Color("f2c14e"))
	n.add_child(flag)
	var light := OmniLight3D.new()
	light.position = Vector3(0.8, 1.2, 0.4)
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 0.8
	light.omni_range = 6.0
	n.add_child(light)
	add_child(n)

func _mat(color: Color, rough := 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat
