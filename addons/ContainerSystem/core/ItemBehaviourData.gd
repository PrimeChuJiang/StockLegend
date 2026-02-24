# 物品行为类，这个类用于用户对所有的物品进行一个统一的行为配置
extends Resource

class_name ItemBehaviourData

# -------------------
# 我们规定：
# 1. 物品行为类必须继承自ItemBehaviourData
# 2. ItemBehaviourData类内只需要实现一个函数use_item：
#    func use_item(item : Item, character_from : Node, character_to : Node) -> Variant:
#    	your code here
#    	return 
# -------------------

@export var tag : Tag

func use_item(item : Item, character_from : Node, character_to : Node, num : int) -> Variant:
	if num == -1:
		push_error("ItemBehaviourData: use_item: 请在子类中实现use_item函数，无视使用个数")
	else:
		push_error("ItemBehaviourData: use_item: 请在子类中实现use_item函数，使用个数:", num)
	return 
