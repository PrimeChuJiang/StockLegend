## 多玩家处理类，负责处理玩家之间的通信以及游戏创建，加入，退出等操作。
class_name MultiplayerHandler
extends Node

## IP地址
const IP_ADDRESS : String = "localhost"
## 服务器端口号
const SERVER_PORT : int = 9090
## 对等端
var peer : ENetMultiplayerPeer
## 最大容纳客户端数量
var max_players : int = 4	
## 玩家列表
var players : Array[PlayerNode] = []
## 客户端Id和玩家Id双端映射表
var peer_to_player : Dictionary = {}
var player_to_peer : Dictionary = {}

func _ready():
	GameBus.player_connected.connect(_on_peer_connected)
	GameBus.player_disconnected.connect(_on_peer_disconnected)

## 创建服务器
func create_server():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, max_players)
	if error != OK:
		printerr("[MultiplayerHandler] 创建服务器失败: %s" % error)
		return
	multiplayer.multiplayer_peer = peer	
	GameBus.server_created.emit()
 
## 创建客户端
func create_client(server_address: String = IP_ADDRESS, _server_port: int = SERVER_PORT):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_address, _server_port)
	if error != OK:
		printerr("[MultiplayerHandler] 客户端链接失败: %s" % error)
		return
	multiplayer.multiplayer_peer = peer

## 注册玩家
func register_player(peer_id: int, player_node: PlayerNode) -> void:
	peer_to_player[peer_id] = player_node.multiplayer_id
	player_to_peer[player_node.multiplayer_id] = peer_id
	players.append(player_node)

## 取消注册玩家
func unregister_player(peer_id: int, player_node: PlayerNode) -> void:
	peer_to_player.erase(peer_id)
	player_to_peer.erase(player_node.multiplayer_id)
	players.erase(player_node)


## ———— 信号绑定函数 ———————————————————————————————————————————————————————
func _on_peer_connected(player_node: PlayerNode):
	print("[MultiplayerHandler] 玩家 %s 连接成功" % player_node.multiplayer_id)
	register_player(player_node.peer_id, player_node)
	

func _on_peer_disconnected(player_node: PlayerNode):
	print("[MultiplayerHandler] 玩家 %s 断开连接" % player_node.multiplayer_id)
	unregister_player(player_node.peer_id, player_node)
	
