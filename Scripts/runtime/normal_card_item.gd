## 普通卡牌：一次性效果牌。仅在主阶段可打出，立即结算后进入弃牌堆。
class_name NormalCardItem
extends CardItem


## 普通卡牌只能在主阶段打出。
func can_play_at_phase(phase: Enums.Phase) -> bool:
	return phase == Enums.Phase.MAIN


## 执行出牌逻辑。
## TODO: 接入 EffectResolver 和 ZoneManager 后实现完整逻辑。
func execute(_ctx: Dictionary) -> void:
	print("[NormalCardItem] '%s' 执行出牌（TODO: 接入效果结算与区域移动）" % data.name)
