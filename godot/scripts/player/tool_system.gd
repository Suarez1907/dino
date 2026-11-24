extends Resource
class_name ToolResource

@export var tool_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var model_path: String
@export var base_damage: float = 10.0
@export var base_precision: float = 0.5
@export var base_fatigue_cost: float = 5.0
@export var upgrade_path: Array[Dictionary] = []

var current_level: int = 1
var max_level: int = 5

func get_damage() -> float:
	return base_damage * pow(1.3, current_level - 1)

func get_precision() -> float:
	return clamp(base_precision + (current_level - 1) * 0.1, 0.0, 1.0)

func get_fatigue_cost() -> float:
	return base_fatigue_cost * pow(0.9, current_level - 1)

func get_upgrade_cost(level: int) -> Dictionary:
	for upgrade in upgrade_path:
		if upgrade.level == level:
			return upgrade.cost
	return {}

func can_upgrade() -> bool:
	return current_level < max_level

func upgrade() -> bool:
	if can_upgrade():
		current_level += 1
		return true
	return false

func get_stats() -> Dictionary:
	return {
		"damage": get_damage(),
		"precision": get_precision(),
		"fatigue_cost": get_fatigue_cost(),
		"level": current_level,
		"max_level": max_level,
	}


class ToolManager:
	var tools: Dictionary = {}
	var current_tool: ToolResource = null
	var on_tool_changed: Callable = null
	var on_tool_upgraded: Callable = null

	func initialize() -> void:
		_create_default_tools()
		if tools.has("brush"):
			current_tool = tools["brush"]

	func _create_default_tools() -> void:
		var brush = ToolResource.new()
		brush.tool_id = "brush"
		brush.display_name = "Fırça"
		brush.description = "Hassas kazı için ince fırça. Düşük hasar, yüksek hassasiyet."
		brush.base_damage = 5.0
		brush.base_precision = 0.9
		brush.base_fatigue_cost = 2.0
		brush.model_path = "res://assets/models/tools/brush.glb"
		brush.upgrade_path = [
			{"level": 2, "cost": {"research_points": 50}, "bonus": "Daha geniş alan"},
			{"level": 3, "cost": {"research_points": 150}, "bonus": "Daha az yorulma"},
			{"level": 4, "cost": {"research_points": 400}, "bonus": "Kırılma riski azalır"},
			{"level": 5, "cost": {"research_points": 1000}, "bonus": "Otomatik temizleme"},
		]
		tools["brush"] = brush

		var pickaxe = ToolResource.new()
		pickaxe.tool_id = "pickaxe"
		pickaxe.display_name = "Kazma"
		pickaxe.description = "Sert katmanları kırmak için ağır kazma. Yüksek hasar, düşük hassasiyet."
		pickaxe.base_damage = 25.0
		pickaxe.base_precision = 0.3
		pickaxe.base_fatigue_cost = 12.0
		pickaxe.model_path = "res://assets/models/tools/pickaxe.glb"
		pickaxe.upgrade_path = [
			{"level": 2, "cost": {"research_points": 100}, "bonus": "Daha az yorulma"},
			{"level": 3, "cost": {"research_points": 300}, "bonus": "Kritik vuruş şansı"},
			{"level": 4, "cost": {"research_points": 800}, "bonus": "Alan etkisi"},
			{"level": 5, "cost": {"research_points": 2000}, "bonus": "Fosil koruma modu"},
		]
		tools["pickaxe"] = pickaxe

		var chisel = ToolResource.new()
		chisel.tool_id = "chisel"
		chisel.display_name = "Keski"
		chisel.description = "Orta katmanlar için keski. Dengeli hasar ve hassasiyet."
		chisel.base_damage = 15.0
		chisel.base_precision = 0.6
		chisel.base_fatigue_cost = 6.0
		chisel.model_path = "res://assets/models/tools/chisel.glb"
		chisel.upgrade_path = [
			{"level": 2, "cost": {"research_points": 75}, "bonus": "Daha hassas kenarlar"},
			{"level": 3, "cost": {"research_points": 200}, "bonus": "Çift uçlu mod"},
			{"level": 4, "cost": {"research_points": 500}, "bonus": "Mikro ayar"},
			{"level": 5, "cost": {"research_points": 1200}, "bonus": "Otomatik derinlik kontrolü"},
		]
		tools["chisel"] = chisel

		var camera = ToolResource.new()
		camera.tool_id = "camera"
		camera.display_name = "Kamera"
		camera.description = "Fosil fotoğrafları çekmek için kamera. Hasar vermez."
		camera.base_damage = 0.0
		camera.base_precision = 1.0
		camera.base_fatigue_cost = 1.0
		camera.model_path = "res://assets/models/tools/camera.glb"
		camera.upgrade_path = [
			{"level": 2, "cost": {"research_points": 50}, "bonus": "Yüksek çözünürlük"},
			{"level": 3, "cost": {"research_points": 150}, "bonus": "Gece modu"},
			{"level": 4, "cost": {"research_points": 400}, "bonus": "360° panoramik"},
			{"level": 5, "cost": {"research_points": 1000}, "bonus": "AR ölçüm modu"},
		]
		tools["camera"] = camera

	func get_tool(tool_id: String) -> ToolResource:
		return tools.get(tool_id)

	func set_current_tool(tool_id: String) -> bool:
		if tools.has(tool_id):
			current_tool = tools[tool_id]
			if on_tool_changed:
				on_tool_changed.call(tool_id)
			return true
		return false

	func upgrade_current_tool() -> bool:
		if current_tool and current_tool.upgrade():
			if on_tool_upgraded:
				on_tool_upgraded.call(current_tool.tool_id, current_tool.current_level)
			return true
		return false

	func get_current_tool_stats() -> Dictionary:
		if current_tool:
			return current_tool.get_stats()
		return {}

	func get_all_tools() -> Array[ToolResource]:
		var result: Array[ToolResource] = []
		for tool in tools.values():
			result.append(tool)
		return result
