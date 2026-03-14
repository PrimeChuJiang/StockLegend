## 回合管理器，驱动整个游戏的行动者轮次循环。
## 持有一个有序的 actors 数组，每回合依次调用每个行动者的 execute_turn()。
## 行动者顺序即行动顺序，默认为：WorldStartActor → PlayerActor → （未来）AIActor → WorldEndActor。
##
## 使用方式：
##   turn_manager.setup({"scene_tree": get_tree(), "schedule": my_schedule})
##   turn_manager.add_player(player_id)
##   turn_manager.start_game()
class_name TurnManager
extends Node

## 当前回合编号，从 1 开始
var turn_number: int = 0

## 行动者列表，按行动顺序排列。由外部（场景脚本）在 start_game() 前赋值。
var actors: Array[Actor] = []

## 上下文字典，透传给每个行动者的 execute_turn()。
## 每回合开始前自动更新 turn_number 字段。
## ctx字段：{
##    "turn_number" : int - 当前回合编号
##	  "player_states" : Array[PlayerState] - 玩家状态列表
##    "world_phase" : Enums.WorldPhase - 当前世界阶段
##    "scene_tree" : SceneTree   — 用于阶段间计时延迟
## }
var _ctx: Dictionary = {}

## ── 初始化 ──────────────────────────────────────────────────────────

func _ready() -> void:
	## 监听 RefCounted Actor 发出的信号，转发给客户端
	GameBus.actor_turn_started.connect(_forward_actor_turn_started)
	GameBus.actor_turn_ended.connect(_forward_actor_turn_ended)
	GameBus.world_start_phase_started.connect(_forward_world_start_phase_started)
	GameBus.world_start_phase_ended.connect(_forward_world_start_phase_ended)
	GameBus.world_end_phase_started.connect(_forward_world_end_phase_started)
	GameBus.world_end_phase_ended.connect(_forward_world_end_phase_ended)
	## 玩家回合信号（带 player_id，由 PlayerActor 发出）
	GameBus.player_turn_started.connect(_forward_player_turn_started)
	GameBus.player_turn_ended.connect(_forward_player_turn_ended)
	## 玩家数据信号（由 RefCounted PlayerActor/PlayerState 发出）
	GameBus.action_points_changed.connect(_forward_action_points_changed)
	GameBus.assets_changed.connect(_forward_assets_changed)
	GameBus.article_composed.connect(_forward_article_composed)
	GameBus.article_published.connect(_forward_article_published)
	GameBus.article_expired.connect(_forward_article_expired)
	## 日程事件信号（公开信息）
	GameBus.event_revealed.connect(_forward_event_revealed)
	GameBus.breaking_event_triggered.connect(_forward_breaking_event_triggered)
	GameBus.events_showed.connect(_forward_events_showed)

## 设置上下文（需在 start_game() 前调用）。
## 推荐字段：
##   "scene_tree"  : SceneTree    — 供 Actor 创建定时器
##   "schedule"    : ScheduleData — 供 WorldStartActor 查询事件
func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	_setup()

## 管理器内自动添加世界开始和世界结束actor
func _setup() -> void:
	actors.append(WorldStartActor.new())
	actors.append(WorldEndActor.new())

## 启动游戏循环（在场景 _ready 末尾调用）。
func start_game() -> void:
	## TODO: 所有玩家初始顺序决定逻辑
	_game_loop()

## 主循环：无限轮转所有行动者。
## 每回合开始时将 turn_number 写入 ctx，Actor 可从 ctx["turn_number"] 读取。
func _game_loop() -> void:
	while true:
		turn_number += 1
		_ctx["turn_number"] = turn_number
		GameBus.turn_started.emit(turn_number)
		if _is_network_server():
			_sync_turn_started.rpc(turn_number)
		print("\n========== 回合 %d 开始 ==========" % turn_number)

		for actor: Actor in actors:
			await actor.execute_turn(_ctx)

		GameBus.turn_ended.emit(turn_number)
		if _is_network_server():
			_sync_turn_ended.rpc(turn_number)
		print("========== 回合 %d 结束 ==========\n" % turn_number)

## 添加新玩家
func add_player(player: PlayerNode) -> void:
	actors.insert(actors.size() - 1, player.player_actor)
	_ctx["player_states"].append(player.player_state)
	print("玩家 %s 加入游戏" % player.multiplayer_id)
	## 主机端：立即推送初始资产数据给所有客户端
	if _is_network_server():
		var s := player.player_state
		_sync_assets_changed.rpc(s.player_id, s.cash, s.holdings.duplicate())

## 玩家离开
func remove_player(player: PlayerNode) -> void:
	for actor in actors:
		if actor.player_id == player.multiplayer_id:
			actors.erase(actor)
			_ctx["player_states"].erase(player.player_state)
			print("玩家 %s 离开游戏" % player.multiplayer_id)
			return
	print("玩家 %s 不存在" % player.multiplayer_id)

## ── 客户端 → 主机 RPC ────────────────────────────────────────────────

## 客户端请求结束回合，主机验证后 emit 信号给 PlayerActor
@rpc("any_peer", "reliable")
func request_end_turn(player_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	GameBus.player_ended_turn.emit(player_id)

## 客户端请求获取素材，主机验证后由对应 PlayerActor 执行
@rpc("any_peer", "reliable")
func request_gather(player_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	for actor in actors:
		if actor is PlayerActor and actor.actor_id == player_id:
			actor.try_gather_material({})
			return

## 客户端请求合成文章，主机验证后由对应 PlayerActor 执行
## material_indices / method_indices 暂为占位，测试阶段使用固定素材
@rpc("any_peer", "reliable")
func request_craft(player_id: StringName, turn: int) -> void:
	if not multiplayer.is_server():
		return
	for actor in actors:
		if actor is PlayerActor and actor.actor_id == player_id:
			## TODO: 从客户端传入素材选择，测试阶段由信号通知 test_turn 处理
			GameBus.craft_requested.emit(player_id, turn)
			return

## 客户端请求发表文章，主机验证后由对应 PlayerActor 执行
@rpc("any_peer", "reliable")
func request_publish(player_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	GameBus.publish_requested.emit(player_id)

## 客户端请求买入股票，主机验证后由对应 PlayerActor 执行
@rpc("any_peer", "reliable")
func request_buy_stock(player_id: StringName, stock_id: StringName, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	for actor in actors:
		if actor is PlayerActor and actor.actor_id == player_id:
			var success: bool = actor.try_buy_stock(stock_id, quantity)
			GameBus.player_trade.emit(player_id, stock_id, quantity, true, success)
			_sync_trade_result.rpc(player_id, stock_id, quantity, true, success)
			return

## 客户端请求卖出股票，主机验证后由对应 PlayerActor 执行
@rpc("any_peer", "reliable")
func request_sell_stock(player_id: StringName, stock_id: StringName, quantity: int) -> void:
	if not multiplayer.is_server():
		return
	for actor in actors:
		if actor is PlayerActor and actor.actor_id == player_id:
			var success: bool = actor.try_sell_stock(stock_id, quantity)
			GameBus.player_trade.emit(player_id, stock_id, quantity, false, success)
			_sync_trade_result.rpc(player_id, stock_id, quantity, false, success)
			return

## ── 网络同步工具 ────────────────────────────────────────────────────

func _is_network_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func _find_player_state(player_id: StringName) -> PlayerState:
	var states: Array = _ctx.get("player_states", [])
	for state: PlayerState in states:
		if state.player_id == player_id:
			return state
	return null

## ── 转发：Actor / Phase 信号 ────────────────────────────────────────

func _forward_actor_turn_started(actor_type: Enums.ActorType) -> void:
	if _is_network_server():
		_sync_actor_turn_started.rpc(actor_type)

func _forward_actor_turn_ended(actor_type: Enums.ActorType) -> void:
	if _is_network_server():
		_sync_actor_turn_ended.rpc(actor_type)

func _forward_world_start_phase_started(phase: Enums.WorldPhase) -> void:
	if _is_network_server():
		_sync_world_start_phase_started.rpc(phase)

func _forward_world_start_phase_ended(phase: Enums.WorldPhase) -> void:
	if _is_network_server():
		_sync_world_start_phase_ended.rpc(phase)

func _forward_world_end_phase_started(phase: Enums.WorldPhase) -> void:
	if _is_network_server():
		_sync_world_end_phase_started.rpc(phase)

func _forward_world_end_phase_ended(phase: Enums.WorldPhase) -> void:
	if _is_network_server():
		_sync_world_end_phase_ended.rpc(phase)

func _forward_player_turn_started(player_id: StringName) -> void:
	if _is_network_server():
		_sync_player_turn_started.rpc(player_id)

func _forward_player_turn_ended(player_id: StringName) -> void:
	if _is_network_server():
		_sync_player_turn_ended.rpc(player_id)

## ── 转发：日程事件信号 ────────────────────────────────────────────

func _forward_event_revealed(cfg: ScheduleEventConfig) -> void:
	if _is_network_server():
		_sync_event_revealed.rpc(cfg.reveal_name, cfg.event_cards.size())

func _forward_breaking_event_triggered(cfg: ScheduleEventConfig) -> void:
	if _is_network_server():
		_sync_breaking_event_triggered.rpc(cfg.reveal_name)

func _forward_events_showed(start_turn: int, end_turn: int, cfg_dic) -> void:
	if not _is_network_server():
		return
	## 序列化：{turn_number: [preview_name, ...]}
	var serialized: Dictionary = {}
	for turn_key in cfg_dic:
		var names: Array = []
		for cfg in cfg_dic[turn_key]:
			names.append(cfg.preview_name)
		serialized[turn_key] = names
	_sync_events_showed.rpc(start_turn, end_turn, serialized)

## ── 转发：玩家数据信号 ──────────────────────────────────────────────

func _forward_action_points_changed(player_id: StringName, new_val: int, max_val: int) -> void:
	if _is_network_server():
		_sync_action_points_changed.rpc(player_id, new_val, max_val)

func _forward_assets_changed(player_id: StringName, cash: float, holdings: Dictionary) -> void:
	if _is_network_server():
		_sync_assets_changed.rpc(player_id, cash, holdings)

func _forward_article_composed(player_id: StringName, article: Article) -> void:
	if _is_network_server():
		_sync_article_composed.rpc(player_id, _serialize_article(article))

func _forward_article_published(player_id: StringName, article: Article, channel: Enums.Channel) -> void:
	if _is_network_server():
		_sync_article_published.rpc(player_id, _serialize_article(article), channel)

## 序列化文章数据用于 RPC 传输
static func _serialize_article(article: Article) -> Dictionary:
	return {
		"article_id": article.article_id,
		"article_type": article.article_type,
		"direction": article.direction,
		"final_impact": article.final_impact,
		"final_credibility": article.final_credibility,
		"target_industry": article.target_industry.name if article.target_industry else "",
		"summary": article.get_summary(),
	}

func _forward_article_expired(article: Article) -> void:
	if _is_network_server():
		_sync_article_expired.rpc(article.article_id)

## ── RPC 接收：客户端重新触发本地 GameBus 信号 ─────────────────────

@rpc("authority", "reliable")
func _sync_turn_started(turn: int) -> void:
	GameBus.turn_started.emit(turn)

@rpc("authority", "reliable")
func _sync_turn_ended(turn: int) -> void:
	GameBus.turn_ended.emit(turn)

@rpc("authority", "reliable")
func _sync_actor_turn_started(actor_type: int) -> void:
	GameBus.actor_turn_started.emit(actor_type as Enums.ActorType)

@rpc("authority", "reliable")
func _sync_actor_turn_ended(actor_type: int) -> void:
	GameBus.actor_turn_ended.emit(actor_type as Enums.ActorType)

@rpc("authority", "reliable")
func _sync_world_start_phase_started(phase: int) -> void:
	GameBus.world_start_phase_started.emit(phase as Enums.WorldPhase)

@rpc("authority", "reliable")
func _sync_world_start_phase_ended(phase: int) -> void:
	GameBus.world_start_phase_ended.emit(phase as Enums.WorldPhase)

@rpc("authority", "reliable")
func _sync_world_end_phase_started(phase: int) -> void:
	GameBus.world_end_phase_started.emit(phase as Enums.WorldPhase)

@rpc("authority", "reliable")
func _sync_world_end_phase_ended(phase: int) -> void:
	GameBus.world_end_phase_ended.emit(phase as Enums.WorldPhase)

@rpc("authority", "reliable")
func _sync_player_turn_started(player_id: StringName) -> void:
	GameBus.player_turn_started.emit(player_id)

@rpc("authority", "reliable")
func _sync_player_turn_ended(player_id: StringName) -> void:
	GameBus.player_turn_ended.emit(player_id)

@rpc("authority", "reliable")
func _sync_action_points_changed(player_id: StringName, new_val: int, max_val: int) -> void:
	_update_client_player_state(player_id, {"action_points": new_val, "max_action_points": max_val})
	GameBus.action_points_changed.emit(player_id, new_val, max_val)

@rpc("authority", "reliable")
func _sync_assets_changed(player_id: StringName, cash: float, holdings: Dictionary) -> void:
	_update_client_player_state(player_id, {"cash": cash, "holdings": holdings})
	GameBus.assets_changed.emit(player_id, cash, holdings)

## 客户端侧更新本地 PlayerState 镜像
func _update_client_player_state(player_id: StringName, data: Dictionary) -> void:
	var players_container = get_node_or_null("../Players")
	if not players_container:
		return
	for child in players_container.get_children():
		if child is PlayerNode and child.multiplayer_id == player_id:
			if child.player_state:
				for key in data:
					child.player_state.set(key, data[key])
			break

@rpc("authority", "reliable")
func _sync_article_composed(player_id: StringName, data: Dictionary) -> void:
	GameBus.article_composed_synced.emit(player_id, data)

@rpc("authority", "reliable")
func _sync_article_published(player_id: StringName, data: Dictionary, channel: int) -> void:
	GameBus.article_published_synced.emit(player_id, data, channel)

@rpc("authority", "reliable")
func _sync_article_expired(article_id: StringName) -> void:
	_log_on_client("[草稿过期] %s" % article_id)

@rpc("authority", "reliable")
func _sync_trade_result(player_id: StringName, stock_id: StringName, quantity: int, is_buy: bool, success: bool) -> void:
	GameBus.player_trade.emit(player_id, stock_id, quantity, is_buy, success)

@rpc("authority", "reliable")
func _sync_event_revealed(reveal_name: String, card_count: int) -> void:
	## 客户端重建精简版 ScheduleEventConfig 用于 UI 显示
	var cfg := ScheduleEventConfig.new()
	cfg.reveal_name = reveal_name
	cfg.event_cards.resize(card_count)
	GameBus.event_revealed.emit(cfg)

@rpc("authority", "reliable")
func _sync_breaking_event_triggered(reveal_name: String) -> void:
	var cfg := ScheduleEventConfig.new()
	cfg.reveal_name = reveal_name
	GameBus.breaking_event_triggered.emit(cfg)

@rpc("authority", "reliable")
func _sync_events_showed(start_turn: int, end_turn: int, serialized: Dictionary) -> void:
	## 反序列化：重建带 preview_name 的精简 config 对象
	var cfg_dic: Dictionary = {}
	for turn_key in serialized:
		var configs: Array = []
		for preview_name in serialized[turn_key]:
			var cfg := ScheduleEventConfig.new()
			cfg.preview_name = preview_name
			configs.append(cfg)
		cfg_dic[int(turn_key)] = configs
	GameBus.events_showed.emit(start_turn, end_turn, cfg_dic)

## 客户端日志输出（文章相关暂用 print，后续可对接 UI）
func _log_on_client(msg: String) -> void:
	print("[Client] %s" % msg)
