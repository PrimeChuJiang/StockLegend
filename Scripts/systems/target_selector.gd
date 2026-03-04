## 目标选择器，为指向性卡牌提供目标选择逻辑。
## 采用策略模式：默认自动选择第一个候选目标，可通过设置 select_callback 替换为 UI 交互选择。
class_name TargetSelector
extends RefCounted

## 外部目标选择回调。签名: (card: CardItem, target_type: Enums.TargetType, candidates: Array) -> Variant
## 设置此回调后，单目标选择将交由外部处理（如 UI 让玩家点选目标）。
var select_callback: Callable = Callable()


## 根据目标类型从候选列表中选择目标。
## NONE → null，SELF → 卡牌自身，ALL_* → 返回整个候选列表，
## SINGLE_* → 若有 select_callback 则调用回调（支持 await），否则自动选择第一个候选。
func select_target(card: CardItem, target_type: Enums.TargetType, candidates: Array) -> Variant:
	if target_type == Enums.TargetType.NONE:
		return null
	if target_type == Enums.TargetType.SELF:
		return card
	if target_type in [Enums.TargetType.ALL_ENEMIES, Enums.TargetType.ALL_ALLIES]:
		return candidates

	if select_callback.is_valid():
		return await select_callback.call(card, target_type, candidates)
	return candidates[0] if not candidates.is_empty() else null
