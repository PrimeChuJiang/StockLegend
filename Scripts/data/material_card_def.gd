## 素材卡定义（不可变）
class_name MaterialCardDef
extends Resource

## 卡牌唯一标识
@export var card_id: StringName
## 卡牌显示名称
@export var card_name: String
## 素材类型
@export var material_type: Enums.MaterialType
## 品质：1=普通, 2=劲爆, 3=核弹级
@export_range(1, 3) var quality: int = 1
## 议题标签
@export var topic: Enums.Topic = Enums.Topic.NONE

## 简短描述
func brief() -> String:
	return "%s%s(%s)" % [Enums.material_name(material_type), Enums.quality_stars(quality), Enums.topic_name(topic)]
