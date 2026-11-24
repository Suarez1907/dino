extends Node3D

signal fossil_completed(dino_id: String)
signal bone_snapped(bone_id: String, progress: float)

const SNAP_THRESHOLD := 0.15

var dino_id := ""
var bone_sockets := {}
var snapped := {}
var progress_ratio := 0.0
var completed := false

func setup(id: String, sockets: Dictionary) -> void:
	dino_id = id
	bone_sockets = sockets.duplicate()
	snapped.clear()
	progress_ratio = 0.0
	completed = false

func register_socket(bone_id: String, xform: Transform3D) -> void:
	bone_sockets[bone_id] = xform

func socket_count() -> int:
	return bone_sockets.size()

func is_snapped(bone_id: String) -> bool:
	return bool(snapped.get(bone_id, false))

func nearest_socket(world_pos: Vector3) -> String:
	var best := ""
	var best_d := SNAP_THRESHOLD
	for bone_id in bone_sockets:
		if is_snapped(bone_id):
			continue
		var xform: Transform3D = bone_sockets[bone_id]
		var d := world_pos.distance_to(xform.origin)
		if d <= best_d:
			best_d = d
			best = str(bone_id)
	return best

func try_snap(bone_id: String, world_pos: Vector3) -> bool:
	if completed or is_snapped(bone_id):
		return false
	if not bone_sockets.has(bone_id):
		return false
	var xform: Transform3D = bone_sockets[bone_id]
	if world_pos.distance_to(xform.origin) > SNAP_THRESHOLD:
		return false
	snapped[bone_id] = true
	_update_progress()
	bone_snapped.emit(bone_id, progress_ratio)
	return true

func snap_to_socket(bone_id: String) -> bool:
	if not bone_sockets.has(bone_id):
		return false
	var xform: Transform3D = bone_sockets[bone_id]
	return try_snap(bone_id, xform.origin)

func reset() -> void:
	snapped.clear()
	progress_ratio = 0.0
	completed = false

func _update_progress() -> void:
	var total := bone_sockets.size()
	progress_ratio = 0.0 if total == 0 else float(snapped.size()) / float(total)
	if progress_ratio >= 1.0 and not completed:
		completed = true
		fossil_completed.emit(dino_id)
