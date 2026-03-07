## 情绪修改器
class_name SentimentModifier
extends RefCounted

## 文章牌ID或环境牌ID
var source_id: StringName
## 修改器来源类型：`"article"` 或 `"enviroment"`
var source_type : String
## 所有目标股票
var target_stock_ids : Array[StringName]
## 修改值
var value : int
## 剩余持续回合数
var remaining_turns : int

## 工厂方法：从文章创建修改器
static func from_article(article: Article) -> SentimentModifier:
	var mod := SentimentModifier.new()
	mod.source_id = article.article_id
	mod.source_type = "article"
	mod.target_stock_ids = article.target_stock_ids
	mod.value = article.final_impact*(1 if article.direction == Enums.Bias.BULLISH else -1)
	mod.remaining_turns = article.final_credibility
	return mod

## 工厂方法：从环境牌创建修改器
static func from_enviroment(env_def: EnviromentCardData, stock_ids: Array[StringName]) -> SentimentModifier:
	var mod := SentimentModifier.new()
	mod.source_id = env_def.id
	mod.source_type = "enviroment"
	mod.target_stock_ids = stock_ids
	mod.value = env_def.sentiment_modifier
	mod.remaining_turns = env_def.duration
	return mod

## SETTLEMENT阶段调用，返回true表示已过期
func tick() -> bool:
	remaining_turns -= 1
	return remaining_turns <= 0