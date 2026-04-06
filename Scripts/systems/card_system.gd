## 卡牌系统：管理牌堆和抽牌。
## 作为 AutoLoad 单例运行。
extends Node

var _deck: Array[CardDef] = []
var _discard: Array[CardDef] = []


# ─── 初始化 ───

func setup_deck(card_pool: Array[CardDef]) -> void:
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

func draw_cards(count: int) -> Array[CardDef]:
	var drawn: Array[CardDef] = []
	for i in count:
		if _deck.is_empty():
			_reshuffle_discard()
		if _deck.is_empty():
			break
		drawn.append(_deck.pop_back())
	return drawn


func draw_for_player(state: PlayerState, count: int) -> Array[CardDef]:
	var cards := draw_cards(count)
	for card in cards:
		state.hand.append(card)
	return cards


func discard(cards: Array[CardDef]) -> void:
	_discard.append_array(cards)


func _reshuffle_discard() -> void:
	if _discard.is_empty():
		return
	_deck = _discard.duplicate()
	_discard.clear()
	_deck.shuffle()
