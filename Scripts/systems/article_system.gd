## 文章效果执行系统
class_name ArticleSystem
extends Node

## 将写作方法应用到文章
func apply_method_to_article(method_card: WritingMethodCard, article: Article) -> void:
	for behaviour in method_card.data.behaviours:
		if not behaviour is WritingMethodBehaviour:
			continue
		var b := behaviour as WritingMethodBehaviour
		match b.effect_type:
			Enums.MethodEffectType.IMPACT_ADD:
				article.final_impact += int(b.value)
			Enums.MethodEffectType.CREDIBILITY_ADD:
				article.final_credibility += int(b.value)
			Enums.MethodEffectType.BIAS_REVERSE:
				# 反转文章中第一张素材卡的倾向
				if article.material_cards.size() > 0:
					article.material_cards[0].reverse_bias()
            # ... 更多效果
	method_card.use()