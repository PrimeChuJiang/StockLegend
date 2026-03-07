## 环境事件卡定义，继承自插件的 ItemData。
## 描述一个市场效果"是什么"：情绪强度、持续时间、影响范围。
## 不包含任何调度信息（何时出现、叫什么名字）——那是 ScheduleEventConfig 的职责。
##
## 注意：
## - tier（MACRO/INDUSTRY/COMPANY）通过 tags 中的 Event.* 标签表达
## - target_industry 通过 tags 中的 Industry.* 标签表达
## - id / name / description / image 使用 ItemData 已有字段
## - name 为揭示后的卡牌正式名称（如"央行加息"）
class_name EnviromentCardData
extends ItemData

## 目标公司股票 ID，仅当 tier = COMPANY 时有效，其余留空
@export var target_company: StringName = &""

## 情绪修改值：正数利好，负数利空
@export var sentiment_modifier: int = 0

## 效果持续回合数
@export var duration: int = 1

## 是否允许玩家将此事件引用为临时素材卡
@export var can_be_referenced: bool = false
