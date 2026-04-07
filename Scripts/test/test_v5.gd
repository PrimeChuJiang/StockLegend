## 测试脚本 v5：竞选大师涂地版
## 无需 UI，两个 AI 自动对战，所有结果输出到控制台（Output 面板）。
## 用途：快速验证核心机制（叠放、重叠、威力计算、格子结算）是否正常工作。
## 运行方式：在 Godot 编辑器中运行 Scenes/test_v5.tscn
extends Node

const MAX_TURNS := 10    ## 总回合数
const FIRST_DRAW := 5    ## 首回合抽牌数
const TURN_DRAW := 2     ## 之后每回合抽牌数
const GRID_W := 10       ## 棋盘宽
const GRID_H := 10       ## 棋盘高

var _player_a: PlayerState   ## 甲方（AI）
var _player_b: PlayerState   ## 乙方（AI）

## 形状模板列表（11种，从2格到5格）
var _shape_templates: Array[CardShape] = []


func _ready() -> void:
	print("=" .repeat(60))
	print("  竞选大师 v5 — 涂地 Playtest Demo")
	print("=" .repeat(60))
	_setup()
	_run_game()


# ─── 初始化 ───

func _setup() -> void:
	BoardManager.setup()
	_create_shape_templates()
	_setup_deck()

	_player_a = PlayerState.new(Enums.CellOwner.PLAYER_A, "甲方")
	_player_b = PlayerState.new(Enums.CellOwner.PLAYER_B, "乙方")

	print("\n棋盘：%d×%d = %d 格" % [GRID_W, GRID_H, GRID_W * GRID_H])
	print("回合数：%d | 行动点：%d | 手牌上限：%d" % [MAX_TURNS, _player_a.max_action_points, _player_a.hand_limit])
	print("牌堆：%d 张\n" % CardSystem.get_deck_size())


## 创建11种形状模板（俄罗斯方块风格）
## 形状图示见 GDD 8.卡牌设计
func _create_shape_templates() -> void:
	_shape_templates = [
		# ── 小型（2格）──
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0)]),                                           # 横线2: ■■
		CardShape.create([Vector2i(0, 0), Vector2i(0, 1)]),                                           # 竖线2: ■
		                                                                                               #        ■
		# ── 中型（3格）──
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]),                           # 横线3: ■■■
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]),                           # 角落:  ■■
		                                                                                               #        ■
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]),                           # 小L:   ■■
		                                                                                               #         ■
		# ── 大型（4格）──
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]),           # 横线4: ■■■■
		CardShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]),           # L形
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]),           # T形
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]),           # 田字: ■■
		                                                                                               #       ■■
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]),           # Z形

		# ── 特大（5格）──
		CardShape.create([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]),  # 十字: +
	]


## 构建牌堆：每种形状按指定数量生成卡牌定义
func _setup_deck() -> void:
	var pool: Array[CardDef] = []
	var shape_names: Array[String] = [
		"横线2", "竖线2",                          # 小型 ×3
		"横线3", "角落", "小L",                    # 中型 ×5/4/4
		"横线4", "L形", "T形", "田字", "Z形",     # 大型 ×3
		"十字",                                     # 特大 ×2
	]

	## 每种形状在牌堆中的张数（共36张）
	var counts: Array[int] = [
		3, 3,           # 小型：各3张
		5, 4, 4,        # 中型：横线3多给1张
		3, 3, 3, 3, 3,  # 大型：各3张
		2,              # 特大：仅2张（稀有）
	]

	var card_idx := 0
	for i in _shape_templates.size():
		var count: int = counts[i]
		for j in count:
			var card_id: StringName = &"card_%d" % card_idx
			var cname: String = shape_names[i]
			var card := CardDef.create(card_id, cname, _shape_templates[i])
			pool.append(card)
			card_idx += 1

	CardSystem.setup_deck(pool)


# ─── 游戏循环 ───

func _run_game() -> void:
	for turn in range(1, MAX_TURNS + 1):
		print("\n" + "─" .repeat(60))
		print("  第 %d / %d 回合" % [turn, MAX_TURNS])
		print("─" .repeat(60))

		GameBus.turn_started.emit(turn)
		_draw_phase(turn)
		_action_phase(_player_a)
		_action_phase(_player_b)
		_settlement_phase()
		_print_board(turn)
		GameBus.turn_ended.emit(turn)

	_final_scoring()


func _draw_phase(turn: int) -> void:
	var draw_count := FIRST_DRAW if turn == 1 else TURN_DRAW

	var drawn_a := CardSystem.draw_for_player(_player_a, draw_count)
	var drawn_b := CardSystem.draw_for_player(_player_b, draw_count)

	print("\n[抽牌] %s 抽 %d 张（手牌 %d）| %s 抽 %d 张（手牌 %d）" % [
		_player_a.player_name, drawn_a.size(), _player_a.hand.size(),
		_player_b.player_name, drawn_b.size(), _player_b.hand.size(),
	])


func _action_phase(player: PlayerState) -> void:
	player.reset_turn()
	print("\n[%s 行动阶段] %d 行动点 | 手牌 %d 张" % [
		player.player_name, player.action_points, player.hand.size(),
	])

	while player.can_spend_ap(1) and player.hand.size() >= 2:
		_ai_publish_article(player)

	if player.action_points > 0:
		print("  剩余 %d 行动点（手牌不足，结束行动）" % player.action_points)


func _settlement_phase() -> void:
	var discard_a := _player_a.discard_to_limit()
	var discard_b := _player_b.discard_to_limit()
	if discard_a.size() > 0:
		CardSystem.discard(discard_a)
	if discard_b.size() > 0:
		CardSystem.discard(discard_b)

	if discard_a.size() > 0 or discard_b.size() > 0:
		print("\n[结算] %s 弃 %d 张 | %s 弃 %d 张" % [
			_player_a.player_name, discard_a.size(),
			_player_b.player_name, discard_b.size(),
		])


# ─── AI 逻辑（与 game_ui 中的 AI 逻辑基本一致，纯控制台版）───

## AI 发表一篇文章：随机选牌 → 随机叠放 → 试20个位置 → 选最佳执行
func _ai_publish_article(player: PlayerState) -> void:
	# 1/3 概率选3张，否则选2张
	var card_count := 2
	if player.hand.size() >= 3 and randi() % 3 == 0:
		card_count = 3

	# 随机选牌（打乱后取前N个）
	var indices: Array[int] = []
	var available := range(player.hand.size())
	available.shuffle()
	for i in card_count:
		indices.append(available[i])

	# 为每张牌随机旋转
	var placements: Array[ShapeResolver.CardPlacement] = []
	for idx in indices:
		var card: CardDef = player.hand[idx]
		var rot := randi() % 4
		placements.append(ShapeResolver.CardPlacement.new(card, rot))

	# 设置叠放偏移（第一张在原点，后续随机偏移）
	_ai_arrange_placements(placements)

	# 计算重叠和威力
	var overlap := ShapeResolver.compute_overlap(placements)
	var power_map := ShapeResolver.compute_power_map(overlap)

	if power_map.is_empty():
		print("  %s：无有效重叠，跳过" % player.player_name)
		player.action_points = 0
		return

	# 随机试20个棋盘位置，选评分最高的
	var best_pos := Vector2i.ZERO
	var best_score := -999.0

	for _attempt in 20:
		var test_pos := Vector2i(randi() % GRID_W, randi() % GRID_H)

		if not ShapeResolver.validate_bounds(power_map, test_pos, GRID_W, GRID_H):
			continue

		var score := _ai_score_placement(power_map, test_pos, player.player_id)
		if score > best_score:
			best_score = score
			best_pos = test_pos

	if best_score <= 0:
		print("  %s：找不到好位置，跳过" % player.player_name)
		player.action_points = 0
		return

	# 执行涂地
	player.spend_ap(1)
	var result := ShapeResolver.resolve_article(placements, best_pos, BoardManager, player.player_id)

	# 从手牌移除使用的卡牌，放入弃牌堆
	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	var used_cards: Array[CardDef] = []
	for idx in sorted_indices:
		used_cards.append(player.hand[idx])
		player.hand.remove_at(idx)
	CardSystem.discard(used_cards)

	# 输出日志
	var card_names_str := ""
	for p: ShapeResolver.CardPlacement in placements:
		if card_names_str != "":
			card_names_str += " + "
		card_names_str += p.card_def.card_name
	print("  发表文章：%s → 位置(%d,%d) | 生效 %d 格，翻色 %d 格，总威力 %d | AP %d/%d" % [
		card_names_str, best_pos.x, best_pos.y,
		result["cells_affected"], result["cells_flipped"], result["total_power"],
		player.action_points, player.max_action_points,
	])

	GameBus.article_published.emit(player.player_id, result)


## 设置叠放偏移：第一张固定在原点，后续卡牌随机偏移 -1~1 格
func _ai_arrange_placements(placements: Array[ShapeResolver.CardPlacement]) -> void:
	if placements.is_empty():
		return

	placements[0].offset = Vector2i.ZERO

	for i in range(1, placements.size()):
		var ox := randi_range(-1, 1)
		var oy := randi_range(-1, 1)
		placements[i].offset = Vector2i(ox, oy)


## AI 评分函数：评估在 grid_pos 位置放置 power_map 的收益
## 权重：翻敌方(×3) > 占中立(×2) > 削敌方(×1) > 加固己方(×0.5)
func _ai_score_placement(power_map: Dictionary, grid_pos: Vector2i, player_id: int) -> float:
	var score := 0.0
	for pos: Vector2i in power_map:
		var board_pos := pos + grid_pos
		if not BoardManager.is_in_bounds(board_pos.x, board_pos.y):
			return -999.0

		var power: int = power_map[pos]
		var cell_owner := BoardManager.get_cell_owner(board_pos.x, board_pos.y)
		var loyalty := BoardManager.get_loyalty(board_pos.x, board_pos.y)

		if cell_owner == Enums.CellOwner.NEUTRAL:
			score += power * 2.0       # 占中立格
		elif cell_owner == player_id:
			score += power * 0.5       # 加固己方（收益低）
		else:
			if loyalty <= power:
				score += power * 3.0   # 能翻色的敌方格（最高收益）
			else:
				score += power * 1.0   # 削弱但翻不了
	return score


# ─── 显示 ───

func _print_board(turn: int) -> void:
	var counts := BoardManager.count_cells()
	print("\n[第 %d 回合结束] %s: %d格 | %s: %d格 | 中立: %d格" % [
		turn,
		_player_a.player_name, counts[Enums.CellOwner.PLAYER_A],
		_player_b.player_name, counts[Enums.CellOwner.PLAYER_B],
		counts[Enums.CellOwner.NEUTRAL],
	])
	print(BoardManager.get_board_string())


func _final_scoring() -> void:
	print("\n" + "=" .repeat(60))
	print("  选举日 — 最终计票")
	print("=" .repeat(60))

	var counts := BoardManager.count_cells()
	var a_cells: int = counts[Enums.CellOwner.PLAYER_A]
	var b_cells: int = counts[Enums.CellOwner.PLAYER_B]

	print(BoardManager.get_board_string())
	print("\n%s: %d 格 | %s: %d 格" % [
		_player_a.player_name, a_cells,
		_player_b.player_name, b_cells,
	])

	var winner_id: int
	if a_cells > b_cells:
		winner_id = Enums.CellOwner.PLAYER_A
		print("\n%s 获胜！" % _player_a.player_name)
	elif b_cells > a_cells:
		winner_id = Enums.CellOwner.PLAYER_B
		print("\n%s 获胜！" % _player_b.player_name)
	else:
		winner_id = Enums.CellOwner.NEUTRAL
		print("\n平局！")

	GameBus.game_ended.emit(winner_id)
