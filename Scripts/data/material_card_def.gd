## 素材卡定义，继承自插件的 ItemData
## 注意：
## - id / name / description 使用 ItemData 已有字段
## - tags 使用 ItemData.tags（Array[Tag]）：包含 Card.Material.* 和 Industry.* 两类标签
## - max_stack 设为 1（素材卡不堆叠）
## - behaviours 留空（素材卡无主动 behaviour，行为由 ArticleSystem 驱动）
class_name MaterialCardData
extends ItemData

## 卡片稀有度
@export var rarity : Enums.Rarity
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

