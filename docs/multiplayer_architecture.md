# StockLegend 多人游戏架构文档

> 本文档描述 StockLegend 项目当前已实现的多人游戏架构，适合开发者快速了解代码结构和数据流。

---

## 1. 总体架构：主机权威制（Host Authority P2P）

```
┌─────────────────────────────────┐         ┌────────────────────────────┐
│         主机（Host）              │         │       客户端（Client）       │
│                                 │         │                            │
│  TurnManager    ← 回合驱动器     │         │  UI 层（按钮、标签、面板）    │
│  StockManager   ← 股票市场       │  ENet   │                            │
│  WorldStartActor ← 世界开始      │ ◄─────► │  本地 PlayerState 镜像      │
│  WorldEndActor   ← 世界结算      │  P2P    │  （只读，由主机 RPC 更新）    │
│  PlayerActor×N   ← 每个玩家的    │         │                            │
│  PlayerState×N   ← 逻辑+状态     │         │  只做两件事：               │
│                                 │         │    ① 发送操作指令给主机      │
│  所有游戏逻辑在这里运行          │         │    ② 接收主机推送的状态更新   │
└─────────────────────────────────┘         └────────────────────────────┘
```

**核心原则：**
- 所有游戏逻辑（回合推进、交易验证、文章结算、股价计算）**只在主机上运行**
- 客户端不做任何业务计算，只负责 UI 展示和发送操作请求
- 主机既是服务器也是一个玩家（第一个加入的 peer_id = 1）
- 使用 Godot 4.4 的 **High-Level Multiplayer API**（ENetMultiplayerPeer + RPC）

---

## 2. 文件结构

```
Scripts/
├── autoload/
│   ├── game_bus.gd              # GameBus — 信号总线（AutoLoad 单例）
│   └── multiplayer_handler.gd   # MultiplayerHandler — 连接管理（AutoLoad 单例）
├── runtime/
│   ├── Node/
│   │   ├── player_node.gd       # PlayerNode — 网络玩家节点
│   │   └── multiplayer_spawner.gd # MultiplayerSpawnerNode — 玩家自动生成
│   ├── actor.gd                 # Actor — 行动者基类
│   ├── player_actor.gd          # PlayerActor — 玩家行动者
│   ├── player_state.gd          # PlayerState — 玩家数据
│   ├── world_actor.gd           # WorldStartActor — 世界开始阶段
│   └── world_end_actor.gd       # WorldEndActor — 世界结算阶段
├── systems/
│   ├── turn_manager.gd          # TurnManager — 回合驱动 + RPC 中枢
│   └── stock_manager.gd         # StockManager — 股票管理 + 同步 RPC
└── test/
    └── test_turn.gd             # 测试场景脚本（含多人集成）

Scenes/
└── test_turn.tscn               # 测试场景（含 Players 容器、MultiplayerSpawner）
```

---

## 3. 节点树结构

```
test_turn (Node)                       ← 场景根节点
├── TurnManager (Node)                 ← 回合驱动器 + 所有 RPC
├── Players (Node2D)                   ← 玩家节点容器
│   ├── Player_1 (PlayerNode)          ← 主机的玩家节点
│   ├── Player_12345 (PlayerNode)      ← 客户端A的玩家节点
│   └── Player_67890 (PlayerNode)      ← 客户端B的玩家节点
├── MultiplayerSpawner (MultiplayerSpawnerNode)  ← 自动生成/复制 PlayerNode
├── CanvasLayer                        ← UI 层
│   ├── Panel / ...                    ← 操作按钮
│   ├── StockPanel / ...               ← 股票信息
│   ├── AssetsPanel / ...              ← 资产信息
│   ├── DealPanel / ...                ← 交易按钮
│   └── MultiplayerPanel / ...         ← 开服/加入/开始游戏按钮
└── AutoLoad（不在场景树中可见，但全局可用）
    ├── GameBus                        ← 信号总线
    ├── MultiplayerHandler             ← 连接管理
    └── StockManager                   ← 股票市场
```

---

## 4. 连接建立流程

### 4.1 主机端

```
用户点击"开服" → MultiplayerHandler.create_server()
  └── ENetMultiplayerPeer.create_server(9090, 4)
  └── multiplayer.multiplayer_peer = peer
  └── GameBus.server_created.emit()
       └── MultiplayerSpawnerNode._on_server_created()
            └── _create_new_player(1)  // 为主机自己创建 PlayerNode
```

### 4.2 客户端

```
用户点击"加入" → MultiplayerHandler.create_client("localhost", 9090)
  └── ENetMultiplayerPeer.create_client(address, port)
  └── multiplayer.multiplayer_peer = peer
  └── 连接成功后 Godot 自动触发 peer_connected 信号
       └── 主机侧：MultiplayerSpawnerNode._on_peer_connected(peer_id)
            └── _create_new_player(peer_id)
                 └── 实例化 PlayerNode → setup(peer_id) → add_child()
                 └── MultiplayerSpawner 自动将节点复制到所有客户端
```

### 4.3 PlayerNode 初始化时序

```
┌──────── 主机 ────────┐          ┌──────── 客户端 ────────┐
│ setup(peer_id)        │          │                        │
│  ├─ 设置 peer_id      │          │                        │
│  ├─ 生成 multiplayer_id│         │                        │
│  ├─ 创建 PlayerState  │          │                        │
│  ├─ 创建 PlayerActor  │          │                        │
│  └─ 填充 sync_player_data       │                        │
│                       │          │                        │
│ add_child()           │ ──复制──► │ 节点到达              │
│                       │          │  └─ _enter_tree()       │
│                       │          │     └─ 从节点名解析 peer_id │
│                       │          │     └─ set_multiplayer_authority │
│                       │          │  └─ _ready()            │
│                       │          │     └─ 检查 sync_player_data │
│                       │          │     └─ _init_from_sync() │
│                       │          │        ├─ 创建本地 PlayerState │
│                       │          │        └─ emit sync_completed │
└───────────────────────┘          └────────────────────────┘
```

---

## 5. 玩家 ID 体系

| 层级 | 变量名 | 类型 | 说明 | 示例 |
|------|--------|------|------|------|
| 网络层 | `peer_id` | `int` | Godot 分配的网络 ID，主机固定为 1 | 1, 23456, 78901 |
| 游戏层 | `multiplayer_id` | `StringName` | 项目自定义的玩家 ID | `"player_1"`, `"player_23456"` |

```gdscript
# 映射关系（MultiplayerHandler 维护）
peer_to_player = {1: "player_1", 23456: "player_23456"}
player_to_peer = {"player_1": 1, "player_23456": 23456}

# 本地玩家识别
var my_peer_id = multiplayer.get_unique_id()  # 每个客户端知道自己的 peer_id
```

---

## 6. RPC 通信架构

### 6.1 数据流方向

```
  客户端                    主机                    所有客户端
 ┌─────────┐           ┌──────────┐           ┌──────────────┐
 │ UI 操作  │──request──►│ 验证+执行 │──sync RPC──►│ 更新本地镜像  │
 │ 按钮点击  │  rpc_id(1) │ 业务逻辑  │  .rpc()    │ 触发 GameBus │
 └─────────┘           └──────────┘           └──────────────┘
```

### 6.2 客户端 → 主机：操作请求 RPC

所有请求 RPC 声明为 `@rpc("any_peer", "reliable")`，表示任何对等端都可以调用，但函数体内用 `if not multiplayer.is_server(): return` 确保只有主机执行。

| RPC 函数 | 参数 | 作用 |
|----------|------|------|
| `request_end_turn` | `player_id` | 请求结束回合 |
| `request_gather` | `player_id` | 请求获取素材 |
| `request_craft` | `player_id, turn` | 请求合成文章 |
| `request_publish` | `player_id` | 请求发表文章 |
| `request_buy_stock` | `player_id, stock_id, quantity` | 请求买入股票 |
| `request_sell_stock` | `player_id, stock_id, quantity` | 请求卖出股票 |

**调用方式：**
```gdscript
# 客户端调用，目标 ID 为 1（主机）
turn_manager.request_gather.rpc_id(1, _local_multiplayer_id)

# 主机本地操作，直接执行
_player_actor.try_gather_material({})
```

### 6.3 主机 → 客户端：状态同步 RPC

所有同步 RPC 声明为 `@rpc("authority", "reliable")`，表示只有权威端（主机）可以调用，所有客户端接收。

**TurnManager 中的同步 RPC：**

| RPC 函数 | 同步内容 | 客户端行为 |
|----------|---------|-----------|
| `_sync_turn_started/ended` | 回合开始/结束 | emit GameBus 信号 |
| `_sync_actor_turn_started/ended` | 行动者阶段 | emit GameBus 信号 |
| `_sync_player_turn_started/ended` | 玩家回合 | emit GameBus 信号，控制按钮启用 |
| `_sync_action_points_changed` | 行动值变化 | 更新本地 PlayerState + emit |
| `_sync_assets_changed` | 现金/持仓变化 | 更新本地 PlayerState + emit |
| `_sync_article_composed` | 文章合成 | emit 序列化版信号 |
| `_sync_article_published` | 文章发表 | emit 序列化版信号 |
| `_sync_trade_result` | 交易结果 | emit GameBus 信号 |
| `_sync_event_revealed` | 日程事件揭示 | 重建精简 config + emit |

**StockManager 中的同步 RPC：**

| RPC 函数 | 同步内容 | 客户端行为 |
|----------|---------|-----------|
| `_sync_stock_price_changed` | 股价变动 | 更新本地 Stock + emit |
| `_sync_stock_delisted` | 股票退市 | 更新本地 Stock + emit |
| `_sync_sentiment_modifier_applied` | 情绪修改器 | 重建 Modifier + 添加到 Stock + emit |
| `_sync_tick_modifiers` | 修改器 tick | 本地所有 Stock tick |

---

## 7. 信号转发机制

主机上的游戏逻辑通过 GameBus 信号通知本地 UI，同时 TurnManager 监听这些信号并自动转发为 RPC 到客户端。

```
┌─ 主机端 ─────────────────────────────────────────────┐
│                                                       │
│  PlayerActor.try_gather_material()                    │
│       │                                               │
│       ▼                                               │
│  GameBus.action_points_changed.emit(pid, val, max)    │
│       │                                               │
│       ├──► 主机本地 UI 更新（通过信号连接）              │
│       │                                               │
│       └──► TurnManager._forward_action_points_changed()│
│                 │                                     │
│                 └── if _is_network_server():           │
│                       _sync_action_points_changed.rpc()│
│                           │                           │
└───────────────────────────│───────────────────────────┘
                            │
                            ▼  (网络传输)
┌─ 客户端 ─────────────────────────────────────────────┐
│  TurnManager._sync_action_points_changed()            │
│       │                                               │
│       ├── _update_client_player_state(pid, data)      │
│       │     └── 找到本地 PlayerNode → 更新 PlayerState │
│       │                                               │
│       └── GameBus.action_points_changed.emit(...)     │
│                 │                                     │
│                 └──► 客户端 UI 更新（通过信号连接）      │
└───────────────────────────────────────────────────────┘
```

**关键设计：客户端收到同步 RPC 后，重新 emit 对应的 GameBus 信号。这使得 UI 层代码在主机和客户端上完全相同——UI 只监听 GameBus 信号，不关心数据来源。**

---

## 8. 回合系统与多人整合

### 8.1 Actor 序列

```
actors = [
    WorldStartActor,    # 世界开始：揭示日程事件、突发事件
    PlayerActor("player_1"),  # 玩家1回合
    PlayerActor("player_23456"),  # 玩家2回合
    PlayerActor("player_78901"),  # 玩家3回合
    WorldEndActor,      # 世界结算：文章结算、股价结算
]
```

### 8.2 游戏循环

```gdscript
# TurnManager._game_loop() — 只在主机上运行
func _game_loop() -> void:
    while true:
        turn_number += 1
        GameBus.turn_started.emit(turn_number)
        _sync_turn_started.rpc(turn_number)  # 通知客户端

        for actor in actors:
            await actor.execute_turn(_ctx)   # 依次执行每个 Actor

        GameBus.turn_ended.emit(turn_number)
        _sync_turn_ended.rpc(turn_number)    # 通知客户端
```

### 8.3 玩家动态加入

```gdscript
func add_player(player: PlayerNode) -> void:
    # 插入到 WorldEndActor 之前
    actors.insert(actors.size() - 1, player.player_actor)
    _ctx["player_states"].append(player.player_state)
```

---

## 9. 对象序列化

RPC 只能传输基本类型（int, float, String, Dictionary, Array），不能直接传输自定义 Resource 或 RefCounted 对象。项目中需要序列化的对象：

### Article（文章）

```gdscript
# 主机端序列化
static func _serialize_article(article: Article) -> Dictionary:
    return {
        "article_id": article.article_id,
        "article_type": article.article_type,
        "direction": article.direction,
        "final_impact": article.final_impact,
        "final_credibility": article.final_credibility,
        "target_industry": article.target_industry.name if article.target_industry else "",
        "summary": article.get_summary(),
    }

# 客户端使用序列化后的 Dictionary 直接显示
```

### SentimentModifier（情绪修改器）

```gdscript
# 主机端拆解为基本类型传输
_sync_sentiment_modifier_applied.rpc(stock_id, mod.source_id, mod.value, mod.remaining_turns)

# 客户端重建对象
func _sync_sentiment_modifier_applied(stock_id, source_id, value, remaining):
    var mod := SentimentModifier.new()
    mod.source_id = source_id
    mod.value = value
    mod.remaining_turns = remaining
    stock.add_modifier(mod)
```

### ScheduleEventConfig（日程事件）

```gdscript
# 主机端序列化为 {turn_number: [preview_name, ...]}
var serialized: Dictionary = {}
for turn_key in cfg_dic:
    var names: Array = []
    for cfg in cfg_dic[turn_key]:
        names.append(cfg.preview_name)
    serialized[turn_key] = names

# 客户端反序列化重建精简版对象
```

---

## 10. 同步数据总表

| 数据 | 方向 | 触发时机 | 同步方式 | 所在文件 |
|------|------|---------|---------|---------|
| 回合开始/结束 | 主→全 | 每回合 | `_sync_turn_started/ended` | turn_manager.gd |
| 行动者阶段 | 主→全 | 每阶段 | `_sync_actor_turn_started/ended` | turn_manager.gd |
| 世界阶段 | 主→全 | 每阶段 | `_sync_world_*_phase_*` | turn_manager.gd |
| 玩家回合 | 主→全 | 轮到时 | `_sync_player_turn_started/ended` | turn_manager.gd |
| 行动值 | 主→全 | 变化时 | `_sync_action_points_changed` | turn_manager.gd |
| 现金/持仓 | 主→全 | 变化时 | `_sync_assets_changed` | turn_manager.gd |
| 文章合成 | 主→全 | 合成时 | `_sync_article_composed` | turn_manager.gd |
| 文章发表 | 主→全 | 发表时 | `_sync_article_published` | turn_manager.gd |
| 交易结果 | 主→全 | 完成时 | `_sync_trade_result` | turn_manager.gd |
| 日程事件 | 主→全 | 揭示时 | `_sync_event_revealed` | turn_manager.gd |
| 股票价格 | 主→全 | 变化时 | `_sync_stock_price_changed` | stock_manager.gd |
| 股票退市 | 主→全 | 结算时 | `_sync_stock_delisted` | stock_manager.gd |
| 情绪修改器 | 主→全 | 应用时 | `_sync_sentiment_modifier_applied` | stock_manager.gd |
| 修改器 tick | 主→全 | 回合尾 | `_sync_tick_modifiers` | stock_manager.gd |
| 操作请求 | 客→主 | 操作时 | `request_*` | turn_manager.gd |

---

## 11. 本地/网络逻辑分离模式

项目中所有 UI 操作都遵循统一的 `if/else` 模式：

```gdscript
func _on_some_button_pressed() -> void:
    if multiplayer.is_server():
        # 主机：直接执行业务逻辑
        _player_actor.do_something()
    else:
        # 客户端：通过 RPC 发送请求给主机
        turn_manager.request_something.rpc_id(1, _local_multiplayer_id)
```

网络检查工具函数：

```gdscript
func _is_network_server() -> bool:
    return multiplayer.has_multiplayer_peer() and multiplayer.is_server()
```

---

## 12. 当前实现状态

| 功能 | 状态 |
|------|------|
| 主机-客户端连接（ENet） | 已实现 |
| 玩家自动生成（MultiplayerSpawner） | 已实现 |
| 玩家数据初始同步（MultiplayerSynchronizer） | 已实现 |
| 所有操作 RPC（素材/合成/发表/交易） | 已实现 |
| 所有状态同步 RPC（行动值/资产/股票/文章） | 已实现 |
| 玩家识别与权限（set_multiplayer_authority） | 已实现 |
| 本地 vs 网络逻辑分离 | 已实现 |
| AI 填充 | 规划中 |
| 断线重连 | 规划中 |
| NAT 穿透 | 规划中 |
