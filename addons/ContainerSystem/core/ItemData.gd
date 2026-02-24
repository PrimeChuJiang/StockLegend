# 物品模板类，这个类用于用户对所有的物品进行一个统一的配置
extends Resource

class_name ItemData

# 物品ID
@export var id : int = 0

# 物品名称
@export var name : String = ""

# 物品标签
@export var tags : Array[Tag] = []

# 物品描述
@export var description : String = ""

# 物品图片
@export var image : Texture2D = null

# 物品最大堆叠层数，-1表示无限堆叠
@export var max_stack : int = -1

# 物品行为
@export var behaviours : Array[ItemBehaviourData] = []

# 重写 to_string 方法，方便打印调试
func _to_string() -> String:
    return "ItemData: id=" + str(id) + ", name=" + name + ", tags=" + str(tags) + ", description=" + description + ", image=" + str(image) + ", max_stack=" + str(max_stack)