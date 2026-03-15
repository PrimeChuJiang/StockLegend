# 多人游戏架构入门教程

> 以 StockLegend 项目为实例，从零理解多人游戏的核心概念。
> 适合完全没有多人游戏开发经验的读者。

---

## 第一章：为什么多人游戏和单人游戏不一样？

### 1.1 单人游戏的世界

在单人游戏中，一切都很简单：

```
玩家按下按钮 → 游戏逻辑执行 → 画面更新
```

所有代码都在同一台电脑上运行，数据都在内存里，随时可以读写。你不需要担心"谁有权修改数据"或"数据是否过时"这类问题。

### 1.2 多人游戏的挑战

当有多个玩家时，每个人在**不同的电脑**上运行着**各自的游戏程序**。这就带来了三个根本性问题：

**问题一：谁说了算？（权威性）**

玩家 A 说"我买了 10 股"，玩家 B 也说"我买了 10 股"——但库存只有 15 股。两个请求几乎同时到达，谁先谁后？最终库存是多少？

如果每个玩家自己在本地计算结果，很快就会出现**状态不一致**：A 的电脑说库存是 5，B 的电脑说库存也是 5，但实际应该只剩 5 或 0。

**问题二：怎么让大家看到一样的东西？（同步性）**

玩家 A 发表了一篇文章影响股价，玩家 B 和 C 的屏幕上也需要看到股价变化。但网络有延迟，B 可能 50ms 后才看到，C 可能 200ms 后才看到。

**问题三：怎么防作弊？（安全性）**

如果玩家本地可以直接修改自己的金钱数据，那作弊就太容易了。

### 1.3 解决思路

针对这三个问题，游戏行业发展出了几种主流架构，本项目选择的是其中最直觉的一种——**主机权威制**。

---

## 第二章：多人游戏的三种主流架构

在深入代码之前，先了解行业中的三种主流方案：

### 2.1 专用服务器（Dedicated Server）

```
        ┌─────────────┐
        │  专用服务器    │  ← 一台独立的机器，只跑游戏逻辑
        │  (无画面)     │
        └──┬──┬──┬──┘
           │  │  │
     ┌─────┘  │  └─────┐
     ▼        ▼        ▼
 客户端A   客户端B   客户端C   ← 每个玩家都是客户端
```

- **特点**：有一台独立的服务器只运行游戏逻辑，没有画面。所有玩家都是客户端。
- **优点**：最公平（没有"主机优势"），最安全，服务器性能可优化。
- **缺点**：需要部署和维护服务器，成本高。
- **典型案例**：CS2、Valorant、大部分 MMORPG。

### 2.2 主机权威制（Host Authority / Listen Server）

```
        ┌─────────────────┐
        │  主机（Host）     │  ← 既是服务器又是玩家
        │  服务器 + 玩家A   │
        └──────┬──┬──────┘
               │  │
         ┌─────┘  └─────┐
         ▼              ▼
      客户端B         客户端C   ← 其他玩家是客户端
```

- **特点**：某个玩家的电脑同时充当服务器。**这就是 StockLegend 使用的方案。**
- **优点**：不需要独立服务器，开发简单，适合小规模游戏。
- **缺点**：主机玩家有延迟优势（本地操作零延迟），主机断线则游戏结束。
- **典型案例**：Among Us、很多独立多人游戏。

### 2.3 帧同步 / 锁步（Lockstep）

```
  玩家A      玩家B      玩家C
    │          │          │
    │  输入    │  输入    │  输入
    ▼          ▼          ▼
 ┌──────────────────────────┐
 │   每帧收集所有人的输入      │
 │   所有客户端用相同输入       │
 │   运行相同的游戏逻辑        │
 └──────────────────────────┘
    │          │          │
    ▼          ▼          ▼
  相同结果   相同结果   相同结果
```

- **特点**：不同步"状态"，而是同步"输入"。所有客户端拿到相同的输入，各自计算，得到相同的结果。
- **优点**：网络流量极小（只传输输入），回放容易实现。
- **缺点**：所有逻辑必须完全确定性（浮点数可能导致偏差），延迟受最慢玩家影响。
- **典型案例**：星际争霸、王者荣耀、格斗游戏。

### 2.4 为什么 StockLegend 选择主机权威制？

| 考量 | 分析 |
|------|------|
| 游戏类型 | 回合制，不需要实时帧同步 |
| 玩家规模 | 3~5 人，小规模 |
| 开发成本 | 不想部署独立服务器 |
| 公平性要求 | 回合制游戏中主机延迟优势可忽略 |
| Godot 支持 | Godot 内置 RPC + MultiplayerSpawner 天然支持这种模式 |

---

## 第三章：Godot 的多人游戏工具箱

Godot 4.x 提供了一套**高级多人 API（High-Level Multiplayer API）**，StockLegend 用到了以下组件：

### 3.1 ENetMultiplayerPeer — 网络连接

ENet 是一个可靠的 UDP 网络库。Godot 把它封装成了 `ENetMultiplayerPeer`，用起来只需要几行代码：

```gdscript
# 创建服务器（主机）
var peer = ENetMultiplayerPeer.new()
peer.create_server(9090, 4)        # 端口 9090，最多 4 个客户端
multiplayer.multiplayer_peer = peer

# 创建客户端
var peer = ENetMultiplayerPeer.new()
peer.create_client("192.168.1.100", 9090)  # 连接到主机的 IP 和端口
multiplayer.multiplayer_peer = peer
```

连接成功后，Godot 会自动给每个对等端（peer）分配一个唯一的整数 ID：
- **主机的 ID 固定为 1**
- 客户端的 ID 是随机的大整数，如 23456、78901

你可以通过 `multiplayer.get_unique_id()` 获取自己的 ID。

> **在 StockLegend 中**：`MultiplayerHandler`（AutoLoad 单例）封装了连接逻辑，见 `Scripts/autoload/multiplayer_handler.gd`。

### 3.2 RPC — 远程过程调用

RPC（Remote Procedure Call）是多人游戏中最核心的通信机制。简单说就是：**在一台电脑上调用函数，让另一台电脑执行这个函数**。

```gdscript
# 声明一个 RPC 函数
@rpc("any_peer", "reliable")
func say_hello(message: String) -> void:
    print("收到消息：", message)

# 在另一台电脑上调用
say_hello.rpc("你好！")              # 调用所有人的 say_hello
say_hello.rpc_id(1, "你好主机！")     # 只调用 ID 为 1 的（主机的）say_hello
```

#### RPC 的两个关键参数

**谁可以调用？**
- `"authority"` — 只有权威端（通常是主机）可以调用此 RPC，用于主机→客户端的同步
- `"any_peer"` — 任何对等端都可以调用此 RPC，用于客户端→主机的请求

**可靠性：**
- `"reliable"` — 保证送达且保序（像 TCP），适合游戏逻辑
- `"unreliable"` — 可能丢包但更快（像 UDP），适合位置同步等实时数据

> **在 StockLegend 中**：所有 RPC 都用 `"reliable"`，因为回合制游戏的每条消息都很重要，不能丢。

### 3.3 MultiplayerSpawner — 自动节点复制

当主机创建一个节点（如 PlayerNode）并添加到场景树时，`MultiplayerSpawner` 会自动将这个节点**复制到所有客户端的场景树中**。

```
主机：add_child(PlayerNode)
  │
  └──► MultiplayerSpawner 自动复制
        ├──► 客户端B 的场景树中出现同名 PlayerNode
        └──► 客户端C 的场景树中出现同名 PlayerNode
```

**注意**：复制的只是节点本身和 `@export` 属性，不包括代码中动态创建的对象（如 PlayerState、PlayerActor）。所以客户端需要在 `_ready()` 中自己创建这些对象。

> **在 StockLegend 中**：`MultiplayerSpawnerNode`（继承 `MultiplayerSpawner`）负责在有人连接时自动创建 PlayerNode，见 `Scripts/runtime/Node/multiplayer_spawner.gd`。

### 3.4 MultiplayerSynchronizer — 属性自动同步

这是 Godot 提供的另一个同步工具，可以自动将指定属性从权威端同步到其他端：

```
主机修改 PlayerNode.sync_player_data
  │
  └──► MultiplayerSynchronizer 自动将新值推送到客户端
        └──► 客户端的 PlayerNode.sync_player_data 被更新
```

> **在 StockLegend 中**：PlayerNode 的 `sync_player_data` 字典通过 MultiplayerSynchronizer 同步，确保客户端能拿到 `peer_id` 和 `multiplayer_id`。

### 3.5 multiplayer_authority — 谁拥有这个节点？

每个节点都有一个"权威"（authority），表示谁有权控制它。默认情况下权威是主机（ID=1），但你可以改：

```gdscript
# 让 peer_id 为 23456 的客户端成为这个节点的权威
set_multiplayer_authority(23456)
```

**权威决定了**：
- 谁可以调用 `@rpc("authority")` 标记的函数
- MultiplayerSynchronizer 从哪个端同步数据

> **在 StockLegend 中**：每个 PlayerNode 的权威被设置为对应的 peer_id，这样 MultiplayerSynchronizer 可以从主机同步数据到对应的客户端。

---

## 第四章：StockLegend 的多人架构实战

现在我们用 StockLegend 的真实代码来看这些概念是怎么落地的。

### 4.1 从按下"买入"按钮到股价更新 —— 一次完整的数据之旅

假设你是**客户端 B**，你按下了"买入科技Alpha"按钮。来看看这一次点击，数据经历了怎样的旅程：

```
═══ 客户端 B 的电脑 ═══════════════════════════════════════════

  ① 你按下"买入"按钮
     │
     ▼
  ② test_turn.gd._on_buy_tech_alpha_pressed()
     │
     ├── multiplayer.is_server() → false（你不是主机）
     │
     ▼
  ③ turn_manager.request_buy_stock.rpc_id(1, "player_23456", "tech_alpha", 1)
     │   ↑ rpc_id(1, ...) 表示"把这个函数调用发送给 ID=1 的主机"
     │
     ╔══════════ 网络传输 ══════════╗
     ║  数据包通过 ENet 发往主机     ║
     ╚══════════════════════════════╝

═══ 主机的电脑 ═════════════════════════════════════════════════

  ④ TurnManager.request_buy_stock("player_23456", "tech_alpha", 1) 被执行
     │
     ├── if not multiplayer.is_server(): return  ← 安全检查通过
     │
     ▼
  ⑤ 找到 player_23456 的 PlayerActor
     │
     ▼
  ⑥ actor.try_buy_stock("tech_alpha", 1)
     │   主机验证：有足够现金吗？股票存在吗？没有退市吧？
     │
     ├── 验证通过 → 修改 PlayerState（减少现金，增加持仓）
     │
     ▼
  ⑦ GameBus.player_trade.emit("player_23456", "tech_alpha", 1, true, true)
     │   GameBus.assets_changed.emit("player_23456", new_cash, new_holdings)
     │
     ├──► 主机本地 UI 更新（主机玩家也能看到交易记录）
     │
     ▼
  ⑧ TurnManager._forward_assets_changed() 被信号触发
     │
     ▼
  ⑨ _sync_assets_changed.rpc("player_23456", new_cash, new_holdings)
     │   _sync_trade_result.rpc("player_23456", "tech_alpha", 1, true, true)
     │   ↑ .rpc() 不带 id → 发送给所有客户端
     │
     ╔══════════ 网络传输 ══════════╗
     ║  数据包通过 ENet 发往所有客户端 ║
     ╚══════════════════════════════╝

═══ 客户端 B 的电脑（收到回复）════════════════════════════════

  ⑩ TurnManager._sync_assets_changed("player_23456", cash, holdings) 被执行
     │
     ├── _update_client_player_state("player_23456", {...})
     │     └── 找到本地 PlayerNode → 更新本地 PlayerState 镜像
     │
     └── GameBus.assets_changed.emit("player_23456", cash, holdings)
           │
           └──► 你的 UI 更新：现金减少了，持仓多了 1 股科技Alpha

═══ 客户端 C 的电脑（旁观者）═══════════════════════════════════

  ⑩' 同样收到 _sync_assets_changed 和 _sync_trade_result
     │
     └──► 如果 UI 显示了所有玩家的信息，C 也能看到 B 买了股票
```

### 4.2 主机玩家的特殊待遇

注意上面 ② 处的 `if/else`。如果是**主机玩家**自己点击按钮：

```gdscript
func _do_buy_stock(stock_id: StringName, quantity: int) -> void:
    if multiplayer.is_server():
        # 主机：跳过网络，直接执行！
        _player_actor.try_buy_stock(stock_id, quantity)
    else:
        # 客户端：走网络 RPC
        turn_manager.request_buy_stock.rpc_id(1, ...)
```

主机玩家不需要给自己发 RPC——那就像给自己寄快递一样多此一举。直接调用函数就行。

### 4.3 "信号转发"模式——优雅的同步方案

StockLegend 使用了一个很聪明的设计模式：**信号转发**。

**核心思想：** 游戏逻辑不关心网络。逻辑代码（PlayerActor、StockManager）执行完后，像单人游戏一样发出 GameBus 信号。TurnManager 监听这些信号，自动通过 RPC 转发给客户端。

```gdscript
# TurnManager._ready() 中连接所有需要同步的信号
func _ready() -> void:
    GameBus.action_points_changed.connect(_forward_action_points_changed)
    GameBus.assets_changed.connect(_forward_assets_changed)
    GameBus.stock_price_changed.connect(_forward_stock_price_changed)
    # ... 更多信号

# 转发函数：检查自己是否是主机，是则 RPC 广播
func _forward_assets_changed(player_id, cash, holdings) -> void:
    if _is_network_server():
        _sync_assets_changed.rpc(player_id, cash, holdings)
```

**这个模式的好处：**
1. **游戏逻辑零侵入**：PlayerActor、WorldActor 等完全不知道网络的存在
2. **单人模式免费获得**：不启动网络时，GameBus 信号照常工作，UI 照常更新
3. **新增同步项很容易**：连接新信号 → 写转发函数 → 写接收 RPC，三步完成

### 4.4 客户端的"镜像"世界

客户端不运行任何游戏逻辑，但它需要显示正确的数据。它维护着一个**镜像**：

```
┌─────────────── 主机 ──────────────────┐    ┌────────────── 客户端 ────────────────┐
│ PlayerState (真实数据)                 │    │ PlayerState (镜像数据)                │
│   cash = 8500.0    ← 真正的值          │    │   cash = 8500.0    ← 主机同步过来的   │
│   holdings = {tech_alpha: 3}          │    │   holdings = {tech_alpha: 3}         │
│   action_points = 2                  │    │   action_points = 2                 │
│                                       │    │                                      │
│ TurnManager (运行游戏循环)             │    │ TurnManager (不运行循环，只接收 RPC)   │
│ StockManager (计算股价)               │    │ StockManager (只更新本地显示值)        │
│ PlayerActor (执行操作)                │    │ PlayerActor (客户端没有，或为空)        │
└───────────────────────────────────────┘    └──────────────────────────────────────┘
```

客户端的 PlayerState 是怎么更新的？通过 RPC 接收函数：

```gdscript
# 客户端收到主机的同步 RPC 后：
func _sync_assets_changed(player_id, cash, holdings) -> void:
    # 1. 找到对应的本地 PlayerNode
    # 2. 更新它的 PlayerState
    _update_client_player_state(player_id, {"cash": cash, "holdings": holdings})
    # 3. 重新触发 GameBus 信号，让 UI 更新
    GameBus.assets_changed.emit(player_id, cash, holdings)
```

**关键洞察：客户端收到 RPC 后，重新 emit GameBus 信号。这使得 UI 代码在主机和客户端上完全相同——UI 只监听 GameBus，不关心数据是本地产生的还是网络来的。**

---

## 第五章：玩家生命周期——从连接到加入游戏

### 5.1 PlayerNode：每个玩家的"网络化身"

在单人游戏中，玩家数据可以简单地放在一个变量里。但在多人游戏中，我们需要一个**网络感知的节点**来代表每个玩家：

```gdscript
class_name PlayerNode
extends Node2D

var peer_id: int = 0                    # 网络 ID（Godot 分配）
var multiplayer_id: StringName = "0"     # 游戏 ID（自定义）
var player_state: PlayerState = null     # 玩家数据
var player_actor: PlayerActor = null     # 玩家逻辑（主机才有意义）
@export var sync_player_data: Dictionary = {}  # 需要同步的初始数据
```

**为什么需要 PlayerNode 而不直接用 PlayerState？**

因为 Godot 的多人 API（MultiplayerSpawner、MultiplayerSynchronizer）工作在**节点**（Node）层面。只有节点可以被自动复制到客户端，只有节点上的属性可以被自动同步。

### 5.2 MultiplayerSpawner 的魔法

当有新玩家连接时，主机需要创建一个 PlayerNode 并让所有客户端都知道。手动做这件事很麻烦，MultiplayerSpawner 自动化了这个过程：

```gdscript
# MultiplayerSpawnerNode（主机端运行）
func _on_peer_connected(peer_id: int) -> void:
    if not multiplayer.is_server(): return

    var player_node = player_scene.instantiate()  # 实例化场景
    player_node.setup(peer_id)                     # 设置数据
    player_node.name = "Player_%d" % peer_id       # 命名（重要！）

    # 添加到场景树 → MultiplayerSpawner 自动复制到所有客户端
    get_node(spawn_path).add_child(player_node, true)
```

**为什么节点名很重要？** 客户端收到复制的节点时，`setup()` 不会被重新调用（那是主机的代码），但节点名会保留。客户端通过解析节点名 `"Player_23456"` 来知道这个节点属于哪个 peer：

```gdscript
func _enter_tree() -> void:
    if peer_id == 0 and name.begins_with("Player_"):
        peer_id = name.trim_prefix("Player_").to_int()
```

### 5.3 完整的加入流程

```
时间线 ──────────────────────────────────────────────────────────►

客户端B                          主机
  │                               │
  │  create_client()              │
  │──── TCP握手 ─────────────────►│
  │                               │
  │                               │ peer_connected(23456) 信号
  │                               │ _create_new_player(23456)
  │                               │   ├─ instantiate PlayerNode
  │                               │   ├─ setup(23456)
  │                               │   │   ├─ peer_id = 23456
  │                               │   │   ├─ multiplayer_id = "player_23456"
  │                               │   │   ├─ PlayerState.new("player_23456")
  │                               │   │   └─ PlayerActor.new("player_23456", state)
  │                               │   ├─ name = "Player_23456"
  │                               │   └─ add_child(player_node)
  │                               │         │
  │◄─── MultiplayerSpawner ──────│─────────┘ (自动复制节点)
  │     复制 Player_23456         │
  │                               │ child_entered_tree 信号
  │ _enter_tree()                 │ _on_player_node_added()
  │  └─ 从名字解析 peer_id        │   └─ turn_manager.add_player()
  │  └─ set_multiplayer_authority │       └─ actors 数组插入 PlayerActor
  │                               │
  │ _ready()                      │
  │  └─ sync_player_data 已到达？ │
  │     ├─ 是 → _init_from_sync() │
  │     └─ 否 → 等 synchronized   │
  │              └─ _init_from_sync()
  │                 ├─ 创建本地 PlayerState
  │                 └─ emit sync_completed
  │                      │
  │ _on_client_player_synced()
  │  └─ 识别自己（peer_id == get_unique_id()）
  │  └─ _local_player_node = player_node
  │  └─ 更新 UI
  │                               │
  ▼                               ▼
  准备就绪，等待游戏开始           准备就绪，等待所有人加入
```

---

## 第六章：回合制游戏的多人同步策略

### 6.1 实时游戏 vs 回合制游戏的同步

**实时游戏**（FPS、MOBA）需要在每一帧（每 16ms）同步所有玩家的位置、朝向、动画状态。这需要大量的网络带宽和复杂的预测/回滚算法。

**回合制游戏**幸运得多：
- 状态变化是**离散的**（只在操作时发生）
- 每回合操作次数**有限**（StockLegend：3 个行动值）
- 不需要实时预测和插值
- 可以用**可靠传输**（"reliable"），不怕延迟

所以回合制游戏天然适合**信号驱动的增量同步**：状态变化了才发数据，不变就不发。

### 6.2 StockLegend 的同步时机

```
回合开始 ─────────────────────────────────────────── 回合结束
  │                                                     │
  │  sync_turn_started                                  │  sync_turn_ended
  │     │                                               │
  │     ▼                                               │
  │  WorldStartActor                                    │
  │  ├─ sync_world_start_phase_started                  │
  │  ├─ sync_event_revealed        ← 有事件才发         │
  │  └─ sync_world_start_phase_ended                    │
  │     │                                               │
  │     ▼                                               │
  │  PlayerActor("player_1")                            │
  │  ├─ sync_player_turn_started                        │
  │  │                                                  │
  │  │  (玩家操作期间，按需同步：)                        │
  │  │  ├─ sync_action_points_changed  ← 每次消耗行动值  │
  │  │  ├─ sync_article_composed       ← 合成文章时      │
  │  │  ├─ sync_article_published      ← 发表文章时      │
  │  │  ├─ sync_assets_changed         ← 交易时          │
  │  │  └─ sync_trade_result           ← 交易时          │
  │  │                                                  │
  │  └─ sync_player_turn_ended                          │
  │     │                                               │
  │     ▼                                               │
  │  PlayerActor("player_2")  ...同上...                 │
  │     │                                               │
  │     ▼                                               │
  │  WorldEndActor                                      │
  │  ├─ sync_world_end_phase_started                    │
  │  ├─ sync_stock_price_changed   ← 结算股价时          │
  │  ├─ sync_stock_delisted        ← 有退市才发          │
  │  ├─ sync_tick_modifiers        ← 修改器 tick         │
  │  └─ sync_world_end_phase_ended                      │
  │                                                     │
  ▼─────────────────────────────────────────────────────▼
```

### 6.3 为什么不用帧同步？

回合制游戏用帧同步就像用卡车送一封信——能送到，但大材小用。信号驱动增量同步的优势：

| 对比项 | 帧同步 | 信号驱动增量同步 |
|--------|--------|----------------|
| 网络流量 | 每帧都发数据 | 状态变化时才发 |
| 实现复杂度 | 需要确定性逻辑 | 直接 RPC 发结果 |
| 延迟容忍度 | 必须低延迟 | 几百毫秒也没关系 |
| 适合游戏类型 | RTS、格斗 | 回合制、卡牌 |

---

## 第七章：RPC 的安全设计

### 7.1 永远不信任客户端

多人游戏的铁律：**客户端发来的数据都可能是伪造的**。

StockLegend 的所有 `request_*` RPC 都只传递"意图"，不传递"结果"：

```gdscript
# ✅ 正确做法：客户端只说"我想买"，主机决定能不能买
@rpc("any_peer", "reliable")
func request_buy_stock(player_id: StringName, stock_id: StringName, quantity: int) -> void:
    if not multiplayer.is_server(): return
    var success = actor.try_buy_stock(stock_id, quantity)  # 主机验证+执行
    _sync_trade_result.rpc(player_id, stock_id, quantity, true, success)

# ❌ 错误做法：客户端直接告诉主机"我已经买了，钱变成这么多了"
# @rpc("any_peer", "reliable")
# func update_my_cash(new_cash: float) -> void:
#     player_state.cash = new_cash  # 客户端说多少就是多少？太危险了！
```

### 7.2 `@rpc("authority")` vs `@rpc("any_peer")`

这两个标记决定了 RPC 的**调用权限**，是防作弊的第一道防线：

```gdscript
# 只有主机能调用 → 用于"下发"数据
@rpc("authority", "reliable")
func _sync_assets_changed(player_id, cash, holdings) -> void:
    # 如果某个恶意客户端试图调用这个函数伪造数据
    # Godot 会自动拒绝，因为调用者不是 authority

# 任何人能调用 → 用于"请求"操作
@rpc("any_peer", "reliable")
func request_buy_stock(player_id, stock_id, quantity) -> void:
    if not multiplayer.is_server(): return  # 即使收到也只在主机上执行
```

### 7.3 双保险：函数体内的主机检查

即使 RPC 标记正确，StockLegend 仍然在函数体内加了主机检查：

```gdscript
@rpc("any_peer", "reliable")
func request_end_turn(player_id: StringName) -> void:
    if not multiplayer.is_server():  # ← 双保险
        return
    GameBus.player_ended_turn.emit(player_id)
```

这是一种**防御性编程**：即使 RPC 标记配置错误，函数体内的检查也能阻止非法执行。

---

## 第八章：对象序列化——网络传输的限制

### 8.1 RPC 能传什么？

Godot 的 RPC 可以传输的数据类型：

```
✅ 可以传输                    ❌ 不可以传输
─────────────                 ─────────────
int, float, bool              自定义 class（如 Article）
String, StringName            Resource 子类
Vector2, Vector3, Color       RefCounted 子类
Array, Dictionary             Node（节点引用）
PackedByteArray               Callable（函数引用）
```

简单来说：**基本类型和容器可以传，自定义对象不行**。

### 8.2 怎么传自定义对象？

答案是**序列化**：把对象拆成 Dictionary，传输后再重建。

```gdscript
# ═══ 主机端：拆解为 Dictionary ═══
static func _serialize_article(article: Article) -> Dictionary:
    return {
        "article_id": article.article_id,
        "article_type": article.article_type,       # 枚举值是 int，可传
        "direction": article.direction,
        "final_impact": article.final_impact,
        "final_credibility": article.final_credibility,
        "target_industry": article.target_industry.name if article.target_industry else "",
        "summary": article.get_summary(),
    }

# 通过 RPC 发送
_sync_article_composed.rpc(player_id, _serialize_article(article))

# ═══ 客户端端：用 Dictionary 直接显示 ═══
func _sync_article_composed(player_id: StringName, data: Dictionary) -> void:
    # 不重建 Article 对象，直接用 data 中的字段显示
    GameBus.article_composed_synced.emit(player_id, data)
```

**StockLegend 的做法：客户端不需要完整的 Article 对象，只需要显示用的字段。所以直接传 Dictionary 就够了，不需要反序列化回对象。**

更简单的对象（如 SentimentModifier）可以直接把字段作为 RPC 参数传：

```gdscript
# 不传整个对象，传它的字段
_sync_sentiment_modifier_applied.rpc(
    stock_id,
    mod.source_id,      # StringName
    mod.value,           # int
    mod.remaining_turns  # int
)

# 客户端用字段重建对象
func _sync_sentiment_modifier_applied(stock_id, source_id, value, remaining):
    var mod := SentimentModifier.new()
    mod.source_id = source_id
    mod.value = value
    mod.remaining_turns = remaining
    stock.add_modifier(mod)
```

---

## 第九章：常见陷阱与最佳实践

### 9.1 陷阱：信号的双重触发

```gdscript
# 主机执行逻辑时发出信号
GameBus.stock_price_changed.emit(stock_id, old, new)

# 同时转发给客户端
_sync_stock_price_changed.rpc(stock_id, old, new)

# 客户端收到后重新 emit
func _sync_stock_price_changed(stock_id, old, new):
    GameBus.stock_price_changed.emit(stock_id, old, new)  # ← 又发了一次！
```

**问题：如果主机也监听了这个信号来做 UI 更新，而转发函数又在 emit 之后调用了 .rpc()，那主机端不会收到 RPC（RPC 不发给自己），所以主机端只触发一次，客户端也只触发一次。这是正确的。**

但要小心：如果你错误地让客户端也运行了游戏逻辑（发出信号），又收到了主机的同步 RPC，就会出现**重复处理**。StockLegend 通过严格的 `if not multiplayer.is_server(): return` 避免了这个问题。

### 9.2 陷阱：节点时序

MultiplayerSpawner 复制节点到客户端时，存在时序问题：

```
节点到达客户端 → _enter_tree() → _ready()
                                    │
                    sync_player_data 可能还没到！
```

StockLegend 的解决方案：

```gdscript
func _ready() -> void:
    if not multiplayer.is_server():
        if not sync_player_data.is_empty():
            # 数据已到达（spawn_function 或快速同步的情况）
            _init_from_sync()
        else:
            # 数据还没到，等后续同步
            multiplayer_synchronizer.synchronized.connect(_on_synchronized)
```

### 9.3 最佳实践总结

| 实践 | 说明 |
|------|------|
| **逻辑与网络分离** | 游戏逻辑不知道网络的存在，通过信号桥接 |
| **客户端只发意图** | `request_buy(stock, qty)` 而不是 `set_cash(new_value)` |
| **主机验证一切** | 所有 request RPC 中先检查 `is_server()` |
| **信号驱动同步** | 监听 GameBus → 转发 RPC，而不是手动到处插 rpc 调用 |
| **处理时序** | 用 `synchronized` 信号 + `sync_completed` 信号确保初始化顺序 |
| **用 Dictionary 传复杂数据** | 避免尝试 RPC 传输自定义对象 |
| **主机本地操作走快速路径** | `if is_server(): 直接执行 else: rpc_id(1, ...)` |

---

## 第十章：扩展阅读

### 10.1 如果我要加一个新的同步操作？

比如要加一个"丢弃手牌"操作：

**第一步：在 TurnManager 中添加请求 RPC**

```gdscript
@rpc("any_peer", "reliable")
func request_discard(player_id: StringName, card_index: int) -> void:
    if not multiplayer.is_server(): return
    # 找到对应 PlayerActor，执行操作
```

**第二步：在 GameBus 中添加信号**

```gdscript
signal card_discarded(player_id: StringName, card_data: Dictionary)
```

**第三步：在 TurnManager 中添加同步 RPC + 转发函数**

```gdscript
# 转发函数
func _forward_card_discarded(player_id, card_data) -> void:
    if _is_network_server():
        _sync_card_discarded.rpc(player_id, card_data)

# 同步 RPC
@rpc("authority", "reliable")
func _sync_card_discarded(player_id: StringName, card_data: Dictionary) -> void:
    GameBus.card_discarded.emit(player_id, card_data)
```

**第四步：在 `_ready()` 中连接信号**

```gdscript
GameBus.card_discarded.connect(_forward_card_discarded)
```

**第五步：UI 层调用**

```gdscript
func _on_discard_pressed() -> void:
    if multiplayer.is_server():
        _player_actor.discard_card(selected_index)
    else:
        turn_manager.request_discard.rpc_id(1, _local_multiplayer_id, selected_index)
```

### 10.2 项目中的多人游戏文件索引

| 文件 | 我应该什么时候看它？ |
|------|-------------------|
| `multiplayer_handler.gd` | 想了解连接建立、玩家注册流程 |
| `player_node.gd` | 想了解玩家网络节点的初始化和同步时序 |
| `multiplayer_spawner.gd` | 想了解玩家自动生成机制 |
| `turn_manager.gd` | 想了解所有 RPC 的定义和信号转发 |
| `stock_manager.gd` | 想了解股票数据的网络同步 |
| `game_bus.gd` | 想了解所有可用的信号 |
| `test_turn.gd` | 想了解 UI 层如何区分主机/客户端操作 |

### 10.3 术语表

| 术语 | 含义 |
|------|------|
| Peer | 网络中的一个参与者（主机或客户端） |
| Peer ID | Godot 为每个参与者分配的唯一整数 |
| Authority | 节点的"拥有者"，决定谁能控制这个节点 |
| RPC | Remote Procedure Call，远程过程调用 |
| Reliable | 保证消息送达且按顺序 |
| Spawn | 在网络中创建并复制一个节点 |
| Sync | 将数据从一端同步到另一端 |
| Host | 主机，同时扮演服务器和玩家角色 |
| Mirror/镜像 | 客户端维护的本地数据副本，由主机 RPC 更新 |
| Forward/转发 | 主机监听本地信号后通过 RPC 发送给客户端 |
| Serialize/序列化 | 将对象转换为可传输的基本类型 |
