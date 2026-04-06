## 手牌视图：显示手牌和选择交互
class_name HandView
extends HBoxContainer

signal selection_changed(selected_indices: Array[int])

const CARD_WIDTH := 70
const CARD_HEIGHT := 80
const CARD_CELL_SIZE := 10

const COLOR_NORMAL := Color(0.3, 0.3, 0.35)
const COLOR_SELECTED := Color(0.3, 0.5, 0.8)
const COLOR_DISABLED := Color(0.2, 0.2, 0.2, 0.5)

var _cards: Array[CardDef] = []
var _selected: Array[bool] = []
var _rotations: Array[int] = []  ## 每张卡的旋转状态
var _enabled := true


func update_hand(cards: Array[CardDef]) -> void:
	_cards = cards.duplicate()
	_selected.clear()
	_rotations.clear()
	for i in _cards.size():
		_selected.append(false)
		_rotations.append(0)
	_rebuild_ui()


func get_selected_indices() -> Array[int]:
	var result: Array[int] = []
	for i in _selected.size():
		if _selected[i]:
			result.append(i)
	return result


func get_selected_count() -> int:
	var count := 0
	for s in _selected:
		if s:
			count += 1
	return count


func get_card_rotation(index: int) -> int:
	if index >= 0 and index < _rotations.size():
		return _rotations[index]
	return 0


func rotate_selected() -> void:
	for i in _selected.size():
		if _selected[i]:
			_rotations[i] = (_rotations[i] + 1) % 4
	_rebuild_ui()


func clear_selection() -> void:
	for i in _selected.size():
		_selected[i] = false
	_rebuild_ui()
	selection_changed.emit(get_selected_indices())


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_rebuild_ui()


func _rebuild_ui() -> void:
	# 清除旧的
	for child in get_children():
		child.queue_free()

	# 安全检查：确保数组长度同步
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


func _draw_shape_thumbnail(container: Control) -> void:
	var shape: CardShape = container.get_meta("shape")
	var rot: int = container.get_meta("rotation")
	var cells := shape.rotated(rot)
	if cells.is_empty():
		return

	# 计算边界
	var max_x := 0
	var max_y := 0
	for cell in cells:
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)

	# 居中偏移
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


func _on_card_input(event: InputEvent, index: int) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# 切换选中
			if _selected[index]:
				_selected[index] = false
			else:
				# 最多选4张
				if get_selected_count() < 4:
					_selected[index] = true
			_rebuild_ui()
			selection_changed.emit(get_selected_indices())
