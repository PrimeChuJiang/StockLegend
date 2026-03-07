## 世界行动者（回合头），负责每回合开始时的全局阶段。
## 阶段顺序：REVEAL_EVENTS → RESOLVE_BREAKING
## 所有阶段自动执行，无需玩家输入。
##
## ctx 所需字段：
##   ctx["scene_tree"]  : SceneTree   — 用于阶段间计时延迟
##   ctx["turn_number"] : int         — 当前回合编号，用于查询日程
##   ctx["schedule"]    : ScheduleData (可选) — 无则跳过事件揭示
class_name WorldStartActor
extends Actor

func _init() -> void:
	actor_id = &"world_start"
	actor_type = Enums.ActorType.WORLD

## 按顺序执行世界回合头的所有阶段，完成后返回。
func execute_turn(ctx: Dictionary) -> void:
	GameBus.actor_turn_started.emit(Enums.ActorType.WORLD)
	print("[WorldStartActor] 世界回合开始（回合 %d）" % ctx.get("turn_number", 0))

	await _run_phase(Enums.WorldPhase.REVEAL_EVENTS, ctx)
	await _run_phase(Enums.WorldPhase.RESOLVE_BREAKING, ctx)

	print("[WorldStartActor] 世界回合结束")
	GameBus.actor_turn_ended.emit(Enums.ActorType.WORLD)

## 执行单个世界阶段：发信号 → 执行逻辑 → 短暂停顿 → 发结束信号。
func _run_phase(phase: Enums.WorldPhase, ctx: Dictionary) -> void:
	GameBus.world_start_phase_started.emit(phase)
	print("[WorldStartActor] 阶段开始: %s" % Enums.WorldPhase.keys()[phase])

	match phase:
		Enums.WorldPhase.REVEAL_EVENTS:
			_reveal_events(ctx)
		Enums.WorldPhase.RESOLVE_BREAKING:
			_resolve_breaking(ctx)

	var tree: SceneTree = ctx.get("scene_tree")
	if tree:
		await tree.create_timer(0.6).timeout

	GameBus.world_start_phase_ended.emit(phase)
	print("[WorldStartActor] 阶段结束: %s" % Enums.WorldPhase.keys()[phase])

## 揭示本回合的日程事件。
## 从 ScheduleData 按回合编号取事件，发出 event_revealed 信号供 UI 翻牌动画使用。
func _reveal_events(ctx: Dictionary) -> void:
	var turn: int = ctx.get("turn_number", 0)		
	var schedule: ScheduleData = ctx.get("schedule")
	if schedule == null:
		print("[WorldStartActor]   → 无日程数据，跳过")
		return
	## 预告未来 5 回合的日程事件
	elif turn % 5 == 1:
		var future_events: Dictionary = schedule.get_events_in_range(turn, turn+4)
		GameBus.events_showed.emit(turn, turn + 4, future_events)
		future_events.sort()
		print("[WorldStartActor]   → 预告未来五回合日程:")
		for _index_turn in range(turn, turn+4):
			if future_events.has(_index_turn):
				for event in future_events[_index_turn]:
					print("[WorldStartActor]   → 第 %d 回合: 「%s」" % [_index_turn, event.preview_name])
			else:
				print("[WorldStartActor]   → 第 %d 回合：无日程事件" % _index_turn)
			_index_turn += 1

	var event_configs: Array[ScheduleEventConfig] = schedule.get_event_for_turn(turn)
	if not event_configs.is_empty():
		for event in event_configs:
			print("[WorldStartActor]   → 揭示日程事件: 「%s」" % event.reveal_name)
			GameBus.event_revealed.emit(event)
	else:
		print("[WorldStartActor]   → 第 %d 回合无日程事件" % turn)

## 检查并触发突发事件。
## 从 ScheduleData 的候选池按概率抽取，发出 breaking_event_triggered 信号。
func _resolve_breaking(ctx: Dictionary) -> void:
	var schedule: ScheduleData = ctx.get("schedule")
	if schedule == null:
		print("[WorldStartActor]   → 无日程数据，跳过")
		return
	var event_config: ScheduleEventConfig = schedule.roll_breaking_event()
	if event_config:
		print("[WorldStartActor]   → 突发事件触发: 「%s」" % event_config.reveal_name)
		GameBus.breaking_event_triggered.emit(event_config)
	else:
		print("[WorldStartActor]   → 本回合无突发事件")
