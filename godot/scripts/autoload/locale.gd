extends Node

var lang := "tr"
var strings := {}

func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/strings.json")
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		strings = parsed
	else:
		push_error("strings.json could not be parsed")

func t(key: String, extra: Dictionary = {}) -> String:
	var value := key
	if strings.has(key):
		var entry = strings[key]
		if typeof(entry) == TYPE_DICTIONARY:
			value = str(entry.get(lang, entry.get("tr", key)))
		else:
			value = str(entry)
	for k in extra.keys():
		value = value.replace("{%s}" % str(k), str(extra[k]))
	return value

func pick(entry) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get(lang, entry.get("tr", "")))
	return str(entry)

func set_lang(next: String) -> void:
	lang = next if next == "en" else "tr"
	GameState.settings["lang"] = lang
	GameState.mark_dirty()
	get_tree().call_group("locale_refresh", "refresh_locale")
