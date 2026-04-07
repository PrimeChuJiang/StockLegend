## 玩家运行时状态 v5：竞选大师
## 管理单个玩家的手牌、行动点等运行时数据。
## 使用 RefCounted（非 Node），不挂载到场景树，由 game_ui 或 test 脚本持有引用。
class_name PlayerState
extends RefCounted

var player_id: int           ## 玩家阵营，取值 Enums.CellOwner.PLAYER_A 或 PLAYER_B
var player_name: String      ## 显示名称（"玩家" / "AI" / "甲方"等）
var action_points: int = 3   ## 当前剩余行动点
var max_action_points: int = 3  ## 每回合行动点上限（测试阶段统一3点）
var hand: Array[CardDef] = []   ## 当前手牌列表
var hand_limit: int = 5     ## 手牌上限，回合结算时超出部分强制弃牌


func _init(id: int, p_name: String = "") -> void:
	player_id = id
	player_name = p_name if p_name != "" else Enums.owner_name(id as Enums.CellOwner)


## 回合开始时调用：重置行动点到上限
func reset_turn() -> void:
	action_points = max_action_points


## 检查是否有足够行动点
func can_spend_ap(cost: int) -> bool:
	return action_points >= cost


## 消耗行动点，成功返回 true，不足返回 false
func spend_ap(cost: int) -> bool:
	if action_points < cost:
		return false
	action_points -= cost
	return true


## 按下标移除手牌（从大到小排序后删除，避免下标偏移），返回被移除的牌
func remove_cards(indices: Array[int]) -> Array[CardDef]:
	var removed: Array[CardDef] = []
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()  # 从后往前删，防止前面的删除影响后面的下标
	for idx in sorted:
		if idx >= 0 and idx < hand.size():
			removed.append(hand[idx])
			hand.remove_at(idx)
	return removed


## 回合结算时弃牌至上限（从末尾弃，AI 用；玩家版未来可改为手动选择）
func discard_to_limit() -> Array[CardDef]:
	var discarded: Array[CardDef] = []
	while hand.size() > hand_limit:
		discarded.append(hand.pop_back())
	return discarded
