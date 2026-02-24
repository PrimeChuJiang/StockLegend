# Tag Manager 运行时单例
# 提供标签的 O(1) 路径查找和层级查询功能
extends Node

# 路径 -> Tag 映射 (O(1) 查找)
var _tag_registry: Dictionary = {}  # String -> Tag
var _hierarchy: TagHierarchy

signal tags_loaded

func _ready() -> void:
	_load_tags()

func _load_tags() -> void:
	var path = ProjectSettings.get_setting(
		"container_system/tag_hierarchy",
		"res://addons/ContainerSystem/templates/TagHierarchy.tres"
	)
	if ResourceLoader.exists(path):
		_hierarchy = load(path) as TagHierarchy
		if _hierarchy:
			_hierarchy.initialize_paths()
			_build_registry()
	tags_loaded.emit()

func _build_registry() -> void:
	_tag_registry.clear()
	if _hierarchy == null:
		return
	for tag in _hierarchy.get_all_tags():
		if tag.tag_path.is_empty():
			tag._update_path()
		_tag_registry[tag.tag_path] = tag

# 重新加载标签 (编辑器修改后调用)
func reload() -> void:
	_load_tags()

# O(1) 按路径获取标签
func get_tag(tag_path: String) -> Tag:
	return _tag_registry.get(tag_path, null)

# 获取所有标签
func get_all_tags() -> Array[Tag]:
	if _hierarchy:
		return _hierarchy.get_all_tags()
	return []

# 获取根标签
func get_root_tags() -> Array[Tag]:
	if _hierarchy:
		return _hierarchy.root_tags.duplicate()
	return []

# 检查标签数组中是否有任一匹配查询标签 (层级匹配)
func any_tag_matches(tags: Array[Tag], query_tag: Tag) -> bool:
	for tag in tags:
		if tag != null and tag.matches_tag(query_tag):
			return true
	return false

# 检查标签数组中是否匹配所有查询标签
func all_tags_match(tags: Array[Tag], query_tags: Array[Tag]) -> bool:
	for query_tag in query_tags:
		if not any_tag_matches(tags, query_tag):
			return false
	return true

# 获取标签的所有后代
func get_descendants(tag: Tag) -> Array[Tag]:
	var result: Array[Tag] = []
	_collect_descendants(tag, result)
	return result

func _collect_descendants(tag: Tag, result: Array[Tag]) -> void:
	if tag == null:
		return
	for child in tag.child_tags:
		result.append(child)
		_collect_descendants(child, result)

# 获取标签的所有祖先
func get_ancestors(tag: Tag) -> Array[Tag]:
	var result: Array[Tag] = []
	var current = tag.parent_tag
	while current:
		result.append(current)
		current = current.parent_tag
	return result

# 获取标签数量
func get_tag_count() -> int:
	return _tag_registry.size()

# 检查标签是否存在
func has_tag(tag_path: String) -> bool:
	return _tag_registry.has(tag_path)
