## 多人联机游戏中的玩家节点生成器。
class_name MultiplayerSpawnerNode
extends MultiplayerSpawner

@export var player_scene : PackedScene

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	GameBus.server_created.connect(_on_server_created)

func _on_server_created() -> void:
	if ! multiplayer.is_server(): return

	print("主机已创建，创建主机玩家节点")
	_create_new_player(1)

func _on_peer_connected(peer_id: int) -> void:
	if ! multiplayer.is_server(): return

	print("peer connected: ", peer_id)
	# 为新连接的玩家创建一个 PlayerNode 实例
	_create_new_player(peer_id)

func _create_new_player(peer_id: int) -> void:
	var player_node: PlayerNode = player_scene.instantiate()
	player_node.setup(peer_id)
	player_node.name = "Player_%d" % peer_id
	(func():
		get_node(spawn_path).add_child(player_node, true)
		GameBus.player_connected.emit(player_node)
	).call_deferred()