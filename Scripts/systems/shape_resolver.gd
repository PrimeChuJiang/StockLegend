## 形状叠放解析器 v5：计算重叠和威力
## 纯静态工具类，不作为 AutoLoad，所有方法都是 static。
## 核心职责：将多张卡牌的叠放操作转化为棋盘上的威力值，并执行涂地结算。
##
## 处理流水线：
##   选牌 → CardPlacement（旋转+偏移）→ compute_overlap（层数）
##   → compute_power_map（威力=层数-1）→ resolve_article（逐格应用到棋盘）
class_name ShapeResolver


## 单张卡牌的放置信息（内部类）
## 封装了"哪张牌、旋转几次、在叠放空间中偏移多少"
class CardPlacement:
	var card_def: CardDef       ## 使用的卡牌定义
	var rotation: int           ## 旋转步数 0-3（0°/90°CW/180°/270°CW）
	var offset: Vector2i        ## 在叠放空间中的偏移（第一张卡通常为原点）

	func _init(p_card: CardDef, p_rotation: int = 0, p_offset: Vector2i = Vector2i.ZERO) -> void:
		card_def = p_card
		rotation = p_rotation
		offset = p_offset

	## 获取此放置在叠放空间中实际占据的格子列表
	## = 形状旋转后的格子 + 偏移
	func get_cells() -> Array[Vector2i]:
		var rotated := card_def.shape.rotated(rotation)
		var result: Array[Vector2i] = []
		for cell in rotated:
			result.append(cell + offset)
		return result


## ─── 第1步：计算重叠层数 ───
## 将所有卡牌的格子叠在一起，统计每个坐标被覆盖了几次。
## 返回 Dictionary[Vector2i, int]：叠放空间坐标 → 重叠层数
static func compute_overlap(placements: Array[CardPlacement]) -> Dictionary:
	var cell_counts := {}
	for placement in placements:
		var cells := placement.get_cells()
		for cell in cells:
			cell_counts[cell] = cell_counts.get(cell, 0) + 1
	return cell_counts


## ─── 第2步：重叠层数 → 威力值 ───
## 规则：只有 ≥2 层的格子才生效，威力 = 层数 - 1
## 例：2层→威力1，3层→威力2，4层→威力3（最大）
## 返回 Dictionary[Vector2i, int]：叠放空间坐标 → 威力值
static func compute_power_map(overlap: Dictionary) -> Dictionary:
	var power_map := {}
	for pos: Vector2i in overlap:
		var count: int = overlap[pos]
		if count >= 2:
			power_map[pos] = count - 1
	return power_map


## 边界检查：验证 power_map 中所有格子放到棋盘 grid_pos 位置后是否都在范围内
static func validate_bounds(power_map: Dictionary, grid_pos: Vector2i, width: int = 10, height: int = 10) -> bool:
	for pos: Vector2i in power_map:
		var board_pos := pos + grid_pos
		if board_pos.x < 0 or board_pos.x >= width:
			return false
		if board_pos.y < 0 or board_pos.y >= height:
			return false
	return true


## ─── 第3步：执行完整的「发表文章」操作 ───
## 这是涂地的完整流程：计算重叠 → 计算威力 → 逐格调用 board.apply_power()
##
## 参数：
##   placements    — 卡牌放置列表（2~4张）
##   grid_pos      — 叠放空间原点对应的棋盘坐标（即投放位置）
##   board         — BoardManager 实例（通过 AutoLoad 获取）
##   player_id     — 攻方玩家ID（Enums.CellOwner）
##   power_modifier — 可选回调 Callable(power_map, placements) -> power_map
##                    特殊卡牌可通过此接口修改威力（如翻倍、附加效果等）
##
## 返回 Dictionary：
##   cells_affected — 生效格子数
##   cells_flipped  — 翻色格子数
##   total_power    — 总威力值
##   cards_used     — 使用卡牌数
##   affected_cells — 每格详情数组 [{pos, power, flipped}, ...]
static func resolve_article(
	placements: Array[CardPlacement],
	grid_pos: Vector2i,
	board: Node,
	player_id: int,
	power_modifier: Callable = Callable()
) -> Dictionary:
	var overlap := compute_overlap(placements)
	var power_map := compute_power_map(overlap)

	# 特殊卡牌效果：通过回调修改 power_map（预留接口，目前无卡使用）
	if power_modifier.is_valid():
		power_map = power_modifier.call(power_map, placements)

	var cells_affected := 0
	var cells_flipped := 0
	var total_power := 0
	var affected_cells: Array[Dictionary] = []

	# 逐格应用威力到棋盘
	for pos: Vector2i in power_map:
		var board_pos := pos + grid_pos
		if not board.is_in_bounds(board_pos.x, board_pos.y):
			continue

		var power: int = power_map[pos]
		total_power += power
		var cell_result: Dictionary = board.apply_power(board_pos.x, board_pos.y, player_id, power)
		cells_affected += 1
		if cell_result["flipped"]:
			cells_flipped += 1
		affected_cells.append({
			"pos": board_pos,
			"power": power,
			"flipped": cell_result["flipped"],
		})

	return {
		"cells_affected": cells_affected,
		"cells_flipped": cells_flipped,
		"total_power": total_power,
		"cards_used": placements.size(),
		"affected_cells": affected_cells,
	}
