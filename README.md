# StockLegend — 回合制卡牌游戏框架

基于 **Godot 4.4** 构建的回合制卡牌游戏核心逻辑框架。当前版本为纯逻辑层实现（不含 UI），专注于提供一套解耦、可扩展、易于修改的卡牌游戏回合系统。

卡牌系统**继承并扩展**了 `ItemContainerSystem` 容器插件（`addons/ContainerSystem/`），复用插件的容器管理、信号机制、标签系统，同时保留卡牌特有的逻辑（修改器、阶段校验、效果结算）。

---

## 目录

- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [架构概览](#架构概览)
- [插件继承关系](#插件继承关系)
- [数据层](#数据层)
  - [全局枚举 Enums](#全局枚举-enums)
  - [卡牌定义 CardItemData](#卡牌定义-carditemdata)
  - [效果定义 EffectDef](#效果定义-effectdef)
- [运行时层](#运行时层)
  - [卡牌基类 CardItem](#卡牌基类-carditem)
  - [普通卡牌 NormalCardItem](#普通卡牌-normalcarditem)
  - [瞬发卡牌 InstantCardItem](#瞬发卡牌-instantcarditem)
  - [场地卡牌 FieldCardItem](#场地卡牌-fieldcarditem)
  - [属性修改器 Modifier](#属性修改器-modifier)
  - [玩家状态 PlayerState](#玩家状态-playerstate)
- [系统层](#系统层)
  - [回合系统 TurnSystem](#回合系统-turnsystem)
  - [区域管理器 CardZoneManager](#区域管理器-cardzonemanager)
  - [效果结算器 EffectResolver](#效果结算器-effectresolver)
  - [目标选择器 TargetSelector](#目标选择器-targetselector)
- [全局信号总线 GameBus](#全局信号总线-gamebus)
- [核心流程详解](#核心流程详解)
  - [回合流程](#回合流程)
  - [出牌流程](#出牌流程)
  - [效果结算流程](#效果结算流程)
  - [属性修改器计算流程](#属性修改器计算流程)
- [扩展指南](#扩展指南)
  - [添加新的卡牌类型](#添加新的卡牌类型)
  - [添加新的效果](#添加新的效果)
  - [修改回合阶段](#修改回合阶段)
  - [接入 UI 目标选择](#接入-ui-目标选择)
- [测试场景](#测试场景)

---

## 快速开始

1. 使用 **Godot 4.4** 打开本项目
2. 运行场景 `scenes/test_battle.tscn`（F6 运行当前场景）
3. 在 Output 面板中观察完整的回合流程日志输出

---

## 项目结构

```
res://
├── project.godot                     # 项目配置（含 GameBus AutoLoad 注册）
├── addons/
│   └── ContainerSystem/              # ItemContainerSystem 容器插件（不修改）
│       └── core/
│           ├── ItemData.gd           #   物品模板 Resource
│           ├── Item.gd               #   物品运行时实例 RefCounted
│           ├── ItemContainer.gd      #   物品容器 Node
│           └── Swapper.gd            #   跨容器操作工具类
├── src/
│   ├── data/                         # 数据层 — 静态配置，不可变
│   │   ├── enums.gd                  #   全局枚举定义
│   │   ├── card_item_data.gd         #   CardItemData：卡牌模板（extends ItemData）
│   │   └── effect_def.gd             #   EffectDef：效果模板 Resource
│   ├── runtime/                      # 运行时层 — 可变游戏状态
│   │   ├── card_item.gd              #   CardItem：卡牌基类 + 工厂方法（extends Item）
│   │   ├── normal_card_item.gd       #   NormalCardItem：普通卡牌
│   │   ├── instant_card_item.gd      #   InstantCardItem：瞬发卡牌
│   │   ├── field_card_item.gd        #   FieldCardItem：场地卡牌
│   │   ├── modifier.gd               #   Modifier：属性修改器
│   │   └── player_state.gd           #   PlayerState：玩家状态
│   ├── systems/                      # 系统层 — 游戏逻辑
│   │   ├── turn_system.gd            #   TurnSystem：回合阶段状态机
│   │   ├── card_zone_manager.gd      #   CardZoneManager：卡牌区域管理（wraps ItemContainer）
│   │   ├── effect_resolver.gd        #   EffectResolver：效果注册与结算
│   │   └── target_selector.gd        #   TargetSelector：目标选择接口
│   ├── autoload/                     # AutoLoad 全局单例
│   │   └── game_bus.gd               #   GameBus：全局信号总线
│   └── test/                         # 测试
│       └── test_battle.gd            #   完整回合流程测试脚本
└── scenes/
    └── test_battle.tscn              # 测试场景
```

---

## 架构概览

系统采用**三层解耦架构**，各层通过全局信号总线 `GameBus` 进行通信，避免直接引用耦合：

```
┌─────────────────────────────────────────────────────────────────┐
│                        GameBus（信号总线）                        │
│  所有系统间通信的唯一通道，AutoLoad 全局单例                       │
└──────────┬──────────────────┬──────────────────┬────────────────┘
           │                  │                  │
   ┌───────▼───────┐  ┌──────▼───────┐  ┌───────▼───────┐
   │   数据层       │  │   运行时层    │  │    系统层      │
   │  （不可变）     │  │  （可变状态）  │  │  （游戏逻辑）  │
   │               │  │              │  │               │
   │ CardItemData  │  │  CardItem    │  │  TurnSystem   │
   │  EffectDef    │◄─│  Modifier    │◄─│CardZoneManager│
   │  Enums        │  │  PlayerState │  │ EffectResolver│
   │               │  │              │  │TargetSelector │
   └───────┬───────┘  └──────┬───────┘  └───────┬───────┘
           │                 │                   │
   extends ItemData    extends Item     wraps ItemContainer
           │                 │                   │
   ┌───────▼─────────────────▼───────────────────▼───────┐
   │              ItemContainerSystem 插件                 │
   │    ItemData / Item / ItemContainer / Swapper          │
   └─────────────────────────────────────────────────────┘
```

**设计原则：**

- **插件继承不修改**：卡牌系统通过继承插件基类（`ItemData`、`Item`）扩展功能，插件代码零修改
- **配置与运行时解耦**：`CardItemData`（不可变模板）与 `CardItem`（可变实例）严格分离，同一个 CardItemData 可创建多个独立的运行时实例
- **信号驱动通信**：系统间零直接引用，全部通过 GameBus 信号解耦
- **继承 + 多态**：三种卡牌类型通过继承 CardItem 并重写虚方法实现差异化行为
- **注册表模式**：效果系统通过 `effect_id → Callable` 映射实现，完全开放可扩展
- **上下文字典传递**：系统引用通过 `ctx: Dictionary` 传入 `execute()`，避免卡牌类直接依赖系统类

---

## 插件继承关系

卡牌系统与 `ItemContainerSystem` 插件的对应关系：

| 插件基类 | 卡牌扩展类 | 关系 | 说明 |
|---------|-----------|------|------|
| `ItemData` (Resource) | `CardItemData` | extends | 不可变模板，添加 card_type/base_stats/effects/target_type |
| `Item` (RefCounted) | `CardItem` | extends | 运行时实例，添加修改器系统/阶段校验/效果结算 |
| `ItemContainer` (Node) | — | wraps (由 CardZoneManager 包装) | 5 个 ItemContainer 对应 5 个卡牌区域 |
| `Swapper` | — | 不使用 | CardZoneManager 自行实现 remove + add 移动 |

**复用的插件能力：**
- `ItemData` 的 `id`、`name`、`tags`、`description`、`image`、`max_stack`、`behaviours`
- `Item` 的 `data`、`stack_count`、`container`、`position_in_container`
- `ItemContainer` 的 `item_list`、`item_id_pos_map`、`item_empty_pos_map`、`add_item()`、`remove_item_in_position()`、`get_item_in_position()`、`item_changed` 信号

---

## 数据层

数据层存放所有**静态、不可变**的游戏配置。这些类继承自 Godot 的 `Resource`，可以在编辑器中创建 `.tres` 文件进行可视化编辑，也可以在代码中动态构建。

### 全局枚举 Enums

**文件**：`src/data/enums.gd`

所有系统共享的枚举常量集合。整个项目的类型基础。

| 枚举 | 值 | 说明 |
|------|---|------|
| `CardType` | `NORMAL`, `INSTANT`, `FIELD` | 卡牌类型 |
| `Phase` | `TURN_START`, `DRAW`, `MAIN`, `TURN_END`, `CLEANUP` | 回合阶段 |
| `StatKey` | `ATTACK`, `DEFENSE`, `COST`, `HP` | 属性键（可扩展） |
| `ModifierOp` | `ADD`, `MULTIPLY`, `SET` | 修改器运算方式 |
| `TargetType` | `NONE`, `SELF`, `SINGLE_ENEMY`, `ALL_ENEMIES`, `SINGLE_ALLY`, `ALL_ALLIES` | 目标类型 |
| `EffectTrigger` | `ON_PLAY`, `ON_TURN_END`, `ON_FIELD_ENTER`, `ON_FIELD_EXIT`, `ON_DISCARD` | 效果触发时机 |
| `Zone` | `DECK`, `HAND`, `FIELD`, `DISCARD`, `EXHAUST` | 卡牌区域 |

### 卡牌定义 CardItemData

**文件**：`src/data/card_item_data.gd`　|　继承：`ItemData`

卡牌的**不可变模板**。继承插件的 `ItemData`，复用其 `id`、`name`、`tags` 等通用字段，添加卡牌特有字段。

**继承自 ItemData 的属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | `int` | 唯一标识符 |
| `name` | `String` | 显示名称 |
| `tags` | `Array[Tag]` | 标签（复用插件标签系统） |
| `description` | `String` | 描述文本 |
| `image` | `Texture2D` | 卡牌图片 |
| `max_stack` | `int` | 最大堆叠数（卡牌固定为 `1`） |
| `behaviours` | `Array[ItemBehaviourData]` | 物品行为（可选） |

**卡牌特有属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `card_type` | `Enums.CardType` | 卡牌类型（决定运行时子类） |
| `base_stats` | `Dictionary` | 基础属性，键为 `Enums.StatKey`，值为 `int` |
| `effects` | `Array[EffectDef]` | 该卡牌携带的效果列表 |
| `target_type` | `Enums.TargetType` | 目标类型，默认 `NONE` |

**示例：创建一张火球术**
```gdscript
var fireball := CardItemData.new()
fireball.id = 1
fireball.name = "火球术"
fireball.max_stack = 1
fireball.card_type = Enums.CardType.NORMAL
fireball.base_stats = { Enums.StatKey.COST: 2 }
fireball.target_type = Enums.TargetType.SINGLE_ENEMY
```

### 效果定义 EffectDef

**文件**：`src/data/effect_def.gd`　|　继承：`Resource`

声明式的效果描述，定义"做什么"和"何时做"，**不包含执行逻辑**。实际执行由 `EffectResolver` 的注册表处理。

| 属性 | 类型 | 说明 |
|------|------|------|
| `effect_id` | `StringName` | 效果标识符，映射到 EffectResolver 的处理函数 |
| `trigger` | `Enums.EffectTrigger` | 触发时机 |
| `params` | `Dictionary` | 效果参数，如 `{"damage": 8}` 或 `{"count": 2}` |

**示例：造成 8 点伤害的效果**
```gdscript
var fx := EffectDef.new()
fx.effect_id = &"deal_damage"
fx.trigger = Enums.EffectTrigger.ON_PLAY
fx.params = { "damage": 8 }
```

---

## 运行时层

运行时层管理所有**可变的游戏状态**。卡牌类继承自插件的 `Item`（`RefCounted`），由引擎自动引用计数管理内存。

### 卡牌基类 CardItem

**文件**：`src/runtime/card_item.gd`　|　继承：`Item`

所有运行时卡牌实例的基类。继承插件的 `Item`，复用其 `data`、`container`、`position_in_container` 等属性，添加修改器系统和卡牌虚方法。

**继承自 Item 的属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `data` | `ItemData` | 引用的卡牌定义（通过 `get_card_data()` 向下转型为 `CardItemData`） |
| `stack_count` | `int` | 堆叠数量（卡牌固定为 `1`） |
| `container` | `ItemContainer` | 当前所在的容器（由插件自动管理） |
| `position_in_container` | `int` | 在容器中的位置索引（由插件自动管理） |

**卡牌特有属性：**

| 属性 | 类型 | 说明 |
|------|------|------|
| `card_instance_id` | `int` | 运行时唯一 ID，由工厂方法自增分配 |
| `modifiers` | `Array[Modifier]` | 附加的属性修改器列表 |
| `extra_data` | `Dictionary` | 自由扩展数据容器 |

**核心方法：**

| 方法 | 说明 |
|------|------|
| `create_from_data(card_data, container, index) → CardItem` | **静态工厂方法**。根据 `card_type` 自动创建对应子类实例 |
| `get_card_data() → CardItemData` | 向下转型获取卡牌专有数据 |
| `get_stat(key) → int` | 计算经过所有修改器叠加后的最终属性值 |
| `add_modifier(mod)` | 添加修改器并广播 `modifier_added` 信号 |
| `remove_modifier(mod)` | 移除修改器并广播 `modifier_removed` 信号 |
| `tick_modifiers()` | 回合清理阶段调用，递减持续时间并移除过期修改器 |
| `can_play_at_phase(phase) → bool` | **虚方法**。判断当前阶段是否可以打出此卡 |
| `execute(ctx)` | **虚方法**。执行出牌逻辑，由子类实现具体行为 |
| `get_card_type() → Enums.CardType` | 返回卡牌类型 |

**创建卡牌实例（通过 CardZoneManager）：**
```gdscript
# 推荐方式：通过 CardZoneManager 创建并自动放入指定区域
var card := zone_manager.create_card(fireball_data, Enums.Zone.DECK)

# 底层工厂方法（通常不直接调用）：
var card := CardItem.create_from_data(card_data, container, index)
```

### 普通卡牌 NormalCardItem

**文件**：`src/runtime/normal_card_item.gd`　|　继承：`CardItem`

一次性效果卡牌。只能在**主阶段（MAIN）**打出，打出后立即结算 `ON_PLAY` 效果，然后进入弃牌堆。

```
出牌 → 结算 ON_PLAY 效果 → 移至 DISCARD
```

### 瞬发卡牌 InstantCardItem

**文件**：`src/runtime/instant_card_item.gd`　|　继承：`CardItem`

即时响应卡牌。可以在**任意阶段**打出，打出后立即结算 `ON_PLAY` 效果，然后进入弃牌堆。

```
出牌（任意阶段）→ 结算 ON_PLAY 效果 → 移至 DISCARD
```

与 NormalCardItem 的核心区别在于**出牌时机不受阶段限制**。

### 场地卡牌 FieldCardItem

**文件**：`src/runtime/field_card_item.gd`　|　继承：`CardItem`

持续性环境卡牌。只能在**主阶段（MAIN）**打出。打出后放置到场地区域并触发 `ON_FIELD_ENTER` 效果，之后**持续留在场地**，每个回合结束时由 TurnSystem 统一触发其 `ON_TURN_END` 效果。

```
出牌 → 移至 FIELD → 结算 ON_FIELD_ENTER 效果
             ↓
      每回合 TURN_END 阶段 → 结算 ON_TURN_END 效果
```

适合实现环境增益/减益、持续性光环等机制。

### 三种卡牌类型对比

| 特性 | NormalCardItem | InstantCardItem | FieldCardItem |
|------|---------------|-----------------|---------------|
| 出牌阶段 | 仅 MAIN | 任意阶段 | 仅 MAIN |
| 效果触发 | ON_PLAY（立即） | ON_PLAY（立即） | ON_FIELD_ENTER + 每回合 ON_TURN_END |
| 出牌后位置 | DISCARD | DISCARD | FIELD（持续存在） |
| 典型用途 | 法术、技能 | 反制、治疗、闪避 | 环境、光环、buff/debuff |

### 属性修改器 Modifier

**文件**：`src/runtime/modifier.gd`　|　继承：`RefCounted`

对卡牌属性进行临时或永久修改的最小单元。附加到 `CardItem.modifiers` 数组中。

| 属性 | 类型 | 说明 |
|------|------|------|
| `stat_key` | `Enums.StatKey` | 要修改的属性 |
| `op` | `Enums.ModifierOp` | 运算方式：`ADD`/`MULTIPLY`/`SET` |
| `value` | `float` | 修改值 |
| `duration` | `int` | 剩余持续回合数，`-1` 表示永久 |
| `source_id` | `int` | 来源卡牌的 `card_instance_id`，`-1` 表示无来源 |

**`tick()` 方法**：每回合 CLEANUP 阶段调用。`duration > 0` 时递减，返回 `true` 表示已过期需移除。永久修改器（`duration == -1`）不受影响。

### 玩家状态 PlayerState

**文件**：`src/runtime/player_state.gd`　|　继承：`RefCounted`

| 属性 | 类型 | 默认值 | 说明 |
|------|------|-------|------|
| `player_id` | `int` | — | 玩家标识 |
| `hp` | `int` | `30` | 生命值 |
| `energy` | `int` | `0` | 当前可用能量 |
| `max_energy` | `int` | `0` | 能量上限 |

---

## 系统层

系统层包含所有游戏逻辑节点，继承自 `Node`，挂载在场景树中运行。

### 回合系统 TurnSystem

**文件**：`src/systems/turn_system.gd`　|　继承：`Node`

整个游戏流程的核心驱动器。基于**可配置的阶段序列**实现状态机，支持动态插入和移除阶段。

**默认阶段序列：**

```
TURN_START → DRAW → MAIN → TURN_END → CLEANUP
```

| 阶段 | 默认行为 |
|------|---------|
| `TURN_START` | 无默认行为（预留给外部系统监听） |
| `DRAW` | 从牌库抽一张牌到手牌 |
| `MAIN` | 发出 `main_phase_entered` 信号，**等待** `main_phase_finished` 信号（玩家操作阶段） |
| `TURN_END` | 遍历场地区域所有卡牌，结算其 `ON_TURN_END` 效果 |
| `CLEANUP` | 对所有卡牌的修改器执行 `tick()`，移除过期修改器 |

**信号：**

| 信号 | 参数 | 说明 |
|------|------|------|
| `phase_started` | `phase: Enums.Phase` | 阶段开始 |
| `phase_ended` | `phase: Enums.Phase` | 阶段结束 |
| `turn_started` | `turn_number: int` | 回合开始 |
| `turn_ended` | `turn_number: int` | 回合结束 |

**关键方法：**

| 方法 | 说明 |
|------|------|
| `execute_turn()` | 执行一个完整回合，按序遍历所有阶段 |
| `play_card(card, player) → bool` | 出牌入口：校验阶段 → 校验费用 → 扣费 → 执行 → 广播 |
| `insert_phase_before(anchor, new_phase)` | 在指定阶段之前插入新阶段 |
| `insert_phase_after(anchor, new_phase)` | 在指定阶段之后插入新阶段 |
| `remove_phase(phase)` | 移除指定阶段 |

**MAIN 阶段的异步等待机制：**

MAIN 阶段通过 `await GameBus.main_phase_finished` 实现异步阻塞。外部代码（UI 或测试脚本）在玩家操作完毕后发出 `GameBus.main_phase_finished.emit()` 来结束主阶段，回合系统继续执行后续阶段。

### 区域管理器 CardZoneManager

**文件**：`src/systems/card_zone_manager.gd`　|　继承：`Node`

管理所有卡牌在不同区域之间的转移。内部包装 5 个 `ItemContainer` 子节点，每个区域对应一个容器。

**区域说明：**

| 区域 | 默认容量 | 说明 |
|------|---------|------|
| `DECK` | 40 | 牌库（抽牌来源） |
| `HAND` | 10 | 手牌（玩家可操作） |
| `FIELD` | 10 | 场地（场地卡牌持续存在的区域） |
| `DISCARD` | 40 | 弃牌堆 |
| `EXHAUST` | 40 | 除外区（永久移除的卡牌） |

**关键方法：**

| 方法 | 说明 |
|------|------|
| `create_card(card_data, zone) → CardItem` | 创建卡牌并放入指定区域（工厂入口） |
| `move_card(card, to_zone)` | 跨区域移动卡牌（保持同一 CardItem 实例），广播 `card_zone_changed` |
| `get_cards_in_zone(zone) → Array[CardItem]` | 获取指定区域内的所有卡牌 |
| `get_all_cards() → Array[CardItem]` | 获取所有区域的所有卡牌 |
| `get_container(zone) → ItemContainer` | 获取指定区域的 ItemContainer 节点 |
| `get_zone_of(card) → Enums.Zone` | 根据卡牌所在 container 反查 Zone 枚举 |
| `shuffle_zone(zone)` | 洗牌（打乱指定区域的卡牌顺序） |
| `draw_card() → CardItem` | 从牌库顶部抽一张牌移至手牌，牌库为空时返回 `null` |

**跨区域移动实现：**

`move_card()` 通过 `remove_item_in_position()` + `add_item()` 实现，保持同一个 `CardItem` 实例在容器间移动。`add_item` 会自动更新 `card.container` 和 `card.position_in_container`。

### 效果结算器 EffectResolver

**文件**：`src/systems/effect_resolver.gd`　|　继承：`Node`

将 `EffectDef` 的声明式描述转化为实际执行。核心是一个 **`effect_id → Callable` 注册表**，完全开放可扩展。

**关键方法：**

| 方法 | 说明 |
|------|------|
| `register_effect(id, handler)` | 注册新的效果处理函数 |
| `resolve_effects(card, trigger, ctx)` | 遍历卡牌的所有效果，按触发条件筛选并执行 |

**内置效果：**

| effect_id | 参数 | 行为 |
|-----------|------|------|
| `&"deal_damage"` | `params.damage: int` | 发出 `damage_dealt` 信号 |
| `&"heal"` | `params.amount: int` | 发出 `heal_applied` 信号 |
| `&"add_modifier"` | `params.stat_key`, `params.op`, `params.value`, `params.duration` | 创建 Modifier 并添加到目标卡牌 |
| `&"draw_cards"` | `params.count: int` | 从牌库抽指定数量的牌 |

**效果处理函数签名：**
```gdscript
func my_effect(card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
    # card: 发起效果的卡牌
    # fx: 效果定义（含 params）
    # ctx: 上下文字典（含 zone_manager, effect_resolver, turn_system, target）
```

### 目标选择器 TargetSelector

**文件**：`src/systems/target_selector.gd`　|　继承：`RefCounted`

为指向性卡牌提供目标选择接口。通过 `select_callback` 回调实现策略模式——默认自动选择第一个候选目标，接入 UI 后替换为玩家手动选择。

**目标选择规则：**

| TargetType | 返回值 |
|------------|--------|
| `NONE` | `null` |
| `SELF` | 卡牌自身 |
| `ALL_ENEMIES` / `ALL_ALLIES` | 候选列表（全部） |
| `SINGLE_ENEMY` / `SINGLE_ALLY` | 若设置了 `select_callback` 则调用回调（支持 `await`），否则返回候选列表第一个 |

---

## 全局信号总线 GameBus

**文件**：`src/autoload/game_bus.gd`　|　注册为 AutoLoad 单例

所有系统间通信的唯一通道。任何系统都不直接引用其他系统，全部通过 GameBus 的信号进行松耦合通信。

**全部信号一览：**

| 分类 | 信号 | 参数 |
|------|------|------|
| 回合 | `turn_started` | `turn_number: int` |
| 回合 | `turn_ended` | `turn_number: int` |
| 回合 | `phase_started` | `phase: Enums.Phase` |
| 回合 | `phase_ended` | `phase: Enums.Phase` |
| 阶段控制 | `main_phase_entered` | — |
| 阶段控制 | `main_phase_finished` | — |
| 卡牌 | `card_played` | `card: CardItem` |
| 卡牌 | `card_zone_changed` | `card: CardItem, from_zone: Enums.Zone, to_zone: Enums.Zone` |
| 效果 | `damage_dealt` | `source: CardItem, target: Variant, amount: int` |
| 效果 | `heal_applied` | `source: CardItem, target: Variant, amount: int` |
| 效果 | `modifier_added` | `card: CardItem, modifier: Modifier` |
| 效果 | `modifier_removed` | `card: CardItem, modifier: Modifier` |

---

## 核心流程详解

### 回合流程

```
execute_turn()
│
├── turn_number += 1
├── 广播 turn_started
│
├── 阶段循环 (for phase in phase_sequence):
│   ├── current_phase = phase
│   ├── 广播 phase_started
│   │
│   ├── TURN_START:  （无默认行为，外部可监听）
│   ├── DRAW:        zone_manager.draw_card()
│   ├── MAIN:        广播 main_phase_entered
│   │                await main_phase_finished ← 阻塞等待玩家操作完毕
│   ├── TURN_END:    遍历 FIELD 区域卡牌 → 结算 ON_TURN_END 效果
│   └── CLEANUP:     遍历所有卡牌 → tick_modifiers() → 移除过期修改器
│   │
│   └── 广播 phase_ended
│
└── 广播 turn_ended
```

### 出牌流程

```
play_card(card, player)
│
├── card.can_play_at_phase(current_phase)?
│   └── false → 返回 false（阶段不允许）
│
├── player.energy >= card.get_stat(COST)?
│   └── false → 返回 false（费用不足）
│
├── player.energy -= cost
│
├── card.execute(ctx)  ← 多态分发到子类
│   │
│   ├── NormalCardItem:
│   │   ├── resolve_effects(ON_PLAY)
│   │   └── zone_mgr.move_card → DISCARD
│   │
│   ├── InstantCardItem:
│   │   ├── resolve_effects(ON_PLAY)
│   │   └── zone_mgr.move_card → DISCARD
│   │
│   └── FieldCardItem:
│       ├── zone_mgr.move_card → FIELD
│       └── resolve_effects(ON_FIELD_ENTER)
│
├── 广播 card_played
└── 返回 true
```

### 效果结算流程

```
resolve_effects(card, trigger, ctx)
│
├── 遍历 card.get_card_data().effects:
│   │
│   ├── effect_def.trigger != trigger? → 跳过
│   │
│   ├── 查找 _handlers[effect_def.effect_id]
│   │   └── 未注册? → push_warning 并跳过
│   │
│   ├── card.get_card_data().target_type != NONE?
│   │   ├── 获取候选目标列表
│   │   └── await target_selector.select_target() → target
│   │
│   ├── ctx["target"] = target
│   └── handler.call(card, effect_def, ctx)
```

### 属性修改器计算流程

`get_stat(key)` 的计算逻辑：

```
base = get_card_data().base_stats[key]（基础值）

遍历所有 modifier:
  ├── stat_key 不匹配 → 跳过
  ├── ADD:      累加到 add_sum
  ├── MULTIPLY: 累乘到 mult
  └── SET:      直接返回该值（最高优先级，立即中断计算）

最终值 = (base + add_sum) * mult
```

**优先级**：`SET` > `MULTIPLY` > `ADD`

**示例**：基础攻击力 10，有两个修改器 ADD +5 和 MULTIPLY ×1.5
```
结果 = (10 + 5) × 1.5 = 22
```

---

## 扩展指南

### 添加新的卡牌类型

1. 在 `Enums.CardType` 中添加新值：
   ```gdscript
   enum CardType { NORMAL, INSTANT, FIELD, TRAP }  # 新增 TRAP
   ```

2. 创建新的子类文件 `src/runtime/trap_card_item.gd`：
   ```gdscript
   class_name TrapCardItem
   extends CardItem

   func can_play_at_phase(phase: Enums.Phase) -> bool:
       return phase == Enums.Phase.MAIN

   func execute(ctx: Dictionary) -> void:
       var zone_mgr: CardZoneManager = ctx.get("zone_manager")
       zone_mgr.move_card(self, Enums.Zone.FIELD)
       # 陷阱牌特有逻辑：设置为隐藏状态
       extra_data["hidden"] = true
   ```

3. 在 `CardItem.create_from_data()` 的 match 中添加分支：
   ```gdscript
   Enums.CardType.TRAP:
       card = TrapCardItem.new(card_data, container, index)
   ```

### 添加新的效果

在 EffectResolver 中注册新处理函数：

```gdscript
# 在 _register_builtin() 中或任何初始化位置
effect_resolver.register_effect(&"destroy_card", func(card: CardItem, fx: EffectDef, ctx: Dictionary) -> void:
    var target = ctx.get("target")
    if target is CardItem:
        var zm: CardZoneManager = ctx.get("zone_manager")
        zm.move_card(target, Enums.Zone.EXHAUST)
)
```

然后在 EffectDef 中使用：
```gdscript
var fx := EffectDef.new()
fx.effect_id = &"destroy_card"
fx.trigger = Enums.EffectTrigger.ON_PLAY
fx.params = {}
```

### 修改回合阶段

```gdscript
# 在 MAIN 和 TURN_END 之间插入战斗阶段
turn_system.insert_phase_after(Enums.Phase.MAIN, Enums.Phase.BATTLE)

# 移除抽牌阶段（某些特殊规则下）
turn_system.remove_phase(Enums.Phase.DRAW)
```

> 注意：自定义阶段需要在 `Enums.Phase` 枚举中先添加对应值，并在 `_process_phase()` 中添加处理逻辑或通过监听 `phase_started` 信号在外部处理。

### 接入 UI 目标选择

替换 TargetSelector 的默认自动选择为 UI 交互：

```gdscript
effect_resolver.target_selector.select_callback = func(card: CardItem, target_type: Enums.TargetType, candidates: Array) -> Variant:
    # 显示目标选择 UI
    target_selection_ui.show(candidates)
    # 等待玩家选择
    var selected = await target_selection_ui.target_selected
    return selected
```

---

## 测试场景

**场景**：`scenes/test_battle.tscn`
**脚本**：`src/test/test_battle.gd`

场景树结构：
```
TestBattle (Node)      ← test_battle.gd
├── TurnSystem         ← turn_system.gd
├── CardZoneManager    ← card_zone_manager.gd
│   ├── DECK           ← ItemContainer (自动创建，容量 40)
│   ├── HAND           ← ItemContainer (自动创建，容量 10)
│   ├── FIELD          ← ItemContainer (自动创建，容量 10)
│   ├── DISCARD        ← ItemContainer (自动创建，容量 40)
│   └── EXHAUST        ← ItemContainer (自动创建，容量 40)
└── EffectResolver     ← effect_resolver.gd
```

测试脚本模拟一个完整回合，创建 5 张测试卡牌：

| 卡牌 | 类型 | 费用 | 效果 |
|------|------|------|------|
| Fireball | NORMAL | 2 | 造成 8 点伤害 |
| Quick Heal | INSTANT | 1 | 治疗 5 点 |
| War Banner | FIELD | 3 | 每回合结束抽 1 张牌 |
| Magic Shield | NORMAL | 1 | 无效果（用于修改器测试） |
| Filler Card | NORMAL | 0 | 无效果（填充牌） |

测试流程：初始化牌库 → 执行回合 → DRAW 阶段抽牌 → MAIN 阶段打出所有可打出的牌 → 测试 Modifier 系统 → TURN_END 阶段结算场地牌效果 → CLEANUP 阶段清理过期修改器 → 输出最终状态。
