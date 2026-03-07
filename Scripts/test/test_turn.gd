## 测试场景脚本：验证完整回合流程，包括：
## - WorldStartActor → PlayerActor → WorldEndActor 的 Phase 切换
## - 文章合成（素材卡 + 写作方法卡 → Article）
## - 股票系统：情绪修改器（文章/环境牌 → 行业级/宏观级分发）、价格修改器、回合尾结算
extends Node

@onready var turn_manager: TurnManager = $TurnManager
@onready var turn_label: Label       = $CanvasLayer/Panel/VBox/TurnLabel
@onready var actor_label: Label      = $CanvasLayer/Panel/VBox/ActorLabel
@onready var phase_label: Label      = $CanvasLayer/Panel/VBox/PhaseLabel
@onready var ap_label: Label         = $CanvasLayer/Panel/VBox/APLabel
@onready var log_box: RichTextLabel  = $CanvasLayer/Panel/VBox/LogBox
@onready var gather_button: Button   = $CanvasLayer/Panel/VBox/GatherButton
@onready var craft_button: Button    = $CanvasLayer/Panel/VBox/CraftButton
@onready var publish_button: Button  = $CanvasLayer/Panel/VBox/PublishButton
@onready var price_mod_button: Button = $CanvasLayer/Panel/VBox/PriceModButton
@onready var end_turn_button: Button = $CanvasLayer/Panel/VBox/EndTurnButton
@onready var stock_info_box: RichTextLabel = $CanvasLayer/StockPanel/VBox/StockInfoBox
@onready var stock_log_box: RichTextLabel  = $CanvasLayer/StockPanel/VBox/StockLogBox

var _player_state: PlayerState
var _world_start_actor: WorldStartActor
var _player_actor: PlayerActor
var _world_end_actor: WorldEndActor

## ── 测试用行业标签 ──────────────────────────────────────────────────────
var _tag_industry: Tag
var _tag_tech: Tag
var _tag_finance: Tag

## ── 预设测试素材 ──────────────────────────────────────────────────────
var _mat_expose: MaterialCardData
var _mat_data: MaterialCardData
var _mat_rumor: MaterialCardData
var _method_deep_dig: WritingMethodCardData

## ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_industry_tags()
	_build_test_stocks()
	_build_test_cards()
	_connect_signals()
	_setup_actors()
	_update_stock_display()
	turn_manager.start_game()

## ── 行业标签构建 ────────────────────────────────────────────────────────

func _build_industry_tags() -> void:
	_tag_industry = Tag.new()
	_tag_industry.name = "Industry"
	_tag_industry._post_init()

	_tag_tech = Tag.new()
	_tag_tech.name = "Tech"
	_tag_industry.add_child(_tag_tech)

	_tag_finance = Tag.new()
	_tag_finance.name = "Finance"
	_tag_industry.add_child(_tag_finance)

## ── 测试股票构建 ────────────────────────────────────────────────────────

func _build_test_stocks() -> void:
	## 科技行业：2 只股票
	var stock_a := StockData.new()
	stock_a.id = &"tech_alpha"
	stock_a.name = "科技Alpha"
	stock_a.industry = _tag_tech
	stock_a.initial_price = 100.0
	stock_a.volatility = Enums.Volatility.HIGH
	StockManager.register_stock(stock_a)

	var stock_b := StockData.new()
	stock_b.id = &"tech_beta"
	stock_b.name = "科技Beta"
	stock_b.industry = _tag_tech
	stock_b.initial_price = 50.0
	stock_b.volatility = Enums.Volatility.MEDIUM
	StockManager.register_stock(stock_b)

	## 金融行业：1 只股票
	var stock_c := StockData.new()
	stock_c.id = &"fin_gamma"
	stock_c.name = "金融Gamma"
	stock_c.industry = _tag_finance
	stock_c.initial_price = 80.0
	stock_c.volatility = Enums.Volatility.LOW
	StockManager.register_stock(stock_c)

## ── 测试卡牌构建 ────────────────────────────────────────────────────────

func _build_test_cards() -> void:
	_mat_expose = MaterialCardData.new()
	_mat_expose.name = "内部爆料"
	_mat_expose.material_type = Enums.MaterialType.EXPOSE
	_mat_expose.bias = Enums.Bias.BULLISH
	_mat_expose.impact = 4
	_mat_expose.credibility = 2
	_mat_expose.industry = _tag_tech

	_mat_data = MaterialCardData.new()
	_mat_data.name = "市场数据"
	_mat_data.material_type = Enums.MaterialType.DATA
	_mat_data.bias = Enums.Bias.BULLISH
	_mat_data.impact = 2
	_mat_data.credibility = 3
	_mat_data.industry = _tag_tech

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

## ── 信号连接 ────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	## 回合信号
	GameBus.turn_started.connect(func(n: int) -> void:
		turn_label.text = "回合：%d" % n
		_log("[b]══ 回合 %d 开始 ══[/b]" % n))

	GameBus.turn_ended.connect(func(n: int) -> void:
		_log("[b]══ 回合 %d 结束 ══[/b]" % n)
		_update_stock_display())

	## Actor 信号
	GameBus.actor_turn_started.connect(_on_actor_turn_started)
	GameBus.actor_turn_ended.connect(_on_actor_turn_ended)

	## 世界阶段信号（回合头）
	GameBus.world_start_phase_started.connect(func(phase: Enums.WorldPhase) -> void:
		phase_label.text = "世界阶段：%s" % Enums.WorldPhase.keys()[phase]
		_log("  [color=cyan]▶ 世界阶段：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.world_start_phase_ended.connect(func(phase: Enums.WorldPhase) -> void:
		_log("  [color=cyan]■ 世界阶段结束：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	## 世界阶段信号（回合尾）
	GameBus.world_end_phase_started.connect(func(phase: Enums.WorldPhase) -> void:
		phase_label.text = "结算阶段：%s" % Enums.WorldPhase.keys()[phase]
		_log("  [color=purple]▶ 结算阶段：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.world_end_phase_ended.connect(func(phase: Enums.WorldPhase) -> void:
		_log("  [color=purple]■ 结算阶段结束：%s[/color]" % Enums.WorldPhase.keys()[phase])
		_update_stock_display())

	## 行动值信号
	GameBus.action_points_changed.connect(func(new_val: int, max_val: int) -> void:
		ap_label.text = "行动值：%d / %d" % [new_val, max_val]
		_log("  行动值变化：%d / %d" % [new_val, max_val]))

	## 文章信号
	GameBus.article_composed.connect(func(article: Article) -> void:
		_log("[color=yellow]  ★ 文章合成完成！[/color]")
		_log("    ID: %s" % article.article_id)
		_log("    素材: %s" % _material_names(article.material_cards))
		_log("    方法: %s" % _method_names(article.method_cards))
		_log("    结果: %s" % article.get_summary()))

	GameBus.article_expired.connect(func(article: Article) -> void:
		_log("[color=gray]  ✕ 草稿过期: %s[/color]" % article.article_id))

	## 日程信号
	GameBus.events_showed.connect(func(turn_start: int, turn_end: int, cfg_dic: Dictionary) -> void:
		_log("  [color=orange]日程预告：[/color]")
		for turn_index in range(turn_start, turn_end):
			if cfg_dic.has(turn_index):
				for cfg in cfg_dic[turn_index]:
					_log("    · [color=orange]第 %d 回合：「%s」[/color]" % [turn_index, cfg.preview_name])
			else:
				_log("    · [color=orange]第 %d 回合：无日程事件[/color]" % turn_index))

	GameBus.event_revealed.connect(func(cfg: ScheduleEventConfig) -> void:
		_log("  [color=orange]日程揭示：「%s」→ 触发 %d 张环境牌[/color]" % [
			cfg.reveal_name, cfg.event_cards.size()]))

	GameBus.breaking_event_triggered.connect(func(cfg: ScheduleEventConfig) -> void:
		_log("  [color=red]突发事件：「%s」[/color]" % cfg.reveal_name))

	## 股票市场信号
	GameBus.sentiment_modifier_applied.connect(func(stock_id: StringName, mod: SentimentModifier) -> void:
		_stock_log("[color=cyan]情绪修改器 → %s | %+d | 持续 %d 回合 | 来源: %s[/color]" % [
			stock_id, mod.value, mod.remaining_turns, mod.source_id]))

	GameBus.stock_price_changed.connect(func(stock_id: StringName, old_price: float, new_price: float) -> void:
		var delta := new_price - old_price
		var color := "green" if delta >= 0 else "red"
		_stock_log("[color=%s]价格变动 %s | %.2f → %.2f (%+.2f)[/color]" % [
			color, stock_id, old_price, new_price, delta])
		_update_stock_display())

	GameBus.stock_delisted.connect(func(stock_id: StringName) -> void:
		_stock_log("[color=red][b]退市！ %s[/b][/color]" % stock_id)
		_update_stock_display())

	## 按钮
	gather_button.pressed.connect(_on_gather_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	publish_button.pressed.connect(_on_publish_pressed)
	price_mod_button.pressed.connect(_on_price_mod_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

## ── 测试日程构建 ────────────────────────────────────────────────────────

func _build_test_schedule() -> ScheduleData:
	## 环境牌：央行加息（宏观利空，无 target_company 无行业标签 → 宏观级）
	var env_rate_hike := EnviromentCardData.new()
	env_rate_hike.id = &"env_rate_hike"
	env_rate_hike.name = "央行加息"
	env_rate_hike.sentiment_modifier = -3
	env_rate_hike.duration = 2

	## 环境牌：AI 政策利好（带行业标签 → 行业级）
	var env_ai_policy := EnviromentCardData.new()
	env_ai_policy.id = &"env_ai_policy"
	env_ai_policy.name = "AI产业政策落地"
	env_ai_policy.tags = [_tag_tech]
	env_ai_policy.sentiment_modifier = 4
	env_ai_policy.duration = 1

	## 日程事件 A
	var cfg_macro := ScheduleEventConfig.new()
	cfg_macro.preview_name = "宏观消息"
	cfg_macro.reveal_name = "央行政策发布"
	cfg_macro.event_cards = [env_rate_hike]
	cfg_macro.weight = 2.0
	cfg_macro.earliest_turn = 1

	## 日程事件 B
	var cfg_industry := ScheduleEventConfig.new()
	cfg_industry.preview_name = "行业动态"
	cfg_industry.reveal_name = "科技行业报告"
	cfg_industry.event_cards = [env_ai_policy]
	cfg_industry.weight = 1.0
	cfg_industry.earliest_turn = 2

	## 突发事件：黑天鹅（公司级，针对 tech_alpha）
	var env_black_swan := EnviromentCardData.new()
	env_black_swan.id = &"env_black_swan"
	env_black_swan.name = "黑天鹅事件"
	env_black_swan.target_company = &"tech_alpha"
	env_black_swan.sentiment_modifier = -5
	env_black_swan.duration = 3

	var cfg_breaking := ScheduleEventConfig.new()
	cfg_breaking.preview_name = "突发消息"
	cfg_breaking.reveal_name = "重大突发事件"
	cfg_breaking.event_cards = [env_black_swan]
	cfg_breaking.weight = 1.0

	var mgr := ScheduleManager.new()
	mgr.scheduled_pool = [cfg_macro, cfg_industry]
	mgr.breaking_pool = [cfg_breaking]
	mgr.game_turns = 5
	mgr.breaking_chance = 0.3
	return mgr.generate()

## ── Actor 设置 ──────────────────────────────────────────────────────────

func _setup_actors() -> void:
	_player_state = PlayerState.new()
	_world_start_actor = WorldStartActor.new()
	_player_actor = PlayerActor.new(_player_state)
	_world_end_actor = WorldEndActor.new()

	var schedule := _build_test_schedule()
	turn_manager.actors = [_world_start_actor, _player_actor, _world_end_actor]
	turn_manager.setup({
		"scene_tree": get_tree(),
		"schedule": schedule,
		"player_state": _player_state,
	})

	## 监听事件揭示 → 自动创建情绪修改器分发到市场
	GameBus.event_revealed.connect(_on_event_apply_modifiers)
	GameBus.breaking_event_triggered.connect(_on_event_apply_modifiers)

## 环境事件触发时，将其环境牌转换为情绪修改器并分发。
func _on_event_apply_modifiers(cfg: ScheduleEventConfig) -> void:
	for env_card: EnviromentCardData in cfg.event_cards:
		var mod := SentimentModifier.from_environment(env_card)
		StockManager.apply_sentiment_modifier(mod)

## ── 按钮事件 ──────────────────────────────────────────────────────────

func _on_gather_pressed() -> void:
	_player_actor.try_gather_material({})

func _on_craft_pressed() -> void:
	var materials: Array[MaterialCardData] = [_mat_expose, _mat_data]
	var methods: Array[WritingMethodCardData] = [_method_deep_dig]
	var article := _player_actor.try_craft_article(materials, methods, turn_manager.turn_number)
	if article:
		## 设置文章的目标行业（素材都是科技行业）
		article.target_industry = _tag_tech

func _on_publish_pressed() -> void:
	if _player_state.draft_articles.is_empty():
		_log("[color=red]  没有可发表的草稿[/color]")
		return
	var article: Article = _player_state.draft_articles[-1]
	_player_actor.publish_article(article, Enums.Channel.SELF_MEDIA, {})
	_player_state.draft_articles.erase(article)

	## 文章发表 → 创建情绪修改器 → 分发到市场
	var mod := SentimentModifier.from_article(article)
	StockManager.apply_sentiment_modifier(mod)
	_log("[color=yellow]  情绪修改器已分发：目标行业=%s | 值=%+d | 持续=%d[/color]" % [
		"Tech" if article.target_industry else "无", mod.value, mod.remaining_turns])

func _on_price_mod_pressed() -> void:
	## 宏观价格修改器：全市场价格 ×0.95（target_stock_ids 和 target_industry 都为空 → 宏观级）
	var mod := PriceModifier.create(
		&"test_macro_shock", &"card", [], &"multiply", 0.95)
	StockManager.apply_price_modifier(mod)
	_stock_log("[color=orange]宏观价格修改器：全市场 ×0.95[/color]")

func _on_end_turn_pressed() -> void:
	_log("[color=gray]  → 玩家点击结束回合[/color]")
	GameBus.player_ended_turn.emit()

## ── Actor 回合事件 ────────────────────────────────────────────────────

func _on_actor_turn_started(actor_type: Enums.ActorType) -> void:
	var is_player := actor_type == Enums.ActorType.PLAYER
	gather_button.disabled = not is_player
	craft_button.disabled = not is_player
	publish_button.disabled = not is_player
	price_mod_button.disabled = not is_player
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
			_update_stock_display()

func _on_actor_turn_ended(actor_type: Enums.ActorType) -> void:
	gather_button.disabled = true
	craft_button.disabled = true
	publish_button.disabled = true
	price_mod_button.disabled = true
	end_turn_button.disabled = true
	match actor_type:
		Enums.ActorType.WORLD:
			_log("[color=yellow]【世界回合】结束[/color]")
		Enums.ActorType.PLAYER:
			_log("[color=green]【玩家回合】结束[/color]")

## ── 股票面板显示 ────────────────────────────────────────────────────────

func _update_stock_display() -> void:
	var text := ""
	for stock: Stock in StockManager.get_all_stocks():
		var sentiment := stock.get_sentiment()
		var s_color := "green" if sentiment > 0 else ("red" if sentiment < 0 else "white")
		var price_change := ""
		if not stock.price_history.is_empty():
			var prev: float = stock.price_history[-1]
			var delta := stock.current_price - prev
			var p_color := "green" if delta >= 0 else "red"
			price_change = " [color=%s](%+.2f)[/color]" % [p_color, delta]

		var status := ""
		if stock.is_delisted:
			status = " [color=red][已退市][/color]"

		text += "[b]%s[/b] (%s)%s\n" % [stock.def.name, stock.def.industry.name, status]
		text += "  价格：[b]%.2f[/b]%s\n" % [stock.current_price, price_change]
		text += "  情绪：[color=%s][b]%+d[/b][/color]  波动性：%s\n" % [
			s_color, sentiment, Enums.Volatility.keys()[stock.def.volatility]]

		var mods := stock.get_modifiers()
		if not mods.is_empty():
			text += "  修改器：\n"
			for mod in mods:
				text += "    · %s %+d（剩余 %d 回合）\n" % [mod.source_id, mod.value, mod.remaining_turns]
		text += "\n"

	stock_info_box.text = ""
	stock_info_box.append_text(text if not text.is_empty() else "（无股票数据）")

## ── 工具方法 ──────────────────────────────────────────────────────────

func _log(text: String) -> void:
	log_box.append_text(text + "\n")

func _stock_log(text: String) -> void:
	stock_log_box.append_text(text + "\n")

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
