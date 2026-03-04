# StockLegend 实现思路文档 v1

> 基于 GDD_v1.md 的完整设计，针对现有代码库的重构与新建指南。
> 目标：纯逻辑层实现，无 UI，可通过测试场景验证所有规则。

---

## 一、总体策略

现有框架是一个通用卡牌对战系统（攻防血量模型），与 StockLegend 的机制差异较大，**不能直接复用卡牌逻辑**，但可以复用架构模式。

| 处理方式 | 文件 | 原因 |
|---------|------|------|
| **保留** | `game_bus.gd`、`effect_resolver.gd`、`card_zone_manager.gd` | 架构模式可复用，信号/注册表/容器管理逻辑是通用的 |
| **改造** | `enums.gd`、`turn_system.gd`、`modifier.gd` | 框架结构保留，内容需要替换 |
| **重写** | `player_state.gd` | 属性完全不同 |
| **删除** | `card_item_data.gd`、`effect_def.gd`、`card_item.gd` 及三个子类 | 新卡牌体系彻底不同，保留会造成混淆 |
| **新建** | 数据资源、运行时对象、五个新系统 | 见第三节 |

---

## 二、文件清单

```
src/
├── autoload/
│   └── game_bus.gd             ← 改造（重写信号，保留 AutoLoad 结构）
│
├── data/                       ← 全部重建（删除旧的，新建以下）
│   ├── enums.gd                ← 改造（全部替换枚举内容）
│   ├── material_card_def.gd    ← 新建（素材卡定义 Resource）
│   ├── writing_method_def.gd   ← 新建（写作方法卡定义 Resource）
│   ├── stock_def.gd            ← 新建（股票定义 Resource）
│   └── environment_card_def.gd ← 新建（环境牌定义 Resource）
│
├── runtime/
│   ├── player_state.gd         ← 重写（全新属性体系）
│   ├── sentiment_modifier.gd   ← 新建（情绪修正器，替代旧 Modifier）
│   ├── stock.gd                ← 新建（股票运行时状态）
│   ├── material_card.gd        ← 新建（素材卡运行时实例）
│   ├── writing_method_card.gd  ← 新建（写作方法卡运行时实例）
│   └── article.gd              ← 新建（文章运行时对象）
│
└── systems/
    ├── turn_system.gd          ← 改造（7 阶段序列，新阶段处理逻辑）
    ├── card_zone_manager.gd    ← 改造（更新 Zone 枚举和类型引用）
    ├── effect_resolver.gd      ← 保留（注册表模式不变）
    ├── market_system.gd        ← 新建（股价/情绪/交易/退市）
    ├── article_system.gd       ← 新建（文章组合/属性计算/事实核查委托）
    ├── environment_system.gd   ← 新建（日程表/突发事件/窥探）
    ├── reputation_system.gd    ← 新建（信誉值/事实核查）
    └── writing_method_system.gd← 新建（方法卡库/进修抽取/冷却）
```

---

## 三、实现顺序（强依赖优先）

```
第1步  enums.gd                  ← 所有系统依赖的枚举定义
第2步  四个 Data Resource          ← 纯数据，无依赖
第3步  sentiment_modifier.gd      ← 纯数据对象
第4步  stock.gd                   ← 依赖 enums + sentiment_modifier
第5步  material_card.gd           ← 依赖 enums + material_card_def
第6步  writing_method_card.gd     ← 依赖 enums + writing_method_def
第7步  article.gd                 ← 依赖 material_card + writing_method_card
第8步  player_state.gd            ← 依赖 enums + writing_method_card
第9步  game_bus.gd                ← 重写所有信号
第10步 card_zone_manager.gd       ← 改造 Zone 枚举引用
第11步 market_system.gd           ← 依赖 stock + sentiment_modifier
第12步 article_system.gd          ← 依赖 article + market_system
第13步 environment_system.gd      ← 依赖 environment_card_def + market_system
第14步 reputation_system.gd       ← 依赖 article + player_state + market_system
第15步 writing_method_system.gd   ← 依赖 writing_method_def + player_state
第16步 turn_system.gd             ← 依赖所有系统
第17步 test_scene                 ← 集成测试
```

---

## 四、各文件实现细节

### 4.1 `enums.gd` — 全部替换

删除旧的所有枚举，替换为以下内容：

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

## 素材卡类型
enum MaterialType { DATA, SCOOP, RUMOR, OPINION }

## 行业标签
enum Industry { TECH, FINANCE, ENERGY, MEDICAL, MACRO }

## 倾向
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

## 环境牌影响层级
enum EventTier { MACRO, INDUSTRY, COMPANY }

## 环境牌来源类型
enum EventSourceType { SCHEDULED, BREAKING }

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

## 素材卡区域（方法卡不进入区域管理）
enum Zone { DECK, HAND, DISCARD, EXHAUST }

## 修改器运算（保留，sentiment_modifier 暂不使用但其他地方可能用到）
enum ModifierOp { ADD, MULTIPLY, SET }
```

**注意**：Zone 从 5 个缩减为 4 个（删除 FIELD，因为素材卡不上场；草稿区 DESK 由 ArticleSystem 管理而非 ZoneManager）。

---

### 4.2 Data Resources — 四个纯数据类------已解决

#### `material_card_def.gd`
```gdscript
class_name MaterialCardDef
extends Resource

@export var id: StringName
@export var card_name: String
@export var type: Enums.MaterialType
@export var industry: Enums.Industry
@export var bias: Enums.Bias
@export var credibility: int   # 1~5
@export var impact: int        # 1~5
@export var tags: Array[StringName]  # 语义标签，用于协同/冲突判定
@export var flavor_text: String
```

#### `writing_method_def.gd`
```gdscript
class_name WritingMethodDef
extends Resource

@export var id: StringName
@export var card_name: String
@export var description: String
@export var rarity: Enums.Rarity
## 效果参数字典，键名统一定义：
## impact_add, impact_mul, credibility_add, credibility_mul,
## fact_check_prob_add, duration_add,
## reverses_one_bias (bool), changes_type_to_scoop (bool),
## affects_whole_industry (bool), targeted_gather_free (bool),
## etc.
@export var effect_params: Dictionary
@export var flavor_text: String
```

#### `stock_def.gd`
```gdscript
class_name StockDef
extends Resource

@export var id: StringName
@export var stock_name: String
@export var industry: Enums.Industry
@export var initial_price: float
@export var volatility: Enums.Volatility

func get_volatility_coefficient() -> float:
    match volatility:
        Enums.Volatility.LOW:    return 0.5
        Enums.Volatility.MEDIUM: return 1.0
        Enums.Volatility.HIGH:   return 1.5
    return 1.0

func get_delisting_threshold() -> float:
    return initial_price * 0.2
```

#### `environment_card_def.gd`
```gdscript
class_name EnvironmentCardDef
extends Resource

@export var id: StringName
@export var card_name: String           # 完整揭示后的名称（如"央行宣布降息50基点"）
@export var preview_name: String        # 日程表显示名（如"央行·议息会议结果公布"）
@export var tier: Enums.EventTier
@export var target_industry: Enums.Industry  # INDUSTRY 层级时使用
@export var target_stock: StringName         # COMPANY 层级时使用
@export var sentiment_modifier: int     # 正=利好，负=利空
@export var duration: int               # 持续回合数
@export var source_type: Enums.EventSourceType
@export var can_be_referenced: bool     # 是否可被引用为临时数据卡
@export var flavor_text: String
```

---

### 4.3 `sentiment_modifier.gd` — 情绪修正器------已解决

这是一个纯数据对象，替代旧的 `Modifier`。

```gdscript
class_name SentimentModifier
extends RefCounted

var source_id: StringName        # 文章ID 或 环境牌ID
var source_type: String          # "article" 或 "environment"
var target_stock: StringName     # 目标股票ID
var value: int                   # 修正值（正=利好，负=利空）
var remaining_turns: int         # 剩余持续回合数

## 工厂方法：从文章创建
static func from_article(article: Article) -> SentimentModifier:
    var mod := SentimentModifier.new()
    mod.source_id = article.article_id
    mod.source_type = "article"
    mod.target_stock = article.target_stock_id
    mod.value = article.final_impact * (1 if article.direction == Enums.Bias.BULLISH else -1)
    mod.remaining_turns = article.final_credibility
    return mod

## 工厂方法：从环境牌创建
static func from_environment(env_def: EnvironmentCardDef, stock_id: StringName) -> SentimentModifier:
    var mod := SentimentModifier.new()
    mod.source_id = env_def.id
    mod.source_type = "environment"
    mod.target_stock = stock_id
    mod.value = env_def.sentiment_modifier
    mod.remaining_turns = env_def.duration
    return mod

## SETTLEMENT 阶段调用，返回 true 表示已过期
func tick() -> bool:
    remaining_turns -= 1
    return remaining_turns <= 0
```

---

### 4.4 `stock.gd` — 股票运行时状态------已完成

```gdscript
class_name Stock
extends RefCounted

var def: StockDef
var current_price: float
var is_delisted: bool = false
var _modifiers: Array[SentimentModifier] = []

func _init(stock_def: StockDef) -> void:
    def = stock_def
    current_price = stock_def.initial_price

## 计算当前情绪值（所有修正器之和，夹到 -10~+10）
func get_sentiment() -> int:
    var total := 0
    for mod in _modifiers:
        total += mod.value
    return clampi(total, -10, 10)

## 添加情绪修正器
func add_modifier(mod: SentimentModifier) -> void:
    _modifiers.append(mod)

## 移除指定来源的修正器（用于打假反转）
func remove_modifier_by_source(source_id: StringName) -> void:
    _modifiers = _modifiers.filter(func(m): return m.source_id != source_id)

## SETTLEMENT 阶段：tick 所有修正器，移除过期的
func tick_modifiers() -> void:
    var expired: Array[SentimentModifier] = []
    for mod in _modifiers:
        if mod.tick():
            expired.append(mod)
    for mod in expired:
        _modifiers.erase(mod)

## MARKET_REACT 阶段：按当前情绪更新股价
func apply_price_change() -> void:
    if is_delisted:
        return
    var delta := get_sentiment() * def.get_volatility_coefficient()
    current_price += delta
    current_price = maxf(current_price, 0.0)

## 检查是否触发退市
func should_delist() -> bool:
    return current_price <= def.get_delisting_threshold() and not is_delisted

## 获取所有活跃修正器（供调试和UI读取）
func get_modifiers() -> Array[SentimentModifier]:
    return _modifiers.duplicate()
```

---

### 4.5 `material_card.gd` — 素材卡运行时实例

```gdscript
class_name MaterialCard
extends RefCounted

var def: MaterialCardDef
## 运行时 bias 覆盖（用于「春秋笔法」等效果，-1 表示不覆盖）
var _bias_reversed: bool = false

static func create(card_def: MaterialCardDef) -> MaterialCard:
    var card := MaterialCard.new()
    card.def = card_def
    return card

## 获取实际生效的倾向（考虑覆盖）
func get_effective_bias() -> Enums.Bias:
    if not _bias_reversed:
        return def.bias
    match def.bias:
        Enums.Bias.BULLISH: return Enums.Bias.BEARISH
        Enums.Bias.BEARISH: return Enums.Bias.BULLISH
        _: return Enums.Bias.NEUTRAL

## 反转倾向（「春秋笔法」调用）
func reverse_bias() -> void:
    _bias_reversed = not _bias_reversed
```

---

### 4.6 `writing_method_card.gd` — 写作方法卡运行时实例

```gdscript
class_name WritingMethodCard
extends RefCounted

var def: WritingMethodDef
var is_on_cooldown: bool = false

static func create(method_def: WritingMethodDef) -> WritingMethodCard:
    var card := WritingMethodCard.new()
    card.def = method_def
    return card

## 使用此方法卡（进入冷却）
func use() -> void:
    is_on_cooldown = true

## SETTLEMENT 阶段调用：恢复冷却
func tick_cooldown() -> void:
    is_on_cooldown = false

func is_available() -> bool:
    return not is_on_cooldown
```

---

### 4.7 `article.gd` — 文章运行时对象

```gdscript
class_name Article
extends RefCounted

## 唯一ID，发表时生成（格式：article_{turn}_{index}）
var article_id: StringName

## 组成材料
var material_cards: Array[MaterialCard] = []
var method_cards: Array[WritingMethodCard] = []

## 计算后的属性（由 ArticleSystem 写入）
var article_type: Enums.ArticleType = Enums.ArticleType.GENERAL
var final_credibility: int = 0
var final_impact: int = 0
var direction: Enums.Bias = Enums.Bias.NEUTRAL
var target_industry: Enums.Industry
var target_stock_id: StringName    # 若有具体目标股票（「病毒传播」时为空）

## 发表相关
var channel: Enums.Channel
var is_published: bool = false
var published_turn: int = -1

## 草稿新鲜度（每个 SETTLEMENT 阶段 -1，归零时废稿）
var freshness: int = 3

## 是否被打假
var is_busted: bool = false
```

---

### 4.8 `player_state.gd` — 玩家状态（完全重写）

```gdscript
class_name PlayerState
extends RefCounted

## 四种资源
var cash: float = 10000.0
var energy: int = 2
var max_energy: int = 2
var connections: int = 3     # 人脉
var reputation: int = 50

## 持仓：{stock_id: StringName -> {quantity: int, avg_cost: float}}
var holdings: Dictionary = {}

## 个人写作方法卡库（永久持有）
var method_library: Array[WritingMethodCard] = []

## 草稿区（撰写完成、等待发表的文章）
var draft_articles: Array[Article] = []

## 当前回合的操作计数器
var trade_count: int = 0
var max_trades: int = 3
var has_trained_today: bool = false     # 进修限制（每回合1次）
var has_scouted_today: bool = false     # 窥探限制（每回合1次）

## 买入股票（成功返回 true）
func buy_stock(stock_id: StringName, quantity: int, price: float) -> bool:
    var total_cost := quantity * price
    if cash < total_cost or trade_count >= max_trades:
        return false
    cash -= total_cost
    if holdings.has(stock_id):
        var h := holdings[stock_id]
        var old_total := h.quantity * h.avg_cost
        h.quantity += quantity
        h.avg_cost = (old_total + total_cost) / h.quantity
    else:
        holdings[stock_id] = {quantity = quantity, avg_cost = price}
    trade_count += 1
    return true

## 卖出股票（成功返回 true）
func sell_stock(stock_id: StringName, quantity: int, price: float) -> bool:
    if not holdings.has(stock_id) or trade_count >= max_trades:
        return false
    var h := holdings[stock_id]
    if h.quantity < quantity:
        return false
    cash += quantity * price
    h.quantity -= quantity
    if h.quantity == 0:
        holdings.erase(stock_id)
    trade_count += 1
    return true

## 回合开始重置计数器
func reset_turn_counters() -> void:
    energy = max_energy
    trade_count = 0
    has_trained_today = false
    has_scouted_today = false

## 信誉区间 → 效果（0=阴谋论, 1=争议, 2=普通, 3=知名, 4=权威）
func get_reputation_tier() -> int:
    if reputation >= 80: return 4
    if reputation >= 60: return 3
    if reputation >= 40: return 2
    if reputation >= 20: return 1
    return 0

## 计算总资产（需传入市场价格查询接口）
func get_total_assets(price_query: Callable) -> float:
    var total := cash
    for stock_id in holdings:
        total += holdings[stock_id].quantity * price_query.call(stock_id)
    return total
```

---

### 4.9 `game_bus.gd` — 重写信号

保留 AutoLoad 结构，替换所有信号为新设计：

```gdscript
class_name GameBus
extends Node

# ─── 回合流程 ────────────────────────────────
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal phase_started(phase: Enums.Phase)
signal phase_ended(phase: Enums.Phase)

# 各阶段的"玩家行动完毕"信号（系统等待这些信号后推进）
signal gather_phase_entered
signal gather_phase_finished
signal writing_phase_entered
signal writing_phase_finished
signal publish_phase_entered
signal publish_phase_finished
signal trade_phase_entered
signal trade_phase_finished

# ─── 市场 ────────────────────────────────────
signal stock_price_changed(stock_id: StringName, new_price: float, delta: float)
signal stock_delisted(stock_id: StringName)
signal sentiment_changed(stock_id: StringName, new_sentiment: int)
signal modifier_added(stock_id: StringName, mod: SentimentModifier)
signal modifier_removed(stock_id: StringName, source_id: StringName)

# ─── 素材卡 ──────────────────────────────────
signal card_drawn(card: MaterialCard)
signal card_zone_changed(card: MaterialCard, from_zone: Enums.Zone, to_zone: Enums.Zone)

# ─── 文章 ────────────────────────────────────
signal article_composed(article: Article)
signal article_published(article: Article)
signal article_fact_checked(article: Article, is_busted: bool)
signal article_expired(article: Article)         # 草稿新鲜度归零

# ─── 环境事件 ─────────────────────────────────
signal schedule_announced(schedule: Array)       # 周期第1天公布日程
signal event_revealed(event_def: EnvironmentCardDef, day: int)  # 窥探或自然揭示
signal breaking_news_triggered(event_def: EnvironmentCardDef)

# ─── 玩家资源 ─────────────────────────────────
signal reputation_changed(new_value: int, delta: int)
signal resource_changed(resource_name: String, new_value: int)  # "cash","energy","connections"

# ─── 写作方法卡 ───────────────────────────────
signal writing_method_acquired(card: WritingMethodCard)
signal writing_method_used(card: WritingMethodCard)
```

---

### 4.10 `card_zone_manager.gd` — 改造 Zone 引用

主要改动：
1. Zone 枚举从 5 个变为 4 个（删除 FIELD，因为素材卡不上场）
2. 泛型 `CardItem` 改为 `MaterialCard`
3. `draw_card()` 改为 `draw_cards(count: int)`
4. 删除 `get_all_cards()` 中对 FIELD 的处理

**DESK（草稿区）和 PUBLISHED 区不进入 ZoneManager**，由 `PlayerState.draft_articles` 和 `ArticleSystem` 直接管理。这是因为文章是多张卡牌的复合对象，不适合用 ItemContainer 的单一槽位管理。

改造后的核心签名：
```gdscript
func create_card(card_def: MaterialCardDef, zone: Enums.Zone) -> MaterialCard
func move_card(card: MaterialCard, to_zone: Enums.Zone) -> void
func get_cards_in_zone(zone: Enums.Zone) -> Array[MaterialCard]
func draw_cards(count: int) -> Array[MaterialCard]    # 从 DECK 抽 count 张到 HAND
func shuffle_deck() -> void
```

---

### 4.11 `market_system.gd` — 市场系统

**职责**：管理所有股票的情绪值、股价计算、交易结算、退市判定。

```gdscript
class_name MarketSystem
extends Node

var _stocks: Dictionary = {}   # StringName -> Stock

func initialize(stock_defs: Array[StockDef]) -> void:
    for def in stock_defs:
        _stocks[def.id] = Stock.new(def)

func get_stock(stock_id: StringName) -> Stock:
    return _stocks.get(stock_id, null)

func get_price(stock_id: StringName) -> float:
    var stock := get_stock(stock_id)
    return stock.current_price if stock else 0.0

func add_sentiment_modifier(stock_id: StringName, mod: SentimentModifier) -> void:
    var stock := get_stock(stock_id)
    if stock and not stock.is_delisted:
        stock.add_modifier(mod)
        GameBus.modifier_added.emit(stock_id, mod)
        GameBus.sentiment_changed.emit(stock_id, stock.get_sentiment())

## MARKET_REACT 阶段调用：结算股价，检查退市
func process_market_react() -> void:
    for stock_id in _stocks:
        var stock: Stock = _stocks[stock_id]
        if stock.is_delisted:
            continue
        var old_price := stock.current_price
        stock.apply_price_change()
        var delta := stock.current_price - old_price
        if delta != 0.0:
            GameBus.stock_price_changed.emit(stock_id, stock.current_price, delta)
        if stock.should_delist():
            _delist_stock(stock_id)

## SETTLEMENT 阶段调用：tick 所有修正器
func process_settlement() -> void:
    for stock_id in _stocks:
        var stock: Stock = _stocks[stock_id]
        if not stock.is_delisted:
            stock.tick_modifiers()

func get_all_active_stocks() -> Array[Stock]:
    var result: Array[Stock] = []
    for stock_id in _stocks:
        if not _stocks[stock_id].is_delisted:
            result.append(_stocks[stock_id])
    return result

func _delist_stock(stock_id: StringName) -> void:
    var stock: Stock = _stocks[stock_id]
    stock.is_delisted = true
    GameBus.stock_delisted.emit(stock_id)
    print("[MarketSystem] Stock delisted: %s at price %.2f" % [stock_id, stock.current_price])
```

---

### 4.12 `article_system.gd` — 文章组合系统

**职责**：验证素材组合合法性、计算文章属性、创建文章对象。

```gdscript
class_name ArticleSystem
extends Node

## 验证素材卡组合是否合法（相同行业，数量 2~4）
func validate_composition(materials: Array[MaterialCard]) -> bool:
    if materials.size() < 2 or materials.size() > 4:
        return false
    var base_industry := materials[0].def.industry
    for card in materials:
        # MACRO 可以与任何行业混搭
        if card.def.industry != base_industry and card.def.industry != Enums.Industry.MACRO and base_industry != Enums.Industry.MACRO:
            return false
    return true

## 组合文章（主入口）
func compose_article(
    materials: Array[MaterialCard],
    methods: Array[WritingMethodCard],
    target_stock_id: StringName = &""
) -> Article:
    if not validate_composition(materials):
        return null

    var article := Article.new()
    article.material_cards = materials.duplicate()
    article.method_cards = methods.duplicate()
    article.target_stock_id = target_stock_id

    # 第一步：基础值
    var base := _calc_base_values(materials)
    article.final_credibility = base.credibility
    article.final_impact = base.impact
    article.direction = base.direction
    article.target_industry = base.industry

    # 第二步：文章类型加成
    article.article_type = _determine_article_type(materials)
    _apply_type_bonus(article)

    # 第三步：协同/冲突
    _apply_synergy_and_contradiction(article, materials)

    # 第四步：写作方法卡修正（加法先于乘法）
    _apply_method_cards(article, methods)

    # 最终 clamp
    article.final_credibility = clampi(article.final_credibility, 1, 5)
    article.final_impact = maxi(article.final_impact, 0)

    GameBus.article_composed.emit(article)
    return article

## 第一步：基础值计算
func _calc_base_values(materials: Array[MaterialCard]) -> Dictionary:
    var total_credibility := 0
    var total_impact := 0
    var bullish_count := 0
    var bearish_count := 0
    var dominant_industry := Enums.Industry.MACRO

    for card in materials:
        total_credibility += card.def.credibility
        total_impact += card.def.impact
        match card.get_effective_bias():
            Enums.Bias.BULLISH: bullish_count += 1
            Enums.Bias.BEARISH: bearish_count += 1
        if card.def.industry != Enums.Industry.MACRO:
            dominant_industry = card.def.industry

    var direction := Enums.Bias.NEUTRAL
    if bullish_count > bearish_count:
        direction = Enums.Bias.BULLISH
    elif bearish_count > bullish_count:
        direction = Enums.Bias.BEARISH

    return {
        credibility = floori(float(total_credibility) / materials.size()),
        impact = total_impact,
        direction = direction,
        industry = dominant_industry,
    }

## 第二步：判定文章类型
func _determine_article_type(materials: Array[MaterialCard]) -> Enums.ArticleType:
    var type_counts := {}
    for t in Enums.MaterialType.values():
        type_counts[t] = 0
    for card in materials:
        type_counts[card.def.type] += 1

    var data_count: int = type_counts[Enums.MaterialType.DATA]
    var scoop_count: int = type_counts[Enums.MaterialType.SCOOP]
    var rumor_count: int = type_counts[Enums.MaterialType.RUMOR]
    var opinion_count: int = type_counts[Enums.MaterialType.OPINION]

    # 精确匹配（按优先级）
    if data_count >= 2 and opinion_count >= 1:
        return Enums.ArticleType.RESEARCH_REPORT    # 深度研报
    if scoop_count >= 1 and data_count >= 1:
        return Enums.ArticleType.INVESTIGATION       # 调查报道
    if rumor_count >= 1 and scoop_count >= 1:
        return Enums.ArticleType.EXCLUSIVE           # 惊天独家
    if rumor_count >= 2:
        return Enums.ArticleType.CONSPIRACY          # 阴谋论
    if scoop_count >= 2:
        return Enums.ArticleType.SERIAL_SCOOP        # 连环爆料
    if data_count >= 1 and opinion_count >= 1:
        return Enums.ArticleType.EXPERT_COMMENT      # 专家点评
    if opinion_count >= 2:
        return Enums.ArticleType.PUBLIC_OPINION      # 舆论造势
    return Enums.ArticleType.GENERAL

## 第二步：应用类型加成
func _apply_type_bonus(article: Article) -> void:
    match article.article_type:
        Enums.ArticleType.RESEARCH_REPORT:
            article.freshness += 1   # 持续时间+1（复用 freshness 字段存 duration bonus？）
            # 注：持续时间实际由 final_credibility 决定，这里用 duration_bonus 字段更好
            # 简化处理：直接在 final_credibility 上 +1
            article.final_credibility += 1
        Enums.ArticleType.INVESTIGATION:
            article.final_credibility += 1
        Enums.ArticleType.EXCLUSIVE:
            article.final_impact = roundi(article.final_impact * 1.5)
            # 事实核查概率翻倍由 ReputationSystem 处理
        Enums.ArticleType.CONSPIRACY:
            # 50%概率影响力翻倍，50%概率文章无效 → 标记，由调用方处理
            if randf() < 0.5:
                article.final_impact *= 2
            else:
                article.final_impact = 0  # 无效
        Enums.ArticleType.SERIAL_SCOOP:
            article.final_impact += 3
        Enums.ArticleType.EXPERT_COMMENT:
            article.final_credibility += 1
        Enums.ArticleType.PUBLIC_OPINION:
            article.final_impact += 2

## 第三步：协同与冲突
func _apply_synergy_and_contradiction(article: Article, materials: Array[MaterialCard]) -> void:
    # 协同1：不同类型素材 tags 有交集 → 可信度 +1
    # 协同2：爆料+数据倾向一致 → 影响力 +2
    # 冲突1：bias 互相矛盾 → 影响力 ×0.5
    # 冲突2：≥2 张谣言 → 可信度额外 -1/张
    # 冲突3：高可信度(≥4) 混用低可信度(≤2) → 整体降至低者

    var has_bullish := false
    var has_bearish := false
    var rumor_count := 0
    var min_credibility := 5
    var max_credibility := 1
    var has_scoop := false
    var has_data := false
    var scoop_bias := Enums.Bias.NEUTRAL
    var data_bias := Enums.Bias.NEUTRAL

    for card in materials:
        var bias := card.get_effective_bias()
        if bias == Enums.Bias.BULLISH: has_bullish = true
        if bias == Enums.Bias.BEARISH: has_bearish = true
        if card.def.type == Enums.MaterialType.RUMOR: rumor_count += 1
        min_credibility = mini(min_credibility, card.def.credibility)
        max_credibility = maxi(max_credibility, card.def.credibility)
        if card.def.type == Enums.MaterialType.SCOOP:
            has_scoop = true
            scoop_bias = bias
        if card.def.type == Enums.MaterialType.DATA:
            has_data = true
            data_bias = bias

    # 冲突1：方向矛盾
    if has_bullish and has_bearish:
        article.final_impact = roundi(article.final_impact * 0.5)

    # 冲突2：谣言堆叠
    if rumor_count >= 2:
        article.final_credibility -= (rumor_count - 1)

    # 冲突3：高低可信度混用
    if max_credibility >= 4 and min_credibility <= 2:
        article.final_credibility = min_credibility

    # 协同2：爆料+数据倾向一致
    if has_scoop and has_data and scoop_bias == data_bias and scoop_bias != Enums.Bias.NEUTRAL:
        article.final_impact += 2
        article.final_credibility += 1

## 第四步：写作方法卡修正
func _apply_method_cards(article: Article, methods: Array[WritingMethodCard]) -> void:
    # 先累计加法修正
    var impact_add := 0
    var credibility_add := 0
    var impact_mul := 1.0
    var credibility_mul := 1.0

    for method_card in methods:
        var p: Dictionary = method_card.def.effect_params
        impact_add += p.get("impact_add", 0)
        credibility_add += p.get("credibility_add", 0)
        impact_mul *= p.get("impact_mul", 1.0)
        credibility_mul *= p.get("credibility_mul", 1.0)

    article.final_impact = roundi((article.final_impact + impact_add) * impact_mul)
    article.final_credibility = floori((article.final_credibility + credibility_add) * credibility_mul)
```

**关键设计说明**：
- `CONSPIRACY`（阴谋论）的随机效果在 `_apply_type_bonus` 里直接用 `randf()` 判定，调用者无需额外处理
- `EXCLUSIVE`（惊天独家）的事实核查概率翻倍，在 `ReputationSystem.calculate_fact_check_probability()` 里通过检查 `article.article_type` 实现
- 「春秋笔法」的 bias 反转发生在 `material_card.reverse_bias()` 层面，所有后续计算自动使用反转后的值

---

### 4.13 `environment_system.gd` — 环境牌系统

**职责**：管理日程表生成、事件揭示、窥探、突发事件、环境修正器施加。

```gdscript
class_name EnvironmentSystem
extends Node

## 两个独立牌堆
var _scheduled_pool: Array[EnvironmentCardDef] = []
var _breaking_pool: Array[EnvironmentCardDef] = []

## 当前周期日程（索引0~4 对应周期内第1~5天）
## 每个元素：{event_def: EnvironmentCardDef, is_revealed: bool} 或 null（无事件）
var _current_schedule: Array = [null, null, null, null, null]
var _current_cycle: int = 0
var _current_day_in_cycle: int = 0  # 0~4

## 本回合已揭示的环境事件（可被引用为素材）
var _todays_revealed_events: Array[EnvironmentCardDef] = []

const BREAKING_NEWS_CHANCE := 0.3
const EVENTS_PER_CYCLE_MIN := 2
const EVENTS_PER_CYCLE_MAX := 3

func initialize(scheduled_defs: Array, breaking_defs: Array) -> void:
    _scheduled_pool = scheduled_defs.duplicate()
    _scheduled_pool.shuffle()
    _breaking_pool = breaking_defs.duplicate()
    _breaking_pool.shuffle()

## 周期第1天（全局第 1,6,11,16 回合）：生成日程表
func generate_schedule(turn_number: int) -> void:
    _current_cycle = (turn_number - 1) / 5
    _current_day_in_cycle = 0
    _current_schedule = [null, null, null, null, null]

    # 随机抽 2~3 个事件分配到 5 天
    var event_count := randi_range(EVENTS_PER_CYCLE_MIN, EVENTS_PER_CYCLE_MAX)
    var available_days := [0, 1, 2, 3, 4]
    available_days.shuffle()

    for i in event_count:
        if _scheduled_pool.is_empty():
            break
        var day_index := available_days[i]
        var event_def: EnvironmentCardDef = _scheduled_pool.pop_front()
        _current_schedule[day_index] = {event_def = event_def, is_revealed = false}

    # 公布日程（只透露 preview_name，不透露结果）
    var schedule_preview := []
    for i in 5:
        if _current_schedule[i] != null:
            schedule_preview.append({
                day_in_cycle = i,
                preview_name = _current_schedule[i].event_def.preview_name,
            })
    GameBus.schedule_announced.emit(schedule_preview)

## MARKET_OPEN 阶段调用：揭示今日事件 + 判定突发新闻
## 返回今日生效的所有 SentimentModifier 列表
func process_market_open(turn_number: int, market: MarketSystem) -> void:
    _current_day_in_cycle = (turn_number - 1) % 5
    _todays_revealed_events.clear()

    # 揭示今日日程事件
    var todays_slot = _current_schedule[_current_day_in_cycle]
    if todays_slot != null and not todays_slot.is_revealed:
        todays_slot.is_revealed = true
        var event_def: EnvironmentCardDef = todays_slot.event_def
        _todays_revealed_events.append(event_def)
        _apply_environment_event(event_def, market)
        GameBus.event_revealed.emit(event_def, turn_number)

    # 判定突发新闻
    if randf() < BREAKING_NEWS_CHANCE and not _breaking_pool.is_empty():
        var breaking: EnvironmentCardDef = _breaking_pool.pop_front()
        _todays_revealed_events.append(breaking)
        _apply_environment_event(breaking, market)
        GameBus.breaking_news_triggered.emit(breaking)

## 将环境事件转换为 SentimentModifier 施加到市场
func _apply_environment_event(event_def: EnvironmentCardDef, market: MarketSystem) -> void:
    match event_def.tier:
        Enums.EventTier.COMPANY:
            var mod := SentimentModifier.from_environment(event_def, event_def.target_stock)
            market.add_sentiment_modifier(event_def.target_stock, mod)

        Enums.EventTier.INDUSTRY:
            for stock in market.get_all_active_stocks():
                if stock.def.industry == event_def.target_industry:
                    var mod := SentimentModifier.from_environment(event_def, stock.def.id)
                    market.add_sentiment_modifier(stock.def.id, mod)

        Enums.EventTier.MACRO:
            for stock in market.get_all_active_stocks():
                var mod := SentimentModifier.from_environment(event_def, stock.def.id)
                market.add_sentiment_modifier(stock.def.id, mod)

## 窥探：花 1 人脉提前揭示未来日程事件
## 返回揭示的事件定义，失败返回 null
func scout_event(day_in_cycle: int, player: PlayerState) -> EnvironmentCardDef:
    if player.has_scouted_today or player.connections < 1:
        return null
    var slot = _current_schedule[day_in_cycle]
    if slot == null or slot.is_revealed:
        return null
    player.connections -= 1
    player.has_scouted_today = true
    slot.is_revealed = true
    GameBus.resource_changed.emit("connections", player.connections)
    GameBus.event_revealed.emit(slot.event_def, -1)  # -1 表示提前揭示
    return slot.event_def

## 获取当前回合已揭示的环境事件（用于写作引用）
func get_referenceable_events() -> Array[EnvironmentCardDef]:
    return _todays_revealed_events.filter(func(e): return e.can_be_referenced)
```

---

### 4.14 `reputation_system.gd` — 信誉与事实核查系统

```gdscript
class_name ReputationSystem
extends Node

const BASE_FACT_CHECK_PROB := 0.10
const RUMOR_FACT_CHECK_ADD := 0.15
const LOW_CREDIBILITY_PENALTY_2 := 0.20
const LOW_CREDIBILITY_PENALTY_1 := 0.40
const MAX_FACT_CHECK_PROB := 0.90

## 计算文章被打假的概率
func calculate_fact_check_probability(article: Article) -> float:
    var prob := BASE_FACT_CHECK_PROB
    var rumor_count := 0
    for card in article.material_cards:
        if card.def.type == Enums.MaterialType.RUMOR:
            rumor_count += 1
    prob += rumor_count * RUMOR_FACT_CHECK_ADD

    if article.final_credibility <= 1:
        prob += LOW_CREDIBILITY_PENALTY_1
    elif article.final_credibility <= 2:
        prob += LOW_CREDIBILITY_PENALTY_2

    # 「情感渲染」方法卡：+15%
    for mc in article.method_cards:
        prob += mc.def.effect_params.get("fact_check_prob_add", 0.0)

    # 惊天独家：概率翻倍
    if article.article_type == Enums.ArticleType.EXCLUSIVE:
        prob *= 2.0

    return minf(prob, MAX_FACT_CHECK_PROB)

## MARKET_REACT 阶段对今日发表的文章执行事实核查
## 返回被打假的文章列表
func perform_fact_checks(
    published_articles: Array[Article],
    player: PlayerState,
    market: MarketSystem
) -> Array[Article]:
    var busted: Array[Article] = []
    for article in published_articles:
        var prob := calculate_fact_check_probability(article)
        if randf() < prob:
            article.is_busted = true
            busted.append(article)
            _apply_bust_consequences(article, player, market)
            GameBus.article_fact_checked.emit(article, true)
            print("[ReputationSystem] Article busted: %s, rep now %d" % [article.article_id, player.reputation])
        else:
            GameBus.article_fact_checked.emit(article, false)
            _on_article_survived(article, player)
    return busted

## 打假后果
func _apply_bust_consequences(article: Article, player: PlayerState, market: MarketSystem) -> void:
    # 1. 移除原修正器
    market.get_stock(article.target_stock_id).remove_modifier_by_source(article.article_id)

    # 2. 施加反转修正器（value反向 × 0.5，持续 2 回合）
    var reverse_value := -roundi(article.final_impact * 0.5)
    if article.direction == Enums.Bias.BEARISH:
        reverse_value = roundi(article.final_impact * 0.5)
    var reverse_mod := SentimentModifier.new()
    reverse_mod.source_id = StringName(str(article.article_id) + "_bust")
    reverse_mod.source_type = "bust"
    reverse_mod.target_stock = article.target_stock_id
    reverse_mod.value = reverse_value
    reverse_mod.remaining_turns = 2
    market.add_sentiment_modifier(article.target_stock_id, reverse_mod)

    # 3. 信誉 -10
    _change_reputation(player, -10)

## 文章未被打假的奖励
func _on_article_survived(article: Article, player: PlayerState) -> void:
    if article.final_credibility >= 4:
        _change_reputation(player, 3)

## SETTLEMENT 阶段：信誉每回合自然恢复 +1
func tick_reputation(player: PlayerState) -> void:
    _change_reputation(player, 1)

func _change_reputation(player: PlayerState, delta: int) -> void:
    var old := player.reputation
    player.reputation = clampi(player.reputation + delta, 0, 100)
    if player.reputation != old:
        GameBus.reputation_changed.emit(player.reputation, player.reputation - old)

## 根据信誉获取文章影响力乘数
func get_impact_multiplier(reputation: int) -> float:
    if reputation >= 80: return 1.3
    if reputation >= 60: return 1.1
    if reputation >= 20: return 1.0
    return 1.0  # 低信誉：影响力不加，但可信度打折

## 根据信誉获取文章可信度乘数
func get_credibility_multiplier(reputation: int) -> float:
    if reputation < 40: return 0.8  # 20~39 争议性写手
    return 1.0

## 主流媒体是否可用
func is_mainstream_unlocked(reputation: int) -> bool:
    return reputation >= 60
```

---

### 4.15 `writing_method_system.gd` — 写作方法卡系统

```gdscript
class_name WritingMethodSystem
extends Node

var _method_pool: Array[WritingMethodDef] = []

## 稀有度出现权重
const RARITY_WEIGHTS := {
    Enums.Rarity.COMMON:   60,
    Enums.Rarity.UNCOMMON: 30,
    Enums.Rarity.RARE:     10,
}

func initialize(all_method_defs: Array[WritingMethodDef]) -> void:
    _method_pool = all_method_defs.duplicate()

## GATHER 阶段进修：抽出 3 张选项（按稀有度加权随机）
func draw_training_options() -> Array[WritingMethodDef]:
    var pool_copy := _method_pool.duplicate()
    var options: Array[WritingMethodDef] = []
    for _i in 3:
        if pool_copy.is_empty():
            break
        var pick := _weighted_random_pick(pool_copy)
        options.append(pick)
        pool_copy.erase(pick)
    return options

## 玩家选择后：创建运行时卡牌加入玩家卡库
func acquire_method(def: WritingMethodDef, player: PlayerState) -> WritingMethodCard:
    var card := WritingMethodCard.create(def)
    player.method_library.append(card)
    GameBus.writing_method_acquired.emit(card)
    return card

## SETTLEMENT 阶段：tick 所有方法卡的冷却
func tick_cooldowns(player: PlayerState) -> void:
    for card in player.method_library:
        if card.is_on_cooldown:
            card.tick_cooldown()

## 获取当前可用的方法卡（不在冷却中）
func get_available_methods(player: PlayerState) -> Array[WritingMethodCard]:
    return player.method_library.filter(func(c): return c.is_available())

func _weighted_random_pick(pool: Array) -> WritingMethodDef:
    var total_weight := 0
    for def in pool:
        total_weight += RARITY_WEIGHTS.get(def.rarity, 0)
    var roll := randi_range(0, total_weight - 1)
    var cumulative := 0
    for def in pool:
        cumulative += RARITY_WEIGHTS.get(def.rarity, 0)
        if roll < cumulative:
            return def
    return pool[-1]
```

---

### 4.16 `turn_system.gd` — 改造为 7 阶段

保留 `execute_turn()`、`insert_phase_before/after()`、`remove_phase()` 的结构，只改 `phase_sequence` 和 `_process_phase()`。

**注入依赖**（改造后 turn_system 需要持有所有系统引用）：
```gdscript
var zone_manager: CardZoneManager
var effect_resolver: EffectResolver
var market_system: MarketSystem
var article_system: ArticleSystem
var environment_system: EnvironmentSystem
var reputation_system: ReputationSystem
var writing_method_system: WritingMethodSystem
var player: PlayerState
```

**新阶段序列**：
```gdscript
var phase_sequence: Array[Enums.Phase] = [
    Enums.Phase.MARKET_OPEN,
    Enums.Phase.GATHER,
    Enums.Phase.WRITING,
    Enums.Phase.PUBLISH,
    Enums.Phase.MARKET_REACT,
    Enums.Phase.TRADE,
    Enums.Phase.SETTLEMENT,
]
```

**`_process_phase()` 新实现**：
```gdscript
func _process_phase(phase: Enums.Phase) -> void:
    match phase:
        Enums.Phase.MARKET_OPEN:
            # 周期第1天公布日程
            if (turn_number - 1) % 5 == 0:
                environment_system.generate_schedule(turn_number)
            # 揭示今日事件 + 突发新闻
            environment_system.process_market_open(turn_number, market_system)

        Enums.Phase.GATHER:
            # 自动抽3张素材卡
            zone_manager.draw_cards(3)
            GameBus.gather_phase_entered.emit()
            await GameBus.gather_phase_finished   # 等待玩家完成定向取材/窥探/进修

        Enums.Phase.WRITING:
            GameBus.writing_phase_entered.emit()
            await GameBus.writing_phase_finished  # 等待玩家完成撰写

        Enums.Phase.PUBLISH:
            GameBus.publish_phase_entered.emit()
            await GameBus.publish_phase_finished  # 等待玩家完成发表

        Enums.Phase.MARKET_REACT:
            market_system.process_market_react()
            # 对本回合发表的文章做事实核查
            var todays_articles := _get_todays_published_articles()
            reputation_system.perform_fact_checks(todays_articles, player, market_system)

        Enums.Phase.TRADE:
            GameBus.trade_phase_entered.emit()
            await GameBus.trade_phase_finished    # 等待玩家完成交易

        Enums.Phase.SETTLEMENT:
            market_system.process_settlement()
            writing_method_system.tick_cooldowns(player)
            reputation_system.tick_reputation(player)
            player.energy = player.max_energy
            player.connections += 1
            player.trade_count = 0
            player.has_trained_today = false
            player.has_scouted_today = false
            _tick_draft_freshness()
            _check_victory_condition()
```

---

## 五、关键数据流梳理

### 5.1 发表文章 → 股价变化的完整路径

```
玩家 PUBLISH 阶段 →
  ArticleSystem.compose_article() → 生成 Article 对象
  Article 选择 Channel 发表 →
  ArticleSystem 或 TurnSystem 调用:
    SentimentModifier.from_article(article) → 生成修正器
    MarketSystem.add_sentiment_modifier(stock_id, mod)

MARKET_REACT 阶段 →
  MarketSystem.process_market_react() →
    Stock.apply_price_change() →  # 情绪值 × 波动系数
    GameBus.stock_price_changed 信号

  ReputationSystem.perform_fact_checks() →
    若打假：Stock.remove_modifier_by_source() + 施加反转修正器

SETTLEMENT 阶段 →
  MarketSystem.process_settlement() →
    Stock.tick_modifiers() → 过期修正器移除
```

### 5.2 发表渠道效果的施加时机

渠道效果不是直接修改 article 的属性（避免和写作方法卡混淆），而是在**发表时**作为临时修正应用到修正器上。建议在「创建 SentimentModifier 时」根据渠道调整 value：

```gdscript
func _create_modifier_with_channel(article: Article, channel: Enums.Channel) -> SentimentModifier:
    var mod := SentimentModifier.from_article(article)
    match channel:
        Enums.Channel.SELF_MEDIA:
            mod.value = roundi(mod.value * 0.7)
        Enums.Channel.MAINSTREAM:
            mod.value = roundi(mod.value * 1.0)  # 可信度加成已在文章属性里
        Enums.Channel.ANONYMOUS:
            mod.value = roundi(mod.value * 0.5)
        Enums.Channel.PAID_PROMOTION:
            mod.value = roundi(mod.value * 1.3)
    return mod
```

### 5.3 信誉影响文章效果的时序

信誉乘数在**发表瞬间**应用，不是被动持续的：

```gdscript
# 发表时
var final_value := article.final_impact
final_value = roundi(final_value * reputation_system.get_impact_multiplier(player.reputation))
```

---

## 六、测试场景规划

测试脚本应验证以下路径（每个路径写一个函数）：

| 测试函数 | 验证内容 |
|---------|---------|
| `test_article_compose()` | 各组合类型的属性计算是否正确 |
| `test_synergy_contradiction()` | 协同/冲突机制是否生效 |
| `test_sentiment_stack()` | 多修正器叠加 → 情绪夹到 -10~+10 |
| `test_price_velocity()` | 情绪=0时股价定格，不回弹 |
| `test_fact_check()` | 打假：修正器反转 + 信誉扣分 |
| `test_schedule_generation()` | 周期日程生成，事件分配正确 |
| `test_scout_event()` | 消耗人脉窥探事件 |
| `test_delisting()` | 股价低于退市线时触发退市 |
| `test_full_turn()` | 7 阶段完整走一遍，信号全部触发 |
| `test_reputation_tiers()` | 不同信誉区间影响文章效果 |

---

## 七、暂不实现的部分（v1 范围外）

- UI 层（所有 UI 相关）
- 「病毒传播」等影响全行业的写作方法卡（需要在发表时对所有股票施加修正器）
- 「连续剧」方法卡（需要 TurnSystem 记录上回合对哪只股票发过文章）
- 「危机公关」方法卡（移除己方修正器并反转，逻辑复杂）
- 环境事件引用为素材的完整流程（临时数据卡需要特殊处理）
- 预测对应现实的信誉奖励（+5）
- 黑色幽默特殊事件（反讽事件牌）
- 发表渠道冷却追踪（打假后渠道封禁1回合）

这些功能的数据结构已经在上方设计中预留了钩子（`effect_params` 字段），可以后续迭代增加。
