## 测试场景脚本：验证 WorldStartActor → PlayerActor 的 Phase 切换流程，
## 以及文章合成（素材卡 + 写作方法卡 → Article）的完整逻辑。
extends Node

@onready var turn_manager: TurnManager = $TurnManager
@onready var turn_label: Label       = $CanvasLayer/Panel/VBox/TurnLabel
@onready var actor_label: Label      = $CanvasLayer/Panel/VBox/ActorLabel
@onready var phase_label: Label      = $CanvasLayer/Panel/VBox/PhaseLabel
@onready var ap_label: Label         = $CanvasLayer/Panel/VBox/APLabel
@onready var log_box: RichTextLabel  = $CanvasLayer/Panel/VBox/LogBox
@onready var gather_button: Button   = $CanvasLayer/Panel/VBox/GatherButton
@onready var craft_button: Button    = $CanvasLayer/Panel/VBox/CraftButton
@onready var end_turn_button: Button = $CanvasLayer/Panel/VBox/EndTurnButton

var _player_state: PlayerState
var _world_start_actor: WorldStartActor
var _player_actor: PlayerActor

## ── 预设测试素材 ──────────────────────────────────────────────────────
## 素材 A：内部爆料（EXPOSE, BULLISH, impact=4, credibility=2）
var _mat_expose: MaterialCardData
## 素材 B：市场数据（DATA, BULLISH, impact=2, credibility=3）
var _mat_data: MaterialCardData
## 素材 C：市场谣言（RUMOR, BEARISH, impact=3, credibility=1）
var _mat_rumor: MaterialCardData

## 预设测试写作方法卡：深度挖掘（IMPACT_ADD +3）
var _method_deep_dig: WritingMethodCardData

## ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_test_cards()
	_connect_signals()
	_setup_actors()
	turn_manager.start_game()

## ── 测试日程构建 ──────────────────────────────────────────────────────

## 创建测试用的素材卡和写作方法卡数据对象（不需要 ItemContainer）。
func _build_test_cards() -> void:
	_mat_expose = MaterialCardData.new()
	_mat_expose.name = "内部爆料"
	_mat_expose.material_type = Enums.MaterialType.EXPOSE
	_mat_expose.bias = Enums.Bias.BULLISH
	_mat_expose.impact = 4
	_mat_expose.credibility = 2

	_mat_data = MaterialCardData.new()
	_mat_data.name = "市场数据"
	_mat_data.material_type = Enums.MaterialType.DATA
	_mat_data.bias = Enums.Bias.BULLISH
	_mat_data.impact = 2
	_mat_data.credibility = 3

	_mat_rumor = MaterialCardData.new()
	_mat_rumor.name = "市场谣言"
	_mat_rumor.material_type = Enums.MaterialType.RUMOR
	_mat_rumor.bias = Enums.Bias.BERISH
	_mat_rumor.impact = 3
	_mat_rumor.credibility = 1

	var b := WritingMethodBehaviour.new()
	b.effect_type = Enums.MethodEffectType.IMPACT_ADD
	b.value = 3.0

	_method_deep_dig = WritingMethodCardData.new()
	_method_deep_dig.name = "深度挖掘"
	_method_deep_dig.rarity = Enums.Rarity.UNCOMMON
	_method_deep_dig.behaviours = [b]

func _connect_signals() -> void:
	GameBus.turn_started.connect(func(n: int) -> void:
		turn_label.text = "回合：%d" % n
		_log("[b]══ 回合 %d 开始 ══[/b]" % n))

	GameBus.turn_ended.connect(func(n: int) -> void:
		_log("[b]══ 回合 %d 结束 ══[/b]" % n))

	GameBus.actor_turn_started.connect(_on_actor_turn_started)
	GameBus.actor_turn_ended.connect(_on_actor_turn_ended)

	GameBus.world_start_phase_started.connect(func(phase: Enums.WorldPhase) -> void:
		phase_label.text = "世界阶段：%s" % Enums.WorldPhase.keys()[phase]
		_log("  [color=cyan]▶ 世界阶段：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.world_start_phase_ended.connect(func(phase: Enums.WorldPhase) -> void:
		_log("  [color=cyan]■ 世界阶段结束：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.action_points_changed.connect(func(new_val: int, max_val: int) -> void:
		ap_label.text = "行动值：%d / %d" % [new_val, max_val]
		_log("  行动值变化：%d / %d" % [new_val, max_val]))

	GameBus.article_composed.connect(func(article: Article) -> void:
		_log("[color=yellow]  ★ 文章合成完成！[/color]")
		_log("    ID: %s" % article.article_id)
		_log("    素材: %s" % _material_names(article.material_cards))
		_log("    方法: %s" % _method_names(article.method_cards))
		_log("    结果: %s" % article.get_summary()))

	GameBus.events_showed.connect(func(turn_start: int, turn_end: int, cfg_dic: Dictionary) -> void:
		_log("  [color=orange]📋 日程预告：[/color]")
		
		for turn_index in range(turn_start, turn_end) :
			if cfg_dic.has(turn_index):
				for cfg in cfg_dic[turn_index]:
					_log("    · [color=orange]第 %d 回合： 预告内容：「%s」[/color]" % [turn_index, cfg.preview_name])
			else :
				_log("    · [color=orange]第 %d 回合：无日程事件[/color]" % turn_index)
			turn_index += 1
		)

	GameBus.event_revealed.connect(func(cfg: ScheduleEventConfig) -> void:
		_log("  [color=orange]📋 日程揭示：「%s」→ 触发 %d 张环境牌[/color]" % [
			cfg.reveal_name, cfg.event_cards.size()]))

	GameBus.breaking_event_triggered.connect(func(cfg: ScheduleEventConfig) -> void:
		_log("  [color=red]⚡ 突发事件：「%s」[/color]" % cfg.reveal_name))

	gather_button.pressed.connect(_on_gather_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func _build_test_schedule() -> ScheduleData:
	## 环境牌：央行加息（宏观利空）
	var env_rate_hike := EnviromentCardData.new()
	env_rate_hike.name = "央行加息"
	env_rate_hike.sentiment_modifier = -3
	env_rate_hike.duration = 2

	## 环境牌：AI政策利好（行业利好）
	var env_ai_policy := EnviromentCardData.new()
	env_ai_policy.name = "AI产业政策落地"
	env_ai_policy.sentiment_modifier = 4
	env_ai_policy.duration = 1

	## 日程事件 A：宏观消息（权重高，第1回合起可出现）
	var cfg_macro := ScheduleEventConfig.new()
	cfg_macro.preview_name = "宏观消息"
	cfg_macro.reveal_name = "央行政策发布"
	cfg_macro.event_cards = [env_rate_hike]
	cfg_macro.weight = 2.0
	cfg_macro.earliest_turn = 1

	## 日程事件 B：行业动态（第2回合起可出现）
	var cfg_industry := ScheduleEventConfig.new()
	cfg_industry.preview_name = "行业动态"
	cfg_industry.reveal_name = "科技行业报告"
	cfg_industry.event_cards = [env_ai_policy]
	cfg_industry.weight = 1.0
	cfg_industry.earliest_turn = 2

	## 突发事件候选：黑天鹅
	var env_black_swan := EnviromentCardData.new()
	env_black_swan.name = "黑天鹅事件"
	env_black_swan.sentiment_modifier = -5
	env_black_swan.duration = 3

	var cfg_breaking := ScheduleEventConfig.new()
	cfg_breaking.preview_name = "突发消息"
	cfg_breaking.reveal_name = "重大突发事件"
	cfg_breaking.event_cards = [env_black_swan]
	cfg_breaking.weight = 1.0

	## 用 ScheduleManager 生成本局日程
	var mgr := ScheduleManager.new()
	mgr.scheduled_pool = [cfg_macro, cfg_industry]
	mgr.breaking_pool = [cfg_breaking]
	mgr.game_turns = 5
	mgr.breaking_chance = 0.3
	return mgr.generate()

func _setup_actors() -> void:
	_player_state = PlayerState.new()
	_world_start_actor = WorldStartActor.new()
	_player_actor = PlayerActor.new(_player_state)

	var schedule := _build_test_schedule()
	turn_manager.actors = [_world_start_actor, _player_actor]
	turn_manager.setup({"scene_tree": get_tree(), "schedule": schedule})

## ── 按钮事件 ──────────────────────────────────────────────────────────

func _on_gather_pressed() -> void:
	_player_actor.try_gather_material({})

func _on_craft_pressed() -> void:
	## 预设合成方案：爆料 + 数据 = 调查报道，加上"深度挖掘"方法
	var materials: Array[MaterialCardData] = [_mat_expose, _mat_data]
	var methods: Array[WritingMethodCardData] = [_method_deep_dig]
	_player_actor.try_craft_article(materials, methods, turn_manager.turn_number)

func _on_end_turn_pressed() -> void:
	_log("[color=gray]  → 玩家点击结束回合[/color]")
	GameBus.player_ended_turn.emit()

## ── Actor 回合事件 ────────────────────────────────────────────────────

func _on_actor_turn_started(actor_type: Enums.ActorType) -> void:
	var is_player := actor_type == Enums.ActorType.PLAYER
	gather_button.disabled = not is_player
	craft_button.disabled = not is_player
	end_turn_button.disabled = not is_player
	match actor_type:
		Enums.ActorType.WORLD:
			actor_label.text = "当前行动者：世界"
			phase_label.text = "阶段：—"
			_log("[color=yellow]【世界回合】开始[/color]")
		Enums.ActorType.PLAYER:
			actor_label.text = "当前行动者：玩家"
			phase_label.text = "阶段：玩家回合"
			_log("[color=green]【玩家回合】开始 — 可用行动值: %d[/color]" % _player_state.action_points)

func _on_actor_turn_ended(actor_type: Enums.ActorType) -> void:
	gather_button.disabled = true
	craft_button.disabled = true
	end_turn_button.disabled = true
	match actor_type:
		Enums.ActorType.WORLD:
			_log("[color=yellow]【世界回合】结束[/color]")
		Enums.ActorType.PLAYER:
			_log("[color=green]【玩家回合】结束[/color]")

## ── 工具方法 ──────────────────────────────────────────────────────────

func _log(text: String) -> void:
	log_box.append_text(text + "\n")

func _material_names(cards: Array[MaterialCardData]) -> String:
	var names: Array[String] = []
	for c in cards:
		names.append(c.name)
	return ", ".join(names)

func _method_names(cards: Array[WritingMethodCardData]) -> String:
	var names: Array[String] = []
	for c in cards:
		names.append(c.name)
	return ", ".join(names) if not names.is_empty() else "（无）"
