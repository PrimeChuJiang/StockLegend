## 卡牌形状模板 v5
## 每张卡牌拥有一个形状（若干格子组成的图案），用于叠放合成时的空间计算。
## 作为 Resource 存储，可被多张 CardDef 共享引用。
class_name CardShape
extends Resource

## 组成此形状的格子坐标列表，相对原点 (0,0) 的偏移
## 例：横线3 = [(0,0), (1,0), (2,0)]
@export var cells: Array[Vector2i] = []

## 返回旋转后的格子列表（不修改自身）
## rotation_steps: 0=0°, 1=90°CW, 2=180°, 3=270°CW
## 旋转公式：90°CW → (x,y) → (y,-x)，连续应用 N 次
## 旋转后自动归一化（平移使左上角对齐到 (0,0)）
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

## 返回此形状包含的格子数量
func get_cell_count() -> int:
	return cells.size()

## 返回指定旋转下的包围盒尺寸（宽×高）
func get_bounds(rotation_steps: int = 0) -> Vector2i:
	var rotated_cells := rotated(rotation_steps)
	if rotated_cells.is_empty():
		return Vector2i.ZERO
	var max_pos := Vector2i.ZERO
	for cell in rotated_cells:
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)
	return max_pos + Vector2i.ONE

## 归一化：将一组格子平移，使最小坐标为 (0,0)
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

## 工厂方法：用格子数组快速创建形状
static func create(cell_array: Array[Vector2i]) -> CardShape:
	var shape := CardShape.new()
	shape.cells = cell_array
	return shape
