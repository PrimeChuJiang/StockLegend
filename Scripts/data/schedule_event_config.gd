## 日程事件配置，描述"这个事件是什么"。
## 这是静态配置数据（.tres 文件），由策划在编辑器中填写，不包含任何调度逻辑。
##
## 与 EnviromentCardData 的关系：
##   一个 ScheduleEventConfig = 玩家看到的"一个日程格子"
##   它触发时会生成一张或多张 EnviromentCardData，作用于市场
##   EnviromentCardData 只管效果，不知道自己在什么日程上
class_name ScheduleEventConfig
extends Resource

## 未揭示时在日程表上显示的名称（牌面朝下时）
@export var preview_name: String = "???"

## 揭示后显示的正式名称
@export var reveal_name: String = "市场事件"

## 触发时生效的环境牌列表（一个日程事件可触发多张环境牌）
@export var event_cards: Array[EnviromentCardData] = []

## 抽取权重，越高越容易被 ScheduleManager 选入本局日程
@export var weight: float = 1.0

## 最早出现回合：ScheduleManager 不会将此事件安排在早于此值的回合
@export var earliest_turn: int = 1

## 是否可在同一局内重复出现（true = 被安排后仍留在候选池）
@export var repeatable: bool = false
