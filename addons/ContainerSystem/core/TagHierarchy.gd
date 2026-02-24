# 标签层级数据存储类
@tool
extends Resource

class_name TagHierarchy

# 所有根级标签
@export var root_tags: Array[Tag] = []

# 添加根标签
func add_root_tag(tag: Tag) -> void:
	if tag == null or tag in root_tags:
		return
	tag.parent_tag = null
	root_tags.append(tag)
	tag._update_path()

# 移除标签 (从父标签或根列表中移除)
func remove_tag(tag: Tag) -> void:
	if tag == null:
		return
	if tag.parent_tag:
		tag.parent_tag.child_tags.erase(tag)
		tag.parent_tag = null
	else:
		root_tags.erase(tag)

# 获取所有标签 (扁平列表)
func get_all_tags() -> Array[Tag]:
	var result: Array[Tag] = []
	for root in root_tags:
		_collect_tags(root, result)
	return result

func _collect_tags(tag: Tag, result: Array[Tag]) -> void:
	if tag == null:
		return
	result.append(tag)
	for child in tag.child_tags:
		_collect_tags(child, result)

# 按路径查找标签
func get_tag_by_path(path: String) -> Tag:
	for tag in get_all_tags():
		# 确保路径已更新
		if tag.tag_path.is_empty():
			tag._update_path()
		if tag.tag_path == path:
			return tag
	return null

# 初始化所有标签路径 (加载后调用)
func initialize_paths() -> void:
	for root in root_tags:
		_init_tag_paths(root)

func _init_tag_paths(tag: Tag) -> void:
	if tag == null:
		return
	tag._update_path()
	for child in tag.child_tags:
		_init_tag_paths(child)

# 获取标签数量
func get_tag_count() -> int:
	return get_all_tags().size()

# 清空所有标签
func clear() -> void:
	root_tags.clear()
