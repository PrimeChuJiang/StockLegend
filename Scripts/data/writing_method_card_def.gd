## 写作方法卡片定义，继承自插件的 ItemData。
## behaviours 数组挂载若干 WritingMethodBehaviour 资源，每个描述一条效果。
## id / name / description / tags 使用 ItemData 已有字段，tags 包含 Card.WritingMethod.* 标签。
class_name WritingMethodCardData
extends ItemData

## 卡牌稀有度
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

## 返回类型化的写作方法效果列表，过滤掉非 WritingMethodBehaviour 的条目。
func get_writing_behaviours() -> Array[WritingMethodBehaviour]:
	var result: Array[WritingMethodBehaviour] = []
	for b in behaviours:
		if b is WritingMethodBehaviour:
			result.append(b as WritingMethodBehaviour)
	return result
