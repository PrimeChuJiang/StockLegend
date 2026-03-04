## 普通卡牌：一次性效果牌。仅在主阶段可打出，立即结算后进入弃牌堆。
class_name NormalCardItem
extends CardItem


## 普通卡牌只能在主阶段（MAIN）打出。
func can_play_at_phase(phase: Enums.Phase) -> bool:
	return phase == Enums.Phase.MAIN


## 执行出牌：结算所有 ON_PLAY 触发的效果，然后将卡牌移至弃牌堆。
func execute(ctx: Dictionary) -> void:
	var resolver: EffectResolver = ctx.get("effect_resolver")
	var zone_mgr: CardZoneManager = ctx.get("zone_manager")
	resolver.resolve_effects(self, Enums.EffectTrigger.ON_PLAY, ctx)
	zone_mgr.move_card(self, Enums.Zone.DISCARD)
