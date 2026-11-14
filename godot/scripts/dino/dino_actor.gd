extends Node3D

var anim := "idle"
var parts := {}
var base_y := 0.0
var time := 0.0
var hint_bone := ""
var placed := {}
var mode := "living"
var _player: AnimationPlayer
var _using_clips := false

func _ready() -> void:
	base_y = position.y
	_player = _find_player(self)
	if _player:
		for clip_name in ["idle", "walk", "eat", "roar"]:
			if _player.has_animation(clip_name):
				_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		_using_clips = _player.has_animation("idle")
		if _using_clips:
			_player.play("idle")
	_apply_lod()

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null

func _apply_lod() -> void:
	var low := str(GameState.settings.get("quality", "medium")) == "low"
	var body := find_child("body", true, false)
	var lod := find_child("body_lod", true, false)
	if body:
		body.visible = not low
	if lod:
		lod.visible = low

func capture_base() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	time += delta
	if _using_clips:
		var want := anim if anim in ["idle", "walk", "eat", "roar"] else "idle"
		if _player.current_animation != want and _player.has_animation(want):
			_player.play(want)
		return
	var walking := anim == "walk"
	var swing := sin(time * 6.2) if walking else 0.0
	_swing("leg_fl", swing)
	_swing("leg_br", swing)
	_swing("leg_fr", -swing)
	_swing("leg_bl", -swing)
	_swing("leg_l", swing)
	_swing("leg_r", -swing)
	_swing("arm_l", -swing * 0.6)
	_swing("arm_r", swing * 0.6)
	_swing("tail_0", sin(time * 1.7) * 0.18)
	_swing("tail_1", sin(time * 1.7 + 0.4) * 0.22)
	_swing("tail_2", sin(time * 1.7 + 0.8) * 0.28)
	var head_x := sin(time * 1.5) * 0.05
	if anim == "eat":
		head_x += 0.5 + sin(time * 5.0) * 0.15
	elif anim == "roar":
		head_x -= 0.32
	if parts.has("head"):
		_add("head", Vector3(head_x, sin(time * 0.8) * 0.08, 0))
	var jaw := 0.0
	if anim == "eat":
		jaw = abs(sin(time * 6.5)) * 0.5
	elif anim == "roar":
		jaw = 0.62
	if parts.has("jaw"):
		_add("jaw", Vector3(jaw, 0, 0))
	if walking:
		position.y = base_y + abs(sin(time * 6.2)) * 0.045
	elif anim == "roar":
		position.y = base_y + sin(time * 9.0) * 0.03
	else:
		position.y = base_y + sin(time * 2.0) * 0.02
	if mode == "ghost":
		for key in parts:
			var node: Node3D = parts[key]
			if not (node is MeshInstance3D):
				continue
			var mesh := node as MeshInstance3D
			var mat := mesh.material_override
			if not (mat is StandardMaterial3D):
				continue
			var bone := str(mesh.get_meta("bone_id", ""))
			var hinted := hint_bone != "" and bone == hint_bone and not bool(placed.get(bone, false))
			mat.emission_energy_multiplier = 0.9 if hinted else 0.16

func _swing(name: String, amount: float) -> void:
	if parts.has(name):
		_add(name, Vector3(amount * 0.5, 0, 0))

func _add(name: String, extra: Vector3) -> void:
	var node: Node3D = parts[name]
	if not node.has_meta("base_rot"):
		return
	node.rotation = node.get_meta("base_rot") + extra

func set_bone_visual(bone_id: String, state: String, damage := 0.0) -> void:
	placed[bone_id] = state == "fossil"
	for key in parts:
		var node: Node3D = parts[key]
		if str(node.get_meta("bone_id", "")) == bone_id:
			_apply(node, state, damage)

func _apply(node: Node3D, state: String, damage: float) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.visible = state != "hidden"
		if state == "fossil":
			var fossil: StandardMaterial3D = mesh.get_meta("fossil_mat")
			if damage > 0.66:
				fossil.albedo_color = Color(0.72, 0.64, 0.54)
			elif damage > 0.2:
				fossil.albedo_color = Color(0.84, 0.76, 0.62)
			mesh.material_override = fossil
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		elif state == "ghost":
			mesh.material_override = mesh.get_meta("ghost_mat")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mesh.material_override = mesh.get_meta("live_mat")
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		if child is Node3D:
			_apply(child, state, damage)
