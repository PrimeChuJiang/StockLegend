## 所有运行时卡牌实例的基类，继承插件的 Item，添加修改器系统和卡牌虚方法。
## 不要直接实例化此类，始终通过 create_from_data() 工厂方法创建。
class_name CardItem
extends Item

## 运行时唯一标识，由工厂方法自动分配
var card_instance_id: StringName
## 当前附加的属性修改器列表
var modifiers: Array[Modifier] = []
## 自由扩展数据容器，供子类或外部系统存储额外运行时数据
var extra_data: Dictionary = {}


func _init(_data: CardItemData, _container: ItemContainer, _index: int):
	super._init(_data, _container, _index, 1)
	card_instance_id = _data.id

## 静态工厂方法：根据 CardItemData.card_type 自动创建对应子类实例。
## 这是创建卡牌实例的唯一推荐入口。
static func create_from_data(card_data: CardItemData, container: ItemContainer, index: int) -> CardItem:
	var card: CardItem
	match card_data.card_type:
		Enums.CardType.NORMAL:
			card = NormalCardItem.new(card_data, container, index)
		Enums.CardType.INSTANT:
			card = InstantCardItem.new(card_data, container, index)
		Enums.CardType.FIELD:
			card = FieldCardItem.new(card_data, container, index)
	return card


## 获取卡牌专有数据（向下转型为 CardItemData）
func get_card_data() -> CardItemData:
	return data as CardItemData


## 计算经过所有修改器叠加后的最终属性值。
## 计算顺序：先累加 ADD，再乘以 MULTIPLY，遇到 SET 则直接返回覆盖值。
func get_stat(key: Enums.StatKey) -> int:
	var base: int = get_card_data().base_stats.get(key, 0)
	var add_sum := 0
	var mult := 1.0
	for mod in modifiers:
		if mod.stat_key != key:
			continue
		match mod.op:
			Enums.ModifierOp.ADD:
				add_sum += int(mod.value)
			Enums.ModifierOp.MULTIPLY:
				mult *= mod.value
			Enums.ModifierOp.SET:
				return int(mod.value)
	return int((base + add_sum) * mult)


## 添加一个属性修改器，并通过 GameBus 广播 modifier_added 信号。
func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)
	GameBus.modifier_added.emit(self, mod)


## 移除一个属性修改器，并通过 GameBus 广播 modifier_removed 信号。
func remove_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)
	GameBus.modifier_removed.emit(self, mod)


## 回合 CLEANUP 阶段调用：对所有修改器执行 tick()，移除已过期的修改器。
func tick_modifiers() -> void:
	var expired: Array[Modifier] = []
	for mod in modifiers:
		if mod.tick():
			expired.append(mod)
	for mod in expired:
		remove_modifier(mod)


## 虚方法：判断当前阶段是否允许打出此卡。子类必须重写。
func can_play_at_phase(_phase: Enums.Phase) -> bool:
	return false


## 虚方法：执行出牌逻辑。子类必须重写，实现各卡牌类型的差异化行为。
## ctx 包含 zone_manager、effect_resolver、turn_system 等系统引用。
func execute(_ctx: Dictionary) -> void:
	pass


## 返回此卡牌的类型枚举值。
func get_card_type() -> Enums.CardType:
	return get_card_data().card_type
