## 全局枚举定义，所有系统共享的常量集合。
class_name Enums

## 卡牌类型：普通卡牌 / 瞬发卡牌 / 场地卡牌
enum CardType { NORMAL, INSTANT, FIELD }
## 回合阶段：回合开始 / 抽牌 / 主阶段 / 回合结束 / 清理
enum Phase { TURN_START, DRAW, MAIN, TURN_END, CLEANUP }
## 属性键：攻击力 / 防御力 / 费用 / 生命值
enum StatKey { ATTACK, DEFENSE, COST, HP }
## 修改器运算方式：加法 / 乘法 / 直接设置
enum ModifierOp { ADD, MULTIPLY, SET }
## 目标类型：无目标 / 自身 / 单个敌人 / 全体敌人 / 单个友军 / 全体友军
enum TargetType { NONE, SELF, SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES }
## 效果触发时机：打出时 / 回合结束时 / 进入场地时 / 离开场地时 / 弃牌时
enum EffectTrigger { ON_PLAY, ON_TURN_END, ON_FIELD_ENTER, ON_FIELD_EXIT, ON_DISCARD }
## 卡牌区域：牌库 / 手牌 / 场地 / 弃牌堆 / 除外区
enum Zone { DECK, HAND, FIELD, DISCARD, EXHAUST }
