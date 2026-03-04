## 股票的运行时类
class_name Stock
extends RefCounted

## 股票的定义数据
var def: StockData
## 股票当前价格
var current_price: float
## 股票历史价格
var price_history: Array[float] = []
## 是否退市
var is_delisted: bool = false
## 正在生效的修改器列表
var _modifiers: Array[SentimentModifier] = []

## 初始化函数，接受一个 StockData 对象，设置初始价格和定义数据。
func _init(stock_def: StockData) -> void:
	def = stock_def
	current_price = stock_def.initial_price

## 计算当前情绪值
func get_sentiment() -> int:
	var total := 0
	for mod in _modifiers:
		total += mod.value
	return clampi(total, -10, 10)

## 添加情绪修改器
func add_modifier(mod: SentimentModifier) -> void:
	_modifiers.append(mod)

## 移除指定来源的修改器
func remove_modifier_by_source(source_id: StringName) -> void:
	_modifiers = _modifiers.filter(judge_mod_from_source.bind(source_id))
func judge_mod_from_source(mod: SentimentModifier, source_id: StringName) -> bool:
	return mod.source_id == source_id

## SETTLEMENT 阶段：tick所有的修改器，移除过期的
func tick_modifiers() -> void:
	var expired: Array[SentimentModifier] = []
	for mod in _modifiers:
		if mod.tick():
			expired.append(mod)
		for expired_mod in expired:
			_modifiers.erase(expired_mod)

## MARKET_REACT阶段：按当前情绪更新股价
func apply_price_change() -> void:
	if is_delisted: return
	var delta := get_sentiment() * def.get_volatility_coefficient()
	price_history.append(current_price)
	current_price += delta
	current_price = maxf(current_price, 0.0)

## 检查是否触发退市
func should_delist() -> bool:
	return current_price <= def.get_delisting_threshold() and not is_delisted

## 获取所有的修改器信息，供UI显示
func get_modifiers() -> Array[SentimentModifier]:
	return _modifiers.duplicate()