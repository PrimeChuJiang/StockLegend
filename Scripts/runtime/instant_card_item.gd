## 瞬发卡牌：可在任意阶段打出的即时响应牌，结算后进入弃牌堆。
class_name InstantCardItem
extends CardItem


## 瞬发卡牌不受阶段限制，任意阶段均可打出。
func can_play_at_phase(_phase: Enums.Phase) -> bool:
	return true


## 执行出牌逻辑。
## TODO: 接入 EffectResolver 和 ZoneManager 后实现完整逻辑。
func execute(_ctx: Dictionary) -> void:
	print("[InstantCardItem] '%s' 执行出牌（TODO: 接入效果结算与区域移动）" % data.name)
