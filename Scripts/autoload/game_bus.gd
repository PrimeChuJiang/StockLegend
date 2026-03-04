## 全局信号总线（AutoLoad 单例）。
## 所有系统间通信的唯一通道，系统之间不直接引用，全部通过此信号总线解耦。
extends Node

# ---- 回合信号 ----
## 回合开始时发出，携带当前回合编号
signal turn_started(turn_number: int)
## 回合结束时发出，携带当前回合编号
signal turn_ended(turn_number: int)
## 阶段开始时发出，携带阶段枚举值
signal phase_started(phase: Enums.Phase)
## 阶段结束时发出，携带阶段枚举值
signal phase_ended(phase: Enums.Phase)

# ---- 阶段控制信号 ----
## 主阶段开始时发出，通知外部（UI/测试）可以开始玩家操作
signal main_phase_entered()
## 主阶段结束信号，由外部发出以通知 TurnSystem 继续执行后续阶段
signal main_phase_finished()

# ---- 卡牌信号 ----
## 卡牌被成功打出时发出
signal card_played(card: CardItem)
## 卡牌在区域间转移时发出，携带来源区域和目标区域
signal card_zone_changed(card: CardItem, from_zone: Enums.Zone, to_zone: Enums.Zone)

# ---- 效果信号 ----
## 造成伤害时发出，携带来源卡牌、目标和伤害数值
signal damage_dealt(source: CardItem, target: Variant, amount: int)
## 治疗生效时发出，携带来源卡牌、目标和治疗数值
signal heal_applied(source: CardItem, target: Variant, amount: int)
## 修改器被添加到卡牌时发出
signal modifier_added(card: CardItem, modifier: Modifier)
## 修改器从卡牌上移除时发出（过期或主动移除）
signal modifier_removed(card: CardItem, modifier: Modifier)
