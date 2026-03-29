## 竞选大师 v4 playtest — AI 自动对战
## 纯控制台输出，通过 Output 面板观察游戏流程。
extends Node

const MAX_TURNS := 6
const PLAYER_A := &"player_a"
const PLAYER_B := &"player_b"

var players: Array[PlayerState] = []


# ═══════════════════════════════════════════
#  启动
# ═══════════════════════════════════════════

func _ready() -> void:
	print("╔══════════════════════════════════════════╗")
	print("║     竞选大师 v4 — Playtest               ║")
	print("╚══════════════════════════════════════════╝")

	_setup()
	await get_tree().process_frame
	_run_game()


# ═══════════════════════════════════════════
#  初始化
# ═══════════════════════════════════════════

func _setup() -> void:
	# 选区
	ElectionManager.setup()
	print("[Setup] 选区初始化完成:")
	for i in ElectionManager.districts.size():
		var d: Dictionary = ElectionManager.districts[i]
		print("  %s — %d选民, %d票, 议题:%s" % [d["name"], d["voters"].size(), d["ticket_value"], Enums.topic_name(d["topic"])])

	# 牌堆
	_setup_deck()

	# 玩家
	players.clear()
	players.append(PlayerState.new(PLAYER_A, "甲方候选人"))
	players.append(PlayerState.new(PLAYER_B, "乙方候选人"))
	print("[Setup] 玩家: %s vs %s" % [players[0].player_name, players[1].player_name])


func _setup_deck() -> void:
	var pool: Array[MaterialCardDef] = []
	var types := [Enums.MaterialType.RECORD, Enums.MaterialType.PROMISE,
				  Enums.MaterialType.DIRT, Enums.MaterialType.EMOTION]
	var topics := [Enums.Topic.JOBS, Enums.Topic.TECH,
				   Enums.Topic.AGRICULTURE, Enums.Topic.ECONOMY,
				   Enums.Topic.EDUCATION]
	# 每种素材 10 张：5★ + 3★★ + 2★★★
	var qualities := [1, 1, 1, 1, 1, 2, 2, 2, 3, 3]

	for t_idx in types.size():
		for i in 10:
			var card := MaterialCardDef.new()
			var mt: Enums.MaterialType = types[t_idx]
			var tp: Enums.Topic = topics[i % 5]
			var q: int = qualities[i]
			card.card_id = StringName("%s_%d" % [Enums.material_name(mt), i])
			card.material_type = mt
			card.quality = q
			card.topic = tp
			card.card_name = card.brief()
			pool.append(card)

	CardSystem.setup_deck(pool)
	print("[Setup] 牌堆: %d 张" % CardSystem.get_deck_size())


# ═══════════════════════════════════════════
#  游戏循环
# ═══════════════════════════════════════════

func _run_game() -> void:
	for turn in range(1, MAX_TURNS + 1):
		print("\n" + "=".repeat(50))
		print("===== 第 %d / %d 回合 =====" % [turn, MAX_TURNS])
		print("=".repeat(50))
		GameBus.turn_started.emit(turn)

		# 抽牌阶段
		_draw_phase(turn)

		# 行动阶段（先后手交替）
		var first := 0 if turn % 2 == 1 else 1
		var second := 1 - first
		_action_phase(players[first], turn)
		_action_phase(players[second], turn)

		# 结算阶段
		_settlement_phase(turn)

		# 状态总览
		_print_board(turn)

		GameBus.turn_ended.emit(turn)

	# 选举日
	_election_day()


func _draw_phase(turn: int) -> void:
	print("\n--- 抽牌阶段 ---")
	for p in players:
		var draw_count := ElectionManager.get_draw_count(p.player_id)
		var drawn := CardSystem.draw_for_player(p, draw_count)
		var cards_str := ", ".join(drawn.map(func(c: MaterialCardDef): return c.brief()))
		print("[%s] 声势Lv→抽%d张: %s (手牌:%d)" % [p.player_name, draw_count, cards_str, p.hand.size()])


func _action_phase(p: PlayerState, turn: int) -> void:
	p.reset_turn()
	print("\n--- %s 行动阶段 (AP:%d) ---" % [p.player_name, p.action_points])

	while p.can_spend_ap(1) and p.hand.size() >= 1:
		# AI 决策：有 2 张牌就投广告，只有 1 张就打假
		if p.hand.size() >= 2:
			_ai_place_ad(p, turn)
		elif not _ai_fact_check(p):
			break  # 打假无目标，结束行动

	if p.action_points > 0:
		print("[%s] 手牌不足，剩余 %d AP 未用" % [p.player_name, p.action_points])


func _settlement_phase(turn: int) -> void:
	print("\n--- 结算阶段 ---")
	# 忠诚度衰减
	var lost := 0
	for d in ElectionManager.districts:
		for v: ElectionManager.Voter in d["voters"]:
			if not v.is_neutral() and v.loyalty == 1:
				lost += 1
	ElectionManager.tick_loyalty()
	print("[结算] 忠诚度全体-1，%d个选民变中立" % lost)

	# 弃牌
	for p in players:
		var discarded := p.discard_to_limit()
		if discarded.size() > 0:
			CardSystem.discard(discarded)
			print("[结算] %s 弃掉 %d 张超出上限" % [p.player_name, discarded.size()])

	# 清除本回合数据
	ElectionManager.clear_turn_data()


# ═══════════════════════════════════════════
#  AI 逻辑
# ═══════════════════════════════════════════

func _ai_place_ad(p: PlayerState, turn: int) -> void:
	# 选目标选区：评分 = ticket_value × 需求度
	var best_district := _ai_pick_district(p)
	# 选两张牌：优先议题匹配 + 高品质
	var pair := _ai_pick_card_pair(p, best_district)
	if pair.size() < 2:
		return

	p.spend_ap(1)
	var card_a: MaterialCardDef = p.hand[pair[0]]
	var card_b: MaterialCardDef = p.hand[pair[1]]
	var result := ElectionManager.place_ad(p.player_id, card_a, card_b, best_district)

	# 移除手牌并弃牌
	var removed := p.remove_cards(pair)
	CardSystem.discard(removed)

	var district_name: String = ElectionManager.districts[best_district]["name"]
	print("[%s] 投广告→%s: %s+%s = %s (强度%d, 议题×%.1f, 拉票%d, 攻击%d) → 拉到%d人,侵蚀%d人,打击%d人,击溃%d人" % [
		p.player_name, district_name, card_a.brief(), card_b.brief(),
		result["ad_name"], result["strength"], result["topic_mult"],
		result["rally_power"], result["attack_power"],
		result["rally_claimed"], result["rally_eroded"],
		result["attack_hit"], result["attack_neutralized"],
	])


func _ai_fact_check(p: PlayerState) -> bool:
	# 找对手控制最多选民的选区
	var opponent_id := PLAYER_B if p.player_id == PLAYER_A else PLAYER_A
	var best_idx := 0
	var best_count := 0
	for i in ElectionManager.districts.size():
		var info := ElectionManager.get_district_info(i)
		var c: int = info["counts"].get(opponent_id, 0)
		if c > best_count:
			best_count = c
			best_idx = i

	if best_count == 0 or p.hand.is_empty():
		return false

	p.spend_ap(1)
	var card_idx := _pick_best_fact_check_card(p)
	var card: MaterialCardDef = p.hand[card_idx]
	var cards: Array[MaterialCardDef] = [card]
	var result := ElectionManager.fact_check(p.player_id, cards, best_idx)
	var removed := p.remove_cards([card_idx] as Array[int])
	CardSystem.discard(removed)

	var district_name: String = ElectionManager.districts[best_idx]["name"]
	var counter_str := "【打假空头支票！】" if result["countered"] else ""
	print("[%s] 事实核查→%s: %s (影响力%d) %s → 打击%d人,击溃%d人" % [
		p.player_name, district_name, card.brief(), result["influence"],
		counter_str, result["attack_hit"], result["attack_neutralized"],
	])
	return true


## AI 选择目标选区
func _ai_pick_district(p: PlayerState) -> int:
	var opponent_id := PLAYER_B if p.player_id == PLAYER_A else PLAYER_A
	var best_idx := 0
	var best_score := -999.0

	for i in ElectionManager.districts.size():
		var d: Dictionary = ElectionManager.districts[i]
		var info := ElectionManager.get_district_info(i)
		var my_count: int = info["counts"].get(p.player_id, 0)
		var opp_count: int = info["counts"].get(opponent_id, 0)
		var neutral: int = info["neutral"]
		var total: int = d["voters"].size()
		var tickets: int = d["ticket_value"]

		# 评分：票值高 + 有中立选民可争 + 接近翻转
		var need_for_majority: int = (total / 2 + 1) - my_count
		var score: float = tickets * 2.0
		if need_for_majority <= neutral:
			score += 5.0  # 能通过拉中立选民赢
		if opp_count > 0 and my_count >= opp_count:
			score += 3.0  # 可以巩固领先
		if neutral > 0:
			score += neutral * 1.0
		# 加点随机性
		score += randf() * 2.0

		if score > best_score:
			best_score = score
			best_idx = i

	return best_idx


## AI 选择两张手牌
func _ai_pick_card_pair(p: PlayerState, district_idx: int) -> Array[int]:
	if p.hand.size() < 2:
		return []

	var district_topic: Enums.Topic = ElectionManager.districts[district_idx]["topic"]
	var best_pair: Array[int] = [0, 1]
	var best_score := -1.0

	# 尝试所有组合，选分数最高的
	for i in p.hand.size():
		for j in range(i + 1, p.hand.size()):
			var ca: MaterialCardDef = p.hand[i]
			var cb: MaterialCardDef = p.hand[j]
			var strength := ca.quality + cb.quality
			var coeffs := ElectionManager.get_ad_coefficients(
				ElectionManager.get_ad_type(ca.material_type, cb.material_type))
			var topic_mult := ElectionManager.get_topic_multiplier(ca, cb, district_topic)
			var total_effect: float = (strength * float(coeffs[0]) + strength * float(coeffs[1])) * topic_mult
			if total_effect > best_score:
				best_score = total_effect
				best_pair = [i, j]

	return best_pair


## 选最适合打假的牌（政绩/黑料优先，品质高优先）
func _pick_best_fact_check_card(p: PlayerState) -> int:
	var best_idx := 0
	var best_score := 0.0
	for i in p.hand.size():
		var card: MaterialCardDef = p.hand[i]
		var score := float(card.quality)
		if card.material_type == Enums.MaterialType.RECORD or card.material_type == Enums.MaterialType.DIRT:
			score *= 1.5
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx


# ═══════════════════════════════════════════
#  状态显示
# ═══════════════════════════════════════════

func _print_board(turn: int) -> void:
	print("\n┌─── 第 %d 回合结束 · 选情总览 ──────────────┐" % turn)
	for i in ElectionManager.districts.size():
		var d: Dictionary = ElectionManager.districts[i]
		var info := ElectionManager.get_district_info(i)
		var a_count: int = info["counts"].get(PLAYER_A, 0)
		var b_count: int = info["counts"].get(PLAYER_B, 0)
		var neutral: int = info["neutral"]
		var a_loy: int = info["loyalty"].get(PLAYER_A, 0)
		var b_loy: int = info["loyalty"].get(PLAYER_B, 0)
		var total: int = d["voters"].size()

		var leader := "平" if a_count == b_count else ("甲领先" if a_count > b_count else "乙领先")
		print("│ %s(%d票): 甲%d(忠%d) 乙%d(忠%d) 中立%d/%d [%s]" % [
			d["name"], d["ticket_value"],
			a_count, a_loy, b_count, b_loy, neutral, total, leader])

	# 总选民
	var a_total := ElectionManager.get_voter_count(PLAYER_A)
	var b_total := ElectionManager.get_voter_count(PLAYER_B)
	print("├──────────────────────────────────────────┤")
	print("│ 选民: 甲%d vs 乙%d  手牌: 甲%d 乙%d" % [
		a_total, b_total, players[0].hand.size(), players[1].hand.size()])
	print("│ 声势: 甲Lv%d(抽%d) 乙Lv%d(抽%d)" % [
		_momentum_level(a_total), ElectionManager.get_draw_count(PLAYER_A),
		_momentum_level(b_total), ElectionManager.get_draw_count(PLAYER_B)])
	print("│ 牌堆: %d  弃牌堆: %d" % [CardSystem.get_deck_size(), CardSystem.get_discard_size()])
	print("└──────────────────────────────────────────┘")


func _momentum_level(voter_count: int) -> int:
	if voter_count >= 18: return 5
	if voter_count >= 13: return 4
	if voter_count >= 8:  return 3
	if voter_count >= 4:  return 2
	return 1


func _election_day() -> void:
	print("\n")
	print("╔══════════════════════════════════════════╗")
	print("║         选举日 · 最终计票                 ║")
	print("╚══════════════════════════════════════════╝")

	var results := ElectionManager.count_votes()
	var a_tickets: int = results["player_tickets"].get(PLAYER_A, 0)
	var b_tickets: int = results["player_tickets"].get(PLAYER_B, 0)

	print("")
	for dr: Dictionary in results["district_results"]:
		var info: Dictionary = dr["info"]
		var a_count: int = info["counts"].get(PLAYER_A, 0)
		var b_count: int = info["counts"].get(PLAYER_B, 0)
		var winner_name := "平局" if dr["winner"] == &"" else (
			"甲方候选人" if dr["winner"] == PLAYER_A else "乙方候选人")
		print("  %s: 甲%d vs 乙%d → %s 获得 %d 票" % [
			dr["name"], a_count, b_count, winner_name, dr["tickets"]])

	print("")
	print("  总计: 甲方 %d 票 vs 乙方 %d 票（需 9 票获胜）" % [a_tickets, b_tickets])
	print("")

	if a_tickets > b_tickets:
		print("  ★ 甲方候选人 获胜！")
		GameBus.game_ended.emit(PLAYER_A)
	elif b_tickets > a_tickets:
		print("  ★ 乙方候选人 获胜！")
		GameBus.game_ended.emit(PLAYER_B)
	else:
		# 平票 → 比控制选民数
		var a_voters := ElectionManager.get_voter_count(PLAYER_A)
		var b_voters := ElectionManager.get_voter_count(PLAYER_B)
		if a_voters > b_voters:
			print("  ★ 票数平局！甲方以选民数 %d > %d 获胜！" % [a_voters, b_voters])
			GameBus.game_ended.emit(PLAYER_A)
		elif b_voters > a_voters:
			print("  ★ 票数平局！乙方以选民数 %d > %d 获胜！" % [b_voters, a_voters])
			GameBus.game_ended.emit(PLAYER_B)
		else:
			print("  ★ 完全平局！")
			GameBus.game_ended.emit(&"")
