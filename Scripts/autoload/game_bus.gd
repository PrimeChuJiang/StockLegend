extends Node

## 多人游戏信号
signal player_connected(player_node: PlayerNode)
signal player_disconnected(player_node: PlayerNode)
signal server_created()

## 回合信号
signal turn_started(turn: int)
signal turn_ended(turn: int)

## 行动者信号：每个行动者（世界/玩家/AI）开始或结束其回合时触发
signal actor_turn_started(actor_type: Enums.ActorType)
signal actor_turn_ended(actor_type: Enums.ActorType)

## 世界阶段信号
## WorldStartActor 内部各阶段的开始与结束
signal world_start_phase_started(phase: Enums.WorldPhase)
signal world_start_phase_ended(phase: Enums.WorldPhase)
## WorldEndActor 内部各阶段的开始与结束（预留）
signal world_end_phase_started(phase: Enums.WorldPhase)
signal world_end_phase_ended(phase: Enums.WorldPhase)

## 玩家行动信号
signal player_turn_started(player_id: StringName)
signal player_turn_ended(player_id: StringName)
signal player_ended_turn(player_id: StringName)
signal action_points_changed(player_id: StringName, new_val: int, max_val: int)
signal assets_changed(player_id: StringName)

## 文章信号
signal article_composed(player_id: StringName, article: Article)
signal article_published(player_id: StringName, article: Article, channel: Enums.Channel)
signal article_busted(article: Article)
signal article_expired(article: Article)

## 市场信号
signal stock_price_changed(stock_id: StringName, old_price: float, new_price: float)
signal stock_delisted(stock_id: StringName)
signal sentiment_modifier_applied(stock_id: StringName, mod: SentimentModifier)
signal price_modifier_applied(stock_id: StringName, mod: PriceModifier)

## 玩家信号
signal player_trade(player_id: StringName, stock_id: StringName, quantity: int, is_buy: bool)
signal reputation_changed(player_id: StringName, old_val: int, new_val: int)

## 环境事件信号
## 携带 ScheduleEventConfig，UI 层可读取 preview_name/reveal_name 以及 event_cards
signal event_revealed(event_config: ScheduleEventConfig)
signal breaking_event_triggered(event_config: ScheduleEventConfig)
signal events_showed(start_turn: int, end_turn: int, events: Array[ScheduleEventConfig])

