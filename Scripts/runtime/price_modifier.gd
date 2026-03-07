## 价格修改器，一次性立即生效，直接修改股票价格。
## 使用 StringName 注册表模式管理运算方式，支持外部注册自定义运算。
##
## 内置运算（按默认优先级排序）：
##   &"add"       (10) — 加法：price + value
##   &"multiply"  (20) — 乘法：price * value
##   &"divide"    (20) — 除法：price / value
##   &"set"       (30) — 直接设置：value
##   &"clamp_min" (40) — 下限钳制：max(price, value)
##   &"clamp_max" (40) — 上限钳制：min(price, value)
##
## 扩展方式：
##   PriceModifier.register_op(&"my_op", func(price, val): return ..., 25)
class_name PriceModifier
extends RefCounted

## 运算注册表：op_name -> Callable(price: float, value: float) -> float
static var _ops: Dictionary = {}
## 默认优先级表：op_name -> int
static var _default_priorities: Dictionary = {}
static var _initialized: bool = false

## 来源卡牌 / 效果 ID
var source_id: StringName
## 来源类型标识：&"card" / &"field_effect" / &"environment"
var source_type: StringName
## 目标股票 ID（公司级定位）
var target_stock_ids: Array[StringName]
## 目标行业标签（行业级定位，null 表示不按行业）
var target_industry: Tag
## 运算方式（注册表中的 key）
var op: StringName
## 运算值
var value: float
## 优先级：数值越小越先执行
var priority: int

## 确保内置运算已注册（惰性初始化）
static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	register_op(&"add", func(price: float, val: float) -> float: return price + val, 10)
	register_op(&"multiply", func(price: float, val: float) -> float: return price * val, 20)
	register_op(&"divide", func(price: float, val: float) -> float:
		return price / val if val != 0.0 else price, 20)
	register_op(&"set", func(_price: float, val: float) -> float: return val, 30)
	register_op(&"clamp_min", func(price: float, val: float) -> float: return maxf(price, val), 40)
	register_op(&"clamp_max", func(price: float, val: float) -> float: return minf(price, val), 40)

## 注册一个新的运算方式，或覆盖已有运算。
## op_name         : 运算标识
## fn              : Callable(current_price: float, value: float) -> float
## default_priority: 使用此运算时的默认优先级
static func register_op(op_name: StringName, fn: Callable, default_priority: int = 50) -> void:
	_ops[op_name] = fn
	_default_priorities[op_name] = default_priority

## 对给定价格执行本修改器的运算，返回修改后的价格。
func apply(current_price: float) -> float:
	_ensure_initialized()
	if _ops.has(op):
		return _ops[op].call(current_price, value)
	push_warning("PriceModifier: 未知运算 '%s'，跳过" % op)
	return current_price

## 工厂方法：创建一个价格修改器。
## p_priority 为 -1 时自动使用该运算的默认优先级。
## p_target_industry 为 null 时不按行业定位。
##
## 目标分发规则（由 StockManager 解析）：
##   target_stock_ids 非空 → 公司级
##   target_industry  非空 → 行业级
##   两者都空             → 宏观级
static func create(
	p_source_id: StringName,
	p_source_type: StringName,
	p_target_stock_ids: Array[StringName],
	p_op: StringName,
	p_value: float,
	p_priority: int = -1,
	p_target_industry: Tag = null
) -> PriceModifier:
	_ensure_initialized()
	var mod := PriceModifier.new()
	mod.source_id = p_source_id
	mod.source_type = p_source_type
	mod.target_stock_ids = p_target_stock_ids
	mod.target_industry = p_target_industry
	mod.op = p_op
	mod.value = p_value
	mod.priority = p_priority if p_priority >= 0 else _default_priorities.get(p_op, 50)
	return mod
