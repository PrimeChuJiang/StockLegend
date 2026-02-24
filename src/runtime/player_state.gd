## 玩家运行时状态，存储生命值、能量等可变数据。
class_name PlayerState
extends RefCounted

## 玩家唯一标识
var player_id: int
## 当前生命值
var hp: int = 30
## 当前可用能量（每回合用于支付卡牌费用）
var energy: int = 0
## 能量上限
var max_energy: int = 0
