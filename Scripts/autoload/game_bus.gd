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
signal event_revealed(event_def: EnviromentCardData)
signal breaking_event_triggered(event_def: EnviromentCardData)