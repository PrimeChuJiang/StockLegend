# Swapper 静态工具类
# 职责：跨容器与批量操作编排
# 负责调用 ItemContainer 的 API 完成移动/交换/拆分/合并
# 提供 simulate_* 只读计算路径用于UI预览
extends RefCounted

class_name Swapper

# ---------------
# Swapper 错误码定义
# 复用 ItemContainer 的基础错误码，并新增 Swapper 专用错误码
# ---------------

# ---------------
# 通用错误码
# 200 - 操作成功
# ---------------

const SUCCESS = 200

# ---------------
# 继承自 ItemContainer 的错误码 (400-410)
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
# ---------------

const ERROR_TAG_CONTAIN = 400
const ERROR_INDEX_OCCUPIED = 401
const ERROR_STACK_OVERFLOW = 402
const ERROR_TAG_LIST_EMPTY = 403
const ERROR_TAG_NULL = 404
const ERROR_ID_CONFLICT = 405
const ERROR_INDEX_OUT_OF_RANGE = 406
const ERROR_REMOVE_NUM_INSUFFICIENT = 407
const ERROR_INDEX_NULL = 408
const ERROR_SPACE_INSUFFICIENT = 409
const ERROR_ID_NOT_FOUND = 410

# ---------------
# Swapper 专用错误码 (500+)
# 500 - 源容器为空
# 501 - 目标容器为空
# 502 - 源索引无效（超出范围或小于0）
# 503 - 目标索引无效（超出范围或小于0）
# 504 - 物品为空
# 505 - 拆分数量无效（必须大于0且小于当前堆叠数量）
# 506 - 源位置与目标位置相同
# 507 - 批量操作部分成功（部分操作失败）
# ---------------

const ERROR_SRC_CONTAINER_NULL = 500
const ERROR_DST_CONTAINER_NULL = 501
const ERROR_SRC_INDEX_INVALID = 502
const ERROR_DST_INDEX_INVALID = 503
const ERROR_ITEM_NULL = 504
const ERROR_SPLIT_NUM_INVALID = 505
const ERROR_SAME_POSITION = 506
const ERROR_PARTIAL_SUCCESS = 507

# ---------------
# 交换操作
# ---------------

# 交换两个容器内指定位置的物品
# 支持同容器内交换和跨容器交换
# 返回错误码
static func swap_positions(src: ItemContainer, src_index: int, dst: ItemContainer, dst_index: int) -> int:
	# 参数校验
	if src == null:
		push_error("Swapper: swap_positions: 源容器为空")
		return ERROR_SRC_CONTAINER_NULL
	if dst == null:
		push_error("Swapper: swap_positions: 目标容器为空")
		return ERROR_DST_CONTAINER_NULL
	if src_index < 0 or src_index >= src.size:
		push_error("Swapper: swap_positions: 源索引", src_index, "超出容器大小")
		return ERROR_SRC_INDEX_INVALID
	if dst_index < 0 or dst_index >= dst.size:
		push_error("Swapper: swap_positions: 目标索引", dst_index, "超出容器大小")
		return ERROR_DST_INDEX_INVALID
	
	# 同位置不需要交换
	if src == dst and src_index == dst_index:
		return SUCCESS
	
	var src_item = src.get_item_in_position(src_index)
	var dst_item = dst.get_item_in_position(dst_index)
	
	# 两个位置都为空，不需要交换
	if src_item == null and dst_item == null:
		return SUCCESS
	
	# 执行交换
	# 先从两个位置移除物品（不触发信号，内部操作）
	src.item_list[src_index] = null
	dst.item_list[dst_index] = null
	
	# 更新源容器映射
	if src_item != null:
		src._remove_from_id_pos_map(src_item.get_id(), src_index)
		src._add_to_empty_pos_map(src_index)
	
	if dst_item != null:
		dst._remove_from_id_pos_map(dst_item.get_id(), dst_index)
		dst._add_to_empty_pos_map(dst_index)
	
	# 放入交换后的物品
	if dst_item != null:
		src.item_list[src_index] = dst_item
		dst_item.container = src
		dst_item.position_in_container = src_index
		src._remove_from_empty_pos_map(src_index)
		src._add_to_id_pos_map(dst_item.get_id(), src_index)
		src.item_changed.emit(true, src_index, dst_item)
	else:
		src.item_changed.emit(false, src_index, null)
	
	if src_item != null:
		dst.item_list[dst_index] = src_item
		src_item.container = dst
		src_item.position_in_container = dst_index
		dst._remove_from_empty_pos_map(dst_index)
		dst._add_to_id_pos_map(src_item.get_id(), dst_index)
		dst.item_changed.emit(true, dst_index, src_item)
	else:
		dst.item_changed.emit(false, dst_index, null)
	
	return SUCCESS

# ---------------
# 转移/移动操作
# ---------------

# 移动物品从源容器到目标容器
# item: 要移动的物品实例
# num: 移动数量，-1表示全部移动
# dst_index: 目标位置，-1表示自动分配
# 返回错误码
static func move_item(src: ItemContainer, dst: ItemContainer, item: Item, num: int = -1, dst_index: int = -1) -> int:
	if src == null:
		push_error("Swapper: move_item: 源容器为空")
		return ERROR_SRC_CONTAINER_NULL
	if dst == null:
		push_error("Swapper: move_item: 目标容器为空")
		return ERROR_DST_CONTAINER_NULL
	if item == null:
		push_error("Swapper: move_item: 物品为空")
		return ERROR_ITEM_NULL
	
	# 确定移动数量
	var move_count = num if num > 0 else item.stack_count
	if move_count > item.stack_count:
		move_count = item.stack_count
	
	# 获取物品在源容器中的位置
	var src_index = item.position_in_container
	if src_index < 0 or src_index >= src.size:
		push_error("Swapper: move_item: 物品不在源容器中")
		return ERROR_SRC_INDEX_INVALID
	
	# 创建用于目标容器的物品副本
	var temp_item = Item.new(item.data, null, -1, move_count)
	
	# 先检查目标容器是否能添加
	var add_result = dst.calculate_add_distribution(temp_item, move_count)
	if add_result["code"] != ItemContainer.CAN_ADD_ITEM_SUCCESS:
		return add_result["code"]
	
	# 从源容器移除
	var remove_result = src.remove_item_in_position(src_index, move_count)
	if remove_result != ItemContainer.CAN_REMOVE_ITEM_SUCCESS:
		return remove_result
	
	# 添加到目标容器
	if dst_index != -1:
		return dst.add_item(temp_item, dst_index)
	else:
		return dst.add_item(temp_item)

# 按物品ID移动物品
# item_id: 物品ID
# num: 移动数量
# dst_index: 目标位置，-1表示自动分配
# 返回错误码
static func move_by_id(src: ItemContainer, dst: ItemContainer, item_id: int, num: int = 1, dst_index: int = -1) -> int:
	if src == null:
		push_error("Swapper: move_by_id: 源容器为空")
		return ERROR_SRC_CONTAINER_NULL
	if dst == null:
		push_error("Swapper: move_by_id: 目标容器为空")
		return ERROR_DST_CONTAINER_NULL
	
	# 检查源容器是否有足够数量的该ID物品
	var has_result = src.has_item_by_id(item_id, num)
	if has_result != ItemContainer.HAS_ITEM_SUCCESS:
		return has_result
	
	# 获取该ID物品的位置列表
	var positions = src.get_positions_by_id(item_id)
	if positions.is_empty():
		return ERROR_ID_NOT_FOUND
	
	# 获取一个物品实例用于创建副本
	var sample_item = src.get_item_in_position(positions[0])
	if sample_item == null:
		return ERROR_ITEM_NULL
	
	# 创建用于目标容器的物品副本
	var temp_item = Item.new(sample_item.data, null, -1, num)
	
	# 先检查目标容器是否能添加
	var add_result = dst.calculate_add_distribution(temp_item, num)
	if add_result["code"] != ItemContainer.CAN_ADD_ITEM_SUCCESS:
		return add_result["code"]
	
	# 从源容器移除
	var remove_result = src.remove_item_by_id(item_id, num)
	if remove_result != ItemContainer.CAN_REMOVE_ITEM_SUCCESS:
		return remove_result
	
	# 添加到目标容器
	if dst_index != -1:
		return dst.add_item(temp_item, dst_index)
	else:
		return dst.add_item(temp_item)

# ---------------
# 拆分/合并堆叠操作
# ---------------

# 拆分堆叠
# container: 容器
# index: 要拆分的物品位置
# split_num: 拆分数量
# dst_index: 目标位置，-1表示自动分配到空位
# 返回错误码
static func split_stack(container: ItemContainer, index: int, split_num: int, dst_index: int = -1) -> int:
	if container == null:
		push_error("Swapper: split_stack: 容器为空")
		return ERROR_SRC_CONTAINER_NULL
	if index < 0 or index >= container.size:
		push_error("Swapper: split_stack: 索引", index, "超出容器大小")
		return ERROR_SRC_INDEX_INVALID
	
	var item = container.get_item_in_position(index)
	if item == null:
		push_error("Swapper: split_stack: 索引", index, "处没有物品")
		return ERROR_INDEX_NULL
	
	if split_num <= 0 or split_num >= item.stack_count:
		push_error("Swapper: split_stack: 拆分数量", split_num, "无效")
		return ERROR_SPLIT_NUM_INVALID
	
	# 如果目标位置与源位置相同，返回错误
	if dst_index == index:
		push_error("Swapper: split_stack: 目标位置与源位置相同")
		return ERROR_SAME_POSITION
	
	# 确定目标位置
	var target_index = dst_index
	if target_index == -1:
		# 自动分配到空位
		if container.item_empty_pos_map.size() > 0:
			target_index = container.item_empty_pos_map[0]
		else:
			push_error("Swapper: split_stack: 没有空位可用")
			return ERROR_SPACE_INSUFFICIENT
	
	# 检查目标位置是否合法
	if target_index < 0 or target_index >= container.size:
		push_error("Swapper: split_stack: 目标索引", target_index, "超出容器大小")
		return ERROR_DST_INDEX_INVALID
	
	# 检查目标位置是否为空或相同ID物品
	var dst_item = container.get_item_in_position(target_index)
	if dst_item != null and dst_item.get_id() != item.get_id():
		push_error("Swapper: split_stack: 目标位置已有不同物品")
		return ERROR_ID_CONFLICT
	
	# 检查目标位置堆叠空间
	if dst_item != null:
		var max_stack = item.get_max_stack()
		if max_stack != -1 and dst_item.stack_count + split_num > max_stack:
			push_error("Swapper: split_stack: 目标位置堆叠空间不足")
			return ERROR_STACK_OVERFLOW
	
	# 执行拆分
	# 减少源堆叠
	item.stack_count -= split_num
	container.item_changed.emit(false, index, item)
	
	# 增加或创建目标堆叠
	if dst_item != null:
		dst_item.stack_count += split_num
		container.item_changed.emit(true, target_index, dst_item)
	else:
		var new_item = Item.new(item.data, container, target_index, split_num)
		container.item_list[target_index] = new_item
		container._remove_from_empty_pos_map(target_index)
		container._add_to_id_pos_map(new_item.get_id(), target_index)
		container.item_changed.emit(true, target_index, new_item)
	
	return SUCCESS

# 合并堆叠
# container: 容器
# from_index: 源位置（物品将被清空）
# to_index: 目标位置（物品数量增加）
# 返回错误码
static func merge_stack(container: ItemContainer, from_index: int, to_index: int) -> int:
	if container == null:
		push_error("Swapper: merge_stack: 容器为空")
		return ERROR_SRC_CONTAINER_NULL
	if from_index < 0 or from_index >= container.size:
		push_error("Swapper: merge_stack: 源索引", from_index, "超出容器大小")
		return ERROR_SRC_INDEX_INVALID
	if to_index < 0 or to_index >= container.size:
		push_error("Swapper: merge_stack: 目标索引", to_index, "超出容器大小")
		return ERROR_DST_INDEX_INVALID
	
	if from_index == to_index:
		return SUCCESS
	
	var from_item = container.get_item_in_position(from_index)
	var to_item = container.get_item_in_position(to_index)
	
	if from_item == null:
		push_error("Swapper: merge_stack: 源位置没有物品")
		return ERROR_INDEX_NULL
	
	if to_item == null:
		# 目标位置为空，直接移动
		return swap_positions(container, from_index, container, to_index)
	
	# 检查ID是否相同
	if from_item.get_id() != to_item.get_id():
		push_error("Swapper: merge_stack: 物品ID不同，无法合并")
		return ERROR_ID_CONFLICT
	
	# 检查堆叠空间
	var max_stack = from_item.get_max_stack()
	var total = from_item.stack_count + to_item.stack_count
	
	if max_stack != -1 and total > max_stack:
		# 部分合并：目标填满，源保留剩余
		var can_merge = max_stack - to_item.stack_count
		if can_merge <= 0:
			push_error("Swapper: merge_stack: 目标位置堆叠已满")
			return ERROR_STACK_OVERFLOW
		
		from_item.stack_count -= can_merge
		to_item.stack_count = max_stack
		container.item_changed.emit(false, from_index, from_item)
		container.item_changed.emit(true, to_index, to_item)
	else:
		# 完全合并
		to_item.stack_count = total
		
		# 清空源位置
		container.item_list[from_index] = null
		container._remove_from_id_pos_map(from_item.get_id(), from_index)
		container._add_to_empty_pos_map(from_index)
		
		container.item_changed.emit(false, from_index, null)
		container.item_changed.emit(true, to_index, to_item)
	
	return SUCCESS

# ---------------
# 批量操作
# ---------------

# 批量操作结构
# ops: Array[Dictionary]
# 每个Dictionary格式：
# { "item_id": int, "num": int, "dst_index": int (可选) }
# 返回: Array[int] 每个操作的结果码
static func move_batch(src: ItemContainer, dst: ItemContainer, ops: Array) -> Array[int]:
	var results: Array[int] = []
	
	if src == null:
		for i in range(ops.size()):
			results.append(ERROR_SRC_CONTAINER_NULL)
		return results
	
	if dst == null:
		for i in range(ops.size()):
			results.append(ERROR_DST_CONTAINER_NULL)
		return results
	
	for op in ops:
		var item_id: int = op.get("item_id", -1)
		var num: int = op.get("num", 1)
		var dst_index: int = op.get("dst_index", -1)
		
		if item_id == -1:
			results.append(ERROR_ITEM_NULL)
			continue
		
		var result = move_by_id(src, dst, item_id, num, dst_index)
		results.append(result)
	
	return results

# ---------------
# 仅计算不执行（SimOnly）
# ---------------

# 模拟移动操作，返回预期结果但不实际执行
# 返回: { "code": int, "src_changes": Array, "dst_changes": Array, "remaining": int }
# src_changes/dst_changes 格式: [{ "index": int, "old_count": int, "new_count": int }]
static func simulate_move(src: ItemContainer, dst: ItemContainer, item_id: int, num: int = 1, dst_index: int = -1) -> Dictionary:
	var result = {
		"code": SUCCESS,
		"src_changes": [],
		"dst_changes": [],
		"remaining": 0
	}
	
	if src == null:
		result["code"] = ERROR_SRC_CONTAINER_NULL
		return result
	if dst == null:
		result["code"] = ERROR_DST_CONTAINER_NULL
		return result
	
	# 检查源容器是否有足够物品
	var total_available = src.get_item_count_by_id(item_id)
	if total_available < num:
		result["code"] = ERROR_REMOVE_NUM_INSUFFICIENT
		result["remaining"] = num - total_available
		return result
	
	# 获取源容器的移除分配方案
	var remove_dist = src.calculate_remove_distribution(item_id, num)
	if remove_dist["code"] != ItemContainer.CAN_REMOVE_ITEM_SUCCESS:
		result["code"] = remove_dist["code"]
		return result
	
	# 计算源容器变更
	var src_changes: Array = []
	for dist in remove_dist["distribution"]:
		var idx: int = dist["index"]
		var count: int = dist["count"]
		var old_item = src.get_item_in_position(idx)
		var old_count = old_item.stack_count if old_item else 0
		var new_count = old_count - count
		src_changes.append({ "index": idx, "old_count": old_count, "new_count": new_count })
	result["src_changes"] = src_changes
	
	# 获取样本物品用于计算目标添加
	var positions = src.get_positions_by_id(item_id)
	if positions.is_empty():
		result["code"] = ERROR_ID_NOT_FOUND
		return result
	
	var sample_item = src.get_item_in_position(positions[0])
	if sample_item == null:
		result["code"] = ERROR_ITEM_NULL
		return result
	
	# 创建临时物品用于计算（不实际添加）
	var temp_item = Item.new(sample_item.data, null, -1, num)
	
	# 计算目标容器添加分配方案
	var add_dist = dst.calculate_add_distribution(temp_item, num)
	if add_dist["code"] != ItemContainer.CAN_ADD_ITEM_SUCCESS:
		result["code"] = add_dist["code"]
		return result
	
	# 计算目标容器变更
	var dst_changes: Array = []
	for dist in add_dist["distribution"]:
		var idx: int = dist["index"]
		var count: int = dist["count"]
		var is_new: bool = dist["is_new"]
		var old_item = dst.get_item_in_position(idx)
		var old_count = old_item.stack_count if old_item else 0
		var new_count = old_count + count if not is_new else count
		dst_changes.append({ "index": idx, "old_count": old_count, "new_count": new_count, "is_new": is_new })
	result["dst_changes"] = dst_changes
	
	return result

# 模拟批量操作
# 返回: { "codes": Array[int], "details": Array[Dictionary] }
static func simulate_batch(src: ItemContainer, dst: ItemContainer, ops: Array) -> Dictionary:
	var result = {
		"codes": [] as Array[int],
		"details": []
	}
	
	for op in ops:
		var item_id: int = op.get("item_id", -1)
		var num: int = op.get("num", 1)
		var dst_index: int = op.get("dst_index", -1)
		
		if item_id == -1:
			result["codes"].append(ERROR_ITEM_NULL)
			result["details"].append({})
			continue
		
		var sim_result = simulate_move(src, dst, item_id, num, dst_index)
		result["codes"].append(sim_result["code"])
		result["details"].append(sim_result)
	
	return result

# 模拟交换操作
# 返回: { "code": int, "src_item": Item, "dst_item": Item }
static func simulate_swap(src: ItemContainer, src_index: int, dst: ItemContainer, dst_index: int) -> Dictionary:
	var result = {
		"code": SUCCESS,
		"src_item": null,
		"dst_item": null
	}
	
	if src == null:
		result["code"] = ERROR_SRC_CONTAINER_NULL
		return result
	if dst == null:
		result["code"] = ERROR_DST_CONTAINER_NULL
		return result
	if src_index < 0 or src_index >= src.size:
		result["code"] = ERROR_SRC_INDEX_INVALID
		return result
	if dst_index < 0 or dst_index >= dst.size:
		result["code"] = ERROR_DST_INDEX_INVALID
		return result
	
	result["src_item"] = src.get_item_in_position(src_index)
	result["dst_item"] = dst.get_item_in_position(dst_index)
	
	return result

# 模拟拆分操作
# 返回: { "code": int, "src_new_count": int, "dst_new_count": int, "dst_is_new": bool }
static func simulate_split(container: ItemContainer, index: int, split_num: int, dst_index: int = -1) -> Dictionary:
	var result = {
		"code": SUCCESS,
		"src_new_count": 0,
		"dst_new_count": 0,
		"dst_is_new": false,
		"dst_index": -1
	}
	
	if container == null:
		result["code"] = ERROR_SRC_CONTAINER_NULL
		return result
	if index < 0 or index >= container.size:
		result["code"] = ERROR_SRC_INDEX_INVALID
		return result
	
	var item = container.get_item_in_position(index)
	if item == null:
		result["code"] = ERROR_INDEX_NULL
		return result
	
	if split_num <= 0 or split_num >= item.stack_count:
		result["code"] = ERROR_SPLIT_NUM_INVALID
		return result
	
	if dst_index == index:
		result["code"] = ERROR_SAME_POSITION
		return result
	
	# 确定目标位置
	var target_index = dst_index
	if target_index == -1:
		if container.item_empty_pos_map.size() > 0:
			target_index = container.item_empty_pos_map[0]
		else:
			result["code"] = ERROR_SPACE_INSUFFICIENT
			return result
	
	if target_index < 0 or target_index >= container.size:
		result["code"] = ERROR_DST_INDEX_INVALID
		return result
	
	var dst_item = container.get_item_in_position(target_index)
	if dst_item != null and dst_item.get_id() != item.get_id():
		result["code"] = ERROR_ID_CONFLICT
		return result
	
	if dst_item != null:
		var max_stack = item.get_max_stack()
		if max_stack != -1 and dst_item.stack_count + split_num > max_stack:
			result["code"] = ERROR_STACK_OVERFLOW
			return result
	
	result["src_new_count"] = item.stack_count - split_num
	result["dst_new_count"] = (dst_item.stack_count if dst_item else 0) + split_num
	result["dst_is_new"] = dst_item == null
	result["dst_index"] = target_index
	
	return result

