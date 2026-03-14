## 玩家节点，用于表示游戏中的玩家。
## 对于多人联机游戏，每个玩家负责管理自己的 PlayerNode 实例和 PlayerState 实例。
## 只是所有的维护动作是在服务器端进行的，客户端只负责显示和交互。
class_name PlayerNode
extends Node2D

@onready var multiplayer_synchronizer : MultiplayerSynchronizer = $MultiplayerSynchronizer

## 客户端同步完成后触发，外部可连接此信号来获取初始化完成的通知
signal sync_completed()

## 多人链接下的底层id
var peer_id : int = 0
## 多人联机状态下的id
var multiplayer_id : StringName = "0"

## 玩家状态
var player_state : PlayerState = null

## 玩家运行时数据
var player_actor : PlayerActor = null

## 对外显示的玩家数据
@export var sync_player_data : Dictionary = {}

## 初始化玩家节点，设置玩家id和状态。
## 注意：不在此处调 set_multiplayer_authority，改由 _enter_tree 处理，
## 避免 MultiplayerSynchronizer 在节点未入树时缺少 network ID。
func setup(_peer_id: int) -> void:
	peer_id = _peer_id
	self.multiplayer_id = "player_" + str(_peer_id)
	player_state = PlayerState.new(multiplayer_id)
	player_actor = PlayerActor.new(multiplayer_id, player_state)
	sync_player_data = {
		"peer_id": _peer_id,
		"multiplayer_id": multiplayer_id,
	}

func _enter_tree() -> void:
	## 客户端通过 MultiplayerSpawner 复制时 peer_id 还是 0，
	## 从节点名 "Player_{peer_id}" 解析真实 peer_id。
	if peer_id == 0 and name.begins_with("Player_"):
		peer_id = name.trim_prefix("Player_").to_int()
	if peer_id != 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	if not multiplayer.is_server():
		if not sync_player_data.is_empty():
			## spawn = true 时数据随节点一起到达，_ready() 时已可用
			_init_from_sync()
		else:
			## 数据尚未到达，等后续同步
			multiplayer_synchronizer.synchronized.connect(_on_synchronized)

func _on_synchronized() -> void:
	if player_state == null and not sync_player_data.is_empty():
		_init_from_sync()
		multiplayer_synchronizer.synchronized.disconnect(_on_synchronized)

func _init_from_sync() -> void:
	peer_id = sync_player_data.get("peer_id", 0)
	multiplayer_id = sync_player_data.get("multiplayer_id", "0")
	player_state = PlayerState.new(multiplayer_id)
	## deferred emit 确保外部 child_entered_tree 回调有机会先连接此信号
	(func():
		sync_completed.emit()
	).call_deferred()