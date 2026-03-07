## 文章合成系统，纯静态工具类，负责将素材卡 + 写作方法卡合成为一篇 Article。
##
## 合成流程：
##   1. 根据素材卡的 MaterialType 组合确定 ArticleType
##   2. 按素材卡的 bias 多数票确定文章立场（direction）
##   3. 累加素材卡的 impact / credibility 作为基础数值
##   4. 依次应用写作方法卡的每条 WritingMethodBehaviour 效果
##   5. 钳位数值（impact >= 0，credibility >= 1）
##
## 使用方式：
##   var article := ArticleSystem.compose(materials, methods, turn_number, index)
class_name ArticleSystem

## 将素材卡和写作方法卡合成为一篇文章。
## materials : 参与合成的素材卡数据列表（至少 1 张）
## methods   : 参与合成的写作方法卡数据列表（可为空）
## turn      : 当前回合编号，用于生成唯一 ID
## index     : 当回合内的文章序号，用于生成唯一 ID
static func compose(
	materials: Array[MaterialCardData],
	methods: Array[WritingMethodCardData],
	turn: int,
	index: int
) -> Article:
	var article := Article.new()
	article.article_id = "article_%d_%d" % [turn, index]
	article.material_cards = materials
	article.method_cards = methods

	## 步骤 1：素材决定基础属性
	article.article_type = _determine_type(materials)
	article.direction = _determine_direction(materials)
	article.final_impact = _sum_impact(materials)
	article.final_credibility = _sum_credibility(materials)

	## 步骤 2：应用所有写作方法效果
	for method in methods:
		_apply_method(article, method)

	## 步骤 3：钳位，保证数值合理
	article.final_impact = maxi(article.final_impact, 0)
	article.final_credibility = maxi(article.final_credibility, 1)

	return article

## ── 私有：属性计算 ────────────────────────────────────────────────────

## 根据素材类型组合判断文章类型。
## 规则（按优先级匹配）：
##   DATA×2 + OPINION×1 → RESEARCH_REPORT
##   EXPOSE + DATA       → INVESTIGATION
##   RUMOR  + EXPOSE     → EXCLUSIVE
##   RUMOR  × 2         → CONSPIRACY
##   EXPOSE × 2         → SERIAL_SCOOP
##   DATA   + OPINION   → EXPERT_COMMENT
##   OPINION× 2         → PUBLIC_OPINION
##   其他               → GENERAL
static func _determine_type(materials: Array[MaterialCardData]) -> Enums.ArticleType:
	var data_n    := _count_type(materials, Enums.MaterialType.DATA)
	var rumor_n   := _count_type(materials, Enums.MaterialType.RUMOR)
	var expose_n  := _count_type(materials, Enums.MaterialType.EXPOSE)
	var opinion_n := _count_type(materials, Enums.MaterialType.OPINION)

	if data_n >= 2 and opinion_n >= 1:
		return Enums.ArticleType.RESEARCH_REPORT
	if expose_n >= 1 and data_n >= 1:
		return Enums.ArticleType.INVESTIGATION
	if rumor_n >= 1 and expose_n >= 1:
		return Enums.ArticleType.EXCLUSIVE
	if rumor_n >= 2:
		return Enums.ArticleType.CONSPIRACY
	if expose_n >= 2:
		return Enums.ArticleType.SERIAL_SCOOP
	if data_n >= 1 and opinion_n >= 1:
		return Enums.ArticleType.EXPERT_COMMENT
	if opinion_n >= 2:
		return Enums.ArticleType.PUBLIC_OPINION
	return Enums.ArticleType.GENERAL

## 按多数票决定文章立场，平票时取 NEUTRAL。
static func _determine_direction(materials: Array[MaterialCardData]) -> Enums.Bias:
	var bullish := 0
	var bearish := 0
	for m in materials:
		match m.bias:
			Enums.Bias.BULLISH: bullish += 1
			Enums.Bias.BERISH:  bearish += 1
	if bullish > bearish: return Enums.Bias.BULLISH
	if bearish > bullish: return Enums.Bias.BERISH
	return Enums.Bias.NEUTRAL

## 累加所有素材的影响力。
static func _sum_impact(materials: Array[MaterialCardData]) -> int:
	var total := 0
	for m in materials:
		total += m.impact
	return total

## 累加所有素材的可信度。
static func _sum_credibility(materials: Array[MaterialCardData]) -> int:
	var total := 0
	for m in materials:
		total += m.credibility
	return total

## 统计素材列表中某个类型的数量。
static func _count_type(materials: Array[MaterialCardData], t: Enums.MaterialType) -> int:
	var count := 0
	for m in materials:
		if m.material_type == t:
			count += 1
	return count

## ── 私有：写作方法效果应用 ───────────────────────────────────────────

## 依次应用一张写作方法卡上所有 WritingMethodBehaviour 效果。
static func _apply_method(article: Article, method: WritingMethodCardData) -> void:
	for behaviour in method.get_writing_behaviours():
		_apply_behaviour(article, behaviour)

## 根据 MethodEffectType 修改文章属性。
static func _apply_behaviour(article: Article, b: WritingMethodBehaviour) -> void:
	match b.effect_type:
		Enums.MethodEffectType.IMPACT_ADD:
			article.final_impact += int(b.value)

		Enums.MethodEffectType.IMPACT_MULTIPLY:
			article.final_impact = int(article.final_impact * b.value)

		Enums.MethodEffectType.CREDIBILITY_ADD:
			article.final_credibility += int(b.value)

		Enums.MethodEffectType.CREDIBILITY_MULTIPLY:
			article.final_credibility = int(article.final_credibility * b.value)

		Enums.MethodEffectType.BIAS_REVERSE:
			match article.direction:
				Enums.Bias.BULLISH: article.direction = Enums.Bias.BERISH
				Enums.Bias.BERISH:  article.direction = Enums.Bias.BULLISH
				## NEUTRAL 不反转

		Enums.MethodEffectType.TYPE_CHANGE_TO_SCOOP:
			article.article_type = Enums.ArticleType.EXCLUSIVE

		Enums.MethodEffectType.DURATION_ADD:
			## 延长草稿有效期（freshness），而非已发表效果的持续回合
			article.freshness += int(b.value)

		Enums.MethodEffectType.AFFECT_WHOLE_INDUSTRY, \
		Enums.MethodEffectType.TARGETED_GATHER_FREE, \
		Enums.MethodEffectType.FACT_CHECK_PROB_ADD:
			## 这些效果影响发表或采集逻辑，在此阶段记录到 article.extra 或留待发表时处理
			## TODO: 在 publish 流程中读取 method_cards 处理这类效果
			pass
