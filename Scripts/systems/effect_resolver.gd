## 效果结算器，将 EffectDef 的声明式描述转化为实际执行。
## 核心是一个 effect_id → Callable 的注册表，支持运行时注册新效果。
class_name EffectResolver
extends Node

## 效果处理函数注册表：{ StringName: Callable }
var _handlers: Dictionary = {}
## 目标选择器实例，用于指向性卡牌的目标选择
var target_selector: TargetSelector
## 区域管理器引用，由外部（测试脚本或场景）注入
var zone_manager: CardZoneManager


## 初始化目标选择器并注册所有内置效果处理函数。
func _ready() -> void:
	target_selector = TargetSelector.new()
	_register_builtin()


## 注册一个新的效果处理函数。handler 签名: (card: CardItem, fx: EffectDef, ctx: Dictionary) -> void
func register_effect(id: StringName, handler: Callable) -> void:
	_handlers[id] = handler


## 结算卡牌上所有匹配指定触发时机的效果。
## 遍历 card.get_card_data().effects，筛选 trigger 匹配的效果，执行对应的 handler。
## 对于指向性卡牌，会先通过 target_selector 选择目标后再执行效果。
func resolve_effects(card: CardItem, trigger: Enums.EffectTrigger, ctx: Dictionary) -> void:
	var card_data := card.get_card_data()
	for effect_def: EffectDef in card_data.effects:
		if effect_def.trigger != trigger:
			continue
		var handler: Callable = _handlers.get(effect_def.effect_id, Callable())
		if not handler.is_valid():
			push_warning("No handler registered for effect: %s" % effect_def.effect_id)
			continue
		var target: Variant = null
		if card_data.target_type != Enums.TargetType.NONE:
			var candidates := _get_candidates(card, card_data.target_type, ctx)
			target = await target_selector.select_target(card, card_data.target_type, candidates)
		ctx["target"] = target
		handler.call(card, effect_def, ctx)


## 根据目标类型获取候选目标列表。
## 当前实现：返回场地区域所有卡牌。后续可根据玩家/敌人区分进行细化。
func _get_candidates(_card: CardItem, _target_type: Enums.TargetType, ctx: Dictionary) -> Array:
	var zm: CardZoneManager = ctx.get("zone_manager")
	return zm.get_cards_in_zone(Enums.Zone.FIELD)


## 注册所有内置效果处理函数。
func _register_builtin() -> void:
	register_effect(&"deal_damage", _fx_deal_damage)
	register_effect(&"heal", _fx_heal)
	register_effect(&"add_modifier", _fx_add_modifier)
	register_effect(&"draw_cards", _fx_draw_cards)


## 内置效果：造成伤害。从 fx.params["damage"] 读取伤害值，通过 GameBus 广播。
func _fx_deal_damage(card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
	var dmg: int = fx.params.get("damage", 0)
	GameBus.damage_dealt.emit(card, ctx.get("target"), dmg)


## 内置效果：治疗。从 fx.params["amount"] 读取治疗量，通过 GameBus 广播。
func _fx_heal(card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
	var amount: int = fx.params.get("amount", 0)
	GameBus.heal_applied.emit(card, ctx.get("target"), amount)


## 内置效果：添加属性修改器。从 fx.params 中读取 stat_key、op、value、duration，
## 创建 Modifier 实例并添加到目标卡牌上。
func _fx_add_modifier(card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
	var mod := Modifier.new()
	mod.stat_key = fx.params.get("stat_key", Enums.StatKey.ATTACK)
	mod.op = fx.params.get("op", Enums.ModifierOp.ADD)
	mod.value = fx.params.get("value", 0)
	mod.duration = fx.params.get("duration", -1)
	mod.source_id = card.card_instance_id
	var target: Variant = ctx.get("target")
	if target is CardItem:
		target.add_modifier(mod)


## 内置效果：抽牌。从 fx.params["count"] 读取抽牌数量，通过 CardZoneManager 执行抽牌。
func _fx_draw_cards(_card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
	var count: int = fx.params.get("count", 1)
	var zm: CardZoneManager = ctx.get("zone_manager")
	for i in count:
		zm.draw_card()
