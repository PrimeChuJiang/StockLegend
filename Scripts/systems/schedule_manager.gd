## 日程系统，负责管理游戏中的事件日程。
## 持有一个序的事件数组，由WorldStartActor进行揭开
## 使用方法：
## 1. 调用create_new_schedule_data()方法创建一个新的日程数据数组
## 2. 从schedule_datas数组中获取事件进行处理
class_name ScheduleSystem
extends Node

var schedule_datas: Array[ScheduleData] = []
var _schedule_csv_path : Resource = preload("res://Scripts/data/csv/schedule.csv")

func _ready():
	_bind_signals()

## 创建一个新的日程数据
func create_new_schedule_data(total_turn_num: int = 20) -> void:
	var schedule_data_array = _schedule_csv_path.records
	for i in range(total_turn_num):
		var rand_index = randi() % schedule_data_array.size()
		var schedule_data = load(schedule_data_array[rand_index].path)
		if schedule_data is ScheduleData:
			schedule_datas.append(schedule_data)

## 获取指定日期的日程数据
func get_schedule_data(turn_int: int) -> ScheduleData:
	return schedule_datas[turn_int]

## 获取指定日期范围的日程数据
func get_schedule_datas(start_turn_int: int, end_turn_int: int) -> Array[ScheduleData]:
	return schedule_datas.slice(start_turn_int, end_turn_int + 1)

## 绑定信号
func _bind_signals():
	## TODO: 处理game_bus内的退市事件，当有公司退市时，需要将其影响的事件替换为无事件
	pass
