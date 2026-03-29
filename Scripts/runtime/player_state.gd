## 玩家运行时状态 v4：竞选大师
class_name PlayerState
extends RefCounted

var player_id: StringName
var player_name: String
var action_points: int = 3
var max_action_points: int = 3
var hand: Array[MaterialCardDef] = []
var hand_limit: int = 10


func _init(id: StringName, p_name: String = "") -> void:
	player_id = id
	player_name = p_name if p_name != "" else String(id)


func reset_turn() -> void:
	action_points = max_action_points


func can_spend_ap(cost: int) -> bool:
	return action_points >= cost


func spend_ap(cost: int) -> bool:
	if action_points < cost:
		return false
	action_points -= cost
	return true


## 移除指定下标的手牌，返回被移除的牌
func remove_cards(indices: Array[int]) -> Array[MaterialCardDef]:
	var removed: Array[MaterialCardDef] = []
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	for idx in sorted:
		if idx >= 0 and idx < hand.size():
			removed.append(hand[idx])
			hand.remove_at(idx)
	return removed


## 超出手牌上限时弃牌
func discard_to_limit() -> Array[MaterialCardDef]:
	var discarded: Array[MaterialCardDef] = []
	while hand.size() > hand_limit:
		discarded.append(hand.pop_back())
	return discarded
