## 棋盘管理器 v5：10×10 涂地格子系统
## 作为 AutoLoad 单例运行（名称 BoardManager）。
## 职责：维护所有格子的归属和忠诚度状态，提供单格结算逻辑。
## 用一维数组存储，通过 _cell_idx(col, row) 映射二维坐标。
extends Node

const GRID_WIDTH := 10
const GRID_HEIGHT := 10
const GRID_SIZE := GRID_WIDTH * GRID_HEIGHT  # 100 格

## 格子归属数组（一维，长度100），值为 Enums.CellOwner 枚举
var _owners: Array[int] = []
## 格子忠诚度数组（一维，长度100），值 >= 0
var _loyalty: Array[int] = []


## 初始化/重置棋盘：所有格子归中立，忠诚度归零
func setup() -> void:
	_owners.clear()
	_owners.resize(GRID_SIZE)
	_owners.fill(Enums.CellOwner.NEUTRAL)
	_loyalty.clear()
	_loyalty.resize(GRID_SIZE)
	_loyalty.fill(0)


## 二维坐标 → 一维下标（行优先：index = row * 宽 + col）
func _cell_idx(col: int, row: int) -> int:
	return row * GRID_WIDTH + col


## 检查坐标是否在棋盘范围内
func is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < GRID_WIDTH and row >= 0 and row < GRID_HEIGHT


## 查询指定格子的归属
func get_cell_owner(col: int, row: int) -> int:
	return _owners[_cell_idx(col, row)]


## 查询指定格子的忠诚度
func get_loyalty(col: int, row: int) -> int:
	return _loyalty[_cell_idx(col, row)]


## ─── 核心结算：对单个格子施加威力 ───
## 这是整个涂地机制的基础操作，由 ShapeResolver.resolve_article() 逐格调用。
## 结算规则（见 GDD 4.4）：
##   中立格 → 翻色为攻方，忠诚度 = 威力值
##   己方格 → 忠诚度 += 威力值（加固）
##   敌方格 → 忠诚度 -= 威力值；归零后剩余威力翻色；刚好归零变中立
## 返回 Dictionary: { flipped: bool, old_owner: int, new_owner: int }
func apply_power(col: int, row: int, player_id: int, power: int) -> Dictionary:
	if not is_in_bounds(col, row) or power <= 0:
		return { "flipped": false, "old_owner": player_id, "new_owner": player_id }

	var idx := _cell_idx(col, row)
	var old_owner: int = _owners[idx]
	var result := { "flipped": false, "old_owner": old_owner, "new_owner": old_owner }

	if old_owner == Enums.CellOwner.NEUTRAL:
		# 中立格：直接翻色，忠诚度 = 威力值
		_owners[idx] = player_id
		_loyalty[idx] = power
		result["flipped"] = true
		result["new_owner"] = player_id
	elif old_owner == player_id:
		# 己方格：加固忠诚度
		_loyalty[idx] += power
	else:
		# 敌方格：削忠诚度
		_loyalty[idx] -= power
		if _loyalty[idx] <= 0:
			var remainder := absi(_loyalty[idx])
			if remainder > 0:
				# 忠诚度被打穿：翻色，剩余威力成为己方忠诚度
				_owners[idx] = player_id
				_loyalty[idx] = remainder
				result["flipped"] = true
				result["new_owner"] = player_id
			else:
				# 刚好归零：变中立，忠诚度0
				_owners[idx] = Enums.CellOwner.NEUTRAL
				_loyalty[idx] = 0
				result["flipped"] = true
				result["new_owner"] = Enums.CellOwner.NEUTRAL

	return result


## 统计各方占领格子数，返回 { NEUTRAL: N, PLAYER_A: N, PLAYER_B: N }
func count_cells() -> Dictionary:
	var counts := { Enums.CellOwner.NEUTRAL: 0, Enums.CellOwner.PLAYER_A: 0, Enums.CellOwner.PLAYER_B: 0 }
	for owner in _owners:
		counts[owner] += 1
	return counts


## 生成棋盘的文本表示（用于控制台调试输出）
## 格式："A3" 表示甲方忠诚度3，"·" 表示中立，忠诚度超过9显示为9
func get_board_string() -> String:
	var lines: Array[String] = []
	# 列号标题行
	var header := "    "
	for col in GRID_WIDTH:
		header += "%2d " % col
	lines.append(header)

	for row in GRID_HEIGHT:
		var line := "%2d  " % row
		for col in GRID_WIDTH:
			var idx := _cell_idx(col, row)
			var owner: int = _owners[idx]
			var loyalty: int = _loyalty[idx]
			if owner == Enums.CellOwner.NEUTRAL:
				line += " · "
			else:
				var symbol := Enums.owner_symbol(owner as Enums.CellOwner)
				line += "%s%d " % [symbol, mini(loyalty, 9)]
		lines.append(line)

	return "\n".join(lines)
