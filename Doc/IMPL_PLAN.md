# StockLegend 实现思路文档 v2

> 基于 GDD_v1.md 的完整设计，深度整合 ContainerSystem 插件。
> 目标：纯逻辑层实现，无 UI，可通过测试场景验证所有规则。

---

## 一、ContainerSystem 插件能力速览

插件提供了以下可直接复用的核心类（**绝对不修改插件源码**）：

| 类 | 类型 | 职责 |
|---|---|---|
| `ItemData` | Resource | 物品**模板**：id、name、description、image、max_stack、tags、behaviours |
| `Item` | RefCounted | 物品**运行时实例**：持有 data 引用、stack_count、container、position_in_container |
| `ItemContainer` | Node | 容器：add/remove/query、tag 过滤、自动维护位置映射、发射 `item_changed` 信号 |
| `ItemBehaviourData` | Resource | 效果**数据类**：挂在 ItemData.behaviours 上，通过 `use_item()` 触发 |
| `ContainerSystem` | AutoLoad Node | 全局注册表：通过 ID 获取任意 ItemData |
| `TagManager` | AutoLoad Node | 全局标签注册：O(1) 路径查找、层级匹配 |
| `Tag` | Resource | 层级标签：类似 UE5 Gameplay Tag（如 "Industry.Tech"） |
| `SwaperTool` | 静态类 | 两容器间物品互换 |

**关键：ItemContainer 内置能力清单（不需要自己实现的功能）**
- 按 ID 查询物品位置、数量 O(1)
- 堆叠分发（`add_item` 自动处理堆叠到现有同 ID 物品）
- tag 过滤 + 层级匹配（`addable_tags` + `use_hierarchical_tags`）
- 物品变更信号（`item_changed(is_add, index, item)`）
- 容器大小变更信号（`size_changed(new_size)`）
- 容器缩小时自动重分配物品

---

## 二、旧计划 vs 新计划对比

| 旧计划（v1，问题所在） | 新计划（v2，整合插件） | 原因 |
|---|---|---|
| `MaterialCardDef extends Resource` | `MaterialCardData extends ItemData` | 复用 id/name/tags/description/behaviours |
| `WritingMethodDef extends Resource` | `WritingMethodCardData extends ItemData` | 同上 |
| `EnvironmentCardDef extends Resource` | `EnvironmentCardData extends ItemData` | tags 字段替代 tier enum 用于容器过滤 |
| `MaterialCard extends RefCounted` | `MaterialCard extends Item` | 获得容器跟踪、位置、stack_count |
| `WritingMethodCard extends RefCounted` | `WritingMethodCard extends Item` | 同上 + 冷却字段附加其上 |
| `card_zone_manager.gd`（完全自建） | 多个 `ItemContainer` 节点 | 插件已实现全部功能 |
| `effect_resolver.gd`（自建注册表） | `WritingMethodBehaviour extends ItemBehaviourData` | 插件的 behaviours 数组就是注册表 |
| `Array[StringName] tags`（素材卡语义标签） | `Array[Tag]`（插件 Tag 体系） | 统一语义，支持层级过滤 |
| `Enums.Industry`（行业枚举） | `Tag`（"Industry.Tech" 等路径） | 容器 addable_tags 可直接过滤行业 |
| `WritingMethodSystem`（独立系统） | 简化为 `ItemContainer` + `ArticleSystem` 中的方法应用逻辑 | 库管理=容器操作，效果应用=系统逻辑 |

---

## 三、标签体系设计

使用插件 Tag 层级取代旧方案中分散的枚举过滤，在编辑器中创建 `TagHierarchy` 资源：

```
Card                       ← 所有卡牌根标签
├── Card.Material          ← 素材卡（ItemContainer.addable_tags 使用此级别过滤）
│   ├── Card.Material.Data
│   ├── Card.Material.Scoop
│   ├── Card.Material.Rumor
│   └── Card.Material.Opinion
└── Card.WritingMethod     ← 写作方法卡
    ├── Card.WritingMethod.Common
    ├── Card.WritingMethod.Uncommon
    └── Card.WritingMethod.Rare

Industry                   ← 行业根标签（附加在 ItemData.tags 上）
├── Industry.Tech
├── Industry.Finance
├── Industry.Energy
├── Industry.Medical
└── Industry.Macro

Event                      ← 环境牌分类标签
├── Event.Macro
├── Event.Industry
└── Event.Company
```

**Tags 的使用方式：**
- `MaterialCardData.tags` 包含：`[Card.Material.Data, Industry.Tech]`（类型 + 行业）
- `hand_container.addable_tags = [Tag("Card.Material")]`，`use_hierarchical_tags = true` → 所有素材卡都可入手
- `method_library_container.addable_tags = [Tag("Card.WritingMethod")]` → 只允许方法卡
- `Article.target_industry: Tag` 直接使用 Tag 对象（已在 article.gd 中正确使用）

---

## 四、文件清单（新结构）

```
addons/ContainerSystem/      ← 插件层（只读，绝不修改）
│  core/ItemData.gd
│  core/Item.gd
│  core/ItemContainer.gd
│  core/ItemBehaviourData.gd
│  core/ContainerSystem.gd   ← AutoLoad
│  core/TagManager.gd        ← AutoLoad
│  core/Tag.gd
│  core/TagHierarchy.gd
│  core/SwaperTool.gd
│  ...

Scripts/
├── autoload/
│   └── game_bus.gd          ← 改造（重写信号，保留 AutoLoad 结构）
│
├── data/                    ← 数据资源层（全部继承 ItemData）
│   ├── enums.gd             ← 改造（精简：Industry/Zone/MaterialType 移除，改用 Tag；保留 Phase/Bias/ArticleType/Channel/Volatility/Rarity/ModifierOp）
│   ├── material_card_data.gd    ← 新建（extends ItemData）
│   ├── writing_method_card_data.gd ← 新建（extends ItemData）
│   ├── environment_card_data.gd    ← 新建（extends ItemData）
│   └── stock_def.gd         ← 新建（extends Resource，股票非卡牌实体）
│
├── behaviours/              ← 效果数据层（extends ItemBehaviourData）
│   ├── writing_method_behaviour.gd  ← 新建（抽象基类，定义 effect_type 字段）
│   └── impl/                ← 具体效果实现（每种效果一个文件）
│       ├── impact_boost_behaviour.gd
│       ├── credibility_boost_behaviour.gd
│       ├── bias_reverse_behaviour.gd
│       └── ... （更多效果）
│
├── runtime/
│   ├── material_card.gd     ← 改造（extends Item，替代 extends RefCounted）
│   ├── writing_method_card.gd ← 改造（extends Item + is_on_cooldown 字段）
│   ├── article.gd           ← 保留（extends RefCounted，组合结果，非卡牌实体）
│   ├── stock.gd             ← 保留（extends RefCounted）
│   ├── player_state.gd      ← 改造（移除 method_library Array，改为引用 ItemContainer）
│   └── sentiment_modifier.gd ← 新建（extends RefCounted）
│
└── systems/
    ├── turn_system.gd       ← 改造（7 阶段序列，新阶段处理逻辑）
    ├── market_system.gd     ← 新建（股价/情绪/交易/退市）
    ├── article_system.gd    ← 新建（文章组合/属性计算/方法应用/事实核查）
    ├── environment_system.gd ← 新建（日程表/突发事件/窥探）
    └── reputation_system.gd ← 新建（信誉值管理）
```

> **已删除**：`card_zone_manager.gd`、`effect_resolver.gd`、`target_selector.gd`、`writing_method_system.gd`（全部由插件或其他系统接管）

---

## 五、容器布局设计

在游戏场景中，每个玩家由以下 `ItemContainer` 节点构成（PlayerNode 的子节点）：

```
PlayerNode (Node)
├── DeckContainer      (ItemContainer) size=无限  addable_tags=[Card.Material]
├── HandContainer      (ItemContainer) size=5     addable_tags=[Card.Material]
├── DiscardContainer   (ItemContainer) size=无限  addable_tags=[Card.Material]
├── ExhaustContainer   (ItemContainer) size=无限  addable_tags=[Card.Material]
├── MethodLibrary      (ItemContainer) size=无限  addable_tags=[Card.WritingMethod]
└── ArticleWorkspace   (ItemContainer) size=6     addable_tags=[Card.Material]
                                                  （撰写文章时临时存放素材卡，max 6 张）
```

**容器替代原来计划的哪些内容：**
- `DeckContainer + HandContainer + DiscardContainer + ExhaustContainer` → 完全替代 `card_zone_manager.gd`
- `MethodLibrary` → 替代 `PlayerState.method_library: Array[WritingMethodCard]`
- `ArticleWorkspace` → 替代 `ArticleSystem` 内的临时列表管理

**移动卡牌：** 使用 `SwaperTool.swap_item()` 或 `remove_item_in_position` + `add_item` 两步操作。

---

## 六、实现顺序（强依赖优先）

```
第1步  配置 TagHierarchy 资源（编辑器内操作）
       → 创建 Card/Industry/Event 标签层级，保存为 .tres 文件
       → 在 ProjectSettings 中设置 container_system/tag_hierarchy

第2步  配置 ItemDataMap 资源（编辑器内操作）
       → 创建 ItemDataMap.tres，后续所有 ItemData 资源注册于此
       → 在 ProjectSettings 中设置 container_system/item_data_map

第3步  enums.gd（精简版）
       → 保留：Phase / Bias / ArticleType / Channel / Volatility / Rarity / ModifierOp
       → 删除：Industry / Zone / MaterialType（改用 Tag）

第4步  stock_def.gd（无依赖）

第5步  material_card_data.gd（extends ItemData）
第6步  writing_method_card_data.gd（extends ItemData）
第7步  environment_card_data.gd（extends ItemData）

第8步  writing_method_behaviour.gd（抽象基类）
第9步  各具体 behaviour 实现（impact_boost、credibility_boost、bias_reverse 等）

第10步 material_card.gd（extends Item）
第11步 writing_method_card.gd（extends Item + cooldown）

第12步 sentiment_modifier.gd（extends RefCounted）
第13步 stock.gd（依赖 sentiment_modifier）
第14步 article.gd（依赖 material_card + writing_method_card）
第15步 player_state.gd（依赖 enums + 引用 ItemContainer）

第16步 game_bus.gd（重写所有信号）

第17步 market_system.gd（依赖 stock + sentiment_modifier + game_bus）
第18步 article_system.gd（依赖 article + ItemContainer + behaviours + market_system）
第19步 environment_system.gd（依赖 environment_card_data + market_system）
第20步 reputation_system.gd（依赖 article + player_state + market_system）
第21步 turn_system.gd（依赖所有系统）

第22步 test_scene（集成测试）
```

---

## 七、各文件实现细节

### 7.1 `enums.gd` — 精简版（已有的需删除 Industry/Zone/MaterialType）---完成

```gdscript
class_name Enums

## 回合阶段（7 阶段）
enum Phase {
    MARKET_OPEN,    # 开盘：揭示日程/突发事件，环境修正器生效
    GATHER,         # 取材：抽牌/定向取材/窥探/进修
    WRITING,        # 撰写：组合素材卡成文章
    PUBLISH,        # 发表：选渠道发出，文章修正器生效
    MARKET_REACT,   # 市场反应：股价结算 → 事实核查
    TRADE,          # 交易：买卖股票
    SETTLEMENT,     # 收盘：资产结算，修正器 tick，新鲜度衰减
}

## 倾向（利好/利空/中性）
enum Bias { BULLISH, BEARISH, NEUTRAL }

## 文章类型（由素材组合模式决定）
enum ArticleType {
    RESEARCH_REPORT,   # 深度研报：数据+数据+观点
    INVESTIGATION,     # 调查报道：爆料+数据
    EXCLUSIVE,         # 惊天独家：谣言+爆料
    CONSPIRACY,        # 阴谋论：谣言+谣言
    SERIAL_SCOOP,      # 连环爆料：爆料+爆料
    EXPERT_COMMENT,    # 专家点评：数据+观点
    PUBLIC_OPINION,    # 舆论造势：观点+观点
    GENERAL,           # 一般报道：其他组合
}

## 发表渠道
enum Channel {
    SELF_MEDIA,        # 自媒体：免费，低效果
    MAINSTREAM,        # 主流媒体：消耗人脉，需信誉≥60
    ANONYMOUS,         # 匿名论坛：免费，最低效果
    PAID_PROMOTION,    # 付费推广：消耗现金，高效果
}

## 股票波动性
enum Volatility { LOW, MEDIUM, HIGH }

## 写作方法卡稀有度
enum Rarity { COMMON, UNCOMMON, RARE }

## 修改器运算
enum ModifierOp { ADD, MULTIPLY, SET }

## 写作方法效果类型（ArticleSystem 的 dispatch key）
enum MethodEffectType {
    IMPACT_ADD,
    IMPACT_MULTIPLY,
    CREDIBILITY_ADD,
    CREDIBILITY_MULTIPLY,
    BIAS_REVERSE,
    TYPE_CHANGE_TO_SCOOP,
    AFFECT_WHOLE_INDUSTRY,
    TARGETED_GATHER_FREE,
    FACT_CHECK_PROB_ADD,
    DURATION_ADD,
}
```

---

### 7.2 `material_card_data.gd` — extends ItemData --- 完成

插件已提供：`id`、`name`、`description`、`image`、`tags`（含行业 + 卡牌类型 Tag）、`behaviours`。
只需添加游戏特有字段：

```gdscript
class_name MaterialCardData
extends ItemData

## 倾向
@export var bias: Enums.Bias = Enums.Bias.NEUTRAL
## 可信度基础值（1~5）
@export var credibility: int = 1
## 影响力基础值（1~5）
@export var impact: int = 1

## 注意：
## - id / name / description 使用 ItemData 已有字段
## - tags 使用 ItemData.tags（Array[Tag]）：包含 Card.Material.* 和 Industry.* 两类标签
## - max_stack 设为 1（素材卡不堆叠）
## - behaviours 留空（素材卡无主动 behaviour，行为由 ArticleSystem 驱动）
```

---

### 7.3 `writing_method_card_data.gd` — extends ItemData --- 完成

```gdscript
class_name WritingMethodCardData
extends ItemData

## 稀有度（也可通过 tags 中的 Card.WritingMethod.Rare 等标签推断，但 enum 更直接）
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

## 注意：
## - behaviours 数组挂载若干 WritingMethodBehaviour 资源
## - id / name / description / tags 使用 ItemData 已有字段
## - tags 包含 Card.WritingMethod.* 标签
## - max_stack 设为 1
```

---

### 7.4 `environment_card_data.gd` — extends ItemData ---完成

```gdscript
class_name EnvironmentCardData
extends ItemData

## 日程表显示名（揭示前显示，card_name 揭示后显示）
@export var preview_name: String = ""
## 修正值（正=利好，负=利空）
@export var sentiment_modifier: int = 0
## 持续回合数
@export var duration: int = 1
## 是否可被玩家引用为临时素材卡
@export var can_be_referenced: bool = false
## 目标股票 ID（Company 层级时非空）
@export var target_stock_id: StringName = &""

## 注意：
## - tier（MACRO/INDUSTRY/COMPANY）通过 tags 中的 Event.* 标签表达
## - target_industry 通过 tags 中的 Industry.* 标签表达
## - id / name / description 使用 ItemData 已有字段
```

---

### 7.5 `writing_method_behaviour.gd` — extends ItemBehaviourData（抽象基类）---完成

```gdscript
class_name WritingMethodBehaviour
extends ItemBehaviourData

## 效果类型（ArticleSystem 按此分派）
@export var effect_type: Enums.MethodEffectType
## 效果数值（加法/乘法值，或布尔 1/0）
@export var value: float = 0.0

## 覆盖 use_item（此处不使用，效果由 ArticleSystem 读取 behaviour 数据后执行）
func use_item(item: Item, _from: Node, _to: Node, _num: int) -> Variant:
    push_error("WritingMethodBehaviour: 请通过 ArticleSystem.apply_method() 触发效果，而非直接调用 use_item")
    return null
```

具体效果资源（.tres）：每个写作方法卡在 `behaviours` 数组中挂载一个或多个这样的资源，无需写代码，编辑器内配置即可。

---

### 7.6 `material_card.gd` — extends Item --- 完成

```gdscript
class_name MaterialCard
extends Item

## 运行时倾向覆盖（[春秋笔法]等效果，false=不覆盖）
var _bias_reversed: bool = false

## 获取实际生效的倾向
func get_effective_bias() -> Enums.Bias:
    var base_bias := (data as MaterialCardData).bias
    if not _bias_reversed:
        return base_bias
    match base_bias:
        Enums.Bias.BULLISH: return Enums.Bias.BEARISH
        Enums.Bias.BEARISH: return Enums.Bias.BULLISH
        _: return Enums.Bias.NEUTRAL

## 反转倾向
func reverse_bias() -> void:
    _bias_reversed = not _bias_reversed

## 快捷访问类型化数据
func get_card_data() -> MaterialCardData:
    return data as MaterialCardData
```

> **注意**：构造时调用 `MaterialCard.new(card_data, container, index)`，符合 Item._init 签名。

---

### 7.7 `writing_method_card.gd` — extends Item --- 完成

```gdscript
class_name WritingMethodCard
extends Item

## 是否处于冷却（每回合 SETTLEMENT 阶段重置）
var is_on_cooldown: bool = false

func use() -> void:
    is_on_cooldown = true

func tick_cooldown() -> void:
    is_on_cooldown = false

func is_available() -> bool:
    return not is_on_cooldown

func get_card_data() -> WritingMethodCardData:
    return data as WritingMethodCardData
```

---

### 7.8 `player_state.gd` — 改造（移除 method_library Array）---完成

```gdscript
class_name PlayerState
extends RefCounted

## 资金
var cash: float = 10000.0
## 能量
var energy: int = 2
var max_energy: int = 2
## 人脉
var connections: int = 3
## 信誉
var reputation: int = 50

## 持仓 {stock_id: StringName -> quantity: int}
var holdings: Dictionary = {}

## 草稿区（已撰写完成、等待发表的 Article 对象列表）
var draft_articles: Array[Article] = []

## 回合操作计数器
var trade_count: int = 0
var max_trades: int = 3
var has_trained_today: bool = false
var has_scouted_today: bool = false

## 容器引用（由场景注入，而非 PlayerState 自己管理）
var deck: ItemContainer = null
var hand: ItemContainer = null
var discard: ItemContainer = null
var exhaust: ItemContainer = null
var method_library: ItemContainer = null      ## 写作方法库（替代旧的 Array[WritingMethodCard]）
var article_workspace: ItemContainer = null   ## 文章撰写区（替代旧的临时列表）

func buy_stock(stock_id: StringName, quantity: int, price: float) -> bool:
    var total_cost := quantity * price
    if cash < total_cost or trade_count >= max_trades:
        return false
    cash -= total_cost
    trade_count += 1
    return true

func sell_stock(stock_id: StringName, quantity: int, price: float) -> bool:
    if not holdings.has(stock_id) or trade_count >= max_trades:
        return false
    var h = holdings[stock_id]
    if h.quantity < quantity:
        return false
    cash += quantity * price
    trade_count += 1
    return true
```

---

### 7.9 `article_system.gd` — 文章组合 + 方法效果应用

ArticleSystem 是 `WritingMethodBehaviour` 效果的执行者（替代旧的 EffectResolver）：

```gdscript
# 将写作方法卡应用到文章（读取 behaviours 数据并分派执行）
func apply_method_to_article(method_card: WritingMethodCard, article: Article) -> void:
    for behaviour in method_card.data.behaviours:
        if not behaviour is WritingMethodBehaviour:
            continue
        var b := behaviour as WritingMethodBehaviour
        match b.effect_type:
            Enums.MethodEffectType.IMPACT_ADD:
                article.final_impact += int(b.value)
            Enums.MethodEffectType.CREDIBILITY_ADD:
                article.final_credibility += int(b.value)
            Enums.MethodEffectType.BIAS_REVERSE:
                # 反转文章中第一张素材卡的倾向
                if article.material_cards.size() > 0:
                    article.material_cards[0].reverse_bias()
            # ... 更多效果
    method_card.use()
```

---

### 7.10 `game_bus.gd` — 重写信号 --- 完成

```gdscript
extends Node

## 回合信号
signal turn_started(turn: int)
signal turn_ended(turn: int)
signal phase_started(phase: Enums.Phase)
signal phase_ended(phase: Enums.Phase)

## 文章信号
signal article_composed(article: Article)
signal article_published(article: Article, channel: Enums.Channel)
signal article_busted(article: Article)

## 市场信号
signal stock_price_changed(stock_id: StringName, old_price: float, new_price: float)
signal stock_delisted(stock_id: StringName)
signal sentiment_modifier_applied(stock_id: StringName, mod: SentimentModifier)

## 玩家信号
signal player_trade(stock_id: StringName, quantity: int, is_buy: bool)
signal reputation_changed(old_val: int, new_val: int)
signal energy_changed(old_val: int, new_val: int)

## 环境信号
signal event_revealed(event_def: EnvironmentCardData)
signal breaking_event_triggered(event_def: EnvironmentCardData)
```

---

### 7.11 `turn_system.gd` — 7 阶段驱动

```gdscript
## 阶段序列：依次推进 Phase 枚举
## 每个阶段结束后 → game_bus.phase_ended → 下一阶段
## 核心接口：
##   start_game()
##   next_phase()（由测试或 UI 调用）
##   play_material_cards(cards, article) → 调用 article_system
##   apply_writing_method(method_card, article) → 调用 article_system
##   publish_article(article, channel) → 调用 article_system
##   buy_stock(id, qty) / sell_stock(id, qty) → 调用 market_system
```

---

## 八、关键设计决策说明

### 为什么素材卡不需要 behaviours？
素材卡的"效果"完全由 `ArticleSystem` 根据素材组合规则计算（文章类型判定、属性加总），不存在"使用素材卡"这个主动行为。`ItemBehaviourData` 适合"使用时触发"的行为，素材卡不符合这个模型。

### 为什么 WritingMethodBehaviour.use_item 不执行逻辑？
`use_item(item, from_node, to_node, num)` 签名要求两个 Node 参数，但 `Article` 是 RefCounted。强行适配会造成 NodeWrapper 等丑陋代码。正确做法：**behaviours 作为数据配置**，`ArticleSystem.apply_method_to_article()` 读取并执行。

### 为什么不删除 EffectResolver，而是让 ArticleSystem 内置分派？
写作方法效果类型有限（约 10 种）、全部与文章有关，无需通用注册表。单一系统内的 `match` 语句比维护注册表更简单清晰。

### Article 为什么不继承 Item？
文章是**组合结果**，不是卡牌实体。它不属于任何 ItemContainer，没有 stack_count 意义，由 player_state.draft_articles 数组管理。

### ItemContainer 的位置管理（index）如何看待？
对于牌堆/手牌，index 有意义（位置）。插件在 `item_changed` 信号中提供 index，UI 层可直接利用。纯逻辑层测试时 index 仅用于 API 调用，不影响游戏规则。

---

## 九、测试场景验证目标

```gdscript
## test_turn.gd 验证清单：
## 1. 从 DeckContainer 抽 3 张素材卡到 HandContainer
## 2. 将 2 张手牌移入 ArticleWorkspace → 组合成 Article
## 3. 从 MethodLibrary 取一张方法卡应用到 Article → 检查属性变化
## 4. 发表 Article（SELF_MEDIA）→ 检查 SentimentModifier 挂载到 Stock
## 5. MARKET_REACT 阶段：MarketSystem 结算股价变化
## 6. TRADE 阶段：买入股票 → 检查 PlayerState.cash / holdings
## 7. SETTLEMENT 阶段：SentimentModifier.tick()，新鲜度衰减，WritingMethodCard 冷却重置
```
