## 场地卡牌：持续性环境牌。打出后放置到场地持续存在，每回合结束时触发 ON_TURN_END 效果。
class_name FieldCardItem
extends CardItem


## 场地卡牌只能在主阶段打出。
func can_play_at_phase(phase: Enums.Phase) -> bool:
	return phase == Enums.Phase.MAIN


## 执行出牌逻辑。
## TODO: 接入 EffectResolver 和 ZoneManager 后实现完整逻辑。
func execute(_ctx: Dictionary) -> void:
	print("[FieldCardItem] '%s' 执行出牌（TODO: 接入效果结算与区域移动）" % data.name)
