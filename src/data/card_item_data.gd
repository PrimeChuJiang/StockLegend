## 卡牌数据定义，继承插件的 ItemData，添加卡牌特有字段。
## 复用 ItemData 的 id、name、tags、description、image、max_stack、behaviours。
## 卡牌的 max_stack 应固定为 1（每张卡牌是唯一实例）。
class_name CardItemData
extends ItemData

## 卡牌类型，决定运行时创建的子类
@export var card_type: Enums.CardType
## 基础属性字典，键为 Enums.StatKey，值为 int
@export var base_stats: Dictionary = {}
## 该卡牌携带的效果定义列表
@export var effects: Array[EffectDef] = []
## 目标选择类型，NONE 表示无需选择目标
@export var target_type: Enums.TargetType = Enums.TargetType.NONE
