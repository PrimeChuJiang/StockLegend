## 测试脚本：模拟一个完整的回合流程。
## 创建包含三种类型的测试卡牌，执行一个回合，验证各系统协作是否正确。
## 所有输出通过 print() 打印到 Godot 的 Output 面板。
extends Node

# @onready var turn_system: TurnSystem = $TurnSystem
# @onready var zone_manager: CardZoneManager = $CardZoneManager
# @onready var effect_resolver: EffectResolver = $EffectResolver

# var player: PlayerState


# ## 入口：依次初始化信号监听、系统引用、玩家状态、测试牌库，然后运行测试。
# func _ready() -> void:
# 	_connect_signals()
# 	_setup_systems()
# 	_setup_player()
# 	_setup_deck()
# 	_run_test()


# ## 连接 GameBus 上的各类信号，将事件以可读格式打印到控制台。
# func _connect_signals() -> void:
# 	GameBus.turn_started.connect(func(n: int) -> void:
# 		print("\n========== TURN %d START ==========" % n))
# 	GameBus.turn_ended.connect(func(n: int) -> void:
# 		print("========== TURN %d END ==========\n" % n))
# 	GameBus.phase_started.connect(func(phase: Enums.Phase) -> void:
# 		print("--- Phase: %s ---" % Enums.Phase.keys()[phase]))
# 	GameBus.card_played.connect(func(card: CardItem) -> void:
# 		print("  >> Card played: %s [%s]" % [
# 			card.data.name, Enums.CardType.keys()[card.get_card_type()]]))
# 	GameBus.card_zone_changed.connect(func(card: CardItem, from: Enums.Zone, to: Enums.Zone) -> void:
# 		print("  Card '%s' moved: %s -> %s" % [
# 			card.data.name,
# 			Enums.Zone.keys()[from],
# 			Enums.Zone.keys()[to]]))
# 	GameBus.damage_dealt.connect(func(source: CardItem, _target: Variant, amount: int) -> void:
# 		print("  !! Damage dealt: %d (from %s)" % [amount, source.data.name]))
# 	GameBus.modifier_added.connect(func(card: CardItem, mod: Modifier) -> void:
# 		print("  + Modifier added to '%s': %s %s %s (duration: %d)" % [
# 			card.data.name,
# 			Enums.StatKey.keys()[mod.stat_key],
# 			Enums.ModifierOp.keys()[mod.op],
# 			str(mod.value),
# 			mod.duration]))
# 	GameBus.modifier_removed.connect(func(card: CardItem, mod: Modifier) -> void:
# 		print("  - Modifier expired on '%s': %s" % [
# 			card.data.name,
# 			Enums.StatKey.keys()[mod.stat_key]]))


# ## 注入系统间的互相引用：TurnSystem 需要 CardZoneManager 和 EffectResolver，
# ## EffectResolver 需要 CardZoneManager。
# func _setup_systems() -> void:
# 	turn_system.zone_manager = zone_manager
# 	turn_system.effect_resolver = effect_resolver
# 	effect_resolver.zone_manager = zone_manager


# ## 初始化测试玩家：30 生命值，5 点能量。
# func _setup_player() -> void:
# 	player = PlayerState.new()
# 	player.player_id = 1
# 	player.hp = 30
# 	player.energy = 5
# 	player.max_energy = 5


# ## 构建测试牌库：创建 5 张不同类型的卡牌定义，通过 zone_manager.create_card() 放入牌库。
# func _setup_deck() -> void:
# 	# --- Normal card: Fireball (deal 8 damage, cost 2) ---
# 	var fireball_data := CardItemData.new()
# 	fireball_data.id = "fireball"
# 	fireball_data.name = "Fireball"
# 	fireball_data.max_stack = 1
# 	fireball_data.card_type = Enums.CardType.NORMAL
# 	fireball_data.base_stats = { Enums.StatKey.COST: 2, Enums.StatKey.ATTACK: 0 }
# 	fireball_data.target_type = Enums.TargetType.NONE
# 	var fireball_fx := EffectDef.new()
# 	fireball_fx.effect_id = &"deal_damage"
# 	fireball_fx.trigger = Enums.EffectTrigger.ON_PLAY
# 	fireball_fx.params = { "damage": 8 }
# 	fireball_data.effects = [fireball_fx]

# 	# --- Instant card: Quick Heal (heal 5, cost 1) ---
# 	var heal_data := CardItemData.new()
# 	heal_data.id = "heal"
# 	heal_data.name = "Quick Heal"
# 	heal_data.max_stack = 1
# 	heal_data.card_type = Enums.CardType.INSTANT
# 	heal_data.base_stats = { Enums.StatKey.COST: 1 }
# 	heal_data.target_type = Enums.TargetType.NONE
# 	var heal_fx := EffectDef.new()
# 	heal_fx.effect_id = &"heal"
# 	heal_fx.trigger = Enums.EffectTrigger.ON_PLAY
# 	heal_fx.params = { "amount": 5 }
# 	heal_data.effects = [heal_fx]

# 	# --- Field card: War Banner (draw 1 card each turn end, cost 3) ---
# 	var banner_data := CardItemData.new()
# 	banner_data.id = "banner"
# 	banner_data.name = "War Banner"
# 	banner_data.max_stack = 1
# 	banner_data.card_type = Enums.CardType.FIELD
# 	banner_data.base_stats = { Enums.StatKey.COST: 3 }
# 	banner_data.target_type = Enums.TargetType.NONE
# 	var banner_fx := EffectDef.new()
# 	banner_fx.effect_id = &"draw_cards"
# 	banner_fx.trigger = Enums.EffectTrigger.ON_TURN_END
# 	banner_fx.params = { "count": 1 }
# 	banner_data.effects = [banner_fx]

# 	# --- Extra card for modifier test ---
# 	var shield_data := CardItemData.new()
# 	shield_data.id = "shield"
# 	shield_data.name = "Magic Shield"
# 	shield_data.max_stack = 1
# 	shield_data.card_type = Enums.CardType.NORMAL
# 	shield_data.base_stats = { Enums.StatKey.COST: 1, Enums.StatKey.DEFENSE: 5 }
# 	shield_data.target_type = Enums.TargetType.NONE
# 	shield_data.effects = []

# 	# --- Extra filler card ---
# 	var filler_data := CardItemData.new()
# 	filler_data.id = "filler"
# 	filler_data.name = "Filler Card"
# 	filler_data.max_stack = 1
# 	filler_data.card_type = Enums.CardType.NORMAL
# 	filler_data.base_stats = { Enums.StatKey.COST: 0 }
# 	filler_data.target_type = Enums.TargetType.NONE
# 	filler_data.effects = []

# 	# Create runtime instances and add to deck via CardZoneManager
# 	var datas: Array[CardItemData] = [fireball_data, heal_data, banner_data, shield_data, filler_data]
# 	for card_data in datas:
# 		zone_manager.create_card(card_data, Enums.Zone.DECK)

# 	print("=== DECK INITIALIZED (%d cards) ===" % zone_manager.get_cards_in_zone(Enums.Zone.DECK).size())


# ## 启动测试：监听主阶段进入信号，然后执行一个完整回合，最后打印最终状态。
# func _run_test() -> void:
# 	GameBus.main_phase_entered.connect(_on_main_phase)
# 	await turn_system.execute_turn()
# 	_print_final_state()


# ## 主阶段回调：模拟玩家操作——尝试打出手中所有卡牌，测试修改器系统，然后结束主阶段。
# func _on_main_phase() -> void:
# 	print("\n  [Player] Main phase - playing cards...")
# 	print("  [Player] Energy: %d/%d" % [player.energy, player.max_energy])

# 	var hand: Array[CardItem] = zone_manager.get_cards_in_zone(Enums.Zone.HAND)
# 	print("  [Player] Hand: %s" % _card_names(hand))

# 	# Play all playable cards from hand
# 	var cards_to_play: Array[CardItem] = hand.duplicate()
# 	for card: CardItem in cards_to_play:
# 		turn_system.play_card(card, player)

# 	print("  [Player] Remaining energy: %d" % player.energy)
# 	print("  [Player] Hand after playing: %s" % _card_names(
# 		zone_manager.get_cards_in_zone(Enums.Zone.HAND)))

# 	# Test modifier system
# 	print("\n  [Test] Modifier test:")
# 	var field_cards: Array[CardItem] = zone_manager.get_cards_in_zone(Enums.Zone.FIELD)
# 	if not field_cards.is_empty():
# 		var test_card: CardItem = field_cards[0]
# 		var mod := Modifier.new()
# 		mod.stat_key = Enums.StatKey.ATTACK
# 		mod.op = Enums.ModifierOp.ADD
# 		mod.value = 5.0
# 		mod.duration = 2
# 		test_card.add_modifier(mod)
# 		print("  [Test] '%s' ATTACK before modifier: base=%d, with mod=%d" % [
# 			test_card.data.name,
# 			test_card.get_card_data().base_stats.get(Enums.StatKey.ATTACK, 0),
# 			test_card.get_stat(Enums.StatKey.ATTACK)])

# 	# End main phase
# 	print("\n  [Player] Ending main phase.")
# 	GameBus.main_phase_finished.emit()


# ## 打印回合结束后的最终状态：各区域卡牌分布和玩家数据。
# func _print_final_state() -> void:
# 	print("\n=== FINAL STATE ===")
# 	for zone_value in Enums.Zone.values():
# 		var cards: Array[CardItem] = zone_manager.get_cards_in_zone(zone_value)
# 		if not cards.is_empty():
# 			print("  %s: %s" % [Enums.Zone.keys()[zone_value], _card_names(cards)])
# 	print("  Player HP: %d, Energy: %d/%d" % [player.hp, player.energy, player.max_energy])
# 	print("===================")


# ## 工具方法：将卡牌数组转为逗号分隔的名称字符串，用于日志输出。
# func _card_names(cards: Array[CardItem]) -> String:
# 	var names: PackedStringArray = []
# 	for card: CardItem in cards:
# 		names.append(card.data.name)
# 	return ", ".join(names) if not names.is_empty() else "(empty)"
