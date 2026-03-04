## 场地卡牌：持续性环境牌。打出后放置到场地持续存在，
## 提供 buff/debuff 效果，每回合结束时由 TurnSystem 统一触发 ON_TURN_END 效果。
class_name FieldCardItem
extends CardItem


## 场地卡牌只能在主阶段（MAIN）打出。
func can_play_at_phase(phase: Enums.Phase) -> bool:
	return phase == Enums.Phase.MAIN


## 执行出牌：先将卡牌移至场地区域，然后结算 ON_FIELD_ENTER 触发的效果。
## ON_TURN_END 效果不在此处触发，而是由 TurnSystem._resolve_field_effects() 在回合结束时统一处理。
func execute(ctx: Dictionary) -> void:
	var resolver: EffectResolver = ctx.get("effect_resolver")
	var zone_mgr: CardZoneManager = ctx.get("zone_manager")
	zone_mgr.move_card(self, Enums.Zone.FIELD)
	resolver.resolve_effects(self, Enums.EffectTrigger.ON_FIELD_ENTER, ctx)
