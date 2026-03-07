## 本局日程运行时数据，由 ScheduleManager.generate() 生成。
## 不是 Resource，不可在编辑器中配置，仅在游戏运行时存在。
##
## WorldStartActor 通过 ctx["schedule"] 获取此对象，
## 调用 get_event_for_turn() / roll_breaking_event() 驱动事件流程。
class_name ScheduleData
extends RefCounted

## 回合 → 日程事件的映射（由 ScheduleManager 写入，外部只读）
## key: int (回合编号，1-based)  value: ScheduleEventConfig
var _slots: Dictionary = {}

## 突发事件候选池（由 ScheduleManager 写入）
var _breaking_pool: Array[ScheduleEventConfig] = []

## 每回合触发突发事件的概率
var _breaking_chance: float = 0.2

## ── 查询接口 ──────────────────────────────────────────────────────────

## 获取指定回合的日程事件，该回合无事件时返回 null。
func get_event_for_turn(turn: int) -> Array[ScheduleEventConfig]:
	var empty_array: Array[ScheduleEventConfig] = []
	return _slots.get(turn, empty_array)

## 获取指定回合区域内的日程时间列表
## TODO: 回合编号从1开始，包含 start_turn 和 end_turn。并且一个回合内可能会有多个事件，需要将Array修改为Dictionary，key为事件类型，value为事件配置。
func get_events_in_range(start_turn: int, end_turn: int) -> Dictionary:
	return _get_slots_in_range(start_turn, end_turn)

## 按概率从突发池随机抽取一个突发事件，未触发或池为空时返回 null。
func roll_breaking_event() -> ScheduleEventConfig:
	if _breaking_pool.is_empty() or randf() > _breaking_chance:
		return null
	return _breaking_pool.pick_random()

## 返回所有已安排事件的回合列表（升序），用于调试/UI预览。
func get_scheduled_turns() -> Array[int]:
	var turns: Array[int] = []
	for t: int in _slots.keys():
		turns.append(t)
	turns.sort()
	return turns

## 返回事件的总数
func get_total_schedules() -> int:
	var ans : int = 0
	for key in _slots.keys():
		var value = _slots.get(key) as Array[ScheduleEventConfig]
		ans += value.size()
	return ans

## ── 内部工具 ──────────────────────────────────────────────────────────

## 获取指定回合区域内的日程事件列表（内部使用）
## 返回值结构：Dictionary[int, Array[ScheduleEventConfig]]
func _get_slots_in_range(start_turn: int, end_turn: int) -> Dictionary:
	if start_turn > 0 and end_turn >= start_turn :
		var slice : Dictionary = {}
		for t in range(start_turn, end_turn + 1):
			if _slots.has(t):
				slice[t] = _slots[t].duplicate()
		return slice
	return {}
