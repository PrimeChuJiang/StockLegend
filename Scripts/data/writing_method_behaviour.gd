class_name WritingMethodBehaviour
extends ItemBehaviourData

## 效果类型（ArticleSystem 按此分类）
@export var effect_type: Enums.MethodEffectType
## 效果数值
@export var value: float = 0.0

## 覆盖 use_item（此处不使用，效果由ArticleSystem读取behaviour数据后执行）
func use_item(item: Item, _from: Node, _to: Node, _num: int) -> Variant:
	push_error("WritingMethodBehaviour: 请通过 ArticleSystem.apply_method() 触发效果，而非直接调用 use_item")
	return null
