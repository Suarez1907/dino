@tool
extends EditorScript

## Scans the levels directory and writes a JSON database of level metadata.

const LEVELS_DIR := "res://levels"
const OUTPUT_PATH := "res://data/level_database.json"

func _run() -> void:
	var database: Array = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		push_error("LevelDatabaseBuilder: cannot open %s" % LEVELS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var entry := _build_entry(file_name)
			if not entry.is_empty():
				database.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()
	_write_database(database)

func _build_entry(file_name: String) -> Dictionary:
	var path := LEVELS_DIR.path_join(file_name)
	var packed := load(path)
	if packed == null:
		push_warning("LevelDatabaseBuilder: failed to load %s" % path)
		return {}
	return {
		"id": file_name.get_basename(),
		"path": path,
	}

func _write_database(database: Array) -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LevelDatabaseBuilder: cannot write %s" % OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(database, "\t"))
	file.close()
	print("LevelDatabaseBuilder: wrote %d entries to %s" % [database.size(), OUTPUT_PATH])
