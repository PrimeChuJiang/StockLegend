class_name WritingMethodBehaviour
extends ItemBehaviourData

## 效果类型（ArticleSystem 按此分类）
@export var effect_type: Enums.MethodEffectType
## 效果数值
@export var value: float = 0.0
## 效果名称
@export var effect_name: String = ""
## 效果描述
@export var effect_discription: String = ""

## 覆盖 use_item（此处不使用，效果由ArticleSystem读取behaviour数据后执行）
func use_item(item: Item, _from: Node, _to: Node, _num: int) -> Variant:
	push_error("WritingMethodBehaviour: 请通过 ArticleSystem.apply_method() 触发效果，而非直接调用 use_item")
	return null

## 获取当前效果名称
func get_effect_name() -> String:
	return effect_name

## 获取当前效果描述
func get_effect_discription() -> String:
	return effect_discription