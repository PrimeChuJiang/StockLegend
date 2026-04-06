class_name CardShape
extends Resource

## 相对原点(0,0)的格子偏移列表
@export var cells: Array[Vector2i] = []

## 返回旋转后的格子列表（不修改自身）
## rotation_steps: 0=0°, 1=90°CW, 2=180°, 3=270°CW
func rotated(rotation_steps: int) -> Array[Vector2i]:
	var steps := rotation_steps % 4
	if steps == 0:
		return cells.duplicate()

	var result: Array[Vector2i] = []
	for cell in cells:
		var rotated_cell := cell
		for i in steps:
			# 90° CW: (x, y) -> (y, -x)
			rotated_cell = Vector2i(rotated_cell.y, -rotated_cell.x)
		result.append(rotated_cell)

	# 归一化：平移使最小坐标为(0,0)
	return _normalize(result)

## 获取格子数量
func get_cell_count() -> int:
	return cells.size()

## 获取边界大小
func get_bounds(rotation_steps: int = 0) -> Vector2i:
	var rotated_cells := rotated(rotation_steps)
	if rotated_cells.is_empty():
		return Vector2i.ZERO
	var max_pos := Vector2i.ZERO
	for cell in rotated_cells:
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)
	return max_pos + Vector2i.ONE

static func _normalize(cells_array: Array[Vector2i]) -> Array[Vector2i]:
	if cells_array.is_empty():
		return cells_array
	var min_x := cells_array[0].x
	var min_y := cells_array[0].y
	for cell in cells_array:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	var offset := Vector2i(min_x, min_y)
	var result: Array[Vector2i] = []
	for cell in cells_array:
		result.append(cell - offset)
	return result

## 创建形状的便捷方法
static func create(cell_array: Array[Vector2i]) -> CardShape:
	var shape := CardShape.new()
	shape.cells = cell_array
	return shape
