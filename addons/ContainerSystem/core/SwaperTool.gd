class_name SwaperTool

static func swap_item(container_a : ItemContainer, container_b : ItemContainer, index_a : int, index_b : int) -> void:
    var item_a = container_a.get_item_in_position(index_a)
    var item_b = container_b.get_item_in_position(index_b)
    # 检查是否在交换两个空位置
    if item_a == null and item_b == null:
        return
    elif item_a == null:
        container_a.add_item(item_b, index_a)
        container_b.remove_item_in_position(index_b, item_b.stack_count)
    elif item_b == null:
        container_b.add_item(item_a, index_b)
        container_a.remove_item_in_position(index_a, item_a.stack_count)
    else:
        # Swap items 
        container_a.remove_item_in_position(index_a, item_a.stack_count)
        container_b.remove_item_in_position(index_b, item_b.stack_count)
        container_b.add_item(item_a, index_b)
        container_a.add_item(item_b, index_a)