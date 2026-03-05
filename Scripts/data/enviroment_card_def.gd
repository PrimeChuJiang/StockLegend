## 环境卡牌定义，继承自插件的 ItemData
## 注意：
## - tier（MACRO/INDUSTRY/COMPANY）通过 tags 中的 Event.* 标签表达
## - target_industry 通过 tags 中的 Industry.* 标签表达
## - id / name / description 使用 ItemData 已有字段
class_name EnviromentCardData
extends ItemData

## 日程表内显示的名字
@export var preview_name : String = ""
## 目标股票，当tier值为COMPANY时使用
@export var target_company : StringName = &""
## 情感修饰符，值为正表示利好，值为负表示利空
@export var sentiment_modifier : int
## 持续回合数
@export var duration : int
## 环境牌来源
@export var source_type : Enums.EventSourceType
## 是否可被引用为临时素材卡
@export var can_be_referenced : bool