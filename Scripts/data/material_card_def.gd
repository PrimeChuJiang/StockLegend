## 素材卡定义，继承自插件的 ItemData
## 复用 ItemData 的 id、name、tags、description、image、max_stack、behaviours。
class_name MaterialCardData
extends ItemData

## 卡片稀有度
@export var rarity : Enums.Rarity
## 素材卡片类型
@export var material_type : Enums.MaterialType
## 行业范围
@export var event_tier : Enums.EventTier
## 行业标签
@export var industry : Tag
## 倾向
@export var bias : Enums.Bias
## 卡片自带可行度，取值范围1~5
@export var credibility : int
## 卡片自带影响力，取值范围1~5
@export var impact : int