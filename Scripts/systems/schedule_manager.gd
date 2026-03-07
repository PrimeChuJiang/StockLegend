## 日程管理器，游戏开始时读取配置、动态生成本局日程。
## 作为 Node 存在于场景中，@export 字段在编辑器 Inspector 内配置。
##
## 使用方式：
##   var schedule := $ScheduleManager.generate()
##   turn_manager.setup({"schedule": schedule, ...})
##
## 生成算法：
##   1. 对候选池按权重加权随机排序
##   2. 打乱可用回合列表（1 ~ game_turns）
##   3. 将每个事件分配到满足 earliest_turn 的最早空闲回合
##   4. 非 repeatable 事件分配后从可用回合中移除
class_name ScheduleManager
extends Node

## 日程事件候选池（在编辑器中配置 ScheduleEventConfig 资源）
@export var scheduled_pool: Array[ScheduleEventConfig] = []

## 突发事件候选池
@export var breaking_pool: Array[ScheduleEventConfig] = []

## 本局游戏总回合数（决定日程分布范围）
@export var game_turns: int = 10

## 每回合触发突发事件的基础概率（0.0 ~ 1.0）
@export_range(0.0, 1.0, 0.05) var breaking_chance: float = 0.2

## 生成本局日程，返回只读的 ScheduleData。
## 每次调用结果都不同（随机生成）。
func generate() -> ScheduleData:
	var data := ScheduleData.new()
	data._breaking_pool = breaking_pool.duplicate()
	data._breaking_chance = breaking_chance

	# 构建并打乱可用回合列表
	var available: Array[int] = []
	for t in range(1, game_turns + 1):
		available.append(t)
	available.shuffle()

	# 对候选池做加权随机排序，保证权重高的事件优先被安排
	var pool_to_place := _weighted_sort(scheduled_pool.duplicate())

	for event_config: ScheduleEventConfig in pool_to_place:
		# 找出所有满足 earliest_turn 的空闲回合
		var valid: Array[int] = available.filter(
			func(t: int) -> bool: return t >= event_config.earliest_turn)
		if valid.is_empty():
			push_warning("[ScheduleManager] 无法为事件「%s」找到合适的回合，已跳过" % event_config.reveal_name)
			continue
		# available 已 shuffle，取第一个 valid 即为随机结果
		var chosen: int = valid[0]
		var event_list : Array[ScheduleEventConfig]= data._slots.get(chosen, [] as Array[ScheduleEventConfig])
		event_list.append(event_config)
		data._slots[chosen] = event_list
		if not event_config.repeatable:
			available.erase(chosen)

	_print_schedule(data)
	return data

## ── 内部工具 ──────────────────────────────────────────────────────────

## 对事件列表按权重做加权随机排序：权重高的排在前面（概率意义上）。
func _weighted_sort(pool: Array[ScheduleEventConfig]) -> Array[ScheduleEventConfig]:
	var result: Array[ScheduleEventConfig] = []
	var remaining := pool.duplicate()
	while not remaining.is_empty():
		var chosen := _pick_by_weight(remaining)
		result.append(chosen)
		remaining.erase(chosen)
	return result

## 从列表中按权重随机抽取一个事件。
func _pick_by_weight(pool: Array[ScheduleEventConfig]) -> ScheduleEventConfig:
	var total := 0.0
	for e: ScheduleEventConfig in pool:
		total += e.weight
	var roll := randf() * total
	var cumulative := 0.0
	for e: ScheduleEventConfig in pool:
		cumulative += e.weight
		if roll <= cumulative:
			return e
	return pool[-1]

## 打印本局日程，用于调试。
func _print_schedule(data: ScheduleData) -> void:
	print("[ScheduleManager] 本局日程生成完毕（共 %d 个事件）：" % data.get_total_schedules())
	for turn: int in data.get_scheduled_turns():
		var configs: Array[ScheduleEventConfig] = data._slots[turn]
		for config in configs:
			print("  回合 %d → 「%s」（揭示后：%s，触发 %d 张环境牌）" % [
				turn, config.preview_name, config.reveal_name, config.event_cards.size()])
