## 文章运行时对象，由 ArticleSystem.compose() 生成。
## 记录参与合成的数据引用，以及计算后的最终属性。
class_name Article
extends RefCounted

## 唯一 ID，格式为 article_{turn}_{index}
var article_id: StringName

## 参与合成的素材卡数据列表（数据引用，非运行时卡牌实例）
var material_cards: Array[MaterialCardData] = []
## 参与合成的写作方法卡数据列表
var method_cards: Array[WritingMethodCardData] = []

## ── 合成计算结果 ──────────────────────────────────────────────────────

## 文章类型（由素材类型组合决定）
var article_type: Enums.ArticleType = Enums.ArticleType.GENERAL
## 最终可信度：已发表后情绪效果持续的回合数
var final_credibility: int = 0
## 最终影响力：情绪效果的强度
var final_impact: int = 0
## 立场方向：BULLISH / BEARISH / NEUTRAL
var direction: Enums.Bias = Enums.Bias.NEUTRAL
## 目标行业（可为 null，由素材的 industry 标签决定）
var target_industry: Tag = null
## 目标股票列表（空数组表示不针对特定股票）
var target_stock_ids: Array[StringName] = []

## ── 生命周期状态 ──────────────────────────────────────────────────────

## 发表渠道（发表时设置）
var channel: Enums.Channel
## 是否已发表
var is_published: bool = false
## 发表时的回合编号
var publish_turn: int = -1
## 草稿新鲜度：每个结算阶段 -1，归零时草稿过期作废
var freshness: int = 3
## 是否已被打假核实
var is_busted: bool = false

## 返回用于 UI 或日志展示的简要描述。
func get_summary() -> String:
	var type_name: String = Enums.ArticleType.keys()[article_type]
	var dir_name: String = Enums.Bias.keys()[direction]
	return "[%s] %s | 影响力:%d 可信度:%d" % [type_name, dir_name, final_impact, final_credibility]
