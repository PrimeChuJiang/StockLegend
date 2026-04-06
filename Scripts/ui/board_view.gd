## 棋盘视图：10×10 格子渲染和点击交互
class_name BoardView
extends Control

signal cell_clicked(pos: Vector2i)
signal cell_hovered(pos: Vector2i)

const CELL_SIZE := 30
const GRID_W := 10
const GRID_H := 10

const COLOR_NEUTRAL := Color(0.25, 0.25, 0.25)
const COLOR_PLAYER_A := Color(0.2, 0.4, 0.8)
const COLOR_PLAYER_B := Color(0.8, 0.2, 0.2)
const COLOR_HOVER := Color(1, 1, 1, 0.15)
const COLOR_PREVIEW_POSITIVE := Color(0.2, 0.8, 0.2, 0.5)
const COLOR_PREVIEW_ATTACK := Color(0.9, 0.6, 0.1, 0.5)
const COLOR_PREVIEW_REINFORCE := Color(0.3, 0.6, 0.9, 0.3)

var _hover_pos := Vector2i(-1, -1)
## 放置预览：棋盘绝对坐标 -> power
var _preview_cells: Dictionary = {}
var _preview_player_id := 0


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE * GRID_W, CELL_SIZE * GRID_H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	# 画格子
	for row in GRID_H:
		for col in GRID_W:
			var rect := Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			var cell_owner := BoardManager.get_cell_owner(col, row)
			var loyalty := BoardManager.get_loyalty(col, row)
			var color := _get_cell_color(cell_owner, loyalty)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.15, 0.15, 0.15), false, 1.0)

			# 忠诚度数字
			if cell_owner != Enums.CellOwner.NEUTRAL and loyalty > 0:
				_draw_cell_text(rect, str(mini(loyalty, 9)), 12, Color.WHITE)

	# 放置预览：显示结算后的预测结果
	if not _preview_cells.is_empty():
		for pos: Vector2i in _preview_cells:
			if pos.x < 0 or pos.x >= GRID_W or pos.y < 0 or pos.y >= GRID_H:
				continue
			var power: int = _preview_cells[pos]
			var cell_owner := BoardManager.get_cell_owner(pos.x, pos.y)
			var loyalty := BoardManager.get_loyalty(pos.x, pos.y)
			var rect := Rect2(pos.x * CELL_SIZE, pos.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)

			# 预测结算后的状态
			var result_owner := _preview_player_id
			var result_loyalty := 0
			if cell_owner == Enums.CellOwner.NEUTRAL:
				result_owner = _preview_player_id
				result_loyalty = power
			elif cell_owner == _preview_player_id:
				result_owner = _preview_player_id
				result_loyalty = loyalty + power
			else:
				# 敌方格
				var remaining := loyalty - power
				if remaining > 0:
					result_owner = cell_owner
					result_loyalty = remaining
				elif remaining == 0:
					result_owner = Enums.CellOwner.NEUTRAL
					result_loyalty = 0
				else:
					result_owner = _preview_player_id
					result_loyalty = absi(remaining)

			# 用预测后的颜色完全覆盖底层
			var preview_bg: Color
			if result_owner == Enums.CellOwner.NEUTRAL:
				preview_bg = COLOR_NEUTRAL
			elif result_owner == _preview_player_id:
				preview_bg = COLOR_PLAYER_A if _preview_player_id == Enums.CellOwner.PLAYER_A else COLOR_PLAYER_B
				preview_bg = preview_bg * clampf(0.6 + result_loyalty * 0.1, 0.6, 1.0)
			else:
				preview_bg = COLOR_PLAYER_A if result_owner == Enums.CellOwner.PLAYER_A else COLOR_PLAYER_B
				preview_bg = preview_bg * clampf(0.6 + result_loyalty * 0.1, 0.6, 1.0)

			draw_rect(rect, preview_bg)
			# 半透明高亮表示这是预览
			draw_rect(rect, Color(1, 1, 1, 0.15))
			draw_rect(rect, Color(1, 1, 1, 0.4), false, 1.5)

			# 显示预测后的忠诚度
			if result_owner != Enums.CellOwner.NEUTRAL and result_loyalty > 0:
				_draw_cell_text(rect, str(mini(result_loyalty, 9)), 14, Color.WHITE)

	# 悬停高亮
	if _hover_pos.x >= 0:
		var rect := Rect2(_hover_pos.x * CELL_SIZE, _hover_pos.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_rect(rect, COLOR_HOVER)


func _draw_cell_text(rect: Rect2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := rect.position + (rect.size - text_size) / 2 + Vector2(0, text_size.y * 0.75)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_pos := _mouse_to_grid(event.position)
		if new_pos != _hover_pos:
			_hover_pos = new_pos
			cell_hovered.emit(_hover_pos)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var pos := _mouse_to_grid(mb.position)
			if pos.x >= 0:
				cell_clicked.emit(pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hover_pos.x >= 0:
			_hover_pos = Vector2i(-1, -1)
			cell_hovered.emit(_hover_pos)
			hide_preview()
			queue_redraw()


func _mouse_to_grid(local_pos: Vector2) -> Vector2i:
	var col := int(local_pos.x / CELL_SIZE)
	var row := int(local_pos.y / CELL_SIZE)
	if col >= 0 and col < GRID_W and row >= 0 and row < GRID_H:
		return Vector2i(col, row)
	return Vector2i(-1, -1)


func _get_cell_color(cell_owner: int, loyalty: int) -> Color:
	if cell_owner == Enums.CellOwner.NEUTRAL:
		return COLOR_NEUTRAL
	var base: Color = COLOR_PLAYER_A if cell_owner == Enums.CellOwner.PLAYER_A else COLOR_PLAYER_B
	var brightness := clampf(0.6 + loyalty * 0.1, 0.6, 1.0)
	return base * brightness


func get_hover_pos() -> Vector2i:
	return _hover_pos


func refresh() -> void:
	queue_redraw()


## 显示放置预览（传入棋盘绝对坐标的 power_map）
func show_preview(power_map: Dictionary, player_id: int) -> void:
	_preview_cells = power_map
	_preview_player_id = player_id
	queue_redraw()


func hide_preview() -> void:
	_preview_cells.clear()
	queue_redraw()
