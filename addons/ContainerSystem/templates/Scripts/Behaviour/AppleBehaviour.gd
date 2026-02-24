extends ItemBehaviourData

class_name AppleBehaviour

# 使用函数，返回使用了多少个
func use_item(item : Item, character_from : Node, character_to : Node, num : int) -> Variant:
	if num == -1:
		push_error("ItemBehaviourData: use_item: 请在子类中实现use_item函数，无视使用个数")
	else:
		push_error("ItemBehaviourData: use_item: 请在子类中实现use_item函数，使用个数:", num)
	return 
