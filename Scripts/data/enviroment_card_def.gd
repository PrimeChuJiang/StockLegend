## 环境卡牌定义，继承自插件的 ItemData
## 复用 ItemData 的 id、name、tags、description、image、max_stack、behaviours。
class_name EnviromentCardData
extends ItemData

## 日程表内显示的名字
@export var preview_name : String
## 环境牌影响层级：宏观 / 产业 / 公司
@export var tier : Enums.EventTier
## 目标行业类型，当tier值为INDUSTRY时使用
@export var target_industry : Tag
## 目标股票，当tier值为COMPANY时使用
@export var target_company : int 
## 情感修饰符，值为正表示利好，值为负表示利空
@export var sentiment_modifier : int
## 持续回合数
@export var duration : int
## 环境牌来源
@export var sourec_type : Enums.EventScoureType
## 是否可被引用为临时数据卡
@export var can_be_referenced : bool