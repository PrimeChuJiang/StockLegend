## 信号总线 v5：竞选大师
extends Node

## 回合
signal turn_started(turn: int)
signal turn_ended(turn: int)

## 发表文章（涂地操作）
signal article_published(player_id: int, result: Dictionary)

## 游戏结束
signal game_ended(winner_id: int)  ## 0=平局, 1=甲方, 2=乙方
