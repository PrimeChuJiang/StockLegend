## 形状叠放解析器 v5：计算重叠和威力
## 纯静态工具类，不作为 AutoLoad
class_name ShapeResolver


## 单张卡牌的放置信息
class CardPlacement:
	var card_def: CardDef
	var rotation: int          ## 0-3（0°/90°/180°/270°）
	var offset: Vector2i       ## 在叠放空间中的偏移位置

	func _init(p_card: CardDef, p_rotation: int = 0, p_offset: Vector2i = Vector2i.ZERO) -> void:
		card_def = p_card
		rotation = p_rotation
		offset = p_offset

	## 获取此放置在叠放空间中占据的格子列表
	func get_cells() -> Array[Vector2i]:
		var rotated := card_def.shape.rotated(rotation)
		var result: Array[Vector2i] = []
		for cell in rotated:
			result.append(cell + offset)
		return result


## 计算多张卡牌叠放后每格的重叠层数
## 返回 Dictionary[Vector2i, int]：叠放空间坐标 → 重叠层数
static func compute_overlap(placements: Array[CardPlacement]) -> Dictionary:
	var cell_counts := {}
	for placement in placements:
		var cells := placement.get_cells()
		for cell in cells:
			cell_counts[cell] = cell_counts.get(cell, 0) + 1
	return cell_counts


## 从重叠层数计算威力值（只保留 ≥2 层的格子，威力 = 层数 - 1）
## 返回 Dictionary[Vector2i, int]：叠放空间坐标 → 威力值
static func compute_power_map(overlap: Dictionary) -> Dictionary:
	var power_map := {}
	for pos: Vector2i in overlap:
		var count: int = overlap[pos]
		if count >= 2:
			power_map[pos] = count - 1
	return power_map


## 验证所有威力格子在棋盘范围内
static func validate_bounds(power_map: Dictionary, grid_pos: Vector2i, width: int = 10, height: int = 10) -> bool:
	for pos: Vector2i in power_map:
		var board_pos := pos + grid_pos
		if board_pos.x < 0 or board_pos.x >= width:
			return false
		if board_pos.y < 0 or board_pos.y >= height:
			return false
	return true


## 执行完整的「发表文章」操作
## placements: 卡牌放置列表（2~4张）
## grid_pos: 在棋盘上的投放位置（叠放空间原点对应的棋盘坐标）
## board: BoardManager 实例
## player_id: 玩家ID（Enums.CellOwner）
## power_modifier: 可选的威力修改回调（特殊卡牌用）
## 返回结果 Dictionary
static func resolve_article(
	placements: Array[CardPlacement],
	grid_pos: Vector2i,
	board: Node,
	player_id: int,
	power_modifier: Callable = Callable()
) -> Dictionary:
	var overlap := compute_overlap(placements)
	var power_map := compute_power_map(overlap)

	# 特殊卡牌效果修改威力（预留接口）
	if power_modifier.is_valid():
		power_map = power_modifier.call(power_map, placements)

	var cells_affected := 0
	var cells_flipped := 0
	var total_power := 0
	var affected_cells: Array[Dictionary] = []

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
