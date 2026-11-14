extends Node

signal changed
signal sticker_unlocked(id: String)
signal site_unlocked(id: String)
signal break_requested

const SAVE_PATH := "user://dino_kazi_save.json"

var settings := {
	"lang": "tr",
	"music": 0.55,
	"sfx": 0.85,
	"voice": 1.0,
	"haptics": true,
	"large_text": false,
	"colorblind": false,
	"guide_arrow": false,
	"effects": true,
	"quality": "medium",
	"session_minutes": 0,
	"pin": "",
}
var sites_save := {}
var stickers: Array = []
var tutorial_done := false
var play_seconds := 0.0
var session_elapsed := 0.0
var counting := false
var _dirty := false
var _break_sent := false

func _ready() -> void:
	load_game()
	Locale.lang = str(settings.lang)

func _process(delta: float) -> void:
	if counting and int(settings.session_minutes) > 0 and not _break_sent:
		session_elapsed += delta
		play_seconds += delta
		if session_elapsed >= float(settings.session_minutes) * 60.0:
			_break_sent = true
			counting = false
			mark_dirty()
			break_requested.emit()
	elif counting:
		play_seconds += delta
	if _dirty:
		_dirty = false
		_write()

func mark_dirty() -> void:
	_dirty = true
	changed.emit()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		for k in settings.keys():
			if parsed.settings.has(k):
				settings[k] = parsed.settings[k]
	sites_save = parsed.get("sites", {}) if typeof(parsed.get("sites")) == TYPE_DICTIONARY else {}
	stickers = parsed.get("stickers", []) if typeof(parsed.get("stickers")) == TYPE_ARRAY else []
	tutorial_done = bool(parsed.get("tutorial_done", false))
	play_seconds = float(parsed.get("play_seconds", 0.0))
	session_elapsed = float(parsed.get("session_elapsed", 0.0))

func _write() -> void:
	var data := {
		"settings": settings,
		"sites": sites_save,
		"stickers": stickers,
		"tutorial_done": tutorial_done,
		"play_seconds": play_seconds,
		"session_elapsed": session_elapsed,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))

func site_state(site_id: String) -> Dictionary:
	if not sites_save.has(site_id) or typeof(sites_save[site_id]) != TYPE_DICTIONARY:
		sites_save[site_id] = {"bones": {}, "revealed": false}
	if typeof(sites_save[site_id].get("bones")) != TYPE_DICTIONARY:
		sites_save[site_id]["bones"] = {}
	return sites_save[site_id]

func bone_state(site_id: String, bone_id: String) -> Dictionary:
	var st := site_state(site_id)
	if not st.bones.has(bone_id) or typeof(st.bones[bone_id]) != TYPE_DICTIONARY:
		st.bones[bone_id] = {"collected": false, "damage": 0.0, "layer": 0, "progress": 0.0, "placed": false}
	return st.bones[bone_id]

func is_site_unlocked(site_id: String) -> bool:
	var idx := Catalog.site_index(site_id)
	if idx <= 0:
		return true
	var prev: Dictionary = Catalog.sites[idx - 1]
	return bool(site_state(str(prev.id)).get("revealed", false))

func site_stars(site_id: String) -> int:
	var site := Catalog.site(site_id)
	var spots: Array = site.get("spots", [])
	if spots.is_empty():
		return 0
	var damage := 0.0
	for spot in spots:
		var bone = bone_state(site_id, str(spot.bone))
		if not bool(bone.collected):
			return 0
		damage += float(bone.damage)
	var avg := damage / float(spots.size())
	if avg <= 0.01:
		return 3
	if avg <= 0.5:
		return 2
	return 1

func collected_count(site_id: String) -> int:
	var site := Catalog.site(site_id)
	var n := 0
	for spot in site.get("spots", []):
		if bool(bone_state(site_id, str(spot.bone)).collected):
			n += 1
	return n

func placed_count(site_id: String) -> int:
	var site := Catalog.site(site_id)
	var n := 0
	for spot in site.get("spots", []):
		var bone = bone_state(site_id, str(spot.bone))
		if bool(bone.collected) and bool(bone.placed):
			n += 1
	return n

func all_placed(site_id: String) -> bool:
	var site := Catalog.site(site_id)
	var spots: Array = site.get("spots", [])
	return not spots.is_empty() and placed_count(site_id) == spots.size()

func note_progress(site_id: String, bone_id: String, layer: int, progress: float, damage: float) -> void:
	var bone := bone_state(site_id, bone_id)
	bone.layer = layer
	bone.progress = progress
	bone.damage = damage
	mark_dirty()

func collect_bone(site_id: String, bone_id: String, damage: float) -> void:
	var bone := bone_state(site_id, bone_id)
	var was := bool(bone.collected)
	bone.collected = true
	bone.damage = damage
	bone.progress = 1.0
	mark_dirty()
	if not was:
		refresh_awards(site_id)

func place_bone(site_id: String, bone_id: String) -> void:
	var bone := bone_state(site_id, bone_id)
	if not bool(bone.collected):
		return
	bone.placed = true
	mark_dirty()
	refresh_awards(site_id)

func reveal_site(site_id: String) -> void:
	var st := site_state(site_id)
	var was := bool(st.revealed)
	st.revealed = true
	mark_dirty()
	if not was:
		refresh_awards(site_id)
		var idx := Catalog.site_index(site_id)
		if idx >= 0 and idx + 1 < Catalog.sites.size():
			var nxt: Dictionary = Catalog.sites[idx + 1]
			site_unlocked.emit(str(nxt.id))

func refresh_awards(site_id: String) -> void:
	var any_bone := false
	for id in sites_save.keys():
		if collected_count(str(id)) > 0:
			any_bone = true
	if any_bone:
		_award("first_bone")
	if site_stars(site_id) == 3:
		_award("gentle")
	if all_placed(site_id):
		_award("builder")
	if bool(site_state(site_id).revealed):
		_award("roar")
		var biomes := {"desert": true, "forest": true, "ice": true}
		for site in Catalog.sites:
			var biome := str(site.biome)
			if biomes.has(biome) and not bool(site_state(str(site.id)).revealed):
				biomes[biome] = false
		for biome in biomes.keys():
			if biomes[biome]:
				_award(biome)
		var all := true
		for site in Catalog.sites:
			if not bool(site_state(str(site.id)).revealed):
				all = false
		if all:
			_award("passport")

func _award(id: String) -> void:
	if stickers.has(id):
		return
	stickers.append(id)
	mark_dirty()
	sticker_unlocked.emit(id)

func has_sticker(id: String) -> bool:
	return stickers.has(id)

func set_setting(key: String, value) -> void:
	settings[key] = value
	if key == "lang":
		Locale.lang = str(value)
	if key == "session_minutes":
		session_elapsed = 0.0
		_break_sent = false
	mark_dirty()
	if key in ["music", "sfx", "voice"]:
		Sfx.apply_volumes()

func extend_session() -> void:
	settings.session_minutes = int(settings.session_minutes) + 15
	_break_sent = false
	counting = true
	mark_dirty()

func reset_progress() -> void:
	sites_save = {}
	stickers = []
	tutorial_done = false
	play_seconds = 0.0
	session_elapsed = 0.0
	_break_sent = false
	mark_dirty()

func buzz(ms: int = 18) -> void:
	if not bool(settings.haptics):
		return
	if Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(ms)

func first_unlocked_site() -> String:
	for site in Catalog.sites:
		if is_site_unlocked(str(site.id)):
			return str(site.id)
	return str(Catalog.sites[0].id) if Catalog.sites.size() else ""
