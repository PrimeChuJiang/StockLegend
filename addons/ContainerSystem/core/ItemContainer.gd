# 容器类
extends Node

class_name ItemContainer

# 背包内操作成功返回码
const SUCCESS = 200

# 物品列表
var item_list : Array[Item] = []
var item_id_pos_map : Dictionary = {} # int -> Array[int]，存储每个物品ID对应的位置列表
var item_empty_pos_map : Array[int] = [] # 空位置列表

# 容器可添加的物品标签
@export var addable_tags : Array[Tag] = []

# 是否使用层级标签匹配 (默认 true)
# true: 物品标签是容器允许标签的后代也可以匹配
# false: 只有精确匹配才能通过
@export var use_hierarchical_tags : bool = true

# 容器大小
@export var size : int = 0		

# 容器描述
@export var description : String = ""

# 容器名称
@export var container_name : String = ""

# 容器内非法物品变更信号，illegal_items表示不能添加的物品列表
signal illegal_items_changed(illegal_items : Array[Item])
# 容器内物品变更信号，is_add表示是添加还是移除物品，index表示物品所在位置，item表示变更后的物品信息
signal item_changed(is_add : bool, index: int, item: Item)
# 容器大小变更信号，new_size表示新的容器大小
signal size_changed(new_size : int)

# 容器初始化函数
func initialize(_size : int = 0, _container_name : String = "", _description : String = "", _addable_tags : Array[Tag] = [], _item_list : Array[Item] = []):
	_set_item_list_size(_size)
	self.container_name = _container_name
	self.description = _description
	self.addable_tags = _addable_tags
	if _item_list.any(func(item): return item != null):
		self.item_list = _item_list
	# 重建映射
	item_id_pos_map.clear()
	item_empty_pos_map.clear()
	for i in range(item_list.size()):
		var item : Item = item_list[i]
		if item != null:
			_add_to_id_pos_map(item.get_id(), i)
		else:
			item_empty_pos_map.append(i)

# ---------------
# 映射维护辅助函数
# ---------------

# 添加位置到ID位置映射
func _add_to_id_pos_map(item_id: int, pos: int) -> void:
	if not item_id_pos_map.has(item_id):
		item_id_pos_map[item_id] = [] as Array[int]
	var pos_list: Array[int] = item_id_pos_map[item_id]
	if pos not in pos_list:
		pos_list.append(pos)

# 从ID位置映射中移除位置
func _remove_from_id_pos_map(item_id: int, pos: int) -> void:
	if item_id_pos_map.has(item_id):
		var pos_list: Array[int] = item_id_pos_map[item_id]
		pos_list.erase(pos)
		if pos_list.is_empty():
			item_id_pos_map.erase(item_id)

# 添加位置到空位列表（保持有序以便快速查找最小空位）
func _add_to_empty_pos_map(pos: int) -> void:
	if pos not in item_empty_pos_map:
		# 插入排序保持有序
		var insert_idx = item_empty_pos_map.bsearch(pos)
		item_empty_pos_map.insert(insert_idx, pos)

# 从空位列表移除位置
func _remove_from_empty_pos_map(pos: int) -> void:
	item_empty_pos_map.erase(pos)

# 设置容器大小（内部函数，不触发信号，用于初始化）
func _set_item_list_size(new_size : int) -> bool:
	if new_size < 0:
		push_error("ItemContainer: set_item_list_size: 容器大小不能为负数")
		return false
	var old_size = item_list.size()
	if item_list.resize(new_size) != OK:
		push_error("ItemContainer: set_item_list_size: 容器大小设置失败")
		return false
	# 更新空位置列表
	if new_size > old_size:
		for i in range(old_size, new_size):
			item_empty_pos_map.append(i)
	elif new_size < old_size:
		# 移除超出范围的空位置
		item_empty_pos_map = item_empty_pos_map.filter(func(pos_idx): return pos_idx < new_size)
		# 同时需要更新id_pos_map，移除超出范围的位置
		for item_id in item_id_pos_map.keys():
			var pos_list: Array[int] = item_id_pos_map[item_id]
			item_id_pos_map[item_id] = pos_list.filter(func(pos_idx): return pos_idx < new_size) as Array[int]
			if item_id_pos_map[item_id].is_empty():
				item_id_pos_map.erase(item_id)
	size = new_size
	print("ItemContainer: _set_item_list_size: 当前容器大小为", item_list.size())
	return true

# 设置容器大小（处理物品重新分配和信号触发）
# 当容器缩小时，会尝试将被挤出的物品重新分配到容器内
# 无法分配的物品会通过 illegal_items_changed 信号广播
func set_container_size(new_size: int) -> bool:
	if new_size < 0:
		push_error("ItemContainer: set_container_size: 容器大小不能为负数")
		return false
	
	var old_size = size
	
	# 如果大小没变，直接返回
	if new_size == old_size:
		return true
	
	# 容器变大的情况
	if new_size > old_size:
		if item_list.resize(new_size) != OK:
			push_error("ItemContainer: set_container_size: 容器大小设置失败")
			return false
		# 添加新的空位到空位列表
		for i in range(old_size, new_size):
			item_empty_pos_map.append(i)
		size = new_size
		size_changed.emit(new_size)
		return true
	
	# 容器变小的情况
	# 1. 收集需要被移除位置上的物品
	var displaced_items: Array[Item] = []
	for i in range(new_size, old_size):
		var item = item_list[i]
		if item != null:
			displaced_items.append(item)
			# 先从映射中移除该位置
			_remove_from_id_pos_map(item.get_id(), i)
			# 触发物品移除信号（从原位置移除）
			item_changed.emit(false, i, null)
	
	# 2. 移除超出范围的空位
	item_empty_pos_map = item_empty_pos_map.filter(func(pos_idx): return pos_idx < new_size)
	
	# 3. 更新id_pos_map，移除超出范围的位置记录
	for item_id in item_id_pos_map.keys():
		var pos_list: Array[int] = item_id_pos_map[item_id]
		item_id_pos_map[item_id] = pos_list.filter(func(pos_idx): return pos_idx < new_size) as Array[int]
		if item_id_pos_map[item_id].is_empty():
			item_id_pos_map.erase(item_id)
	
	# 4. 调整item_list大小
	if item_list.resize(new_size) != OK:
		push_error("ItemContainer: set_container_size: 容器大小设置失败")
		return false
	size = new_size
	
	# 5. 尝试将被挤出的物品重新分配到容器内
	var illegal_items: Array[Item] = []
	for item in displaced_items:
		var redistribute_result = _try_redistribute_item(item)
		if not redistribute_result:
			# 无法重新分配，加入非法物品列表
			item.container = null
			item.position_in_container = -1
			illegal_items.append(item)
	
	# 6. 广播非法物品
	if illegal_items.size() > 0:
		illegal_items_changed.emit(illegal_items)
	
	size_changed.emit(new_size)
	return true

# 尝试将物品重新分配到容器内
# 返回 true 表示成功分配，false 表示无法分配
func _try_redistribute_item(item: Item) -> bool:
	var item_id = item.get_id()
	var max_stack = item.get_max_stack()
	var remaining = item.stack_count
	
	# 先尝试堆叠到现有相同ID的物品上
	if item_id_pos_map.has(item_id):
		var positions = item_id_pos_map[item_id].duplicate()
		for pos in positions:
			if remaining <= 0:
				break
			var existing_item = item_list[pos]
			if existing_item != null:
				var available_space = 0
				if max_stack == -1:
					available_space = remaining
				else:
					available_space = max_stack - existing_item.stack_count
				
				if available_space > 0:
					var to_add = min(remaining, available_space)
					existing_item.stack_count += to_add
					remaining -= to_add
					# 触发物品变更信号
					item_changed.emit(true, pos, existing_item)
	
	# 如果还有剩余，尝试使用空位
	while remaining > 0 and item_empty_pos_map.size() > 0:
		var empty_pos = item_empty_pos_map[0]
		var to_add = 0
		if max_stack == -1:
			to_add = remaining
		else:
			to_add = min(remaining, max_stack)
		
		# 创建新物品实例放入空位
		var new_item = Item.new(item.data, self, empty_pos, to_add)
		
		# 更新映射
		_remove_from_empty_pos_map(empty_pos)
		_add_to_id_pos_map(item_id, empty_pos)
		
		# 放入物品
		item_list[empty_pos] = new_item
		remaining -= to_add
		
		# 触发物品变更信号
		item_changed.emit(true, empty_pos, new_item)
	
	# 如果还有剩余，说明无法完全分配
	if remaining > 0:
		# 部分分配成功，但还有剩余
		# 更新原物品的堆叠数量为剩余数量
		item.stack_count = remaining
		return false
	
	return true

# ---------------
# 物品能否加入和移除容器相关code注释
# 200 - 成功添加/移除物品
# 400 - 物品标签不在容器可添加的标签列表中
# 401 - 物品添加的位置处已存在物品（且无法堆叠）
# 402 - 物品堆叠数量超过最大堆叠数量
# 403 - 容器设置为check_tag为true，但是容器没有设置可添加的标签列表
# 404 - 物品内没有设置标签
# 405 - 物品所在位置已存在物品，但是物品id不同
# 406 - 指定的位置索引超出容器大小
# 407 - 物品的删除数量大于当前背包内的物品堆叠数量
# 408 - 指定的删除的index处的物品不存在
# 409 - 容器空间不足，无法添加所有物品
# 410 - 容器内没有该ID的物品

const CAN_ADD_ITEM_SUCCESS = 200
const CAN_ADD_ITEM_TAG_CONTAIN_ERROR = 400
const CAN_ADD_ITEM_INDEX_ERROR = 401
const CAN_ADD_ITEM_STACK_ERROR = 402
const CAN_ADD_ITEM_TAG_LIST_ERROR = 403
const CAN_ADD_ITEM_TAG_NULL_ERROR = 404
const CAN_ADD_ITEM_ID_CONFLICT_ERROR = 405
const CAN_ADD_ITEM_INDEX_OUT_OF_RANGE_ERROR = 406
const CAN_REMOVE_ITEM_SUCCESS = 200
const CAN_REMOVE_ITEM_NUM_ERROR = 407
const CAN_REMOVE_ITEM_INDEX_NULL_ERROR = 408
const CAN_ADD_ITEM_SPACE_ERROR = 409
const CAN_REMOVE_ITEM_ID_NOT_FOUND_ERROR = 410

# ---------------

# 检查物品标签是否合法
func _check_item_tag(item: Item) -> int:
	if item.data.tags.size() == 0:
		push_error("ItemContainer: can_add_item: 物品", item, "没有标签")
		return CAN_ADD_ITEM_TAG_LIST_ERROR

	# 如果容器没有设置可添加标签限制，则允许所有物品
	if addable_tags.size() == 0:
		return CAN_ADD_ITEM_SUCCESS

	var has_valid_tag = false

	if use_hierarchical_tags:
		# 层级匹配：物品标签匹配容器允许的标签或其祖先
		for item_tag in item.data.tags:
			for addable_tag in addable_tags:
				if item_tag.matches_tag(addable_tag):
					has_valid_tag = true
					break
			if has_valid_tag:
				break
	else:
		# 旧式精确匹配
		for tag in item.data.tags:
			if tag in addable_tags:
				has_valid_tag = true
				break

	if not has_valid_tag:
		push_error("ItemContainer: can_add_item: 物品", item, "标签不在容器可添加的标签列表中")
		return CAN_ADD_ITEM_TAG_CONTAIN_ERROR

	return CAN_ADD_ITEM_SUCCESS

# 查找指定物品id的可用位置信息
# 返回格式：{ "stackable": Array[Dictionary], "empty": Array[int] }
# stackable 数组元素格式: { "index": int, "available_space": int }
func find_available_positions(item_id: int, max_stack: int = -1) -> Dictionary:
	var result = { "stackable": [], "empty": [] as Array[int] }
	
	# 查找未满堆叠的位置 O(n) n为该ID物品的堆叠组数
	if item_id_pos_map.has(item_id):
		for pos in item_id_pos_map[item_id]:
			var existing_item = item_list[pos]
			if existing_item != null:
				var available_space = 0
				if max_stack == -1:
					# 无限堆叠
					available_space = -1
				else:
					available_space = max_stack - existing_item.stack_count
				
				if available_space != 0:  # -1 或 > 0 都表示可以添加
					result["stackable"].append({ "index": pos, "available_space": available_space })
	
	# 空位置直接从缓存获取 O(1)
	result["empty"] = item_empty_pos_map.duplicate()
	
	return result

# 查找指定物品id的第一个可用位置（优先返回未满堆叠的位置）
# 参数 add_count: 要添加的数量，用于判断位置是否能容纳
func find_position_by_id(item_id: int, max_stack: int = -1, add_count: int = 1) -> int:
	# 先查找未满堆叠的位置 O(n)
	if item_id_pos_map.has(item_id):
		for pos in item_id_pos_map[item_id]:
			var existing_item = item_list[pos]
			if existing_item != null:
				# 检查是否能容纳要添加的数量
				if max_stack == -1:
					# 无限堆叠，直接返回
					return pos
				elif existing_item.stack_count + add_count <= max_stack:
					return pos
	
	# 没有可堆叠位置，返回第一个空位 O(1)
	if item_empty_pos_map.size() > 0:
		return item_empty_pos_map[0]
	
	return -1

# 计算添加物品的分配方案
# 返回 { "code": int, "distribution": Array } 
# distribution 格式: [{ "index": int, "count": int, "is_new": bool }] 表示每个位置添加的数量
func calculate_add_distribution(item: Item, count: int = -1, check_tag: bool = false) -> Dictionary:
	if count == -1:
		count = item.stack_count
	
	var result = { "code": CAN_ADD_ITEM_SUCCESS, "distribution": [] }
	
	# 首先检查物品的标签
	if check_tag:
		var tag_result = _check_item_tag(item)
		if tag_result != CAN_ADD_ITEM_SUCCESS:
			result["code"] = tag_result
			return result
	
	var remaining = count
	var max_stack = item.get_max_stack()
	var item_id = item.get_id()
	var distribution: Array = []
	
	# 先尝试填充现有堆叠
	if item_id_pos_map.has(item_id):
		for pos in item_id_pos_map[item_id]:
			if remaining <= 0:
				break
			var existing_item = item_list[pos]
			if existing_item != null:
				var available_space = 0
				if max_stack == -1:
					# 无限堆叠，直接放入所有
					available_space = remaining
				else:
					available_space = max_stack - existing_item.stack_count
				
				if available_space > 0:
					var to_add = min(remaining, available_space)
					distribution.append({ "index": pos, "count": to_add, "is_new": false })
					remaining -= to_add
	
	# 如果还有剩余，使用空位
	if remaining > 0:
		for empty_pos in item_empty_pos_map:
			if remaining <= 0:
				break
			var to_add = 0
			if max_stack == -1:
				to_add = remaining
			else:
				to_add = min(remaining, max_stack)
			distribution.append({ "index": empty_pos, "count": to_add, "is_new": true })
			remaining -= to_add
	
	# 检查是否还有剩余未分配的数量
	if remaining > 0:
		push_error("ItemContainer: calculate_add_distribution: 容器空间不足，无法添加", remaining, "个物品")
		result["code"] = CAN_ADD_ITEM_SPACE_ERROR
		return result
	
	result["distribution"] = distribution
	return result

# 查看是否能够添加指定物品到指定位置
func can_add_item(item: Item, index: int = -1, check_tag: bool = false) -> int:
	# 首先检查物品的标签
	if check_tag:
		var tag_result = _check_item_tag(item)
		if tag_result != CAN_ADD_ITEM_SUCCESS:
			return tag_result
	
	var max_stack = item.get_max_stack()
	
	# 如果没有指定位置，查找可用位置
	if index == -1:
		index = find_position_by_id(item.get_id(), max_stack, item.stack_count)
		if index == -1:
			push_error("ItemContainer: can_add_item: 容器", self, "没有可用位置可以添加物品")
			return CAN_ADD_ITEM_INDEX_ERROR
	
	# 检查索引是否超出范围
	if index >= size or index < 0:
		push_error("ItemContainer: can_add_item: 索引", index, "超出容器大小")
		return CAN_ADD_ITEM_INDEX_OUT_OF_RANGE_ERROR
	
	# 检查目标位置的物品情况
	if item_list[index] != null:
		var existing_item = item_list[index]
		if existing_item.data.id == item.data.id:
			# 相同id，检查堆叠是否超限
			if max_stack != -1 and max_stack < existing_item.stack_count + item.stack_count:
				push_error("ItemContainer: can_add_item: 物品", item, "堆叠数量超过最大堆叠数量")
				return CAN_ADD_ITEM_STACK_ERROR
			return CAN_ADD_ITEM_SUCCESS
		else:
			push_error("ItemContainer: can_add_item: 物品", item, "所在位置已存在物品，但是物品id不同")
			return CAN_ADD_ITEM_ID_CONFLICT_ERROR
	
	return CAN_ADD_ITEM_SUCCESS

# 内部函数：在指定位置添加物品（维护映射）
func _do_add_item_at_index(item: Item, index: int) -> void:
	if item_list[index] == null:
		# 新位置，从空位列表移除
		_remove_from_empty_pos_map(index)
		# 添加到ID位置映射
		_add_to_id_pos_map(item.get_id(), index)
		
		item_list[index] = item
		item.container = self
		item.position_in_container = index
		item_changed.emit(true, index, item)
	else:
		# 已有物品，增加堆叠
		item_list[index].stack_count += item.stack_count
		item_changed.emit(true, index, item_list[index])

# 添加物品到容器
# 如果指定了index，则尝试添加到指定位置
# 如果没有指定index（-1），则智能分配：优先堆叠到现有同ID物品，然后使用空位
func add_item(item: Item, index: int = -1, check_tag: bool = false) -> int:
	# 如果指定了位置，使用原来的逻辑
	if index != -1:
		var can_add = can_add_item(item, index, check_tag)
		if can_add != CAN_ADD_ITEM_SUCCESS:
			push_error("ItemContainer: add_item: 物品", item, "不能添加到容器，错误码：", can_add)
			var illegal_items: Array[Item] = []
			illegal_items.append(item)
			illegal_items_changed.emit(illegal_items)
			return can_add
		
		_do_add_item_at_index(item, index)
		return CAN_ADD_ITEM_SUCCESS
	
	# 没有指定位置，使用智能分配
	var add_result = calculate_add_distribution(item, item.stack_count, check_tag)
	if add_result["code"] != CAN_ADD_ITEM_SUCCESS:
		push_error("ItemContainer: add_item: 物品", item, "不能添加到容器，错误码：", add_result["code"])
		var illegal_items: Array[Item] = []
		illegal_items.append(item)
		illegal_items_changed.emit(illegal_items)
		return add_result["code"]
	
	# 执行分配
	for dist in add_result["distribution"]:
		var target_index: int = dist["index"]
		var count: int = dist["count"]
		var is_new: bool = dist["is_new"]
		
		if is_new:
			# 创建新物品实例放入新位置
			var new_item = Item.new(item.data, self, target_index, count)
			_do_add_item_at_index(new_item, target_index)
		else:
			# 增加现有堆叠
			item_list[target_index].stack_count += count
			item_changed.emit(true, target_index, item_list[target_index])
	
	return CAN_ADD_ITEM_SUCCESS

# 一次性添加多个物品到容器内
func add_multi_items(_items: Array[Item]) -> Array[int]:
	var results: Array[int] = []
	var illegal_items: Array[Item] = []
	for _item in _items:
		var code = add_item(_item)
		if code != CAN_ADD_ITEM_SUCCESS:
			push_error("ItemContainer: add_items: 物品", _item, "不能添加到容器，错误码：", code)
			illegal_items.append(_item)
		results.append(code)
	if illegal_items.size() > 0:
		illegal_items_changed.emit(illegal_items)
	return results

# 通过物品模板添加物品实例到容器内
func add_item_by_itemdata(item_data: ItemData, index: int = -1, check_tag: bool = false, stack_count: int = 1) -> int:
	return add_item(Item.new(item_data, self, index, stack_count), index, check_tag)

# 查看是否能够移除指定位置上的指定格数的物品
func can_remove_item(index: int = -1, num: int = 1) -> int:
	# 先检查index是否合法
	if index >= size or index < 0:
		push_error("ItemContainer: can_remove_item: 索引", index, "超出容器大小或无效")
		return CAN_ADD_ITEM_INDEX_OUT_OF_RANGE_ERROR
	# 检查指定的位置上是否有物品
	if item_list[index] == null:
		push_error("ItemContainer: can_remove_item: 索引", index, "处的物品不存在")
		return CAN_REMOVE_ITEM_INDEX_NULL_ERROR
	# 检查是否有足够的物品可以移除
	if item_list[index].stack_count < num:
		push_error("ItemContainer: can_remove_item: 索引", index, "处的物品堆叠数量不足，当前只有", item_list[index].stack_count, "个，需要移除", num, "个")
		return CAN_REMOVE_ITEM_NUM_ERROR
	return CAN_REMOVE_ITEM_SUCCESS

# 计算按ID移除物品的分配方案
# 返回 { "code": int, "distribution": Array }
# distribution 格式: [{ "index": int, "count": int }]
func calculate_remove_distribution(item_id: int, num: int = 1) -> Dictionary:
	var result = { "code": CAN_REMOVE_ITEM_SUCCESS, "distribution": [] }
	
	if not item_id_pos_map.has(item_id):
		push_error("ItemContainer: calculate_remove_distribution: 容器内没有id为", item_id, "的物品")
		result["code"] = CAN_REMOVE_ITEM_ID_NOT_FOUND_ERROR
		return result
	
	var remaining = num
	var distribution: Array = []
	
	# 遍历所有该ID的位置
	for pos in item_id_pos_map[item_id]:
		if remaining <= 0:
			break
		var existing_item = item_list[pos]
		if existing_item != null:
			var to_remove = min(remaining, existing_item.stack_count)
			distribution.append({ "index": pos, "count": to_remove })
			remaining -= to_remove
	
	if remaining > 0:
		push_error("ItemContainer: calculate_remove_distribution: 物品id", item_id, "的数量不足，还差", remaining, "个")
		result["code"] = CAN_REMOVE_ITEM_NUM_ERROR
		return result
	
	result["distribution"] = distribution
	return result

# 内部函数：在指定位置移除物品（维护映射）
func _do_remove_item_at_index(index: int, num: int) -> void:
	var existing_item = item_list[index]
	var item_id = existing_item.get_id()
	
	if existing_item.stack_count > num:
		# 只减少堆叠
		existing_item.stack_count -= num
		item_changed.emit(false, index, existing_item)
	else:
		# 完全移除
		item_list[index] = null
		# 从ID位置映射移除
		_remove_from_id_pos_map(item_id, index)
		# 添加到空位列表
		_add_to_empty_pos_map(index)
		item_changed.emit(false, index, null)

# 删除指定位置的物品
func remove_item_in_position(index: int = -1, num: int = 1) -> int:
	# 先检查是否能够移除物品
	var can_remove = can_remove_item(index, num)
	if can_remove != CAN_REMOVE_ITEM_SUCCESS:
		push_error("ItemContainer: remove_item: 索引", index, "处的物品不能移除，错误码：", can_remove)
		return can_remove
	
	_do_remove_item_at_index(index, num)
	return CAN_REMOVE_ITEM_SUCCESS

# 按物品ID删除指定数量的物品（不需要指定位置）
# 会自动从该ID的多个堆叠组中移除，直到移除足够数量
func remove_item_by_id(item_id: int, num: int = 1) -> int:
	var remove_result = calculate_remove_distribution(item_id, num)
	if remove_result["code"] != CAN_REMOVE_ITEM_SUCCESS:
		return remove_result["code"]
	
	# 执行移除
	for dist in remove_result["distribution"]:
		var target_index: int = dist["index"]
		var count: int = dist["count"]
		_do_remove_item_at_index(target_index, count)
	
	return CAN_REMOVE_ITEM_SUCCESS

# 按物品实例删除（不需要指定位置）
func remove_item(item: Item, num: int = 1) -> int:
	return remove_item_by_id(item.get_id(), num)

# 检查是否能够按ID移除指定数量的物品
func can_remove_item_by_id(item_id: int, num: int = 1) -> int:
	var result = calculate_remove_distribution(item_id, num)
	return result["code"]

# ---------------
# 查看物品是否存在以及数量是否足够相关code注释
# 200 - 物品存在，数量足够
# 301 - 指定位置为空
# 302 - 指定位置物品不同
# 303 - 物品存在但数量不足
# 304 - 指定索引超出容器大小
# 305 - 容器内没有该物品

const HAS_ITEM_SUCCESS = 200
const HAS_ITEM_INDEX_NULL_ERROR = 301
const HAS_ITEM_ID_CONFLICT_ERROR = 302
const HAS_ITEM_NUM_ERROR = 303
const HAS_ITEM_INDEX_OUT_OF_RANGE_ERROR = 304
const HAS_ITEM_NOT_FOUND_ERROR = 305
# ---------------

# 查看容器内是否有指定物品
func has_item(item: Item, index: int = -1, check_num: bool = false) -> int:
	if index != -1:
		# 检查索引是否超出容器大小
		if index < 0 or index >= size:
			push_error("ItemContainer: has_item: 索引", index, "超出容器大小")
			return HAS_ITEM_INDEX_OUT_OF_RANGE_ERROR
		# 检查指定位置是否有物品
		var existing_item = item_list[index]
		if existing_item == null:
			push_error("ItemContainer: has_item: 索引", index, "处为空")
			return HAS_ITEM_INDEX_NULL_ERROR
		# 检查物品id是否相同
		if existing_item.data.id != item.data.id:
			push_error("ItemContainer: has_item: 索引", index, "处的物品id为", existing_item.data.id, "，与指定物品id", item.data.id, "不同")
			return HAS_ITEM_ID_CONFLICT_ERROR
		# 如果需要检查数量，那么检查堆叠数量是否足够
		if check_num:
			if existing_item.stack_count < item.stack_count:
				push_error("ItemContainer: has_item: 索引", index, "处的物品堆叠数量为", existing_item.stack_count, "，不足指定数量", item.stack_count)
				return HAS_ITEM_NUM_ERROR
		# 如果以上检查都通过，那么物品存在且数量足够
		return HAS_ITEM_SUCCESS
	else:
		# 使用 item_id_pos_map 快速查找 O(1)
		var item_id = item.get_id()
		if not item_id_pos_map.has(item_id):
			push_error("ItemContainer: has_item: 容器", self, "内没有id为", item_id, "的物品")
			return HAS_ITEM_NOT_FOUND_ERROR
		# 如果需要检查数量，统计所有堆叠的总数
		if check_num:
			var total_count = 0
			for pos in item_id_pos_map[item_id]:
				if item_list[pos] != null:
					total_count += item_list[pos].stack_count
			if total_count < item.stack_count:
				push_error("ItemContainer: has_item: 容器", self, "内物品id", item_id, "总数量为", total_count, "，不足指定数量", item.stack_count)
				return HAS_ITEM_NUM_ERROR
		# 如果以上检查都通过，那么物品存在且数量足够
		return HAS_ITEM_SUCCESS

# 按ID检查容器内是否有指定物品及数量
func has_item_by_id(item_id: int, num: int = 1) -> int:
	if not item_id_pos_map.has(item_id):
		push_error("ItemContainer: has_item_by_id: 容器", self, "内没有id为", item_id, "的物品")
		return HAS_ITEM_NOT_FOUND_ERROR
	
	var total_count = 0
	for pos in item_id_pos_map[item_id]:
		if item_list[pos] != null:
			total_count += item_list[pos].stack_count
	
	if total_count < num:
		push_error("ItemContainer: has_item_by_id: 容器", self, "内物品id", item_id, "总数量为", total_count, "，不足指定数量", num)
		return HAS_ITEM_NUM_ERROR
	
	return HAS_ITEM_SUCCESS

# 获取容器内指定ID物品的总数量 O(n)，n为该ID的堆叠组数
func get_item_count_by_id(item_id: int) -> int:
	if not item_id_pos_map.has(item_id):
		return 0
	
	var total_count = 0
	for pos in item_id_pos_map[item_id]:
		if item_list[pos] != null:
			total_count += item_list[pos].stack_count
	return total_count

# 变更容器到指定大小
# 变更容器大小（推荐使用此函数，会处理物品重新分配）
func change_size(new_size: int) -> bool:
	return set_container_size(new_size)

# 获取容器内指定位置的物品
func get_item_in_position(index: int) -> Item:
	if index >= size or index < 0:
		push_error("ItemContainer: get_item_in_position: 索引", index, "超出容器大小")
		return null
	return item_list[index]

# 获取容器内第一个空位索引 O(1)
func get_first_empty_position() -> int:
	if item_empty_pos_map.size() > 0:
		return item_empty_pos_map[0]
	return -1

# 获取容器内空位数量 O(1)
func get_empty_count() -> int:
	return item_empty_pos_map.size()

# 获取容器内指定ID物品所在的所有位置 O(1)
func get_positions_by_id(item_id: int) -> Array[int]:
	if item_id_pos_map.has(item_id):
		return item_id_pos_map[item_id].duplicate()
	return [] as Array[int]
