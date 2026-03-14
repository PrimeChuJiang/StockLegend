## 玩家运行时状态，纯数据层，不包含行动控制逻辑。
## 行动控制（如消耗行动值、结束回合）由 PlayerActor 负责。
class_name PlayerState
extends RefCounted

## 玩家ID，用于在多人游戏中标明不同玩家
var player_id: StringName = &""

## 金钱
var cash: float = 10000.0
## 行动值（每回合可用于：获取素材 / 文章合成 / 获取写作方法卡）
var action_points: int = 3
## 行动值上限
var max_action_points: int = 3
## 人脉
var connections: int = 3
## 信誉
var reputation: int = 50

## 持仓 {stock_id: StringName -> quantity: int}
var holdings: Dictionary[StringName, int] = {}

## 草稿区（撰写完成，等待发表的文章）
var draft_articles: Array[Article] = []

## 交易次数（与行动值独立，单独限制）
var trade_count: int = 0
var max_trades: int = 3
## 每回合限制行为
var has_trained_today: bool = false
var has_scouted_today: bool = false

## 容器引用（由场景注入）
var deck: ItemContainer = null
var hand: ItemContainer = null
var discard: ItemContainer = null
var exhaust: ItemContainer = null
var method_library: ItemContainer = null
var article_workspace: ItemContainer = null

func _init(_player_id : StringName) -> void:
	self.player_id = _player_id

## 每个玩家回合开始时由 PlayerActor 调用，重置所有回合限制资源。
func reset_turn_resources() -> void:
	action_points = max_action_points
	trade_count = 0
	has_trained_today = false
	has_scouted_today = false

## 买入股票
func buy_stock(stock_id: StringName, quantity: int, price: float) -> bool:
	var total_cost := quantity * price
	if cash < total_cost or trade_count >= max_trades:
		return false
	cash -= total_cost
	trade_count += 1
	holdings[stock_id] = holdings.get(stock_id, 0) + quantity
	GameBus.assets_changed.emit(player_id)
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
	GameBus.assets_changed.emit(player_id)
	return true
