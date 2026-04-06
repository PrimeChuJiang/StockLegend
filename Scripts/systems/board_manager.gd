## 棋盘管理器 v5：10×10 涂地格子系统
## 作为 AutoLoad 单例运行（名称 BoardManager），替代 v4 的 ElectionManager
extends Node

const GRID_WIDTH := 10
const GRID_HEIGHT := 10
const GRID_SIZE := GRID_WIDTH * GRID_HEIGHT

## 格子归属：0=中立, 1=甲方, 2=乙方
var _owners: Array[int] = []
## 格子忠诚度：>= 0
var _loyalty: Array[int] = []


func setup() -> void:
	_owners.clear()
	_owners.resize(GRID_SIZE)
	_owners.fill(Enums.CellOwner.NEUTRAL)
	_loyalty.clear()
	_loyalty.resize(GRID_SIZE)
	_loyalty.fill(0)


func _cell_idx(col: int, row: int) -> int:
	return row * GRID_WIDTH + col


func is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < GRID_WIDTH and row >= 0 and row < GRID_HEIGHT


func get_cell_owner(col: int, row: int) -> int:
	return _owners[_cell_idx(col, row)]


func get_loyalty(col: int, row: int) -> int:
	return _loyalty[_cell_idx(col, row)]


## 对单个格子施加威力
## 返回 Dictionary: { flipped: bool, old_owner: int, new_owner: int }
func apply_power(col: int, row: int, player_id: int, power: int) -> Dictionary:
	if not is_in_bounds(col, row) or power <= 0:
		return { "flipped": false, "old_owner": player_id, "new_owner": player_id }

	var idx := _cell_idx(col, row)
	var old_owner: int = _owners[idx]
	var result := { "flipped": false, "old_owner": old_owner, "new_owner": old_owner }

	if old_owner == Enums.CellOwner.NEUTRAL:
		# 中立格：翻色，忠诚度 = 威力值
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
			# 归零后翻色，剩余威力成为己方忠诚度
			var remainder := absi(_loyalty[idx])
			if remainder > 0:
				_owners[idx] = player_id
				_loyalty[idx] = remainder
				result["flipped"] = true
				result["new_owner"] = player_id
			else:
				# 刚好归零，变中立
				_owners[idx] = Enums.CellOwner.NEUTRAL
				_loyalty[idx] = 0
				result["flipped"] = true
				result["new_owner"] = Enums.CellOwner.NEUTRAL

	return result


## 统计各方占领格子数
func count_cells() -> Dictionary:
	var counts := { Enums.CellOwner.NEUTRAL: 0, Enums.CellOwner.PLAYER_A: 0, Enums.CellOwner.PLAYER_B: 0 }
	for owner in _owners:
		counts[owner] += 1
	return counts


## 获取棋盘字符串用于控制台显示
func get_board_string() -> String:
	var lines: Array[String] = []
	# 列号标题
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
