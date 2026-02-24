# Tag Manager 编辑器面板
@tool
extends PanelContainer

var tag_tree: Tree
var add_root_btn: Button
var add_child_btn: Button
var delete_btn: Button
var hierarchy: TagHierarchy
var hierarchy_path: String

var selected_item: TreeItem = null
var selected_tag: Tag = null

func _init() -> void:
	# 在 _init 中设置 name，确保在添加到 dock 之前就有名称
	name = "Tag Manager"

func _ready() -> void:
	custom_minimum_size = Vector2(200, 300)
	_setup_ui()
	_load_hierarchy()
	_populate_tree()

func _setup_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 标题
	var title_label = Label.new()
	title_label.text = "Tag Manager"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# 工具栏
	var toolbar = HBoxContainer.new()

	add_root_btn = Button.new()
	add_root_btn.text = "添加根标签"
	add_root_btn.pressed.connect(_on_add_root_pressed)
	toolbar.add_child(add_root_btn)

	add_child_btn = Button.new()
	add_child_btn.text = "添加子标签"
	add_child_btn.pressed.connect(_on_add_child_pressed)
	add_child_btn.disabled = true
	toolbar.add_child(add_child_btn)

	delete_btn = Button.new()
	delete_btn.text = "删除"
	delete_btn.pressed.connect(_on_delete_pressed)
	delete_btn.disabled = true
	toolbar.add_child(delete_btn)

	main_vbox.add_child(toolbar)

	# 分隔线
	var separator = HSeparator.new()
	main_vbox.add_child(separator)

	# 标签树
	tag_tree = Tree.new()
	tag_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_tree.item_selected.connect(_on_item_selected)
	tag_tree.item_edited.connect(_on_item_edited)
	tag_tree.item_activated.connect(_on_item_activated)  # 双击时触发
	tag_tree.set_column_expand(0, true)
	main_vbox.add_child(tag_tree)

	add_child(main_vbox)

func _load_hierarchy() -> void:
	hierarchy_path = ProjectSettings.get_setting(
		"container_system/tag_hierarchy",
		"res://addons/ContainerSystem/templates/TagHierarchy.tres"
	)
	if ResourceLoader.exists(hierarchy_path):
		hierarchy = load(hierarchy_path) as TagHierarchy
		if hierarchy:
			hierarchy.initialize_paths()
			# 确保所有已有标签都有独立的 .tres 文件
			_ensure_tag_files()
	if not hierarchy:
		hierarchy = TagHierarchy.new()
		_save_hierarchy()

func _save_hierarchy() -> void:
	if hierarchy == null:
		return
	# 确保目录存在
	var dir = hierarchy_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	hierarchy.take_over_path(hierarchy_path)
	var err = ResourceSaver.save(hierarchy, hierarchy_path)
	if err != OK:
		push_error("TagManagerPanel: 保存 TagHierarchy 失败，错误码: " + str(err))

# ---- Tag 文件管理 ----

# 获取 Tag 独立文件的存储目录
func _get_tags_dir() -> String:
	return hierarchy_path.get_base_dir() + "/Tags"

# 根据 tag_path 生成文件路径，如 "Food.Fruit" -> "Tags/Food.Fruit.tres"
func _get_tag_file_path(tag: Tag) -> String:
	if tag.tag_path.is_empty():
		tag._update_path()
	return _get_tags_dir() + "/" + tag.tag_path + ".tres"

# 递归收集某个标签及其所有子标签的文件路径（用于删除/重命名前）
func _collect_tag_file_paths(tag: Tag) -> Array[String]:
	var paths: Array[String] = []
	if tag == null:
		return paths
	paths.append(_get_tag_file_path(tag))
	for child in tag.child_tags:
		paths.append_array(_collect_tag_file_paths(child))
	return paths

# 将层级中所有标签保存为独立 .tres 文件
func _save_all_tag_files() -> void:
	var tags_dir = _get_tags_dir()
	if not DirAccess.dir_exists_absolute(tags_dir):
		DirAccess.make_dir_recursive_absolute(tags_dir)
	if not hierarchy:
		return
	var all_tags = hierarchy.get_all_tags()
	# 第一遍：先设置所有 resource_path，确保交叉引用时使用 ExtResource
	for tag in all_tags:
		var file_path = _get_tag_file_path(tag)
		tag.take_over_path(file_path)
	# 第二遍：保存所有文件
	for tag in all_tags:
		var err = ResourceSaver.save(tag, tag.resource_path)
		if err != OK:
			push_error("TagManagerPanel: 保存 Tag 文件失败: " + tag.resource_path + ", 错误码: " + str(err))

# 删除指定路径列表中的 .tres 文件
func _delete_tag_files(paths: Array[String]) -> void:
	for path in paths:
		if FileAccess.file_exists(path):
			var err = DirAccess.remove_absolute(path)
			if err != OK:
				push_error("TagManagerPanel: 删除 Tag 文件失败: " + path + ", 错误码: " + str(err))

# 通知编辑器文件系统重新扫描，使新文件出现在 Resource 选择器中
func _scan_filesystem() -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

# 确保层级中所有标签都有对应的独立文件（用于加载时迁移旧数据）
func _ensure_tag_files() -> void:
	if not hierarchy or hierarchy.root_tags.size() == 0:
		return
	var needs_save = false
	for tag in hierarchy.get_all_tags():
		var file_path = _get_tag_file_path(tag)
		if tag.resource_path != file_path or not FileAccess.file_exists(file_path):
			needs_save = true
			break
	if needs_save:
		_save_all_tag_files()
		_save_hierarchy()
		_scan_filesystem()

# ---- Tree 显示 ----

func _populate_tree() -> void:
	tag_tree.clear()
	var root = tag_tree.create_item()
	root.set_text(0, "所有标签")
	root.set_selectable(0, false)

	if hierarchy:
		for tag in hierarchy.root_tags:
			_add_tag_to_tree(root, tag)

func _add_tag_to_tree(parent_item: TreeItem, tag: Tag) -> TreeItem:
	if tag == null:
		return null
	var item = tag_tree.create_item(parent_item)
	item.set_text(0, tag.name)
	# 不设置 editable，双击时才启用编辑
	item.set_meta("tag", tag)

	# 显示完整路径作为提示
	if tag.tag_path.is_empty():
		tag._update_path()
	item.set_tooltip_text(0, tag.tag_path)

	for child_tag in tag.child_tags:
		_add_tag_to_tree(item, child_tag)

	return item

# ---- 交互回调 ----

func _on_item_selected() -> void:
	selected_item = tag_tree.get_selected()
	if selected_item and selected_item.has_meta("tag"):
		selected_tag = selected_item.get_meta("tag")
		add_child_btn.disabled = false
		delete_btn.disabled = false
	else:
		selected_tag = null
		add_child_btn.disabled = true
		delete_btn.disabled = true

func _on_item_activated() -> void:
	# 双击时进入编辑模式
	var item = tag_tree.get_selected()
	if item and item.has_meta("tag"):
		item.set_editable(0, true)
		tag_tree.edit_selected()
		# 编辑完成后会触发 _on_item_edited

func _on_item_edited() -> void:
	var item = tag_tree.get_edited()
	if item and item.has_meta("tag"):
		var tag: Tag = item.get_meta("tag")
		var new_name = item.get_text(0)
		# 编辑完成后禁用编辑状态
		item.set_editable(0, false)
		if new_name.is_empty():
			# 不允许空名称，恢复原名
			item.set_text(0, tag.name)
			return
		if new_name != tag.name:
			# 收集重命名前的旧文件路径（包含所有子标签）
			var old_paths = _collect_tag_file_paths(tag)
			tag.name = new_name
			tag._update_path()
			item.set_tooltip_text(0, tag.tag_path)
			# 删除旧文件，保存新文件
			_delete_tag_files(old_paths)
			_save_all_tag_files()
			_save_hierarchy()
			_scan_filesystem()

func _on_add_root_pressed() -> void:
	var new_tag = Tag.new()
	new_tag.name = "NewTag"
	new_tag.tag_path = "NewTag"
	hierarchy.add_root_tag(new_tag)
	_save_all_tag_files()
	_save_hierarchy()
	_scan_filesystem()
	_populate_tree()

func _on_add_child_pressed() -> void:
	if not selected_tag:
		return
	var new_tag = Tag.new()
	new_tag.name = "NewTag"
	new_tag.parent_tag = selected_tag
	new_tag._update_path()
	selected_tag.child_tags.append(new_tag)
	_save_all_tag_files()
	_save_hierarchy()
	_scan_filesystem()
	_populate_tree()

func _on_delete_pressed() -> void:
	if not selected_tag:
		return
	# 删除前收集该标签及其所有子标签的文件路径
	var old_paths = _collect_tag_file_paths(selected_tag)
	hierarchy.remove_tag(selected_tag)
	selected_tag = null
	selected_item = null
	add_child_btn.disabled = true
	delete_btn.disabled = true
	# 删除文件，重新保存剩余标签（更新父标签的 child_tags 引用），保存层级
	_delete_tag_files(old_paths)
	_save_all_tag_files()
	_save_hierarchy()
	_scan_filesystem()
	_populate_tree()

# 刷新面板 (外部调用)
func refresh() -> void:
	_load_hierarchy()
	_populate_tree()
