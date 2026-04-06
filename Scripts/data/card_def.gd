class_name CardDef
extends Resource

@export var card_id: StringName
@export var card_name: String
@export var shape: CardShape
## 特殊效果预留接口，空字符串表示普通卡牌
@export var effect_id: StringName = &""

func brief() -> String:
	var cell_count := shape.get_cell_count() if shape else 0
	return "%s(%d格)" % [card_name, cell_count]

static func create(id: StringName, p_name: String, p_shape: CardShape, p_effect: StringName = &"") -> CardDef:
	var def := CardDef.new()
	def.card_id = id
	def.card_name = p_name
	def.shape = p_shape
	def.effect_id = p_effect
	return def
