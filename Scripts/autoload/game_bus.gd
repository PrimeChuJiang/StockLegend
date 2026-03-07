extends Node

## 回合信号
signal turn_started(turn: int)
signal turn_ended(turn: int)

## 行动者信号：每个行动者（世界/玩家/AI）开始或结束其回合时触发
signal actor_turn_started(actor_type: Enums.ActorType)
signal actor_turn_ended(actor_type: Enums.ActorType)

## 世界阶段信号：WorldActor 内部各阶段的开始与结束
signal world_phase_started(phase: Enums.WorldPhase)
signal world_phase_ended(phase: Enums.WorldPhase)

## 玩家行动信号
## UI 层在玩家点击"结束回合"按钮时发出此信号，PlayerActor 等待它
signal player_ended_turn
## 行动值发生变化时广播（当前值, 上限值）
signal action_points_changed(new_val: int, max_val: int)

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

## 修改器信号
signal modifier_added(card: CardItem, mod: Modifier)
signal modifier_removed(card: CardItem, mod: Modifier)

## 环境信号
signal event_revealed(event_def: EnviromentCardData)
signal breaking_event_triggered(event_def: EnviromentCardData)
