## 卡牌定义 v5
## 一张卡牌 = 形状模板 + 可选特殊效果。
## 作为 Resource 存储在牌堆中，运行时通过引用传递。
class_name CardDef
extends Resource

@export var card_id: StringName       ## 唯一标识符，如 &"card_0"
@export var card_name: String         ## 显示名称，如 "T形"、"十字"
@export var shape: CardShape          ## 关联的形状模板
## 特殊效果标识（预留接口），空字符串 = 普通卡牌
## 未来可对接效果系统，通过 effect_id 查找对应逻辑
@export var effect_id: StringName = &""

## 返回简短描述，如 "T形(4格)"，用于日志输出
func brief() -> String:
	var cell_count := shape.get_cell_count() if shape else 0
	return "%s(%d格)" % [card_name, cell_count]

## 工厂方法：快速创建卡牌定义
static func create(id: StringName, p_name: String, p_shape: CardShape, p_effect: StringName = &"") -> CardDef:
	var def := CardDef.new()
	def.card_id = id
	def.card_name = p_name
	def.shape = p_shape
	def.effect_id = p_effect
	return def
