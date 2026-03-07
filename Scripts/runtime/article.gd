## 文章类，为运行时对象，
class_name Article
extends RefCounted

## 唯一ID，在发表时生成，格式为`article_{turn}_{index}`
var article_id: StringName

## 组成材料
var material_cards: Array[MaterialCard] = []
var method_cards: Array[WritingMethodCard] = []

## 计算后的属性
var article_type: Enums.ArticleType = Enums.ArticleType.GENERAL
var final_credibility: int = 0
var final_impact: int = 0
var direction: Enums.Bias = Enums.Bias.NEUTRAL
var target_industry: Tag
## 目标股票列表，空数组表示无具体股票目标（如病毒传播效果）
var target_stock_ids: Array[StringName] = []

## 发表相关
## 发表渠道
var channel: Enums.Channel
## 是否已经被发表
var is_published: bool = false
## 已经发表的回合数
var publish_turn: int = -1

## 草稿新鲜度(每个 SETTLEMENT 阶段 -1，归零时废稿)
var freshness: int = 3

## 是否被打假
var is_busted: bool = false
