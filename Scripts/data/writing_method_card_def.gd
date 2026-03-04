## 写作方法卡片定义，继承自插件的 ItemData
## 复用 ItemData 的 id、name、tags、description、image、max_stack、behaviours。
class_name WritingMethodCardData
extends ItemData

## 卡牌稀有度
@export var rarity : Enums.Rarity
## 效果参数
## 效果参数字典，键名统一定义：
## impact_add, impact_mul, credibility_add, credibility_mul,
## fact_check_prob_add, duration_add,
## reverses_one_bias (bool), changes_type_to_scoop (bool),
## affects_whole_industry (bool), targeted_gather_free (bool),
## etc. 具体使用哪些参数由卡牌效果定义决定
@export var effect_params: Dictionary
