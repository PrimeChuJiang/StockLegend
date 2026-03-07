## 回合管理器，驱动整个游戏的行动者轮次循环。
## 持有一个有序的 actors 数组，每回合依次调用每个行动者的 execute_turn()。
## 行动者顺序即行动顺序，默认为：WorldStartActor → PlayerActor → （未来）AIActor → WorldEndActor。
##
## 使用方式：
##   turn_manager.actors = [world_actor, player_actor]
##   turn_manager.setup(ctx)
##   turn_manager.start_game()
class_name TurnManager
extends Node

## 当前回合编号，从 1 开始
var turn_number: int = 0

## 行动者列表，按行动顺序排列。由外部（场景脚本）在 start_game() 前赋值。
var actors: Array[Actor] = []

## 上下文字典，透传给每个行动者的 execute_turn()
var _ctx: Dictionary = {}

## 设置上下文（需在 start_game() 前调用）
func setup(ctx: Dictionary) -> void:
	_ctx = ctx

## 启动游戏循环（在 _ready 完成后调用）
func start_game() -> void:
	_game_loop()

## 主循环：无限轮转所有行动者。
## 每个 await 会挂起协程，让 Godot 主线程继续渲染，玩家回合期间不会卡死。
func _game_loop() -> void:
	while true:
		turn_number += 1
		GameBus.turn_started.emit(turn_number)
		print("\n========== 回合 %d 开始 ==========" % turn_number)

		for actor: Actor in actors:
			await actor.execute_turn(_ctx)

		GameBus.turn_ended.emit(turn_number)
		print("========== 回合 %d 结束 ==========\n" % turn_number)
