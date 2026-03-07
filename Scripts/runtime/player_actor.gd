## 玩家行动者，持有 PlayerState 引用，负责玩家回合的全部控制逻辑。
## execute_turn() 会 await GameBus.player_ended_turn 信号，
## UI 层在玩家点击"结束回合"时发出该信号。
##
## 消耗行动值的操作（行动值共享池）：
##   - try_gather_material()      获取素材
##   - try_craft_article()        文章合成
##   - try_acquire_writing_method() 获取写作方法卡
## 不消耗行动值的操作（无次数限制）：
##   - publish_article()          发表文章
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

	## 挂起，等待玩家点击"结束回合"按钮
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
func try_craft_article(_ctx: Dictionary) -> bool:
	if not _try_spend_ap(1):
		return false
	print("[PlayerActor] 文章合成，剩余行动值: %d" % state.action_points)
	## TODO: 实际合成逻辑
	return true

## 获取写作方法卡（消耗 1 行动值）。
func try_acquire_writing_method(_ctx: Dictionary) -> bool:
	if not _try_spend_ap(1):
		return false
	print("[PlayerActor] 获取写作方法卡，剩余行动值: %d" % state.action_points)
	## TODO: 实际获取逻辑
	return true

## ── 无限制操作 ────────────────────────────────────────────────────────

## 发表文章至指定渠道（无行动值消耗）。
## 情感修改直接生效（对应 article 的 SentimentModifier）。
func publish_article(article: Article, channel: Enums.Channel, _ctx: Dictionary) -> void:
	print("[PlayerActor] 发表文章 → 渠道: %s" % Enums.Channel.keys()[channel])
	GameBus.article_published.emit(article, channel)

## ── 内部工具 ──────────────────────────────────────────────────────────

func _try_spend_ap(cost: int) -> bool:
	if state.action_points < cost:
		print("[PlayerActor] 行动值不足，需要 %d，当前 %d" % [cost, state.action_points])
		return false
	state.action_points -= cost
	GameBus.action_points_changed.emit(state.action_points, state.max_action_points)
	return true
