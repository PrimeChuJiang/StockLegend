## 世界行动者，负责每回合开始时的全局阶段：揭示日程事件、结算突发事件。
## 所有阶段自动执行，无需玩家输入。
## 使用 ctx["scene_tree"] 来添加阶段间延迟，使 UI 有时间渲染。
class_name WorldStartActor
extends Actor

func _init() -> void:
	actor_id = &"world"
	actor_type = Enums.ActorType.WORLD

## 按顺序执行世界的所有阶段，完成后返回。
func execute_turn(ctx: Dictionary) -> void:
	GameBus.actor_turn_started.emit(Enums.ActorType.WORLD)
	print("[WorldStartActor] 世界回合开始")

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

	## 等待一帧，让 UI 渲染当前阶段状态
	var tree: SceneTree = ctx.get("scene_tree")
	if tree:
		await tree.create_timer(0.6).timeout

	GameBus.world_start_phase_ended.emit(phase)
	print("[WorldStartActor] 阶段结束: %s" % Enums.WorldPhase.keys()[phase])

## 揭示本回合的日程表事件，发出 event_revealed 信号。
## TODO: 从事件牌库按回合索引取牌并公开。
func _reveal_events(_ctx: Dictionary) -> void:
	print("[WorldStartActor]   → 揭示本回合日程事件（暂无数据，跳过）")
	## GameBus.event_revealed.emit(event_def)

## 检查并触发突发事件，发出 breaking_event_triggered 信号。
## TODO: 根据概率或条件判断是否触发突发事件。
func _resolve_breaking(_ctx: Dictionary) -> void:
	print("[WorldStartActor]   → 检查突发事件（暂无数据，跳过）")
	## GameBus.breaking_event_triggered.emit(event_def)
