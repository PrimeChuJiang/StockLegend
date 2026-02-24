# 物品计算类，这个类用于对物品进行实时计算
extends RefCounted

class_name Item

# 物品信息配置的引用（只读，不修改配置）
var data: ItemData:
	set(value):
		if _data == null:
			_data = value
	get:
		return _data
var _data: ItemData = null

# 物品行为配置引用（只读，不修改配置）
var behaviours: Array[ItemBehaviourData]:
	set(value):
		if _behaviour == []:
			_behaviour = value
	get:
		return _behaviour
var _behaviour: Array[ItemBehaviourData] = []

# 运行时动态数据（只有运行时才会变化的属性）
var stack_count: int = 1  # 当前堆叠数量
var container: ItemContainer = null  # 物品所在容器
var position_in_container: int = -1  # 物品在容器中的位置

# 构造函数：通过【配置类】快速创建【运行类】实例
func _init(_data_: ItemData, _container : ItemContainer, _index : int, _stack_count: int = 1):
	self.data = _data_
	self.behaviours = _data_.behaviours
	self.container = _container
	self.position_in_container = _index
	if _data_.max_stack != -1:
		self.stack_count = clamp(_stack_count, 1, _data_.max_stack)
	else:
		self.stack_count = max(_stack_count, 1)
	
# 使用物品调用函数
func use_item(character_from : Node, character_to : Node) -> void :
	_triger_behaviour(character_from, character_to)

# 触发behaviour内的函数
func _triger_behaviour(character_from : Node, character_to : Node, num : int = -1) -> Variant :
	if behaviours.size() > 0:
		print_debug("触发物品行为：use_item ，物品：", self)
		for behaviour in behaviours:
			behaviour.use_item(self, character_from, character_to, num)
	else :
		push_error("Item: _triger_behaviour: 物品", self, "没有物品行为")
	return null

# 重写 to_string 方法，方便打印调试
func _to_string():
	return "Item(id: %d, name: %s, stack_count: %d)" % [data.id, data.name, stack_count]

# 快捷获取静态数据的封装（语法糖，调用更简洁）
func get_id() -> int: return data.id
func get_name() -> String: return data.name
func get_icon() -> Texture2D: return data.image
func get_max_stack() -> int: return data.max_stack
func get_current_count() -> int: return stack_count
