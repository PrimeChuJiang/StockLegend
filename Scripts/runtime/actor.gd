## 行动者基类，代表游戏中任何能在回合内行动的参与者。
## 子类：WorldStartActor（世界头）、PlayerActor（玩家）、AIActor（未来）、WorldEndActor（世界尾）。
## 不要直接实例化此类。
class_name Actor
extends RefCounted

## 行动者唯一标识
var actor_id: StringName
## 行动者类型枚举
var actor_type: Enums.ActorType

## 执行本行动者的一个完整回合。
## 世界行动者：自动按阶段执行后返回。
## 玩家行动者：await 玩家结束信号后返回。
## ctx 包含场景树引用等系统资源。
func execute_turn(_ctx: Dictionary) -> void:
	pass
