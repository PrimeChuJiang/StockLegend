@tool
extends EditorPlugin

# 自定义项目设置的路径
const ITEM_DATA_MAP_SETTING_PATH: String = "container_system/item_data_map"
# 核心类的路径
const ITEM_DATA_MAP_CLASS_PATH: String = "res://addons/ContainerSystem/core/ItemDataMap.gd"
const ITEM_DATA_PATH: String = "res://addons/ContainerSystem/core/ItemData.gd"
# 单例类路径
const AUTOLOAD_NAME: String = "ItemContainerSystem"
const AUTOLOAD_SCRIPT_PATH: String = "res://addons/ContainerSystem/core/ContainerSystem.gd"

# 新增：Tag Manager 相关常量
const TAG_MANAGER_AUTOLOAD_NAME: String = "TagManager"
const TAG_MANAGER_SCRIPT_PATH: String = "res://addons/ContainerSystem/core/TagManager.gd"
const TAG_HIERARCHY_SETTING_PATH: String = "container_system/tag_hierarchy"
const TAG_HIERARCHY_CLASS_PATH: String = "res://addons/ContainerSystem/core/TagHierarchy.gd"
const TAG_MANAGER_PANEL_PATH: String = "res://addons/ContainerSystem/editor/TagManagerPanel.gd"

# 存储注册的资源类型(卸载时需删除)
var _registered_resource_types: Array[Dictionary] = []
# Tag Manager 面板实例
var _tag_manager_panel = null

# ---------------
# 插件加载时执行
# ---------------
func _enter_tree():
	# 1. 注册自定义资源类型(让用户能在编辑器中创建ItemData/ItemDataMap资源)
	register_custom_resource_types()
	# 2. 注册自定义项目设置
	register_custom_project_settings()

	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_SCRIPT_PATH)
	add_autoload_singleton(TAG_MANAGER_AUTOLOAD_NAME, TAG_MANAGER_SCRIPT_PATH)

	# 创建 Tag Manager 面板
	_create_tag_manager_panel()

	ProjectSettings.save()

	print("ContainerSystem插件加载完成")

# ---------------
# 插件卸载时执行(禁用/关闭编辑器时)
# ---------------
func _exit_tree():
	# 1. 注销自定义资源类型
	unregister_custom_resource_types()
	# 2. 移除自定义项目设置
	if ProjectSettings.has_setting(ITEM_DATA_MAP_SETTING_PATH):
		ProjectSettings.set_setting(ITEM_DATA_MAP_SETTING_PATH, null)
	if ProjectSettings.has_setting(TAG_HIERARCHY_SETTING_PATH):
		ProjectSettings.set_setting(TAG_HIERARCHY_SETTING_PATH, null)

	remove_autoload_singleton(AUTOLOAD_NAME)
	remove_autoload_singleton(TAG_MANAGER_AUTOLOAD_NAME)

	# 移除 Tag Manager 面板
	_remove_tag_manager_panel()

	# ProjectSettings.save()

	print("ContainerSystem 插件已卸载")

# ---------------
# 创建 Tag Manager 面板
# ---------------
func _create_tag_manager_panel() -> void:
	var panel_script = load(TAG_MANAGER_PANEL_PATH)
	if panel_script:
		_tag_manager_panel = panel_script.new()
		# 必须在添加到 dock 之前设置 name，这样 dock 标签才会显示正确的名称
		_tag_manager_panel.name = "Tag Manager"
		# DOCK_SLOT_LEFT_BL = 1，左侧面板的下半部分（FileSystem 所在位置）
		add_control_to_dock(DOCK_SLOT_LEFT_BL, _tag_manager_panel)

# ---------------
# 移除 Tag Manager 面板
# ---------------
func _remove_tag_manager_panel() -> void:
	if _tag_manager_panel:
		remove_control_from_docks(_tag_manager_panel)
		_tag_manager_panel.queue_free()
		_tag_manager_panel = null

# ---------------
# 注册自定义资源类型
# ---------------
func register_custom_resource_types() -> void:
	# 注册 BaseTemplate 资源类型
	# 参数说明：
	# 1. 显示名称（右键新建时看到的名称）
	# 2. 基类（必须是 Resource 或其子类）
	# 3. 脚本路径
	# 4. 图标路径（可选，填""则用默认图标）
	register_single_custom_type("Base Template", "Resource", ITEM_DATA_PATH, "")
	# 注册 ItemDataMap 资源类型
	register_single_custom_type("Item Data Map", "Resource", ITEM_DATA_MAP_CLASS_PATH, "")
	# 注册 TagHierarchy 资源类型
	register_single_custom_type("Tag Hierarchy", "Resource", TAG_HIERARCHY_CLASS_PATH, "")

# 封装单个类型的注册逻辑（方便复用）
func register_single_custom_type(display_name: String, base_class: String, script_path: String, icon_path: String) -> void:
	# 加载脚本并验证
	var script = load(script_path)
	if not script:
		push_error("注册失败：脚本不存在 %s" % script_path)
		return
	# 注册自定义类型
	add_custom_type(display_name, base_class, script, null)
	# 记录已注册的类型（用于卸载）
	_registered_resource_types.append({
		"display_name": display_name,
		"base_class": base_class,
		"script": script,
		"icon_path": icon_path
	})

# ------------------------------
# 注销自定义资源类型
# ------------------------------
func unregister_custom_resource_types() -> void:
	for type_info in _registered_resource_types:
		remove_custom_type(type_info.display_name)
	_registered_resource_types.clear()

# ------------------------------
# 注册自定义项目设置（逻辑不变）
# ------------------------------
func register_custom_project_settings() -> void:
	# 延迟加载资源，避免在插件初始化时过早加载导致项目路径问题
	var template_path = "res://addons/ContainerSystem/templates/ItemDataMapTemplate.tres"
	ProjectSettings.set_setting(ITEM_DATA_MAP_SETTING_PATH, template_path)
	# 注册自定义项目设置
	var property_info = {
		"name": ITEM_DATA_MAP_SETTING_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
	}
	ProjectSettings.add_property_info(property_info)

	# 新增：标签层级设置
	var hierarchy_path = "res://addons/ContainerSystem/templates/TagHierarchy.tres"
	ProjectSettings.set_setting(TAG_HIERARCHY_SETTING_PATH, hierarchy_path)
	ProjectSettings.add_property_info({
		"name": TAG_HIERARCHY_SETTING_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres"
	})
