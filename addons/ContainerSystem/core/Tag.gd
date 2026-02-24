# 标签模板类，支持层级结构 (类似 UE5 Gameplay Tag)
@tool
extends Resource

class_name Tag

# 标签名称
@export var name: String = "":
	set(value):
		name = value
		if not _initializing:
			_update_path()

# 父标签引用
@export var parent_tag: Tag = null

# 子标签列表
@export var child_tags: Array[Tag] = []

# 完整路径 (自动生成，如 "Food.Fruit.Apple")
var tag_path: String = ""

var _initializing: bool = false

func _init() -> void:
	_initializing = true

# Resource 不会自动调用 _ready，需要在加载后手动初始化
func _post_init() -> void:
	_initializing = false
	_update_path()

# 更新路径 (基于父标签链)
func _update_path() -> void:
	if parent_tag:
		# 确保父标签路径已更新
		if parent_tag.tag_path.is_empty():
			parent_tag._update_path()
		tag_path = parent_tag.tag_path + "." + name
	else:
		tag_path = name
	# 递归更新子标签路径
	for child in child_tags:
		child._update_path()

# 获取路径段数组
func get_segments() -> PackedStringArray:
	return tag_path.split(".") if not tag_path.is_empty() else PackedStringArray()

# 获取层级深度 (0 = 根)
func get_depth() -> int:
	var depth = 0
	var current = parent_tag
	while current:
		depth += 1
		current = current.parent_tag
	return depth

# 核心匹配：检查此标签是否匹配查询标签 (自身或祖先)
# 例如：Food.Fruit.Apple.matches_tag(Food) 返回 true
func matches_tag(query_tag: Tag) -> bool:
	if query_tag == null:
		return false
	return matches_tag_path(query_tag.tag_path)

func matches_tag_path(query_path: String) -> bool:
	if query_path.is_empty():
		return false
	# 确保自身路径已更新
	if tag_path.is_empty():
		_update_path()
	if tag_path == query_path:
		return true
	return tag_path.begins_with(query_path + ".")

# 检查是否是另一标签的后代
func is_descendant_of(ancestor: Tag) -> bool:
	var current = parent_tag
	while current:
		if current == ancestor:
			return true
		current = current.parent_tag
	return false

# 获取所有祖先路径 (含自身)
func get_all_ancestor_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	var segments = get_segments()
	var current = ""
	for segment in segments:
		current = segment if current.is_empty() else current + "." + segment
		paths.append(current)
	return paths

# 添加子标签
func add_child(child: Tag) -> void:
	if child == null or child in child_tags:
		return
	child.parent_tag = self
	child_tags.append(child)
	child._update_path()

# 移除子标签
func remove_child(child: Tag) -> void:
	if child == null:
		return
	child_tags.erase(child)
	child.parent_tag = null
	child._update_path()
