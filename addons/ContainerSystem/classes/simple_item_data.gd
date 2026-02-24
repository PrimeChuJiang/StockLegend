# 物品最简单的数据结构，只有id和数量
@tool

extends RefCounted
class_name SimpleItemData

class SingleSimpleItemData:
    var id : int = 0
    var count : int = 1

    func _to_string() -> String:
        var name : String = ItemContainerSystem.get_item_data_by_id(id).name
        return "SingleSimpleItemData(id: %d, name: %s, count: %d)" % [id, name, count]

var item_save_datas : Array[SingleSimpleItemData] = []

# 从最简数据加载物品
func load_from_save_datas(item_container : ItemContainer) -> Array[Item] :
    var items : Array[Item] = []
    for i in range(item_save_datas.size()):
        var save_data : SingleSimpleItemData = item_save_datas[i]
        if save_data != null:
            var item_data := ItemContainerSystem.get_item_data_by_id(save_data.id)
            if item_data != null:
                var item := Item.new(item_data, item_container, i, save_data.count)
                items.append(item)
            else:
                push_error("SimpleItemData: load_from_save_datas: 物品ID", save_data.id, "不存在，无法加载物品")
                items.append(null)
        else:
            items.append(null)
    return items

# 保存物品到最简数据
func save_to_save_datas(items : Array[Item]) -> void:
    item_save_datas.clear()
    for i in range(items.size()):
        var item : Item = items[i]
        if item != null:
            var save_data := SingleSimpleItemData.new()
            save_data.id = item.data.id
            save_data.count = item.stack_count
            item_save_datas.append(save_data)
        else:
            item_save_datas.append(null)

# 重写 to_string 方法，方便打印调试
func _to_string() -> String:
    var result : String = "SimpleItemData:\n"
    for save_data in item_save_datas:
        result += "  " + str(save_data) + "\n"
    return result

