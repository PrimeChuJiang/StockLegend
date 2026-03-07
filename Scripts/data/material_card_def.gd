## 素材卡定义，继承自插件的 ItemData
## 注意：
## - id / name / description 使用 ItemData 已有字段
## - tags 使用 ItemData.tags（Array[Tag]）：包含 Card.Material.* 和 Industry.* 两类标签
## - max_stack 设为 1（素材卡不堆叠）
## - behaviours 留空（素材卡无主动 behaviour，行为由 ArticleSystem 驱动）
class_name MaterialCardData
extends ItemData

## 素材类型，决定参与合成时的文章类型组合
@export var material_type: Enums.MaterialType = Enums.MaterialType.DATA
## 卡片稀有度
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
## 影响层级：宏观 / 行业 / 公司
@export var event_tier: Enums.EventTier = Enums.EventTier.INDUSTRY
## 行业标签
@export var industry: Tag
## 倾向（看涨 / 看跌 / 中性）
@export var bias: Enums.Bias = Enums.Bias.NEUTRAL
## 基础可信度（1~5），决定已发表文章的情绪效果持续回合数
@export var credibility: int = 2
## 基础影响力（1~5），决定已发表文章对股价的情绪强度
@export var impact: int = 2
