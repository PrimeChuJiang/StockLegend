## 信号总线 v4：竞选大师
extends Node

## 回合
signal turn_started(turn: int)
signal turn_ended(turn: int)

## 广告投放
signal ad_placed(player_id: StringName, ad_type: Enums.AdType, district_idx: int)

## 事实核查
signal fact_checked(player_id: StringName, district_idx: int, countered: bool)

## 游戏结束
signal game_ended(winner_id: StringName)
