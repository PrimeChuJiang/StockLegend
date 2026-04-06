# 竞选大师 v5 — 卡牌涂地策略游戏

基于 **Godot 4.4** (GDScript) 开发的回合制卡牌涂地对战游戏原型。玩家扮演竞选经理，通过叠放卡牌合成形状在棋盘上涂地争夺领土，10回合后占领格子多者获胜。

> 当前为 Playtest 原型阶段，包含简易 UI 和 AI 对战。

---

## 核心玩法

1. **选择手牌** — 从手中选择 2~4 张卡牌
2. **叠放调整** — 旋转、移动每张卡牌，调整重叠方式
3. **发表文章** — 将叠放结果放置到 10×10 棋盘上，只有重叠部分生效
4. **争夺领土** — 占领中立格、加固己方格、削弱敌方格

**核心博弈：面积 vs 强度** — 最大重叠 = 少量格子高威力（攻坚），最小重叠 = 大面积低威力（铺地）

---

## 快速开始

1. 使用 **Godot 4.4** 打开本项目
2. 运行主场景 `Scenes/game_v5.tscn`（F5）— 玩家 vs AI 对战
3. 或运行 `Scenes/test_v5.tscn`（F6）— AI vs AI 纯逻辑测试

### 操作方式

| 操作 | 按键/鼠标 |
|------|----------|
| 选牌 | 点击底部卡牌（2~4张） |
| 移动激活卡牌 | WASD / 方向按钮 |
| 旋转激活卡牌 | R |
| 切换激活卡牌 | Tab |
| 整体旋转重叠图案 | Q |
| 放置 | 点击棋盘 |
| 结束回合 | 点击"结束回合" |

---

## 游戏规则

| 参数 | 值 |
|------|-----|
| 地图 | 10×10 格子（100格） |
| 回合数 | 10 回合 |
| 行动点 | 每回合 3 点 |
| 手牌上限 | 5 张 |
| 首回合抽牌 | 5 张 |
| 每回合抽牌 | 2 张 |

### 发表文章

消耗 1 行动点 + 2~4 张手牌。所有卡牌叠放后，只有重叠部分的格子生效，威力 = 重叠层数 - 1。

### 格子结算

| 目标格 | 效果 |
|--------|------|
| 中立格 | 翻色为己方，忠诚度 = 威力 |
| 己方格 | 忠诚度 + 威力 |
| 敌方格 | 忠诚度 - 威力，归零后翻色 |

### 胜负

10 回合结束后，占领格子多的一方获胜。

---

## 项目结构

```
res://
├── project.godot
├── addons/                              # 插件（不修改）
│   ├── ContainerSystem/
│   └── csv-data-importer/
├── Scripts/
│   ├── autoload/
│   │   └── game_bus.gd                  # GameBus：信号总线（AutoLoad）
│   ├── data/                            # 数据层
│   │   ├── enums.gd                     #   CellOwner 枚举
│   │   ├── card_shape.gd               #   CardShape：形状模板（Vector2i + 旋转）
│   │   └── card_def.gd                 #   CardDef：卡牌定义（形状 + 效果预留）
│   ├── runtime/                         # 运行时层
│   │   └── player_state.gd             #   PlayerState：玩家状态
│   ├── systems/                         # 系统层
│   │   ├── board_manager.gd            #   BoardManager：10×10 棋盘（AutoLoad）
│   │   ├── shape_resolver.gd           #   ShapeResolver：叠放计算（静态工具类）
│   │   └── card_system.gd             #   CardSystem：牌堆管理（AutoLoad）
│   ├── ui/                              # UI 层
│   │   ├── game_ui.gd                  #   主控制器（状态机 + AI）
│   │   ├── board_view.gd              #   棋盘视图
│   │   ├── hand_view.gd              #   手牌视图
│   │   └── preview_view.gd           #   叠放预览视图
│   └── test/
│       └── test_v5.gd                  #   AI vs AI 测试
├── Scenes/
│   ├── game_v5.tscn                    #   主游戏场景（玩家 vs AI）
│   └── test_v5.tscn                    #   纯逻辑测试场景
├── Doc/
│   └── GDD_v5_election.md             #   游戏设计文档
└── Tags/
    └── TagHierarchy.tres               #   标签层级（插件配置）
```

---

## 架构

### 三层架构

- **数据层** (`Scripts/data/`) — `CardShape` 和 `CardDef` 定义卡牌形状，不可变
- **系统层** (`Scripts/systems/`) — `BoardManager` 管理棋盘状态，`ShapeResolver` 处理叠放计算，`CardSystem` 管理牌堆
- **UI 层** (`Scripts/ui/`) — `GameUI` 状态机驱动回合流程，`BoardView`/`HandView`/`PreviewView` 负责渲染和交互

### 核心流程

```
发表文章流程：
选卡 → 旋转/移动叠放 → compute_overlap() → compute_power_map()
→ 整体旋转(可选) → 点击棋盘 → apply_power() 逐格结算
```

### 信号总线

所有系统间通信通过 `GameBus` AutoLoad 信号完成：`turn_started/ended`、`article_published`、`game_ended`

---

## GDScript 约定

- 缩进使用 Tab（Godot 标准）
- 所有自定义类使用 `class_name` 全局注册
- 数据类 extends `Resource`；运行时对象 extends `RefCounted`；系统节点 extends `Node`
- 使用 `&"string_name"` 语法表示 StringName 字面量
- 私有成员/方法以 `_` 前缀命名
