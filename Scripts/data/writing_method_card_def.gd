## 写作方法卡片定义，继承自插件的 ItemData
## 注意：
## - behaviours 数组挂载若干 WritingMethodBehaviour 资源
## - id / name / description / tags 使用 ItemData 已有字段
## - tags 包含 Card.WritingMethod.* 标签
## - max_stack 设为 1
class_name WritingMethodCardData
extends ItemData

## 卡牌稀有度
@export var rarity : Enums.Rarity = Enums.Rarity.COMMON

