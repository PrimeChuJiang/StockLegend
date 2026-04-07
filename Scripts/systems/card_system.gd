## 卡牌系统 v5：管理牌堆和抽牌
## 作为 AutoLoad 单例运行（名称 CardSystem）。
## 职责：维护抽牌堆和弃牌堆，处理抽牌和洗牌逻辑。
## 抽牌堆耗尽时自动将弃牌堆洗入（无限循环，不会牌荒）。
extends Node

var _deck: Array[CardDef] = []     ## 抽牌堆（从末尾 pop，后进先出）
var _discard: Array[CardDef] = []  ## 弃牌堆


# ─── 初始化 ───

## 用卡牌池初始化牌堆（复制一份，洗牌）
func setup_deck(card_pool: Array[CardDef]) -> void:
	_deck.clear()
	_discard.clear()
	_deck = card_pool.duplicate()
	shuffle_deck()


## 洗牌（随机打乱抽牌堆顺序）
func shuffle_deck() -> void:
	_deck.shuffle()


## 查询抽牌堆剩余张数
func get_deck_size() -> int:
	return _deck.size()


## 查询弃牌堆张数
func get_discard_size() -> int:
	return _discard.size()


# ─── 抽牌 ───

## 从牌堆顶抽指定数量的牌（牌堆空则先洗入弃牌堆）
func draw_cards(count: int) -> Array[CardDef]:
	var drawn: Array[CardDef] = []
	for i in count:
		if _deck.is_empty():
			_reshuffle_discard()  # 抽牌堆空了，把弃牌堆洗回来
		if _deck.is_empty():
			break  # 弃牌堆也空了，真的没牌了
		drawn.append(_deck.pop_back())
	return drawn


## 为指定玩家抽牌，自动加入手牌
func draw_for_player(state: PlayerState, count: int) -> Array[CardDef]:
	var cards := draw_cards(count)
	for card in cards:
		state.hand.append(card)
	return cards


## 将卡牌放入弃牌堆
func discard(cards: Array[CardDef]) -> void:
	_discard.append_array(cards)


## 将弃牌堆洗入抽牌堆（当抽牌堆耗尽时自动调用）
func _reshuffle_discard() -> void:
	if _discard.is_empty():
		return
	_deck = _discard.duplicate()
	_discard.clear()
	_deck.shuffle()
