extends SceneTree

## Runs feature test scripts with a per-test timeout to prevent hangs.

const FEATURES_DIR := "res://tests/features"
const DEFAULT_TIMEOUT_MS := 30000

var _timeout_ms: int = DEFAULT_TIMEOUT_MS
var _failures: int = 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--timeout="):
			_timeout_ms = int(arg.get_slice("=", 1))
	_run_all()
	quit(1 if _failures > 0 else 0)

func _run_all() -> void:
	var dir := DirAccess.open(FEATURES_DIR)
	if dir == null:
		push_error("run_features: cannot open %s" % FEATURES_DIR)
		_failures += 1
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			_run_feature(FEATURES_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _run_feature(path: String) -> void:
	var script := load(path)
	if script == null:
		push_error("run_features: failed to load %s" % path)
		_failures += 1
		return
	var instance = script.new()
	if instance == null:
		push_error("run_features: failed to instantiate %s" % path)
		_failures += 1
		return
	var start := Time.get_ticks_msec()
	if instance.has_method("run"):
		instance.run()
	var elapsed := Time.get_ticks_msec() - start
	if elapsed > _timeout_ms:
		push_error("run_features: %s exceeded timeout (%d ms)" % [path, elapsed])
		_failures += 1
	else:
		print("run_features: %s passed in %d ms" % [path, elapsed])
