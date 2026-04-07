## 信号总线 v5：竞选大师
## AutoLoad 单例（名称 GameBus），用于解耦各系统之间的通信。
## 所有游戏事件通过这里广播，UI / 音效 / 统计等系统各自监听所需信号。
extends Node

## ─── 回合信号 ───
signal turn_started(turn: int)   ## 回合开始时触发（turn = 当前回合数，从1开始）
signal turn_ended(turn: int)     ## 回合结算完成后触发

## ─── 行动信号 ───
signal article_published(player_id: int, result: Dictionary)
## 发表文章（涂地操作）完成后触发
## result 包含：cells_affected, cells_flipped, total_power, cards_used

## ─── 游戏结束信号 ───
signal game_ended(winner_id: int)
## winner_id: 0=平局(NEUTRAL), 1=甲方(PLAYER_A), 2=乙方(PLAYER_B)
