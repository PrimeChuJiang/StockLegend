## 全局枚举定义，所有系统共享的常量集合。
class_name Enums

## 卡牌类型：普通卡牌 / 瞬发卡牌 / 场地卡牌
enum CardType { NORMAL, INSTANT, FIELD }
## 回合阶段：开市阶段 / 收集阶段 / 写作阶段 / 发表阶段 / 市场反应阶段 / 交易阶段 / 结算阶段
enum Phase { MARKET_OPEN, GATHER, WRITING, PUBLISH, MARKET_REACT, TRADE, SETTLEMENT }
## 属性键：攻击力 / 防御力 / 费用 / 生命值
enum StatKey { ATTACK, DEFENSE, COST, HP }
## 目标类型：无目标 / 自身 / 单个敌人 / 全体敌人 / 单个友军 / 全体友军
enum TargetType { NONE, SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES }
## 效果触发时机：打出时 / 回合结束时 / 进入场地时 / 离开场地时 / 弃牌时
enum EffectTrigger { ON_PLAY, ON_TURN_END, ON_FIELD_ENTER, ON_FIELD_EXIT, ON_DISCARD }

## 倾向：看涨 / 看跌 / 中性
enum Bias { BULLISH, BERISH, NEUTRAL }
## 环境牌影响层级：宏观 / 产业 / 公司
enum EventTier { MACRO, INDUSTRY, COMPANY } 
## 环境牌来源类型：计划表内事件 / 突发事件
enum EventSourceType { SCHEDULED, BREAKING }
## 发表渠道：自媒体 / 主流媒体 / 匿名论坛 / 付费推广
enum Channel { SELF_MEDIA, MAINSTREAM, ANONYMOUS, PAID_PROMOTION }
## 股票波动类型：低波动 / 中波动 / 高波动
enum Volatility { LOW, MEDIUM, HIGH}
## 写作方法稀有度：普通 / 稀有 / 罕见
enum Rarity { COMMON, UNCOMMON, RARE }
## 修改器运算方式：加法 / 乘法 / 直接设置
enum ModifierOp { ADD, MULTIPLY, SET }
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