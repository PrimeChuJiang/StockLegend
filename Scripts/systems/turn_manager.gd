## 回合管理器，驱动整个游戏的行动者轮次循环。
## 持有一个有序的 actors 数组，每回合依次调用每个行动者的 execute_turn()。
## 行动者顺序即行动顺序，默认为：WorldStartActor → PlayerActor → （未来）AIActor → WorldEndActor。
##
## 使用方式：
##   turn_manager.actors = [world_start_actor, player_actor]
##   turn_manager.setup({"scene_tree": get_tree(), "schedule": my_schedule})
##   turn_manager.start_game()
class_name TurnManager
extends Node

## 当前回合编号，从 1 开始
var turn_number: int = 0

## 行动者列表，按行动顺序排列。由外部（场景脚本）在 start_game() 前赋值。
var actors: Array[Actor] = []

## 上下文字典，透传给每个行动者的 execute_turn()。
## 每回合开始前自动更新 turn_number 字段。
var _ctx: Dictionary = {}

## 设置上下文（需在 start_game() 前调用）。
## 推荐字段：
##   "scene_tree"  : SceneTree    — 供 Actor 创建定时器
##   "schedule"    : ScheduleData — 供 WorldStartActor 查询事件
func setup(ctx: Dictionary) -> void:
	_ctx = ctx

## 启动游戏循环（在场景 _ready 末尾调用）。
func start_game() -> void:
	_game_loop()

## 主循环：无限轮转所有行动者。
## 每回合开始时将 turn_number 写入 ctx，Actor 可从 ctx["turn_number"] 读取。
func _game_loop() -> void:
	while true:
		turn_number += 1
		_ctx["turn_number"] = turn_number
		GameBus.turn_started.emit(turn_number)
		print("\n========== 回合 %d 开始 ==========" % turn_number)

		for actor: Actor in actors:
			await actor.execute_turn(_ctx)

		GameBus.turn_ended.emit(turn_number)
		print("========== 回合 %d 结束 ==========\n" % turn_number)
