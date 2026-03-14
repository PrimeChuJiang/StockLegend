## 世界行动者（回合尾），负责每回合结束时的全局结算。
## 阶段顺序：SETTLE_ARTICLES → RESOLVE_PRICE
##
## _ctx 所需字段：
##   _ctx["scene_tree"]   : SceneTree   — 用于阶段间计时延迟
##   _ctx["turn_number"]  : int         — 当前回合编号
##   _ctx["player_states"] : Array[PlayerState] — 用于结算草稿文章新鲜度
class_name WorldEndActor
extends Actor

func _init() -> void:
	actor_id = &"world_end"
	actor_type = Enums.ActorType.WORLD

## 按顺序执行世界回合尾的所有阶段，完成后返回。
func execute_turn(ctx: Dictionary) -> void:
	GameBus.actor_turn_started.emit(Enums.ActorType.WORLD)
	print("[WorldEndActor] 世界回合尾开始（回合 %d）" % ctx.get("turn_number", 0))

	await _run_phase(Enums.WorldPhase.SETTLE_ARTICLES, ctx)
	await _run_phase(Enums.WorldPhase.RESOLVE_PRICE, ctx)

	print("[WorldEndActor] 世界回合尾结束")
	GameBus.actor_turn_ended.emit(Enums.ActorType.WORLD)

## 执行单个阶段：发信号 → 执行逻辑 → 短暂停顿 → 发结束信号。
func _run_phase(phase: Enums.WorldPhase, _ctx: Dictionary) -> void:
	GameBus.world_end_phase_started.emit(phase)
	print("[WorldEndActor] 阶段开始: %s" % Enums.WorldPhase.keys()[phase])

	match phase:
		Enums.WorldPhase.SETTLE_ARTICLES:
			_settle_articles(_ctx)
		Enums.WorldPhase.RESOLVE_PRICE:
			_resolve_price()

	var tree: SceneTree = _ctx.get("scene_tree")
	if tree:
		await tree.create_timer(0.6).timeout

	GameBus.world_end_phase_ended.emit(phase)
	print("[WorldEndActor] 阶段结束: %s" % Enums.WorldPhase.keys()[phase])

## 结算草稿文章新鲜度：每篇 -1，归零时从草稿区移除。
func _settle_articles(_ctx: Dictionary) -> void:
	var player_states: Array[PlayerState] = _ctx.get("player_states")
	if player_states.is_empty():
		print("[WorldEndActor]   → 玩家状态列表为空，跳过文章结算")
		return

	for player_state in player_states:

		print("[WorldEndActor]   → 玩家 %s 草稿文章新鲜度结算" % player_state.player_id)
		if player_state.draft_articles.is_empty():
			print("[WorldEndActor]   → 无草稿文章")
			continue

		var expired: Array[Article] = []
		for article in player_state.draft_articles:
			article.freshness -= 1
			if article.freshness <= 0:
				expired.append(article)
				print("[WorldEndActor]   → 草稿过期: %s" % article.article_id)
			else:
				print("[WorldEndActor]   → 草稿 %s 新鲜度: %d" % [article.article_id, article.freshness])

		for article in expired:
			player_state.draft_articles.erase(article)
			GameBus.article_expired.emit(article)

## 结算股票价格：委托给 StockManager 执行情绪 → 价格变动。
func _resolve_price() -> void:
	StockManager.settle_turn()
