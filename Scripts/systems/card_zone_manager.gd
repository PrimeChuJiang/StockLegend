## 卡牌区域管理器，包装 5 个 ItemContainer 子节点（DECK/HAND/FIELD/DISCARD/EXHAUST）。
## 提供卡牌专用的创建、移动、查询、抽牌、洗牌等操作。
## move_card() 通过 remove + add 在容器间移动同一个 CardItem 实例。
class_name CardZoneManager
extends Node

## 区域字典，键为 Enums.Zone 枚举值，值为 ItemContainer 节点
var _containers: Dictionary = {}

@export var default_zone_size: Dictionary = {
	"DECK": 40,
	"HAND": 10,
	"FIELD": 10,
	"DISCARD": 40,
	"EXHAUST": 40
}


## 为每个 Zone 创建一个 ItemContainer 子节点并初始化。
func _ready() -> void:
	for zone_value in Enums.Zone.values():
		var container := ItemContainer.new()
		container.name = Enums.Zone.keys()[zone_value]
		var zone_size := _get_default_size(zone_value)
		container.initialize(zone_size, Enums.Zone.keys()[zone_value])
		add_child(container)
		_containers[zone_value] = container


## 创建卡牌并放入指定区域。
## 使用 CardItem.create_from_data() 工厂方法根据 card_type 创建对应子类。
func create_card(card_data: CardItemData, zone: Enums.Zone) -> CardItem:
	var container := get_container(zone)
	var index := container.get_first_empty_position()
	if index == -1:
		push_error("CardZoneManager: create_card: Zone %s is full" % Enums.Zone.keys()[zone])
		return null
	var card := CardItem.create_from_data(card_data, container, index)
	container.add_item(card, index)
	GameBus.card_zone_changed.emit(card, zone, zone)
	return card


## 跨区域移动卡牌（保持同一 CardItem 实例）。
## 使用 remove_item_in_position + add_item 实现，自动更新 card.container 和 card.position_in_container。
func move_card(card: CardItem, to_zone: Enums.Zone) -> void:
	var from_zone := get_zone_of(card)
	var from_container := card.container
	from_container.remove_item_in_position(card.position_in_container, 1)
	var to_container := get_container(to_zone)
	var to_index := to_container.get_first_empty_position()
	to_container.add_item(card, to_index)
	GameBus.card_zone_changed.emit(card, from_zone, to_zone)


## 获取指定区域的所有卡牌，按位置顺序返回。
func get_cards_in_zone(zone: Enums.Zone) -> Array[CardItem]:
	var cards: Array[CardItem] = []
	var container := get_container(zone)
	for i in container.size:
		var item := container.get_item_in_position(i)
		if item != null and item is CardItem:
			cards.append(item as CardItem)
	return cards


## 从牌库顶部抽一张牌移至手牌区域。
## 牌库为空时返回 null。
func draw_card() -> CardItem:
	var deck_cards := get_cards_in_zone(Enums.Zone.DECK)
	if deck_cards.is_empty():
		return null
	var card: CardItem = deck_cards[0]
	move_card(card, Enums.Zone.HAND)
	return card


## 获取指定区域的 ItemContainer 节点。
func get_container(zone: Enums.Zone) -> ItemContainer:
	return _containers[zone]


## 根据卡牌所在 container 反查 Zone 枚举。
func get_zone_of(card: CardItem) -> Enums.Zone:
	for zone_value in _containers:
		if card.container == _containers[zone_value]:
			return zone_value
	return Enums.Zone.DECK


## 打乱指定区域的卡牌顺序。
## 取出所有卡牌，打乱后重新放入容器。
func shuffle_zone(zone: Enums.Zone) -> void:
	var cards := get_cards_in_zone(zone)
	var container := get_container(zone)
	for card in cards:
		container.remove_item_in_position(card.position_in_container, 1)
	cards.shuffle()
	for card in cards:
		var index := container.get_first_empty_position()
		container.add_item(card, index)


## 获取所有区域中的所有卡牌（合并为一个数组）。
func get_all_cards() -> Array[CardItem]:
	var all: Array[CardItem] = []
	for zone_value in Enums.Zone.values():
		all.append_array(get_cards_in_zone(zone_value))
	return all


## 获取各区域的默认容量。
func _get_default_size(zone: Enums.Zone) -> int:
	match zone:
		Enums.Zone.DECK: return default_zone_size["DECK"]
		Enums.Zone.HAND: return default_zone_size["HAND"]
		Enums.Zone.FIELD: return default_zone_size["FIELD"]
		Enums.Zone.DISCARD: return default_zone_size["DISCARD"]
		Enums.Zone.EXHAUST: return default_zone_size["EXHAUST"]
	return 20
