## 股票的运行时类
class_name Stock
extends RefCounted

## 股票的定义数据
var def: StockData
## 股票当前价格
var current_price: float
## 股票历史价格（每回合结算时记录一次）
var price_history: Array[float] = []
## 是否退市
var is_delisted: bool = false
## 正在生效的情绪修改器列表
var _modifiers: Array[SentimentModifier] = []

## 初始化函数，接受一个 StockData 对象，设置初始价格和定义数据。
func _init(stock_def: StockData) -> void:
	def = stock_def
	current_price = stock_def.initial_price

## ── 情绪修改器 ──────────────────────────────────────────────────────────

## 计算当前情绪值（所有修改器的总和，钳制在 -10 ~ +10）
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
	_modifiers = _modifiers.filter(func(mod: SentimentModifier) -> bool:
		return mod.source_id != source_id)

## 获取所有情绪修改器信息，供 UI 显示
func get_modifiers() -> Array[SentimentModifier]:
	return _modifiers.duplicate()

## ── 价格修改器（立即生效） ──────────────────────────────────────────────

## 立即应用一个价格修改器，直接修改 current_price。
func apply_price_modifier(mod: PriceModifier) -> void:
	if is_delisted:
		return
	current_price = mod.apply(current_price)
	current_price = maxf(current_price, 0.0)

## 批量应用价格修改器（按 priority 排序后依次执行）。
func apply_price_modifiers(mods: Array[PriceModifier]) -> void:
	if is_delisted:
		return
	mods.sort_custom(func(a: PriceModifier, b: PriceModifier) -> bool:
		return a.priority < b.priority)
	for mod in mods:
		current_price = mod.apply(current_price)
	current_price = maxf(current_price, 0.0)

## ── 回合尾结算 ──────────────────────────────────────────────────────────

## tick 所有情绪修改器，移除过期的
func tick_modifiers() -> void:
	var expired: Array[SentimentModifier] = []
	for mod in _modifiers:
		if mod.tick():
			expired.append(mod)
	for mod in expired:
		_modifiers.erase(mod)

## 按当前情绪值更新股价（回合尾结算时调用）。
## 记录变动前价格到历史，然后按 情绪 × 波动系数 计算价格变动。
func apply_price_change() -> void:
	if is_delisted:
		return
	price_history.append(current_price)
	var delta := get_sentiment() * def.get_volatility_coefficient()
	current_price += delta
	current_price = maxf(current_price, 0.0)

## 检查是否触发退市
func should_delist() -> bool:
	return current_price <= def.get_delisting_threshold() and not is_delisted
