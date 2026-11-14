extends Node

## Spoken lines go through DisplayServer TTS.
## Drop an .ogg at res://assets/voice/<clip>_<lang>.ogg to replace that line later.

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func speak(text: String, clip_id: String = "") -> void:
	var gain := float(GameState.settings.voice)
	if gain <= 0.01 or text.strip_edges() == "":
		return
	if clip_id != "":
		var path := "res://assets/voice/%s_%s.ogg" % [clip_id, Locale.lang]
		if ResourceLoader.exists(path):
			_player.stream = load(path)
			_player.volume_db = linear_to_db(max(gain, 0.0001))
			_player.play()
			return
	if not DisplayServer.has_method("tts_get_voices"):
		return
	var voices: Array = DisplayServer.tts_get_voices()
	if voices.is_empty():
		return
	var voice := _pick_voice(voices)
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	var volume := int(round(clampf(gain, 0.0, 1.0) * 100.0))
	DisplayServer.tts_speak(text, voice, volume, 1.0, 0.92)

func stop() -> void:
	if _player and _player.playing:
		_player.stop()
	if DisplayServer.has_method("tts_stop") and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()

func _pick_voice(voices: Array) -> String:
	var want := "tr" if Locale.lang == "tr" else "en"
	var fallback := ""
	for item in voices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", ""))
		var language := str(item.get("language", "")).to_lower()
		if fallback == "":
			fallback = id
		if language.begins_with(want):
			return id
	return fallback
