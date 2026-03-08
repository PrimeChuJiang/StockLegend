## 玩家行动者，持有 PlayerState 引用，负责玩家回合的全部控制逻辑。
## execute_turn() 会 await GameBus.player_ended_turn 信号，
## UI 层在玩家点击"结束回合"时发出该信号。
##
## 消耗行动值的操作（行动值共享池）：
##   - try_gather_material()       获取素材
##   - try_craft_article()         文章合成 → 返回 Article 或 null
##   - try_acquire_writing_method() 获取写作方法卡
## 不消耗行动值的操作（无次数限制）：
##   - publish_article()           发表文章（情绪修改直接生效）
class_name PlayerActor
extends Actor

var state: PlayerState

func _init(player_state: PlayerState) -> void:
	actor_id = &"player"
	actor_type = Enums.ActorType.PLAYER
	state = player_state

## 重置资源、等待玩家结束回合信号。
func execute_turn(_ctx: Dictionary) -> void:
	state.reset_turn_resources()
	GameBus.actor_turn_started.emit(Enums.ActorType.PLAYER)
	GameBus.action_points_changed.emit(state.action_points, state.max_action_points)
	print("[PlayerActor] 玩家回合开始，行动值: %d/%d" % [state.action_points, state.max_action_points])

	await GameBus.player_ended_turn

	print("[PlayerActor] 玩家回合结束")
	GameBus.actor_turn_ended.emit(Enums.ActorType.PLAYER)

## ── 消耗行动值的操作 ──────────────────────────────────────────────────

## 获取素材（消耗 1 行动值）。
func try_gather_material(_ctx: Dictionary) -> bool:
	if not _try_spend_ap(1):
		return false
	print("[PlayerActor] 获取素材，剩余行动值: %d" % state.action_points)
	## TODO: 实际素材抽取逻辑
	return true

## 文章合成（消耗 1 行动值）。
## materials : 选择参与合成的素材卡数据
## methods   : 选择参与合成的写作方法卡数据（可为空）
## turn      : 当前回合编号，用于生成文章 ID
## 返回合成成功的 Article；行动值不足时返回 null。
func try_craft_article(
	materials: Array[MaterialCardData],
	methods: Array[WritingMethodCardData],
	turn: int
) -> Article:
	if not _try_spend_ap(1):
		return null
	var article := ArticleSystem.compose(materials, methods, turn, state.draft_articles.size())
	state.draft_articles.append(article)
	GameBus.article_composed.emit(article)
	print("[PlayerActor] 文章合成完成: %s → %s" % [article.article_id, article.get_summary()])
	return article

## 获取写作方法卡（消耗 1 行动值）。
func try_acquire_writing_method(_ctx: Dictionary) -> bool:
	if not _try_spend_ap(1):
		return false
	print("[PlayerActor] 获取写作方法卡，剩余行动值: %d" % state.action_points)
	## TODO: 实际获取逻辑
	return true

## 购买股票（消耗 1 行动值）。
func try_buy_stock(stock_id: StringName, quantity: int) -> bool:
	if not _try_spend_ap(1):
		return false
	if state.buy_stock(stock_id, quantity, StockManager.get_stock(stock_id).current_price):
		print("[PlayerActor] 购买股票 %s * %d" % [stock_id, quantity])
		return true
	return false

## 卖出股票（消耗 1 行动值）。
func try_sell_stock(stock_id: StringName, quantity: int) -> bool:
	if not _try_spend_ap(1):
		return false
	if state.sell_stock(stock_id, quantity, StockManager.get_stock(stock_id).current_price):
		print("[PlayerActor] 卖出股票 %s * %d" % [stock_id, quantity])
		return true
	return false

## ── 无限制操作 ────────────────────────────────────────────────────────

## 发表文章至指定渠道（无行动值消耗）。
## 情绪效果在 Stock.add_modifier() 后立即生效。
func publish_article(article: Article, channel: Enums.Channel, _ctx: Dictionary) -> void:
	article.channel = channel
	article.is_published = true
	print("[PlayerActor] 发表文章 → 渠道: %s | %s" % [
		Enums.Channel.keys()[channel], article.get_summary()])
	GameBus.article_published.emit(article, channel)

## ── 内部工具 ──────────────────────────────────────────────────────────

func _try_spend_ap(cost: int) -> bool:
	if state.action_points < cost:
		print("[PlayerActor] 行动值不足，需要 %d，当前 %d" % [cost, state.action_points])
		return false
	state.action_points -= cost
	GameBus.action_points_changed.emit(state.action_points, state.max_action_points)
	return true
