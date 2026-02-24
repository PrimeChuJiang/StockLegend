## 属性修改器，附加到卡牌上对其属性进行临时或永久修改。
## 通过 CardItem.add_modifier() 添加，在 CLEANUP 阶段自动 tick 并移除过期的修改器。
class_name Modifier
extends RefCounted

## 要修改的属性键
var stat_key: Enums.StatKey
## 修改运算方式：ADD 加法 / MULTIPLY 乘法 / SET 直接覆盖
var op: Enums.ModifierOp
## 修改值
var value: float
## 剩余持续回合数，-1 表示永久生效
var duration: int = -1
## 施加此修改器的来源卡牌 instance_id，-1 表示无来源
var source_id: int = -1


## 每回合 CLEANUP 阶段调用一次。递减 duration，返回 true 表示已过期需移除。
## 永久修改器（duration == -1）不受影响。
func tick() -> bool:
	if duration > 0:
		duration -= 1
	return duration == 0
