## 全局枚举定义 v5：竞选大师（涂地版）
## 提供格子归属枚举和相关辅助函数，全局通过 class_name 直接访问
class_name Enums

## 格子归属：中立(0) / 甲方(1) / 乙方(2)
enum CellOwner { NEUTRAL = 0, PLAYER_A = 1, PLAYER_B = 2 }

## 返回归属的中文名（用于日志输出）
static func owner_name(o: CellOwner) -> String:
	match o:
		CellOwner.NEUTRAL:
			return "中立"
		CellOwner.PLAYER_A:
			return "甲方"
		CellOwner.PLAYER_B:
			return "乙方"
	return "?"

## 返回归属的单字符符号（用于棋盘文本渲染：· / A / B）
static func owner_symbol(o: CellOwner) -> String:
	match o:
		CellOwner.NEUTRAL:
			return "·"
		CellOwner.PLAYER_A:
			return "A"
		CellOwner.PLAYER_B:
			return "B"
	return "?"

## 返回对手的归属枚举（甲↔乙，中立返回中立）
static func opponent(o: CellOwner) -> CellOwner:
	match o:
		CellOwner.PLAYER_A:
			return CellOwner.PLAYER_B
		CellOwner.PLAYER_B:
			return CellOwner.PLAYER_A
	return CellOwner.NEUTRAL
