## 素材运行时卡牌
class_name MaterialCard
extends Item

## 运行时 bias 覆盖(用于[春秋笔法]等效果，false 表示不覆盖)
var _bias_reversed : bool = false

## 获取实际生效的倾向
func get_effective_bias() -> Enums.Bias:
	var base_bias := (data as MaterialCardData).bias
	if not _bias_reversed:
		return base_bias
	match base_bias:
		Enums.Bias.BULLISH: return Enums.Bias.BERISH
		Enums.Bias.BERISH: return Enums.Bias.BULLISH
		_ : return Enums.Bias.NEUTRAL

## 反转倾向(用于[春秋笔法]等效果)
func reverse_bias() -> void:
	_bias_reversed = not _bias_reversed

## 快捷访问类型化数据
func get_card_data() -> MaterialCardData:
	return data as MaterialCardData