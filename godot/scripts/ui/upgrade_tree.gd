extends Resource
class_name UpgradeTree

## Node/Graph tabanlı araştırma ağacı tanımı ve GameState senkronizasyonu.
## Her düğüm: {id, cost, requires[], branch, title_tr, title_en, effect_fn}

var nodes: Dictionary = {}
var unlocked: Dictionary = {}

func _init() -> void:
	_build()

func _def(id: String, cost: int, requires: Array, branch: String, title_tr: String, title_en: String, effect: Callable) -> void:
	nodes[id] = {
		"id": id,
		"cost": cost,
		"requires": requires.duplicate(),
		"branch": branch,
		"title_tr": title_tr,
		"title_en": title_en,
		"effect_fn": effect,
	}

func _build() -> void:
	# --- Araç tier dalı (1 -> 4) ---
	_def("tier_2", 60, [], "tier", "Kazı Aracı II", "Dig Rig II", _eff_tier.bind(2))
	_def("tier_3", 180, ["tier_2"], "tier", "Kazı Aracı III", "Dig Rig III", _eff_tier.bind(3))
	_def("tier_4", 420, ["tier_3"], "tier", "Kazı Aracı IV", "Dig Rig IV", _eff_tier.bind(4))
	# --- Yeni içerik dalları ---
	_def("biome_new", 150, ["tier_2"], "biome", "Yeni Biyom", "New Biome", _eff_biome.bind("canyon"))
	_def("dino_new", 150, ["tier_2"], "dino", "Yeni Dino", "New Dino", _eff_dino.bind("dilophosaurus"))
	# --- Yardımcı dallar ---
	_def("speed", 90, [], "utility", "Hız", "Speed", _eff_research.bind("speed"))
	_def("quality", 120, ["speed"], "utility", "Kalite", "Quality", _eff_research.bind("quality"))

func _eff_tier(tier: int, gs: Node) -> void:
	if gs.has_method("upgrade_tool_tier"):
		gs.upgrade_tool_tier(tier)
	elif "tool_tier" in gs:
		gs.set("tool_tier", maxi(int(gs.get("tool_tier")), tier))

func _eff_biome(biome_id: String, gs: Node) -> void:
	if gs.has_method("unlock_biome"):
		gs.unlock_biome(biome_id)
	elif "unlocked_biomes" in gs:
		var list: Array = gs.get("unlocked_biomes")
		if not list.has(biome_id):
			list.append(biome_id)

func _eff_dino(dino_id: String, gs: Node) -> void:
	if gs.has_method("unlock_dino"):
		gs.unlock_dino(dino_id)
	elif "unlocked_dinos" in gs:
		var list: Array = gs.get("unlocked_dinos")
		if not list.has(dino_id):
			list.append(dino_id)

func _eff_research(key: String, gs: Node) -> void:
	if gs.has_method("apply_research"):
		gs.apply_research(key)
	elif "research_bonus" in gs:
		var bonus: Dictionary = gs.get("research_bonus")
		bonus[key] = float(bonus.get(key, 1.0)) + 0.15

func can_unlock(id: String, science: int) -> bool:
	if not nodes.has(id):
		return false
	if bool(unlocked.get(id, false)):
		return false
	var n: Dictionary = nodes[id]
	if science < int(n.cost):
		return false
	for r in n.requires:
		if not bool(unlocked.get(str(r), false)):
			return false
	return true

func unlock(id: String, gs: Node) -> bool:
	if not nodes.has(id):
		return false
	if not can_unlock(id, int(gs.science)):
		return false
	gs.science -= int(nodes[id].cost)
	unlocked[id] = true
	var fn: Callable = nodes[id].effect_fn
	if fn.is_valid():
		fn.call(gs)
	sync_to(gs)
	return true

func sync_to(gs: Node) -> void:
	if "research_tree" in gs:
		gs.set("research_tree", unlocked.duplicate(true))

func load_from(gs: Node) -> void:
	if "research_tree" in gs and gs.get("research_tree") is Dictionary:
		unlocked = (gs.get("research_tree") as Dictionary).duplicate(true)

func serialize() -> Dictionary:
	return unlocked.duplicate(true)

## GraphView (Control._draw) içinden çağrılır: düğümleri kutucuk olarak çizer.
func draw_graph(canvas: CanvasItem, origin: Vector2, spacing: Vector2, accent: Color, dim: Color) -> void:
	var columns := {"tier": 0, "biome": 1, "dino": 1, "utility": 2}
	var row_count := {}
	for id in nodes:
		var branch: String = nodes[id].branch
		var col := int(columns.get(branch, 3))
		var row := int(row_count.get(col, 0))
		row_count[col] = row + 1
		var pos := origin + Vector2(col * spacing.x, row * spacing.y)
		var size := Vector2(spacing.x * 0.8, spacing.y * 0.55)
		var open := bool(unlocked.get(id, false))
		var col_color: Color = accent if open else dim
		canvas.draw_rect(Rect2(pos, size), col_color, true)
		canvas.draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.5), false, 2.0)
		var label: String = str(nodes[id].title_tr)
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8, size.y * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 14, Color(1, 1, 1))
		var cost_label := "✔" if open else str(int(nodes[id].cost)) + " 🔬"
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8, size.y - 6), cost_label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12, Color(1, 1, 1, 0.85))
