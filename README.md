# StockLegend — 股市舆论操盘手

基于 **Godot 4.4** (GDScript) 开发的回合制策略卡牌游戏原型。玩家扮演一名财经记者，通过收集素材、撰写文章、操纵舆论来影响股票市场情绪，并利用信息差进行股票交易获利。

> 当前为逻辑原型阶段，包含完整的回合流程、文章合成系统、股票市场系统和基础测试 UI。

---

## 核心玩法

1. **收集素材** — 获取数据、谣言、爆料、观点等不同类型的素材卡
2. **撰写文章** — 将素材卡与写作方法卡组合，合成不同类型的文章（调查报道、阴谋论、深度研报等）
3. **发表文章** — 选择渠道发表，文章会对目标股票/行业产生情绪影响（看涨或看跌）
4. **交易股票** — 利用信息优势在合适的时机买入/卖出，赚取差价
5. **应对事件** — 日程事件和突发事件会改变市场环境，影响你的策略

---

## 快速开始

1. 使用 **Godot 4.4** 打开本项目
2. 运行场景 `Scenes/test_turn.tscn`（F6 运行当前场景）
3. 通过按钮操作体验完整的回合流程：获取素材 → 合成文章 → 发表 → 交易 → 结束回合

---

## 项目结构

```
res://
├── project.godot                        # 项目配置（AutoLoad 注册）
├── addons/
│   ├── ContainerSystem/                 # ItemContainerSystem 容器插件（不修改）
│   └── csv-data-importer/               # CSV 数据导入插件
├── Scripts/
│   ├── autoload/
│   │   └── game_bus.gd                  # GameBus：全局信号总线（AutoLoad）
│   ├── data/                            # 数据层 — 静态定义，不可变
│   │   ├── enums.gd                     #   全局枚举
│   │   ├── material_card_def.gd         #   素材卡定义（extends ItemData）
│   │   ├── writing_method_card_def.gd   #   写作方法卡定义（extends ItemData）
│   │   ├── writing_method_behaviour.gd  #   写作方法效果行为
│   │   ├── enviroment_card_def.gd       #   环境事件牌定义（extends ItemData）
│   │   ├── stock_def.gd                 #   股票定义（extends ItemData）
│   │   └── schedule_event_config.gd     #   日程事件配置
│   ├── runtime/                         # 运行时层 — 可变游戏状态
│   │   ├── actor.gd                     #   Actor 抽象基类
│   │   ├── world_actor.gd               #   WorldStartActor：世界回合头
│   │   ├── world_end_actor.gd           #   WorldEndActor：世界回合尾
│   │   ├── player_actor.gd              #   PlayerActor：玩家行动者
│   │   ├── player_state.gd              #   PlayerState：玩家数据
│   │   ├── article.gd                   #   Article：文章运行时对象
│   │   ├── stock.gd                     #   Stock：股票运行时实例
│   │   ├── sentiment_modifier.gd        #   SentimentModifier：情绪修改器
│   │   ├── price_modifier.gd            #   PriceModifier：价格修改器
│   │   ├── material_card.gd             #   素材卡运行时
│   │   ├── writing_method_card.gd       #   写作方法卡运行时
│   │   └── schedule_data.gd             #   日程运行时数据
│   ├── systems/                         # 系统层 — 游戏逻辑
│   │   ├── turn_manager.gd              #   TurnManager：回合驱动器
│   │   ├── stock_manager.gd             #   StockManager：股票管理（AutoLoad）
│   │   ├── article_system.gd            #   ArticleSystem：文章合成（静态工具类）
│   │   └── schedule_manager.gd          #   ScheduleManager：日程生成器
│   └── test/
│       └── test_turn.gd                 #   回合流程测试脚本
├── Scenes/
│   └── test_turn.tscn                   #   测试场景
└── Tags/
    └── TagHierarchy.tres                #   标签层级配置
```

---

## 架构概览

### 三层回合结构

游戏以 **Actor 轮转** 驱动回合流程，每回合由三个行动者按序执行：

```
TurnManager（回合驱动器，while true 循环）
│
├── WorldStartActor  ← 世界回合头（自动执行）
│   ├── REVEAL_EVENTS    揭示本回合日程事件
│   └── RESOLVE_BREAKING 检查并触发突发事件
│
├── PlayerActor      ← 玩家回合（await 玩家操作）
│   ├── 获取素材（消耗行动值）
│   ├── 合成文章（消耗行动值）
│   ├── 获取写作方法（消耗行动值）
│   ├── 发表文章（不限次数）
│   └── 买卖股票（独立交易次数限制）
│
└── WorldEndActor    ← 世界回合尾（自动执行）
    ├── SETTLE_ARTICLES  草稿新鲜度 -1，过期作废
    └── RESOLVE_PRICE    情绪结算 → 股价变动 → 退市检查
```

### 信号驱动

所有系统间通信通过 `GameBus` AutoLoad 信号总线完成，系统之间零直接引用。

### 插件继承

卡牌数据类继承自 `ItemContainerSystem` 插件的 `ItemData`，复用其 ID、名称、标签、容器管理能力，插件代码零修改。

---

## 核心系统

### 文章合成系统

玩家通过组合**素材卡**和**写作方法卡**来合成文章。

**素材卡类型：**

| MaterialType | 说明 | 典型组合 |
|-------------|------|---------|
| DATA | 数据 | DATA + DATA + OPINION → 深度研报 |
| RUMOR | 谣言 | RUMOR + EXPOSE → 惊天独家 |
| EXPOSE | 爆料 | EXPOSE + DATA → 调查报道 |
| OPINION | 观点 | OPINION + OPINION → 舆论造势 |

**文章类型（由素材组合决定）：**

| ArticleType | 组合要求 |
|------------|---------|
| RESEARCH_REPORT | 数据×2 + 观点 |
| INVESTIGATION | 爆料 + 数据 |
| EXCLUSIVE | 谣言 + 爆料 |
| CONSPIRACY | 谣言×2 |
| SERIAL_SCOOP | 爆料×2 |
| EXPERT_COMMENT | 数据 + 观点 |
| PUBLIC_OPINION | 观点×2 |
| GENERAL | 其他组合 |

**合成流程：**
1. 素材的 `bias`（看涨/看跌）多数票 → 文章立场
2. 素材的 `impact` + `credibility` 累加 → 基础数值
3. 写作方法卡的 `WritingMethodBehaviour` 依次修正数值
4. 钳位保证合理范围

### 股票市场系统

**股票属性：**
- `current_price` — 当前价格，受情绪和价格修改器影响
- `volatility` — 波动性（LOW/MEDIUM/HIGH），决定情绪对价格的放大系数
- `sentiment` — 情绪值（-10 ~ +10），所有情绪修改器的总和

**两类修改器：**

| 修改器 | 触发方式 | 生效时机 | 生命周期 |
|-------|---------|---------|---------|
| SentimentModifier | 文章发表 / 环境事件 | 持续影响情绪值 | 有 duration，回合尾 tick 过期 |
| PriceModifier | 特殊效果 | 立即修改价格 | 一次性 |

**目标分发规则（三级影响范围）：**
- `target_stock_ids` 非空 → 公司级，仅影响指定股票
- `target_industry` 非空 → 行业级，影响该行业所有股票
- 两者都空 → 宏观级，影响全市场

**回合尾结算流程：**
```
tick 情绪修改器（过期的移除）
    → 计算当前情绪总值
    → 价格变动 = 情绪 × 波动系数
    → 更新价格
    → 检查退市（价格 ≤ 初始价 × 20%）
```

### 日程事件系统

每局游戏开始时，`ScheduleManager` 从候选池按权重随机生成日程：

- **日程事件** — 预先安排在特定回合，提前 5 回合预告（仅显示 `preview_name`），到达时揭示（显示 `reveal_name` 并触发环境牌）
- **突发事件** — 每回合按概率随机触发，不可预测

环境牌触发后会创建 `SentimentModifier`，按目标规则分发到股票市场。

### 玩家资源

| 资源 | 默认值 | 说明 |
|------|-------|------|
| 行动值 | 3/回合 | 获取素材、合成文章、获取写作方法各消耗 1 点 |
| 交易次数 | 3/回合 | 买卖股票各消耗 1 次（独立于行动值） |
| 现金 | 10000 | 买卖股票的资金 |
| 信誉 | 50 | （预留）影响文章可信度 |
| 人脉 | 3 | （预留）影响素材获取 |

---

## 信号总线 GameBus

所有跨系统通信通过 `GameBus` AutoLoad 单例的信号完成：

| 分类 | 信号 | 说明 |
|------|------|------|
| 回合 | `turn_started/ended` | 回合开始/结束 |
| 行动者 | `actor_turn_started/ended` | Actor 回合开始/结束 |
| 世界阶段 | `world_start_phase_started/ended` | 世界回合头阶段 |
| 世界阶段 | `world_end_phase_started/ended` | 世界回合尾阶段 |
| 玩家 | `player_ended_turn` | 玩家点击结束回合 |
| 玩家 | `action_points_changed` | 行动值变化 |
| 玩家 | `assets_changed` | 持仓/现金变化 |
| 文章 | `article_composed/published/busted/expired` | 文章生命周期 |
| 市场 | `stock_price_changed/stock_delisted` | 股价变动/退市 |
| 市场 | `sentiment/price_modifier_applied` | 修改器分发 |
| 事件 | `event_revealed/breaking_event_triggered` | 事件触发 |
| 事件 | `events_showed` | 日程预告 |

---

## 关键设计模式

- **Actor 轮转**：`TurnManager` 持有有序 Actor 数组，`while true` 循环依次 `await actor.execute_turn(ctx)`，天然支持扩展新行动者（如 AI 对手）
- **上下文字典**：`ctx = {scene_tree, turn_number, schedule, player_state}` 透传给所有 Actor，避免直接依赖
- **信号总线**：`GameBus` 作为唯一通信通道，系统间完全解耦
- **插件继承**：数据类 extends `ItemData`，复用容器系统能力，插件代码不修改
- **运算注册表**：`PriceModifier` 支持通过 `register_op()` 扩展自定义运算（内置 add/multiply/divide/set/clamp_min/clamp_max）
- **声明式效果**：写作方法效果通过 `MethodEffectType` 枚举 + `WritingMethodBehaviour` 数据驱动

---

## GDScript 约定

- 缩进使用 Tab（Godot 标准）
- 所有自定义类使用 `class_name` 全局注册
- 数据类 extends `Resource`/`ItemData`；运行时对象 extends `RefCounted`；系统节点 extends `Node`
- 使用 `&"string_name"` 语法表示 StringName 字面量
- 私有成员/方法以 `_` 前缀命名
