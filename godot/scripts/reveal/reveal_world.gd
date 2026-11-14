extends Node3D

signal request_menu
signal request_next
signal request_museum

const Ui := preload("res://scripts/ui/ui_kit.gd")
const DinoBuilder := preload("res://scripts/dino/dino_builder.gd")

var site_id := ""
var dino: Node3D
var cam: Camera3D
var age := 0.0
var _spoke := false
var _fact := ""
var _subtitle: Label
var _title: Label
var _walk_time := 0.0

func _ready() -> void:
	add_to_group("locale_refresh")
	_scene()
	var info := Catalog.dino(str(Catalog.site(site_id).dino))
	dino = DinoBuilder.build(info, "living")
	dino.position = Vector3(0, 0, 0)
	dino.scale *= 1.2
	add_child(dino)
	dino.call("capture_base")
	cam = Camera3D.new()
	cam.fov = 46
	add_child(cam)
	_fact = ""
	var facts: Array = info.get("facts", [])
	if facts.size() > 0:
		_fact = Locale.pick(facts[0])
	_hud(info)
	Sfx.play("star")
	GameState.reveal_site(site_id)

func _process(delta: float) -> void:
	age += delta
	var info := Catalog.dino(str(Catalog.site(site_id).dino))
	var focus := dino.global_position + Vector3(0, 1.2, 0)
	if age < 1.4:
		dino.set("anim", "idle")
		cam.global_position = cam.global_position.lerp(Vector3(2.2, 2.4, 5.2), 1.0 - exp(-2.0 * delta))
	elif age < 5.2:
		dino.set("anim", "walk")
		_walk_time += delta
		dino.position.x = sin(_walk_time * 0.55) * 2.4
		dino.position.z = -1.2 + cos(_walk_time * 0.55) * 1.4
		dino.rotation.y = atan2(cos(_walk_time * 0.55), -sin(_walk_time * 0.55))
		dino.call("capture_base")
		cam.global_position = cam.global_position.lerp(dino.global_position + Vector3(3.2, 2.2, 4.2), 1.0 - exp(-2.2 * delta))
	elif age < 8.0:
		dino.set("anim", "eat")
		cam.global_position = cam.global_position.lerp(dino.global_position + Vector3(1.6, 1.6, 3.4), 1.0 - exp(-2.4 * delta))
		if _subtitle and _subtitle.text == "":
			var diet := str(info.get("diet", "herbivore"))
			_subtitle.text = Locale.t("eat_herb" if diet == "herbivore" else "eat_carn")
	elif age < 11.0:
		dino.set("anim", "roar")
		cam.global_position = cam.global_position.lerp(dino.global_position + Vector3(0.4, 1.8, 4.6), 1.0 - exp(-2.0 * delta))
		if not _spoke:
			_spoke = true
			var roar := str(info.get("sounds", {}).get("roar", "mid"))
			Sfx.play("roar_" + roar)
			GameState.buzz(28)
			_subtitle.text = _fact
			var clip := str(info.get("sounds", {}).get("voice", ""))
			Voice.speak(Locale.t("hello_dino", {"name": Locale.pick(info.name)}) + " " + _fact, clip)
	else:
		dino.set("anim", "idle")
		cam.global_position = cam.global_position.lerp(dino.global_position + Vector3(2.4, 2.0, 5.0), 1.0 - exp(-1.6 * delta))
	cam.look_at(focus)

func _hud(info: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	Ui.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_title = Ui.label(Locale.t("hello_dino", {"name": Locale.pick(info.name)}), 48)
	_title.position = Vector2(40, 24)
	_title.size = Vector2(1200, 70)
	root.add_child(_title)
	var diet := Locale.t("diet_herb" if str(info.diet) == "herbivore" else "diet_carn")
	var stars := GameState.site_stars(site_id)
	var line := Ui.label("%s   %s" % [diet, "★".repeat(maxi(stars, 1))], 28)
	line.position = Vector2(40, 96)
	root.add_child(line)
	_subtitle = Ui.label(Locale.t("wake_line", {"name": Locale.pick(info.name)}), 30)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_left = -520
	_subtitle.offset_top = -250
	_subtitle.offset_right = 520
	_subtitle.offset_bottom = -150
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_subtitle)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -130
	row.offset_bottom = -28
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	var menu := Ui.button(Locale.t("menu"), "cream")
	menu.pressed.connect(func(): request_menu.emit())
	row.add_child(menu)
	var again := Ui.button(Locale.t("museum"), "teal")
	again.pressed.connect(func(): request_museum.emit())
	row.add_child(again)
	var nxt := Ui.button(Locale.t("next_site"), "primary")
	var idx := Catalog.site_index(site_id)
	nxt.disabled = idx < 0 or idx + 1 >= Catalog.sites.size()
	nxt.pressed.connect(func(): request_next.emit())
	row.add_child(nxt)
	var roar := Ui.button(Locale.t("roar"), "sun")
	roar.pressed.connect(func():
		age = 8.05
		_spoke = false
	)
	row.add_child(roar)
	_food(str(info.diet))

func _food(diet: String) -> void:
	var node := Node3D.new()
	node.position = Vector3(1.5, 0, -0.4)
	if diet == "herbivore":
		for i in 5:
			var leaf := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.4
			leaf.mesh = sphere
			leaf.position = Vector3(sin(float(i)) * 0.25, 0.35 + float(i) * 0.05, cos(float(i)) * 0.2)
			leaf.material_override = _mat(Color("3f8f4e").lightened(float(i) * 0.04))
			node.add_child(leaf)
	else:
		var plate := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.4
		cyl.height = 0.08
		plate.mesh = cyl
		plate.position = Vector3(0, 0.2, 0)
		plate.material_override = _mat(Color("f4efe6"))
		node.add_child(plate)
		var meat := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.12
		cap.height = 0.46
		meat.mesh = cap
		meat.rotation_degrees = Vector3(0, 30, 70)
		meat.position = Vector3(0, 0.38, 0)
		meat.material_override = _mat(Color("c46a4a"))
		node.add_child(meat)
	add_child(node)

func _scene() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.42, 0.7, 0.95)
	sky_mat.sky_horizon_color = Color(1.0, 0.84, 0.62)
	sky_mat.ground_horizon_color = Color(0.55, 0.72, 0.45)
	sky_mat.ground_bottom_color = Color(0.3, 0.45, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = bool(GameState.settings.effects)
	env.glow_intensity = 0.45
	env.ssao_enabled = bool(GameState.settings.effects)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	add_child(sun)
	var floor_m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_m.mesh = plane
	floor_m.material_override = _mat(Color("7dae62"))
	add_child(floor_m)

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat

func refresh_locale() -> void:
	pass
