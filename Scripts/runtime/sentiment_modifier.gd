## 情绪修改器（持久性，回合尾 tick）。
##
## 目标分发规则（由 StockManager 解析）：
##   target_stock_ids 非空 → 公司级，只影响指定股票
##   target_industry  非空 → 行业级，影响该行业所有股票
##   两者都空             → 宏观级，影响所有股票
class_name SentimentModifier
extends RefCounted

## 文章牌ID或环境牌ID
var source_id: StringName
## 修改器来源类型：&"article" / &"environment"
var source_type: StringName
## 目标股票 ID（公司级定位）
var target_stock_ids: Array[StringName]
## 目标行业标签（行业级定位，null 表示不按行业）
var target_industry: Tag
## 修改值
var value: int
## 剩余持续回合数
var remaining_turns: int

## 工厂方法：从文章创建修改器。
## 文章的 target_stock_ids 和 target_industry 会同时传递，
## StockManager 按优先级解析实际影响范围。
static func from_article(article: Article) -> SentimentModifier:
	var mod := SentimentModifier.new()
	mod.source_id = article.article_id
	mod.source_type = &"article"
	mod.target_stock_ids = article.target_stock_ids
	mod.target_industry = article.target_industry
	mod.value = article.final_impact * (1 if article.direction == Enums.Bias.BULLISH else -1)
	mod.remaining_turns = article.final_credibility
	return mod

## 工厂方法：从环境牌创建修改器。
## 根据环境牌的 EventTier 自动设置目标范围：
##   COMPANY  → target_stock_ids = [target_company]
##   INDUSTRY → target_industry = 环境牌的行业标签
##   MACRO    → 两者都空，影响全部股票
static func from_environment(env_def: EnviromentCardData) -> SentimentModifier:
	var mod := SentimentModifier.new()
	mod.source_id = env_def.id
	mod.source_type = &"environment"
	mod.value = env_def.sentiment_modifier
	mod.remaining_turns = env_def.duration

	## 根据标签判断影响层级
	var tier := _resolve_tier(env_def)
	match tier:
		Enums.EventTier.COMPANY:
			if env_def.target_company != &"":
				mod.target_stock_ids = [env_def.target_company]
		Enums.EventTier.INDUSTRY:
			mod.target_industry = _resolve_industry_tag(env_def)
		Enums.EventTier.MACRO:
			pass  ## 两者都空 → 宏观级
	return mod

## 从环境牌的 tags 中解析 EventTier。
static func _resolve_tier(env_def: EnviromentCardData) -> Enums.EventTier:
	if env_def.target_company != &"":
		return Enums.EventTier.COMPANY
	if _resolve_industry_tag(env_def) != null:
		return Enums.EventTier.INDUSTRY
	return Enums.EventTier.MACRO

## 从环境牌的 tags 中提取行业标签（约定行业标签路径以 "Industry" 开头）。
## 例如 tag_path = "Industry.Tech" 会匹配。
static func _resolve_industry_tag(env_def: EnviromentCardData) -> Tag:
	for tag: Tag in env_def.tags:
		if tag.matches_tag_path("Industry"):
			return tag
	return null

## 创建一份独立副本（用于多股票分发，避免共享同一实例）。
func clone() -> SentimentModifier:
	var copy := SentimentModifier.new()
	copy.source_id = source_id
	copy.source_type = source_type
	copy.target_stock_ids = target_stock_ids
	copy.target_industry = target_industry
	copy.value = value
	copy.remaining_turns = remaining_turns
	return copy

## SETTLEMENT 阶段调用，返回 true 表示已过期。
func tick() -> bool:
	remaining_turns -= 1
	return remaining_turns <= 0