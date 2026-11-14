extends Node

var catalog := {}
var dinos: Array = []
var dinos_by_id := {}
var sites: Array = []
var sites_by_id := {}

func _ready() -> void:
	catalog = _read("res://data/catalog.json")
	dinos = _read_array("res://data/dinosaurs.json")
	sites = _read_array("res://data/sites.json")
	for dino in dinos:
		dinos_by_id[str(dino.id)] = dino
	for site in sites:
		sites_by_id[str(site.id)] = site

func _read(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _read_array(path: String) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_ARRAY else []

func dino(id: String) -> Dictionary:
	return dinos_by_id.get(id, {})

func site(id: String) -> Dictionary:
	return sites_by_id.get(id, {})

func tool(id: String) -> Dictionary:
	for item in catalog.get("tools", []):
		if str(item.id) == id:
			return item
	return {}

func soil(id: String) -> Dictionary:
	for item in catalog.get("soils", []):
		if str(item.id) == id:
			return item
	return {}

func clue(id: String) -> Dictionary:
	for item in catalog.get("clues", []):
		if str(item.id) == id:
			return item
	return {}

func sticker(id: String) -> Dictionary:
	for item in catalog.get("stickers", []):
		if str(item.id) == id:
			return item
	return {}

func biome(id: String) -> Dictionary:
	for item in catalog.get("biomes", []):
		if str(item.id) == id:
			return item
	return {}

func bone(dino_id: String, bone_id: String) -> Dictionary:
	var d = dino(dino_id)
	for item in d.get("bones", []):
		if str(item.id) == bone_id:
			return item
	return {}

func site_index(id: String) -> int:
	for i in sites.size():
		if str(sites[i].id) == id:
			return i
	return -1
