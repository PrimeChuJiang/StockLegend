## 效果定义资源，声明式描述一个效果"做什么"和"何时触发"。
## 不包含执行逻辑，实际执行由 EffectResolver 的注册表处理。
class_name EffectDef
extends Resource

## 效果标识符，映射到 EffectResolver 中注册的处理函数
@export var effect_id: StringName
## 效果触发时机
@export var trigger: Enums.EffectTrigger
## 效果参数字典，如 {"damage": 8} 或 {"count": 2, "duration": 3}
@export var params: Dictionary
