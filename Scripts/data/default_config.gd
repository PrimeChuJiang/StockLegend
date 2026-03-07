## 全局默认配置，提供游戏参数的统一访问入口。
## 回合阶段配置已迁移至各 Actor 内部，此处只保留通用参数。
class_name DefaultConfig
extends Object

static var _instance: DefaultConfig = null

func _init() -> void:
	if _instance != null:
		return
	_instance = self

static func get_instance() -> DefaultConfig:
	if _instance == null:
		_instance = DefaultConfig.new()
	return _instance
