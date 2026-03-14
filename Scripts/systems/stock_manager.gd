## 股票管理器（AutoLoad），管理所有 Stock 实例的注册、查询、修改器分发与结算。
## UI 层可通过 StockManager.get_stock() / get_all_stocks() 随时访问股票数据。
##
## 修改器目标分发规则：
##   target_stock_ids 非空 → 公司级，只影响指定股票
##   target_industry  非空 → 行业级，影响该行业所有股票
##   两者都空             → 宏观级，影响所有股票
extends Node

## 所有已注册股票 {stock_id: StringName -> Stock}
var _stocks: Dictionary = {}

## ── 注册 / 查询 ────────────────────────────────────────────────────────

## 注册一只股票，返回创建的 Stock 运行时实例。
func register_stock(stock_def: StockData) -> Stock:
	var stock := Stock.new(stock_def)
	_stocks[stock_def.id] = stock
	return stock

## 按 ID 查询股票，不存在时返回 null。
func get_stock(stock_id: StringName) -> Stock:
	return _stocks.get(stock_id)

## 获取所有股票的数组副本。
func get_all_stocks() -> Array[Stock]:
	var result: Array[Stock] = []
	for stock: Stock in _stocks.values():
		result.append(stock)
	return result

## 获取所有股票 ID。
func get_stock_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _stocks.keys():
		ids.append(id)
	return ids

## 获取指定行业的所有股票（支持层级匹配）。
## 例如传入 "Industry.Tech"，会匹配 "Industry.Tech" 和 "Industry.Tech.AI" 等子标签。
func get_stocks_by_industry(industry: Tag) -> Array[Stock]:
	var result: Array[Stock] = []
	for stock: Stock in _stocks.values():
		if stock.def.industry and stock.def.industry.matches_tag(industry):
			result.append(stock)
	return result

## ── 目标解析 ────────────────────────────────────────────────────────────

## 根据修改器的目标字段解析实际影响的股票 ID 列表。
## 优先级：target_stock_ids > target_industry > 全部（宏观）
func _resolve_sentiment_targets(mod: SentimentModifier) -> Array[StringName]:
	if not mod.target_stock_ids.is_empty():
		return mod.target_stock_ids
	if mod.target_industry != null:
		return _get_ids_by_industry(mod.target_industry)
	return get_stock_ids()

func _resolve_price_targets(mod: PriceModifier) -> Array[StringName]:
	if not mod.target_stock_ids.is_empty():
		return mod.target_stock_ids
	if mod.target_industry != null:
		return _get_ids_by_industry(mod.target_industry)
	return get_stock_ids()

func _get_ids_by_industry(industry: Tag) -> Array[StringName]:
	var ids: Array[StringName] = []
	for stock_id: StringName in _stocks:
		var stock: Stock = _stocks[stock_id]
		if stock.def.industry and stock.def.industry.matches_tag(industry):
			ids.append(stock_id)
	return ids

## ── 修改器分发 ──────────────────────────────────────────────────────────

## 分发情绪修改器（持久性，回合尾 tick）。
## 自动按目标规则解析影响范围：公司级 / 行业级 / 宏观级。
func apply_sentiment_modifier(mod: SentimentModifier) -> void:
	var target_ids := _resolve_sentiment_targets(mod)
	for stock_id in target_ids:
		var stock := get_stock(stock_id)
		if stock and not stock.is_delisted:
			## 每只股票持有独立副本，避免共享 remaining_turns 导致多次 tick
			var stock_mod := mod.clone()
			stock.add_modifier(stock_mod)
			GameBus.sentiment_modifier_applied.emit(stock_id, stock_mod)
			if _is_network_server():
				_sync_sentiment_modifier_applied.rpc(
					stock_id, stock_mod.source_id, stock_mod.value, stock_mod.remaining_turns)
			print("[StockManager] 情绪修改器 → %s | 来源: %s | 值: %+d | 持续: %d 回合" % [
				stock_id, stock_mod.source_id, stock_mod.value, stock_mod.remaining_turns])

## 分发价格修改器（立即生效，一次性）。
## 自动按目标规则解析影响范围：公司级 / 行业级 / 宏观级。
func apply_price_modifier(mod: PriceModifier) -> void:
	var target_ids := _resolve_price_targets(mod)
	for stock_id in target_ids:
		var stock := get_stock(stock_id)
		if stock and not stock.is_delisted:
			var old_price := stock.current_price
			stock.apply_price_modifier(mod)
			if stock.current_price != old_price:
				GameBus.stock_price_changed.emit(stock_id, old_price, stock.current_price)
				if _is_network_server():
					_sync_stock_price_changed.rpc(stock_id, old_price, stock.current_price)
			print("[StockManager] 价格修改器 → %s | %s(%s) | %.2f → %.2f" % [
				stock_id, mod.op, mod.value, old_price, stock.current_price])

## 批量应用价格修改器（按 priority 排序后依次执行）。
func apply_price_modifiers_batch(mods: Array[PriceModifier]) -> void:
	mods.sort_custom(func(a: PriceModifier, b: PriceModifier) -> bool:
		return a.priority < b.priority)
	for mod in mods:
		apply_price_modifier(mod)

## ── 回合尾结算 ──────────────────────────────────────────────────────────

## 结算所有股票：tick 情绪修改器 → 按情绪计算价格变动 → 检查退市。
## 由 WorldEndActor 在 RESOLVE_PRICE 阶段调用。
func settle_turn() -> void:
	for stock_id: StringName in _stocks:
		var stock: Stock = _stocks[stock_id]
		if stock.is_delisted:
			continue

		## 1. tick 情绪修改器，移除过期的
		stock.tick_modifiers()

		## 2. 按当前情绪总值计算价格变动
		var old_price := stock.current_price
		stock.apply_price_change()

		if stock.current_price != old_price:
			GameBus.stock_price_changed.emit(stock_id, old_price, stock.current_price)
			if _is_network_server():
				_sync_stock_price_changed.rpc(stock_id, old_price, stock.current_price)
			print("[StockManager] 结算 %s | 情绪: %+d | %.2f → %.2f" % [
				stock_id, stock.get_sentiment(), old_price, stock.current_price])

		## 3. 检查退市
		if stock.should_delist():
			stock.is_delisted = true
			GameBus.stock_delisted.emit(stock_id)
			if _is_network_server():
				_sync_stock_delisted.rpc(stock_id)
			print("[StockManager] %s 已退市！" % stock_id)

	## 4. 通知客户端也 tick 情绪修改器，保持修改器列表同步
	if _is_network_server():
		_sync_tick_modifiers.rpc()

## ── 网络同步 ────────────────────────────────────────────────────────

func _is_network_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

@rpc("authority", "reliable")
func _sync_stock_price_changed(stock_id: StringName, old_price: float, new_price: float) -> void:
	var stock := get_stock(stock_id)
	if stock:
		stock.current_price = new_price
	GameBus.stock_price_changed.emit(stock_id, old_price, new_price)

@rpc("authority", "reliable")
func _sync_stock_delisted(stock_id: StringName) -> void:
	var stock := get_stock(stock_id)
	if stock:
		stock.is_delisted = true
	GameBus.stock_delisted.emit(stock_id)

@rpc("authority", "reliable")
func _sync_sentiment_modifier_applied(stock_id: StringName, source_id: StringName, value: int, remaining: int) -> void:
	var mod := SentimentModifier.new()
	mod.source_id = source_id
	mod.value = value
	mod.remaining_turns = remaining
	var stock := get_stock(stock_id)
	if stock:
		stock.add_modifier(mod)
	GameBus.sentiment_modifier_applied.emit(stock_id, mod)

@rpc("authority", "reliable")
func _sync_tick_modifiers() -> void:
	for stock_id: StringName in _stocks:
		var stock: Stock = _stocks[stock_id]
		if not stock.is_delisted:
			stock.tick_modifiers()
