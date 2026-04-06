## 全局枚举定义 v5：竞选大师（涂地版）
class_name Enums

enum CellOwner { NEUTRAL = 0, PLAYER_A = 1, PLAYER_B = 2 }

static func owner_name(o: CellOwner) -> String:
	match o:
		CellOwner.NEUTRAL:
			return "中立"
		CellOwner.PLAYER_A:
			return "甲方"
		CellOwner.PLAYER_B:
			return "乙方"
	return "?"

static func owner_symbol(o: CellOwner) -> String:
	match o:
		CellOwner.NEUTRAL:
			return "·"
		CellOwner.PLAYER_A:
			return "A"
		CellOwner.PLAYER_B:
			return "B"
	return "?"

static func opponent(o: CellOwner) -> CellOwner:
	match o:
		CellOwner.PLAYER_A:
			return CellOwner.PLAYER_B
		CellOwner.PLAYER_B:
			return CellOwner.PLAYER_A
	return CellOwner.NEUTRAL
