## 瞬发卡牌：可在任意阶段打出的即时响应牌，结算后进入弃牌堆。
class_name InstantCardItem
extends CardItem


## 瞬发卡牌不受阶段限制，任意阶段均可打出。
func can_play_at_phase(_phase: Enums.Phase) -> bool:
	return true


## 执行出牌：立即结算所有 ON_PLAY 触发的效果，然后将卡牌移至弃牌堆。
func execute(ctx: Dictionary) -> void:
	var resolver: EffectResolver = ctx.get("effect_resolver")
	var zone_mgr: CardZoneManager = ctx.get("zone_manager")
	resolver.resolve_effects(self, Enums.EffectTrigger.ON_PLAY, ctx)
	zone_mgr.move_card(self, Enums.Zone.DISCARD)
