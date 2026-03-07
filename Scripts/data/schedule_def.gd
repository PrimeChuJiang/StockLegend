## 日程信息的可配置数据类，由ScheduleSystem进行管理，包含以下字段：
## 1. 事件未开启时显示名称
## 2. 事件开启后显示名称
## 3. 事件描述
## 4. 事件效果
class_name ScheduleData
extends ItemData

## 事件未开启时显示名称
@export var name_unopened: String = ""
## 事件开启后显示名称
@export var name_opened: String = ""
## 事件未开启时描述
@export var description_unopened: String = ""
## 事件开启后描述
@export var description_opened: String = ""
## 事件影响力
@export var impact: int = 0
## 事件持续时间
@export var duration: int = 0
# ## 事件效果
# @export var effect: Array[WritingMethodBehaviour] = []

## 获取当前事件未开启时显示名称
func get_schedule_unopened_name() -> String:
	return name_unopened

## 获取当前事件开启后显示名称
func get_shedule_opened_name() -> String:
	return name_opened

## 获取当前事件未开启时描述
func get_schedule_unopened_description() -> String:
	return description_unopened

## 获取当前事件开启后描述
func get_schedule_opened_description() -> String:
	return description_opened

## 获取事件效果列表
func get_schedule_effect() -> Array[WritingMethodBehaviour]:
	return behaviours.filter(func(b): return b is WritingMethodBehaviour)
