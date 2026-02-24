# Container System单例，会放到audoLoad内，该单例负责维护ItemDataMap，方便用户随时通过ID获取物品的模板数据
extends Node

class_name ContainerSystem

# 物品数据ID映射表
var _item_map_id : Dictionary = {} 

# 物品名称映射表
var _item_map_name : Dictionary = {} 

func _ready():
	var raw_resource_path = ProjectSettings.get_setting("container_system/item_data_map")

	var item_map_data = load(raw_resource_path) as ItemDataMap
	if item_map_data == null:
		push_error("ContainerSystem: _ready: 物品数据地图设置错误")
		return
	else :
		for item_data in item_map_data.item_data_map :
			_item_map_id[item_data.id] = item_data
			_item_map_name[item_data.name] = item_data.id
		print("ContainerSystem: _ready: 物品数据地图加载成功")

# 通过ID获取物品模板数据
func get_item_data_by_id(id : int) -> ItemData:
	if _item_map_id.has(id):
		return _item_map_id[id]
	else :
		return null

# 通过名称获取物品模板数据
func get_item_data_by_name(name : String) -> ItemData:
	if _item_map_name.has(name):
		return _item_map_id[_item_map_name[name]]
	else :
		return null

# 获取所有物品模板数据的数组
func get_all_item_data() -> Array:
	return _item_map_id.values()

func _to_string() -> String:
	var result : String = "ContainerSystem:\n"
	for item_data in _item_map_id.values():
		result += "  " + str(item_data) + "\n"
	return result
