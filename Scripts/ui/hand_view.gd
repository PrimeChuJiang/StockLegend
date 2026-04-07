## 手牌视图：显示玩家手牌并处理选牌交互
## 使用 HBoxContainer 水平排列卡牌面板，每张牌是一个 Panel + Label + 形状缩略图。
## 点击切换选中状态（最多选4张），选中变化时发送 selection_changed 信号。
class_name HandView
extends HBoxContainer

signal selection_changed(selected_indices: Array[int])  ## 选中的卡牌下标列表变化时触发

const CARD_WIDTH := 70       ## 单张卡牌面板宽度
const CARD_HEIGHT := 80      ## 单张卡牌面板高度
const CARD_CELL_SIZE := 10   ## 形状缩略图中每个小方块的像素大小

const COLOR_NORMAL := Color(0.3, 0.3, 0.35)       ## 未选中卡牌底色
const COLOR_SELECTED := Color(0.3, 0.5, 0.8)      ## 选中卡牌底色（蓝色高亮）
const COLOR_DISABLED := Color(0.2, 0.2, 0.2, 0.5) ## 禁用状态底色（AI回合时）

var _cards: Array[CardDef] = []     ## 当前手牌数据
var _selected: Array[bool] = []     ## 每张牌的选中状态
var _rotations: Array[int] = []     ## 每张牌的旋转步数（0-3）
var _enabled := true                ## 是否允许交互（AI回合时禁用）


## 刷新手牌数据（抽牌/使用后调用），重置所有选中和旋转状态
func update_hand(cards: Array[CardDef]) -> void:
	_cards = cards.duplicate()
	_selected.clear()
	_rotations.clear()
	for i in _cards.size():
		_selected.append(false)
		_rotations.append(0)
	_rebuild_ui()


## 返回当前选中的卡牌下标列表
func get_selected_indices() -> Array[int]:
	var result: Array[int] = []
	for i in _selected.size():
		if _selected[i]:
			result.append(i)
	return result


## 返回当前选中的卡牌数量
func get_selected_count() -> int:
	var count := 0
	for s in _selected:
		if s:
			count += 1
	return count


## 获取指定卡牌的旋转步数
func get_card_rotation(index: int) -> int:
	if index >= 0 and index < _rotations.size():
		return _rotations[index]
	return 0


## 将所有选中的卡牌旋转90°（目前未被 game_ui 直接调用，保留备用）
func rotate_selected() -> void:
	for i in _selected.size():
		if _selected[i]:
			_rotations[i] = (_rotations[i] + 1) % 4
	_rebuild_ui()


## 清除所有选中状态
func clear_selection() -> void:
	for i in _selected.size():
		_selected[i] = false
	_rebuild_ui()
	selection_changed.emit(get_selected_indices())


## 启用/禁用交互（AI回合时禁用，防止玩家误操作）
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_rebuild_ui()


## 重建整个手牌UI（销毁旧节点，重新创建）
## 每次手牌数据或选中状态变化时调用
func _rebuild_ui() -> void:
	# 清除旧的子节点
	for child in get_children():
		child.queue_free()

	# 安全检查：确保 _selected/_rotations 和 _cards 长度同步
	while _selected.size() < _cards.size():
		_selected.append(false)
		_rotations.append(0)
	_selected.resize(_cards.size())
	_rotations.resize(_cards.size())

	for i in _cards.size():
		var card := _cards[i]
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

		# 样式
		var style := StyleBoxFlat.new()
		if not _enabled:
			style.bg_color = COLOR_DISABLED
		elif _selected[i]:
			style.bg_color = COLOR_SELECTED
		else:
			style.bg_color = COLOR_NORMAL
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color.WHITE if _selected[i] else Color(0.4, 0.4, 0.4)
		panel.add_theme_stylebox_override("panel", style)

		# 卡牌名称
		var label := Label.new()
		label.text = card.card_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, 4)
		label.size = Vector2(CARD_WIDTH, 20)
		label.add_theme_font_size_override("font_size", 11)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)

		# 旋转标记
		if _selected[i] and _rotations[i] > 0:
			var rot_label := Label.new()
			rot_label.text = "R%d" % _rotations[i]
			rot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rot_label.position = Vector2(0, 20)
			rot_label.size = Vector2(CARD_WIDTH, 16)
			rot_label.add_theme_font_size_override("font_size", 10)
			rot_label.add_theme_color_override("font_color", Color.YELLOW)
			rot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(rot_label)

		# 形状缩略图（用小方块画）
		var shape_container := Control.new()
		shape_container.position = Vector2(8, 34)
		shape_container.size = Vector2(CARD_WIDTH - 16, CARD_HEIGHT - 40)
		shape_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_container.set_meta("card_index", i)
		shape_container.set_meta("rotation", _rotations[i])
		shape_container.set_meta("shape", card.shape)
		shape_container.draw.connect(_draw_shape_thumbnail.bind(shape_container))
		panel.add_child(shape_container)

		# 点击事件
		panel.gui_input.connect(_on_card_input.bind(i))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

		add_child(panel)


## 绘制形状缩略图（在卡牌面板内的 Control 上画小方块）
## 通过 meta 读取 shape 和 rotation 数据，居中绘制
func _draw_shape_thumbnail(container: Control) -> void:
	var shape: CardShape = container.get_meta("shape")
	var rot: int = container.get_meta("rotation")
	var cells := shape.rotated(rot)
	if cells.is_empty():
		return

	# 计算包围盒
	var max_x := 0
	var max_y := 0
	for cell in cells:
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)

	# 居中偏移（让形状在容器内居中显示）
	var shape_w := (max_x + 1) * CARD_CELL_SIZE
	var shape_h := (max_y + 1) * CARD_CELL_SIZE
	var offset := Vector2(
		(container.size.x - shape_w) / 2,
		(container.size.y - shape_h) / 2,
	)

	for cell in cells:
		var rect := Rect2(
			offset.x + cell.x * CARD_CELL_SIZE,
			offset.y + cell.y * CARD_CELL_SIZE,
			CARD_CELL_SIZE - 1,
			CARD_CELL_SIZE - 1,
		)
		container.draw_rect(rect, Color.WHITE)


## 卡牌面板的点击处理：左键切换选中状态（最多4张）
func _on_card_input(event: InputEvent, index: int) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _selected[index]:
				_selected[index] = false  # 取消选中
			else:
				if get_selected_count() < 4:
					_selected[index] = true  # 选中（上限4张）
			_rebuild_ui()
			selection_changed.emit(get_selected_indices())
