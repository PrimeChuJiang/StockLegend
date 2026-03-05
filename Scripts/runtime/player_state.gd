## 玩家运行时状态，存储生命值、能量等可变数据。
class_name PlayerState
extends RefCounted

## 金钱
var cash: float = 10000.0
## 能量
var energy: int = 2
## 能量上限值
var max_energy: int = 2
## 人脉
var connections: int = 3
## 信誉
var reputation: int = 50

## 持仓{stock_id: StringName -> quantity: int}
var holdings: Dictionary = {}

## 草稿区（撰写完成，等待发表的文章）
var draft_articles: Array[Article] = []

## 当前回合的操作计数器
var trade_count: int = 0
var max_trades: int = 3
## 进修限制(每个回合只能进修一次)
var has_trained_today: bool = false
## 窥视限制(每个回合只能窥视一次)
var has_scouted_today: bool = false

## 容器引用（由场景注入，而非 PlayerState 自己管理）
var deck: ItemContainer = null
var hand: ItemContainer = null
var discard: ItemContainer = null
var exhaust: ItemContainer = null
var method_library: ItemContainer = null      ## 写作方法库（替代旧的 Array[WritingMethodCard]）
var article_workspace: ItemContainer = null   ## 文章撰写区（替代旧的临时列表）

## 买入股票
func buy_stock(stock_id: StringName, quantity: int, price: float) -> bool:
	var total_cost := quantity * price
	if cash < total_cost or trade_count >= max_trades:
		return false
	cash -= total_cost
	trade_count += 1
	## 更新持仓
	holdings[stock_id] = holdings.get(stock_id, 0) + quantity
	return true

## 卖出股票
func sell_stock(stock_id: StringName, quantity: int, price: float) -> bool:
	if not holdings.has(stock_id) or trade_count >= max_trades:
		return false
	if holdings[stock_id] < quantity:
		return false
	cash += quantity * price
	holdings[stock_id] -= quantity
	if holdings[stock_id] == 0:
		holdings.erase(stock_id)
	trade_count += 1
	return true