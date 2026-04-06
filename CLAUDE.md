# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role & Communication

- **始终使用中文与用户对话**
- 你的角色是**游戏设计师 + Godot 程序员**，与用户共同完成整个游戏原型的设计与开发
- 在讨论游戏机制、系统设计时，主动从游戏设计角度提出建议和权衡
- 在编写代码时，遵循 Godot 最佳实践并保持架构一致性

## Project Overview

竞选大师 v5 — 政治竞选主题的卡牌涂地游戏，使用 **Godot 4.4** (GDScript) 开发。核心玩法：2~4张卡牌叠放合成形状，重叠部分涂地生效，争夺 10×10 格子棋盘。

## Running the Project

- **Engine**: Godot 4.4 stable (Forward Plus renderer)
- **Test scene**: Run `Scenes/test_v5.tscn` to execute AI auto-play — check the Output panel for logs
- No build step required; open project in Godot editor and press F5/F6

## Architecture

Three-layer architecture:

### Data Layer (`Scripts/data/`)
- `Enums` — CellOwner 枚举（NEUTRAL/PLAYER_A/PLAYER_B）
- `CardShape` (Resource) — 卡牌形状模板，`cells: Array[Vector2i]` 存储格子偏移，支持旋转
- `CardDef` (Resource) — 卡牌定义（形状 + effect_id 预留接口）

### Runtime Layer (`Scripts/runtime/`)
- `PlayerState` (RefCounted) — 玩家状态（hand, AP, hand_limit=5）

### Systems Layer (`Scripts/systems/`)
- `BoardManager` (AutoLoad) — 10×10 格子管理，`apply_power()` 处理单格结算
- `ShapeResolver` (静态工具类) — 形状叠放计算，`resolve_article()` 执行完整涂地操作
- `CardSystem` (AutoLoad) — 牌堆/弃牌堆管理

### Signal Bus (`Scripts/autoload/game_bus.gd`)
`GameBus` AutoLoad 单例。信号：`turn_started/ended`, `article_published`, `game_ended`

## Key Patterns

- **CardPlacement**: `ShapeResolver.CardPlacement` 封装单张卡的放置信息（卡牌、旋转、偏移）
- **发表文章流程**: 选卡 → 旋转/叠放 → `compute_overlap()` → `compute_power_map(威力=层数-1)` → `resolve_article()` 逐格应用
- **格子结算**: 中立→翻色 | 己方→加固 | 敌方→削忠诚度，归零翻色
- **Power Modifier**: `resolve_article()` 接受 `Callable` 参数，特殊卡牌可修改威力计算

## AutoLoad Singletons

| Name | File | Purpose |
|------|------|---------|
| GameBus | Scripts/autoload/game_bus.gd | Signal bus |
| BoardManager | Scripts/systems/board_manager.gd | Grid state |
| CardSystem | Scripts/systems/card_system.gd | Deck management |

## GDScript Conventions

- Use tabs for indentation (Godot standard)
- All custom classes use `class_name` for global registration
- Data classes extend `Resource`; runtime objects extend `RefCounted`; system nodes extend `Node`
- Use `&"string_name"` syntax for StringName literals
- Prefix private members/methods with `_`
