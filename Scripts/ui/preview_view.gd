## 叠放预览视图：显示当前选中卡牌的重叠效果
## 在一个 10×10 的小网格中可视化多张卡牌叠放后的重叠情况。
## 功能：
##   - 每张卡用不同颜色显示各自的覆盖范围
##   - 重叠部分用绿色/黄色标注威力值数字
##   - 支持单卡旋转（R键）、单卡移动（WASD）、整体旋转（Q键）
##   - 当前激活的卡牌边框高亮（Tab切换）
class_name PreviewView
extends Control

const CELL_SIZE := 14      ## 预览区每格像素大小（比棋盘小，紧凑显示）
const GRID_SIZE := 10      ## 预览区网格尺寸（10×10）

## ─── 预览区配色 ───
const COLOR_BG := Color(0.15, 0.15, 0.15)          ## 背景色
const COLOR_SINGLE := Color(0.4, 0.4, 0.4, 0.5)    ## （预留）单层格子色
const COLOR_OVERLAP_1 := Color(0.3, 0.7, 0.3)       ## 威力1（2层重叠）绿色
const COLOR_OVERLAP_2 := Color(0.5, 0.8, 0.3)       ## 威力2（3层重叠）黄绿色
const COLOR_OVERLAP_3 := Color(0.8, 0.9, 0.2)       ## 威力3（4层重叠）亮黄色

## 每张卡的独立颜色（最多4张，用于区分哪张卡占了哪些格子）
const CARD_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.8, 0.6),   # 卡1：蓝
	Color(0.8, 0.4, 0.3, 0.6),   # 卡2：红
	Color(0.3, 0.7, 0.4, 0.6),   # 卡3：绿
	Color(0.7, 0.5, 0.8, 0.6),   # 卡4：紫
]

var _placements: Array[ShapeResolver.CardPlacement] = []  ## 当前叠放的卡牌列表
var _overlap: Dictionary = {}           ## 重叠层数 {Vector2i → int}
var _power_map: Dictionary = {}         ## 原始威力图 {Vector2i → int}（仅≥2层的格子）
var _rotated_power_map: Dictionary = {} ## 整体旋转后的威力图（用于实际放到棋盘上）
var _composite_rotation := 0            ## 整体旋转次数 (0-3)，Q键递增
var _display_offset := Vector2i.ZERO    ## 显示偏移（让叠放图案居中在预览区）
var _active_card_index := -1            ## 当前激活卡牌的索引（WASD移动、R旋转的目标）

signal placements_changed()  ## 叠放状态变化时触发（通知 game_ui 刷新棋盘预览）


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE * GRID_SIZE, CELL_SIZE * GRID_SIZE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

	# 网格线
	for i in GRID_SIZE + 1:
		var x := float(i * CELL_SIZE)
		var y := float(i * CELL_SIZE)
		draw_line(Vector2(x, 0), Vector2(x, GRID_SIZE * CELL_SIZE), Color(0.25, 0.25, 0.25), 1.0)
		draw_line(Vector2(0, y), Vector2(GRID_SIZE * CELL_SIZE, y), Color(0.25, 0.25, 0.25), 1.0)

	if _placements.is_empty():
		_draw_hint("选择2~4张牌")
		return

	# 先画每张卡的独立格子（单层，用各自颜色）
	for card_idx in _placements.size():
		var placement := _placements[card_idx]
		var cells := placement.get_cells()
		var card_color: Color = CARD_COLORS[card_idx % CARD_COLORS.size()]
		# 如果是当前调整的卡，边框加亮
		var is_active := (card_idx == _active_card_index)

		for cell in cells:
			var dp := cell + _display_offset
			if dp.x < 0 or dp.x >= GRID_SIZE or dp.y < 0 or dp.y >= GRID_SIZE:
				continue
			var rect := Rect2(dp.x * CELL_SIZE, dp.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, card_color)
			if is_active:
				draw_rect(rect, Color.WHITE, false, 2.0)

	# 画重叠区域（使用原始 power_map + 同一个 display_offset，和卡牌对齐）
	for pos: Vector2i in _power_map:
		var power: int = _power_map[pos]
		var dp := pos + _display_offset
		if dp.x < 0 or dp.x >= GRID_SIZE or dp.y < 0 or dp.y >= GRID_SIZE:
			continue

		var rect := Rect2(dp.x * CELL_SIZE, dp.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)

		var color: Color
		if power == 1:
			color = COLOR_OVERLAP_1
		elif power == 2:
			color = COLOR_OVERLAP_2
		else:
			color = COLOR_OVERLAP_3

		draw_rect(rect, color)

		var font := ThemeDB.fallback_font
		var text := str(power)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		var text_pos := rect.position + (rect.size - text_size) / 2 + Vector2(0, text_size.y * 0.75)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	if _power_map.is_empty() and _placements.size() >= 2:
		_draw_hint("无重叠，调整位置")

	# 整体旋转提示
	if _composite_rotation > 0 and not _power_map.is_empty():
		var rot_text := "整体旋转: %d°" % (_composite_rotation * 90)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(4, GRID_SIZE * CELL_SIZE - 4), rot_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)


func _draw_hint(text: String) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	var center := Vector2(GRID_SIZE * CELL_SIZE / 2 - text_size.x / 2, GRID_SIZE * CELL_SIZE / 2)
	draw_string(font, center, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.5, 0.5))


## 更新预览：传入新的卡牌放置列表（选牌变化时由 game_ui 调用）
func update_preview(placements: Array[ShapeResolver.CardPlacement]) -> void:
	_placements = placements

	if _placements.size() < 2:
		_overlap.clear()
		_power_map.clear()
		_active_card_index = -1
		queue_redraw()
		return

	# 默认激活第二张卡（第一张固定在原点，玩家通常移动后面的卡来调整重叠）
	if _active_card_index < 0 or _active_card_index >= _placements.size():
		_active_card_index = mini(1, _placements.size() - 1)

	_recalculate()


## 重新计算重叠、威力、旋转、显示偏移，然后触发重绘
func _recalculate() -> void:
	_overlap = ShapeResolver.compute_overlap(_placements)
	_power_map = ShapeResolver.compute_power_map(_overlap)
	_rotated_power_map = _apply_rotation(_power_map, _composite_rotation)
	_compute_display_offset()
	queue_redraw()


## 计算显示偏移，使所有卡牌的组合图案在预览区居中
func _compute_display_offset() -> void:
	if _overlap.is_empty() and _placements.is_empty():
		_display_offset = Vector2i.ZERO
		return

	# 收集所有卡牌的所有格子坐标
	var all_cells: Array[Vector2i] = []
	for placement in _placements:
		all_cells.append_array(placement.get_cells())

	if all_cells.is_empty():
		_display_offset = Vector2i.ZERO
		return

	# 找包围盒
	var min_pos := all_cells[0]
	var max_pos := all_cells[0]
	for cell in all_cells:
		min_pos.x = mini(min_pos.x, cell.x)
		min_pos.y = mini(min_pos.y, cell.y)
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)

	# 居中：让包围盒中心对齐预览区中心
	var shape_size := max_pos - min_pos + Vector2i.ONE
	_display_offset = Vector2i(
		(GRID_SIZE - shape_size.x) / 2 - min_pos.x,
		(GRID_SIZE - shape_size.y) / 2 - min_pos.y,
	)


## 设置当前正在调整的卡牌索引
func set_active_card(index: int) -> void:
	_active_card_index = index
	queue_redraw()


func get_active_card() -> int:
	return _active_card_index


## 移动当前激活卡牌的偏移（不重新居中）
func move_active_card(direction: Vector2i) -> void:
	if _active_card_index < 0 or _active_card_index >= _placements.size():
		return
	_placements[_active_card_index].offset += direction
	_refresh_overlap()
	placements_changed.emit()


## 旋转当前激活卡牌
func rotate_active_card() -> void:
	if _active_card_index < 0 or _active_card_index >= _placements.size():
		return
	_placements[_active_card_index].rotation = (_placements[_active_card_index].rotation + 1) % 4
	_refresh_overlap()
	placements_changed.emit()


## 只刷新重叠计算，不改变显示偏移
func _refresh_overlap() -> void:
	_overlap = ShapeResolver.compute_overlap(_placements)
	_power_map = ShapeResolver.compute_power_map(_overlap)
	_rotated_power_map = _apply_rotation(_power_map, _composite_rotation)
	queue_redraw()


## 对 power_map 整体旋转 N 次 90°CW，并归一化到左上角 (0,0)
## 这样玩家按 Q 旋转整体图案后，放到棋盘上的坐标也是正确旋转后的
static func _apply_rotation(pmap: Dictionary, steps: int) -> Dictionary:
	if pmap.is_empty():
		return pmap.duplicate()
	var result := pmap.duplicate()
	# 旋转（0次则跳过）
	for _s in steps % 4:
		var rotated := {}
		for pos: Vector2i in result:
			# 90° CW: (x, y) -> (y, -x)
			rotated[Vector2i(pos.y, -pos.x)] = result[pos]
		result = rotated
	# 归一化：无论是否旋转，都确保左上角对齐到 (0,0)
	var min_x := 999
	var min_y := 999
	for pos: Vector2i in result:
		min_x = mini(min_x, pos.x)
		min_y = mini(min_y, pos.y)
	var normalized := {}
	for pos: Vector2i in result:
		normalized[pos - Vector2i(min_x, min_y)] = result[pos]
	return normalized


## 为一组格子计算居中显示偏移
func _compute_offset_for(cells_map: Dictionary) -> Vector2i:
	if cells_map.is_empty():
		return Vector2i.ZERO
	var min_pos := Vector2i(999, 999)
	var max_pos := Vector2i(-999, -999)
	for pos: Vector2i in cells_map:
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)
	var shape_size := max_pos - min_pos + Vector2i.ONE
	return Vector2i(
		(GRID_SIZE - shape_size.x) / 2 - min_pos.x,
		(GRID_SIZE - shape_size.y) / 2 - min_pos.y,
	)


func get_power_map() -> Dictionary:
	return _power_map


## 返回旋转+归一化后的 power_map（左上角从 0,0 开始）
## 用于棋盘放置时鼠标位置 = 重叠图案左上角
func get_normalized_power_map() -> Dictionary:
	return _rotated_power_map


func get_placements() -> Array[ShapeResolver.CardPlacement]:
	return _placements


## 旋转整体重叠图案（不改变单卡排列，只旋转最终输出）
func rotate_all() -> void:
	if _power_map.is_empty():
		return
	_composite_rotation = (_composite_rotation + 1) % 4
	_rotated_power_map = _apply_rotation(_power_map, _composite_rotation)
	queue_redraw()
	placements_changed.emit()


func clear_preview() -> void:
	_placements.clear()
	_overlap.clear()
	_power_map.clear()
	_rotated_power_map.clear()
	_composite_rotation = 0
	_active_card_index = -1
	queue_redraw()
