## 卡牌系统：管理素材牌堆和抽牌。
## 作为 AutoLoad 单例运行。
extends Node

## 牌堆（抽牌来源）
var _deck: Array[MaterialCardDef] = []
## 弃牌堆
var _discard: Array[MaterialCardDef] = []


# ─── 初始化 ───

## 用卡牌数组初始化牌堆
func setup_deck(card_pool: Array[MaterialCardDef]) -> void:
	_deck.clear()
	_discard.clear()
	_deck = card_pool.duplicate()
	shuffle_deck()


func shuffle_deck() -> void:
	_deck.shuffle()


func get_deck_size() -> int:
	return _deck.size()


func get_discard_size() -> int:
	return _discard.size()


# ─── 抽牌 ───

## 抽取指定数量的牌。牌堆空时自动洗入弃牌堆。
func draw_cards(count: int) -> Array[MaterialCardDef]:
	var drawn: Array[MaterialCardDef] = []
	for i in count:
		if _deck.is_empty():
			_reshuffle_discard()
		if _deck.is_empty():
			break
		drawn.append(_deck.pop_back())
	return drawn


## 为玩家抽牌并加入手牌
func draw_for_player(state: PlayerState, count: int) -> Array[MaterialCardDef]:
	var cards := draw_cards(count)
	for card in cards:
		state.hand.append(card)
	return cards


## 将牌放入弃牌堆
func discard(cards: Array[MaterialCardDef]) -> void:
	_discard.append_array(cards)


func _reshuffle_discard() -> void:
	if _discard.is_empty():
		return
	_deck = _discard.duplicate()
	_discard.clear()
	_deck.shuffle()
