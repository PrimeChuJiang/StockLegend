## 回合系统，整个游戏流程的核心驱动器。
## 基于可配置的阶段序列实现状态机，支持动态插入和移除阶段。
## 默认阶段序列：TURN_START → DRAW → MAIN → TURN_END → CLEANUP
class_name TurnSystem
extends Node

## 阶段开始时发出
signal phase_started(phase: Enums.Phase)
## 阶段结束时发出
signal phase_ended(phase: Enums.Phase)
## 回合开始时发出
signal turn_started(turn_number: int)
## 回合结束时发出
signal turn_ended(turn_number: int)

## 当前回合编号，从 1 开始
var turn_number: int = 0
## 当前正在执行的阶段
var current_phase: Enums.Phase
## 阶段执行序列，可通过 insert_phase_before/after 和 remove_phase 动态修改
var phase_sequence: Array[Enums.Phase] = [
	Enums.Phase.TURN_START,
	Enums.Phase.DRAW,
	Enums.Phase.MAIN,
	Enums.Phase.TURN_END,
	Enums.Phase.CLEANUP,
]

## 区域管理器引用，由外部注入
var zone_manager: CardZoneManager
## 效果结算器引用，由外部注入
var effect_resolver: EffectResolver


## 执行一个完整回合：按序遍历所有阶段，每个阶段前后广播信号。
## 包含 await，需在异步上下文中调用。
func execute_turn() -> void:
	turn_number += 1
	turn_started.emit(turn_number)
	GameBus.turn_started.emit(turn_number)
	for phase in phase_sequence:
		current_phase = phase
		phase_started.emit(phase)
		GameBus.phase_started.emit(phase)
		await _process_phase(phase)
		phase_ended.emit(phase)
		GameBus.phase_ended.emit(phase)
	turn_ended.emit(turn_number)
	GameBus.turn_ended.emit(turn_number)


## 出牌入口：校验阶段合法性 → 校验费用 → 扣费 → 执行卡牌逻辑 → 广播信号。
## 返回 true 表示出牌成功，false 表示被拒绝（阶段不允许或费用不足）。
func play_card(card: CardItem, player: PlayerState) -> bool:
	if not card.can_play_at_phase(current_phase):
		print("[TurnSystem] Card '%s' cannot be played in current phase." % card.data.name)
		return false
	var cost := card.get_stat(Enums.StatKey.COST)
	if player.energy < cost:
		print("[TurnSystem] Not enough energy to play '%s'. Need %d, have %d." % [
			card.data.name, cost, player.energy])
		return false
	player.energy -= cost
	var ctx := _build_context()
	card.execute(ctx)
	GameBus.card_played.emit(card)
	print("[TurnSystem] Played card '%s'." % card.data.name)
	return true


## 处理单个阶段的默认行为。
## DRAW：抽一张牌；MAIN：等待玩家操作完毕；TURN_END：结算场地牌效果；CLEANUP：清理过期修改器。
func _process_phase(phase: Enums.Phase) -> void:
	match phase:
		Enums.Phase.DRAW:
			zone_manager.draw_card()
		Enums.Phase.MAIN:
			GameBus.main_phase_entered.emit()
			await GameBus.main_phase_finished
		Enums.Phase.TURN_END:
			_resolve_field_effects()
		Enums.Phase.CLEANUP:
			_cleanup_modifiers()


## 结算所有场地区域卡牌的 ON_TURN_END 效果。
## 先复制场地卡牌列表再遍历，避免效果执行过程中修改列表导致迭代异常。
func _resolve_field_effects() -> void:
	var ctx := _build_context()
	var field_cards := zone_manager.get_cards_in_zone(Enums.Zone.FIELD).duplicate()
	for card: CardItem in field_cards:
		effect_resolver.resolve_effects(card, Enums.EffectTrigger.ON_TURN_END, ctx)


## 对所有区域的所有卡牌执行修改器 tick，移除已过期的修改器。
func _cleanup_modifiers() -> void:
	var all_cards := zone_manager.get_all_cards()
	for card: CardItem in all_cards:
		card.tick_modifiers()


## 构建上下文字典，传递给 card.execute(ctx) 和 effect handler。
## 使卡牌逻辑可以访问系统引用而无需直接依赖。
func _build_context() -> Dictionary:
	return {
		"zone_manager": zone_manager,
		"effect_resolver": effect_resolver,
		"turn_system": self,
	}


## 在指定锚点阶段之后插入一个新阶段。
func insert_phase_after(anchor: Enums.Phase, new_phase: Enums.Phase) -> void:
	var idx := phase_sequence.find(anchor)
	if idx >= 0:
		phase_sequence.insert(idx + 1, new_phase)


## 在指定锚点阶段之前插入一个新阶段。
func insert_phase_before(anchor: Enums.Phase, new_phase: Enums.Phase) -> void:
	var idx := phase_sequence.find(anchor)
	if idx >= 0:
		phase_sequence.insert(idx, new_phase)


## 从阶段序列中移除指定阶段。
func remove_phase(phase: Enums.Phase) -> void:
	phase_sequence.erase(phase)
