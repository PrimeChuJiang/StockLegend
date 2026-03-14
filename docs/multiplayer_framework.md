# StockLegend 多人框架设计文档

## 总体架构：主机权威制（Host Authority）

```
主机（Host）                         客户端（Client）
┌──────────────────────┐            ┌──────────────────────┐
│ TurnManager          │            │                      │
│ StockManager         │            │ UI 层                │
│ ArticleSystem        │  ← RPC →  │ 本地 PlayerState 镜像 │
│ 所有 PlayerState     │            │ 只发送操作指令        │
│ ScheduleManager      │            │ 只接收状态更新        │
│ 游戏逻辑全跑这里      │            │                      │
└──────────────────────┘            └──────────────────────┘
```

**核心原则：**
- 所有游戏逻辑只在主机上运行
- 客户端只做两件事：①发送操作指令 ②接收状态更新
- 主机既是服务器也是一个玩家（Host + Player）

---

## 实施路线（四个阶段）

### 阶段一：玩家身份层重构（纯本地，不涉及网络）

目标：让现有代码支持多个 PlayerState / PlayerActor 同时存在。

#### 1.1 PlayerState 加 player_id

```gdscript
# player_state.gd
var player_id: StringName = &""
```

#### 1.2 PlayerActor 参数化

```gdscript
# player_actor.gd — 当前
func _init(player_state: PlayerState) -> void:
	actor_id = &"player"  # 硬编码

# player_actor.gd — 改为
func _init(p_player_id: StringName, player_state: PlayerState) -> void:
	actor_id = p_player_id
	player_id = p_player_id
```

#### 1.3 GameBus 信号加 player_id

需要改的信号清单：

| 原信号 | 改为 |
|--------|------|
| `player_ended_turn` | `player_ended_turn(player_id: StringName)` |
| `action_points_changed(new_val, max_val)` | `action_points_changed(player_id: StringName, new_val: int, max_val: int)` |
| `assets_changed()` | `assets_changed(player_id: StringName)` |
| `player_trade(stock_id, quantity, is_buy)` | `player_trade(player_id: StringName, stock_id: StringName, quantity: int, is_buy: bool)` |
| `article_composed(article)` | `article_composed(player_id: StringName, article: Article)` |
| `article_published(article, channel)` | `article_published(player_id: StringName, article: Article, channel: Channel)` |

不需要改的信号（全局事件，不属于任何玩家）：
- `turn_started/ended`
- `stock_price_changed / stock_delisted`
- `sentiment_modifier_applied / price_modifier_applied`
- `event_revealed / breaking_event_triggered`
- `world_start_phase_started/ended`
- `world_end_phase_started/ended`

#### 1.4 TurnManager ctx 改造

```gdscript
# 当前
_ctx = {"scene_tree": get_tree(), "player_state": _player_state}

# 改为
_ctx = {
	"scene_tree": get_tree(),
	"player_states": {
		&"player_1": player_state_1,
		&"player_2": player_state_2,
		# ...
	},
	"schedule": schedule_data,
	"turn_number": turn_number,
}
```

每个 PlayerActor 在 `execute_turn(ctx)` 中通过自己的 `player_id` 从 `ctx["player_states"]` 取自己的状态。

#### 1.5 WorldEndActor 遍历所有玩家

```gdscript
# 当前：只结算一个玩家
func _settle_articles(ctx: Dictionary) -> void:
	var player_state = ctx["player_state"]
	# ...

# 改为：遍历所有玩家
func _settle_articles(ctx: Dictionary) -> void:
	var player_states = ctx["player_states"]
	for player_id in player_states:
		var ps: PlayerState = player_states[player_id]
		# 结算该玩家的草稿文章...
```

---

### 阶段二：本地多人测试（同一台电脑，多个 PlayerActor）

目标：验证多人回合流程在本地跑通。

#### 2.1 构建多玩家 Actor 序列

```gdscript
func _setup_actors() -> void:
	var world_start = WorldStartActor.new()
	var world_end = WorldEndActor.new()

	var player_ids = [&"player_1", &"player_2", &"player_3"]
	var actors: Array[Actor] = [world_start]

	for pid in player_ids:
		var state = PlayerState.new()
		state.player_id = pid
		_player_states[pid] = state
		actors.append(PlayerActor.new(pid, state))

	actors.append(world_end)
	turn_manager.actors = actors
```

回合流程变为：
```
WorldStart → Player1 行动 → Player2 行动 → Player3 行动 → WorldEnd → 下一回合
```

#### 2.2 测试要点

- [ ] 每个 PlayerActor 独立 await 自己的结束信号
- [ ] 一个玩家的操作不影响其他玩家的状态（除了共享的股票市场）
- [ ] WorldEndActor 正确遍历所有玩家的文章
- [ ] GameBus 信号的 player_id 参数正确传递
- [ ] StockManager 作为全局共享状态，所有玩家可见

---

### 阶段三：网络层（Godot High-Level Multiplayer）

目标：用 ENetMultiplayerPeer 实现 P2P 主机-客户端。

#### 3.1 连接建立

```gdscript
# 主机端
func host_game(port: int = 9999) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer

# 客户端
func join_game(address: String, port: int = 9999) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
```

#### 3.2 玩家 ID 映射

```gdscript
# Godot multiplayer.get_unique_id() 返回网络 ID（int）
# 主机的 ID 固定为 1
# 可以用这个 ID 作为 player_id，或维护一个映射表：

var _network_to_player: Dictionary = {}  # {network_id: player_id}

func _on_peer_connected(id: int) -> void:
	var player_id = StringName("player_%d" % _network_to_player.size())
	_network_to_player[id] = player_id
```

#### 3.3 操作指令流（客户端 → 主机）

客户端发送操作意图，主机验证并执行：

```gdscript
# ---- 客户端 UI 层 ----
func _on_buy_button_pressed(stock_id: StringName, quantity: int) -> void:
	# 不直接修改状态，而是发 RPC 请求给主机
	request_buy_stock.rpc_id(1, stock_id, quantity)

@rpc("any_peer", "reliable")
func request_buy_stock(stock_id: StringName, quantity: int) -> void:
	# 只在主机上执行
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var player_id = _network_to_player[sender_id]
	var player_actor = _get_player_actor(player_id)

	var success = player_actor.try_buy_stock(stock_id, quantity)
	# 结果同步回客户端...
```

#### 3.4 状态同步（主机 → 客户端）

主机在状态变化时推送给所有客户端：

```gdscript
# 方案 A：信号驱动同步（推荐）
# 主机监听 GameBus 信号，每次状态变化时 RPC 推送

func _ready() -> void:
	if multiplayer.is_server():
		GameBus.stock_price_changed.connect(_on_stock_price_changed)

func _on_stock_price_changed(stock_id: StringName, old_price: float, new_price: float) -> void:
	sync_stock_price.rpc(stock_id, new_price)

@rpc("authority", "reliable")
func sync_stock_price(stock_id: StringName, new_price: float) -> void:
	# 客户端更新本地镜像
	local_stock_display.update_price(stock_id, new_price)
```

```gdscript
# 方案 B：回合快照同步（简单但粗暴）
# 每个阶段结束后，主机发送完整状态快照

@rpc("authority", "reliable")
func sync_game_state(snapshot: Dictionary) -> void:
	# snapshot 包含：所有股价、所有玩家的公开信息、当前回合数等
	_apply_snapshot(snapshot)
```

#### 3.5 PlayerActor 的三种输入模式

```gdscript
# PlayerActor 根据玩家类型，await 不同的输入来源：

enum InputMode { LOCAL, REMOTE, AI }

func execute_turn(ctx: Dictionary) -> void:
	_reset_resources()
	GameBus.actor_turn_started.emit(Enums.ActorType.PLAYER)

	match input_mode:
		InputMode.LOCAL:
			# 本地玩家：等待 UI 操作
			await GameBus.player_ended_turn  # 需要带 player_id 过滤
		InputMode.REMOTE:
			# 远程玩家：等待网络指令（主机端代理执行）
			await _remote_turn_ended  # 自定义信号，RPC 触发
		InputMode.AI:
			# AI 玩家：自动决策
			await _ai_decide_and_act(ctx)

	GameBus.actor_turn_ended.emit(Enums.ActorType.PLAYER)
```

#### 3.6 需要同步的数据清单

| 数据 | 方向 | 时机 | 可见性 |
|------|------|------|--------|
| 股票价格 | 主机 → 全体 | 每次变化 | 公开 |
| 玩家现金 | 主机 → 全体 | 每次变化 | 公开（或隐藏） |
| 玩家持仓 | 主机 → 全体 | 每次变化 | 可设计为隐藏 |
| 已发表文章 | 主机 → 全体 | 发表时 | 公开 |
| 草稿文章 | 主机 → 本人 | 合成时 | 仅本人可见 |
| 手牌（素材/方法） | 主机 → 本人 | 变化时 | 仅本人可见 |
| 公共素材池 | 主机 → 全体 | 翻牌时 | 公开 |
| 日程事件 | 主机 → 全体 | 揭示时 | 公开 |
| 操作指令（买/卖/发文） | 客户端 → 主机 | 操作时 | 仅主机处理 |

---

### 阶段四：AI 填充

目标：当玩家人数不足时，用 AI 补位。

#### 4.1 AI 接口

AI 不需要特殊架构——它就是一个 `InputMode.AI` 的 PlayerActor：

```gdscript
func _ai_decide_and_act(ctx: Dictionary) -> void:
	# AI 拥有和玩家完全相同的操作接口：
	# - try_gather_material()
	# - try_craft_article()
	# - try_buy_stock()
	# - try_sell_stock()
	# - publish_article()

	# 决策逻辑可以是：
	# - 规则 AI（if-else / 评分函数）
	# - 行为树
	# - LLM 调用（异步 await HTTP 请求）

	await _ai_logic.decide(self, ctx)
```

#### 4.2 AI 信息访问权限

AI 应该只能访问「公开信息」，和真人玩家看到的一样：
- 所有股票价格和历史 ✓
- 已发表的文章 ✓
- 日程事件 ✓
- 自己的手牌、草稿、持仓 ✓
- 其他玩家的手牌、草稿 ✗（除非有特殊机制）

---

## 关键设计决策备忘

### Q: 回合是顺序执行还是同时行动？

**当前设计：顺序执行**（Player1 → Player2 → Player3）

优点：实现简单，网络同步容易
缺点：后手玩家有信息优势

**未来可选：同时行动阶段**
- 交易阶段改为所有玩家同时提交订单，然后同时结算
- 需要「提交-揭示」两步机制
- 网络实现更复杂，但博弈更有趣

建议先用顺序执行跑通，后续再考虑同时行动。

### Q: High-Level vs Low-Level Multiplayer？

| 方面 | High-Level (ENet + RPC) | Low-Level (自定义协议) |
|------|------------------------|----------------------|
| 开发速度 | 快，Godot 内置支持 | 慢，需要自己写协议 |
| 灵活性 | 中等，受限于 RPC 模型 | 高，完全自定义 |
| NAT 穿透 | 需要额外处理 | 需要额外处理 |
| 适合阶段 | 原型验证、快速上线 | 性能优化、高度自定义需求 |

建议路线：先 High-Level 跑通 → 确认瓶颈 → 按需切换 Low-Level。

### Q: 状态同步策略？

**推荐：信号驱动增量同步**

理由：
1. 你的游戏是回合制，不是实时游戏，不需要帧同步
2. GameBus 信号已经标记了所有状态变化点，天然适合增量同步
3. 每回合操作次数有限（3行动值），数据量很小

### Q: 断线重连？

回合制游戏的优势：状态变化不频繁，可以在重连时发送完整快照恢复。
- 主机维护完整游戏状态（已经是这样）
- 客户端重连后，主机发送当前快照
- 如果是该玩家的回合，重新进入等待状态

---

## 文件变动预览

| 文件 | 阶段 | 改动类型 |
|------|------|---------|
| `Scripts/runtime/player_state.gd` | 一 | 加 `player_id` 字段 |
| `Scripts/runtime/player_actor.gd` | 一 | 构造函数加 `player_id`，InputMode 枚举 |
| `Scripts/autoload/game_bus.gd` | 一 | 玩家相关信号加 `player_id` 参数 |
| `Scripts/systems/turn_manager.gd` | 一 | ctx 改为多玩家字典 |
| `Scripts/runtime/world_end_actor.gd` | 一 | 遍历所有玩家结算 |
| `Scripts/test/test_turn.gd` | 二 | 多玩家测试场景 |
| `Scripts/systems/network_manager.gd` | 三 | **新增** — 网络连接管理 |
| `Scripts/systems/sync_manager.gd` | 三 | **新增** — 状态同步管理 |
| `Scripts/runtime/ai_actor.gd` | 四 | **新增** — AI 决策逻辑 |
