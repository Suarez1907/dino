extends CharacterBody3D
class_name PlayerController

@export var move_speed: float = 5.0
@export var run_speed: float = 9.0
@export var jump_velocity: float = 7.0
@export var gravity: float = 25.0
@export var mouse_sensitivity: float = 0.003
@export var camera_min_angle: float = -1.3
@export var camera_max_angle: float = 0.8

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var excavation_ray: RayCast3D = $ExcavationRay
@onready var tool_ray: RayCast3D = $ToolRay

var current_tool: String = "brush"
var tool_level: int = 1
var is_running: bool = false
var is_digging: bool = false
var dig_target: Node3D = null
var fatigue: float = 0.0
var max_fatigue: float = 100.0
var velocity_smoothing: float = 10.0

const TOOL_ORDER: Array[String] = ["brush", "pickaxe", "chisel", "camera"]

var is_touch_device: bool = false
var joystick_radius: float = 120.0
var touch_joystick_active: bool = false
var touch_joystick_index: int = -1
var touch_joystick_origin: Vector2 = Vector2.ZERO
var touch_joystick_vector: Vector2 = Vector2.ZERO
var touch_look_index: int = -1
var touch_look_last: Vector2 = Vector2.ZERO

signal tool_changed(tool_id: String)
signal interaction_started(target: Node3D)
signal interaction_ended()
signal fossil_detected(bone_id: String, progress: float, quality: float)
signal photo_taken(photo_data: Dictionary)

func _ready() -> void:
	is_touch_device = DisplayServer.is_touchscreen_available()
	if not is_touch_device:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_tree.active = true
	_setup_animation_state_machine()
	_load_tool_level()

func _setup_animation_state_machine() -> void:
	var state_machine = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.travel("idle")

func _load_tool_level() -> void:
	if GameState:
		tool_level = GameState.get_tool_level(current_tool)

func _physics_process(delta: float) -> void:
	_handle_actions()
	_handle_movement(delta)
	_handle_gravity(delta)
	_handle_digging(delta)
	_update_animation_state()
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event)
	
	if event is InputEventKey:
		_handle_key_input(event)
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, camera_min_angle, camera_max_angle)

func _handle_key_input(event: InputEventKey) -> void:
	if event.pressed:
		match event.keycode:
			KEY_1: _switch_tool("brush")
			KEY_2: _switch_tool("pickaxe")
			KEY_3: _switch_tool("chisel")
			KEY_4: _switch_tool("camera")
			KEY_SHIFT: is_running = true
			KEY_E: _try_interact()
			KEY_SPACE: _jump()
			KEY_F: _toggle_flashlight()
	
	if not event.pressed and event.keycode == KEY_SHIFT:
		is_running = false

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_digging()
	elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_digging()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_take_photo()

func _handle_actions() -> void:
	if Input.is_action_just_pressed("tool_next"):
		_cycle_tool()
	if Input.is_action_just_pressed("photo_mode"):
		_take_photo()
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	
	var heavy: bool = Input.is_action_pressed("dig_heavy")
	var light: bool = Input.is_action_pressed("dig_brush")
	if heavy and not is_digging:
		_switch_tool("pickaxe")
		_start_digging()
	elif light and not is_digging:
		_switch_tool("brush")
		_start_digging()
	elif is_digging and not heavy and not light and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_digging()

func _cycle_tool() -> void:
	var idx: int = TOOL_ORDER.find(current_tool)
	idx = (idx + 1) % TOOL_ORDER.size()
	_switch_tool(TOOL_ORDER[idx])

func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	if not is_touch_device:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if tree.paused else Input.MOUSE_MODE_CAPTURED

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var half_width: float = get_viewport().get_visible_rect().size.x * 0.5
	if event.pressed:
		if event.position.x < half_width and not touch_joystick_active:
			touch_joystick_active = true
			touch_joystick_index = event.index
			touch_joystick_origin = event.position
			touch_joystick_vector = Vector2.ZERO
		elif event.position.x >= half_width and touch_look_index == -1:
			touch_look_index = event.index
			touch_look_last = event.position
	else:
		if event.index == touch_joystick_index:
			touch_joystick_active = false
			touch_joystick_index = -1
			touch_joystick_vector = Vector2.ZERO
		elif event.index == touch_look_index:
			touch_look_index = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == touch_joystick_index and touch_joystick_active:
		var offset: Vector2 = event.position - touch_joystick_origin
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius
		touch_joystick_vector = offset / joystick_radius
	elif event.index == touch_look_index:
		var look_delta: Vector2 = event.position - touch_look_last
		touch_look_last = event.position
		rotate_y(-look_delta.x * mouse_sensitivity)
		camera_pivot.rotate_x(-look_delta.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, camera_min_angle, camera_max_angle)

func _handle_movement(delta: float) -> void:
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	if touch_joystick_active:
		input_dir.x += touch_joystick_vector.x
		input_dir.z += touch_joystick_vector.y
	
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var basis = global_transform.basis
	var target_velocity = (basis * input_dir) * (run_speed if is_running else move_speed)
	
	if input_dir == Vector3.ZERO:
		target_velocity = Vector3.ZERO
	
	velocity.x = lerp(velocity.x, target_velocity.x, velocity_smoothing * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, velocity_smoothing * delta)

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

func _jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
		animation_tree.set("parameters/conditions/jumping", true)
		await get_tree().create_timer(0.3).timeout
		animation_tree.set("parameters/conditions/jumping", false)

func _switch_tool(tool_id: String) -> void:
	if current_tool != tool_id:
		current_tool = tool_id
		if GameState:
			tool_level = GameState.get_tool_level(tool_id)
		tool_changed.emit(tool_id)
		_update_tool_visuals()

func _update_tool_visuals() -> void:
	# Tool mesh switching handled by ToolSystem
	pass

func _try_interact() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + -Vector3.UP * 2.0)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		interaction_started.emit(result.collider)

func _start_digging() -> void:
	if is_digging:
		return
	
	excavation_ray.target_position = -Vector3.UP * 1.5
	excavation_ray.force_raycast_update()
	
	if excavation_ray.is_colliding():
		var collider = excavation_ray.get_collider()
		if collider and collider.has_method("start_excavation"):
			dig_target = collider
			is_digging = true
			collider.start_excavation(current_tool, tool_level)
			animation_tree.set("parameters/conditions/digging", true)
			animation_tree.set("parameters/conditions/dig_tool", _get_tool_anim_index())

func _stop_digging() -> void:
	if not is_digging:
		return
	
	is_digging = false
	animation_tree.set("parameters/conditions/digging", false)
	
	if dig_target and dig_target.has_method("stop_excavation"):
		var result = dig_target.stop_excavation()
		if result:
			fossil_detected.emit(result.bone_id, result.progress, result.quality)
	dig_target = null

func _handle_digging(delta: float) -> void:
	if not is_digging or not dig_target:
		return
	
	fatigue += _get_fatigue_cost() * delta
	if fatigue >= max_fatigue:
		_stop_digging()
		_show_exhausted_feedback()
		return
	
	if dig_target.has_method("excavate_step"):
		dig_target.excavate_step(current_tool, tool_level, delta)

func _take_photo() -> void:
	if current_tool != "camera":
		_switch_tool("camera")
		return
	
	var photo_data = {
		"position": global_position,
		"rotation": global_transform.basis.get_euler(),
		"time": Time.get_datetime_dict_from_system(),
		"site": GameState.current_site if GameState else "",
	}
	photo_taken.emit(photo_data)
	animation_tree.set("parameters/conditions/taking_photo", true)
	await get_tree().create_timer(0.5).timeout
	animation_tree.set("parameters/conditions/taking_photo", false)

func _toggle_flashlight() -> void:
	# Flashlight toggle logic
	pass

func _get_tool_anim_index() -> int:
	match current_tool:
		"brush": return 0
		"pickaxe": return 1
		"chisel": return 2
		"camera": return 3
	return 0

func _get_fatigue_cost() -> float:
	match current_tool:
		"brush": return 2.0
		"pickaxe": return 8.0
		"chisel": return 5.0
		"camera": return 1.0
	return 3.0

func _update_animation_state() -> void:
	var speed = velocity.length()
	var is_moving = speed > 0.1
	
	animation_tree.set("parameters/conditions/moving", is_moving)
	animation_tree.set("parameters/conditions/running", is_running and is_moving)
	animation_tree.set("parameters/blend_space_1d/blend_position", speed)
	
	if is_on_floor():
		animation_tree.set("parameters/conditions/grounded", true)
	else:
		animation_tree.set("parameters/conditions/grounded", false)

func _show_exhausted_feedback() -> void:
	# UI feedback for exhaustion
	pass

func recover_fatigue(amount: float) -> void:
	fatigue = max(0.0, fatigue - amount)

func get_fatigue_ratio() -> float:
	return fatigue / max_fatigue
