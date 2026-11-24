extends Camera3D
class_name PhotoMode

## Foto modu: DOF + pozlama + vinyet + LUT filtre. capture() -> galeri + bilim puanı.

signal photo_captured(entry: Dictionary)

const FILTERS := ["none", "sepia", "noir", "warm", "cool"]

var active := false
var dof_amount := 0.5
var exposure := 1.0
var vignette := 0.3
var lut := "none"
var current_site := ""
var current_dino := ""

func _ready() -> void:
	active = false
	_apply()

func enter(site := "", dino := "") -> void:
	current_site = site
	current_dino = dino
	active = true
	_apply()

func exit() -> void:
	active = false
	_apply()

func cycle_filter() -> String:
	var idx := FILTERS.find(lut)
	lut = FILTERS[(idx + 1) % FILTERS.size()]
	_apply()
	return lut

func _apply() -> void:
	var env := get_world_3d().environment if get_world_3d() else null
	if env == null:
		return
	env.dof_blur_far_enabled = dof_amount > 0.01
	env.dof_blur_near_enabled = dof_amount > 0.01
	env.dof_blur_far_distance = lerpf(12.0, 3.0, clampf(dof_amount, 0.0, 1.0))
	env.dof_blur_near_distance = lerpf(2.0, 0.4, clampf(dof_amount, 0.0, 1.0))
	env.dof_blur_amount = dof_amount
	env.tonemap_exposure = exposure
	env.adjustment_enabled = lut != "none"
	env.adjustment_saturation = _saturation()
	env.adjustment_brightness = _brightness()
	env.adjustment_contrast = _contrast()

func _saturation() -> float:
	match lut:
		"sepia", "noir":
			return 0.15
		"warm":
			return 1.25
		"cool":
			return 1.1
		_:
			return 1.0

func _brightness() -> float:
	match lut:
		"noir":
			return 0.9
		"warm":
			return 1.05
		_:
			return 1.0

func _contrast() -> float:
	match lut:
		"noir":
			return 1.25
		"cool":
			return 1.1
		_:
			return 1.0

func _quality_score(notes: String) -> int:
	var score := 10
	score += int(clampf(exposure, 0.5, 2.0) * 6.0)
	score += int(clampf(dof_amount, 0.0, 1.0) * 8.0)
	score += int(clampf(vignette, 0.0, 1.0) * 4.0)
	if lut != "none":
		score += 4
	if current_dino != "":
		score += 6
	if notes.strip_edges().length() >= 8:
		score += 8
	return score

func capture(notes := "") -> Dictionary:
	if not active:
		return {}
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return {}
	var tex := ImageTexture.create_from_image(img)
	var q := _quality_score(notes)
	var entry := {
		"tex": tex,
		"site": current_site,
		"dino": current_dino,
		"notes": notes,
		"timestamp": Time.get_datetime_string_from_system(),
		"quality": q,
		"filter": lut,
	}
	_ensure_gallery()
	(GameState.get("photo_gallery") as Array).append(entry)
	GameState.set("science", int(GameState.get("science")) + q)
	if GameState.has_method("notify"):
		GameState.call("notify", "photo", q)
	photo_captured.emit(entry)
	return entry

func _ensure_gallery() -> void:
	if not ("photo_gallery" in GameState):
		GameState.set("photo_gallery", [])
