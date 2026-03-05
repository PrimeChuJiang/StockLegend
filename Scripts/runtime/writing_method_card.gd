## 写作方法运行时卡牌
class_name WritingMethodCard
extends Item

## 是否处于冷却时间
var is_on_cooldown: bool = false

## 使用次方法卡
func use() -> void:
	is_on_cooldown = true

## SETTLEMENT 阶段调用，重置冷却时间
func tick_cooldown() -> void:
	is_on_cooldown = false

## 查看是否可用
func is_available() -> bool:
	return not is_on_cooldown

## 快捷访问类型化数据
func get_card_data() -> WritingMethodCardData:
	return data as WritingMethodCardData