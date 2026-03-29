## 选举管理器：管理选区、选民、广告合成与结算。
## 作为 AutoLoad 单例运行。
extends Node


## ─── 选民内部类 ───

class Voter:
	var owner_id: StringName = &""
	var loyalty: int = 0

	func is_neutral() -> bool:
		return owner_id == &""


## ─── 数据 ───

## 选区列表，每项: {name, ticket_value, topic, voters: Array}
var districts: Array[Dictionary] = []

## 本回合的空头支票记录 [{player_id, district_idx}]
var _turn_empty_checks: Array[Dictionary] = []


# ═══════════════════════════════════════════
#  初始化
# ═══════════════════════════════════════════

func setup() -> void:
	districts.clear()
	_turn_empty_checks.clear()
	_add_district("铁锈镇", 3, Enums.Topic.JOBS, 5)
	_add_district("硅谷湾", 4, Enums.Topic.TECH, 4)
	_add_district("农心县", 2, Enums.Topic.AGRICULTURE, 6)
	_add_district("华尔街", 5, Enums.Topic.ECONOMY, 3)
	_add_district("大学城", 3, Enums.Topic.EDUCATION, 7)


func _add_district(p_name: String, tickets: int, topic: Enums.Topic, voter_count: int) -> void:
	var voters: Array = []
	for i in voter_count:
		voters.append(Voter.new())
	districts.append({
		"name": p_name,
		"ticket_value": tickets,
		"topic": topic,
		"voters": voters,
	})


# ═══════════════════════════════════════════
#  广告合成
# ═══════════════════════════════════════════

## 根据两张素材类型确定广告类型
static func get_ad_type(type_a: Enums.MaterialType, type_b: Enums.MaterialType) -> Enums.AdType:
	var a := mini(type_a, type_b)
	var b := maxi(type_a, type_b)
	match [a, b]:
		[0, 0]: return Enums.AdType.RECORD_REPORT
		[0, 1]: return Enums.AdType.POLICY_BLUEPRINT
		[0, 2]: return Enums.AdType.INVESTIGATION
		[0, 3]: return Enums.AdType.TOUCHING_STORY
		[1, 1]: return Enums.AdType.EMPTY_CHECK
		[1, 2]: return Enums.AdType.COMPARISON_AD
		[1, 3]: return Enums.AdType.CAMPAIGN_SPEECH
		[2, 2]: return Enums.AdType.SCANDAL_COMBO
		[2, 3]: return Enums.AdType.FEAR_AD
		[3, 3]: return Enums.AdType.POPULIST_RALLY
	return Enums.AdType.RECORD_REPORT


## 获取广告系数 [拉票系数, 攻击系数]
static func get_ad_coefficients(ad_type: Enums.AdType) -> Array:
	match ad_type:
		Enums.AdType.EMPTY_CHECK:       return [2.5, 0.0]
		Enums.AdType.CAMPAIGN_SPEECH:   return [2.0, 0.0]
		Enums.AdType.RECORD_REPORT:     return [2.0, 0.0]
		Enums.AdType.POLICY_BLUEPRINT:  return [1.5, 0.0]
		Enums.AdType.TOUCHING_STORY:    return [1.5, 0.0]
		Enums.AdType.POPULIST_RALLY:    return [1.0, 0.5]
		Enums.AdType.COMPARISON_AD:     return [0.5, 1.5]
		Enums.AdType.INVESTIGATION:     return [0.0, 1.5]
		Enums.AdType.FEAR_AD:           return [0.0, 2.0]
		Enums.AdType.SCANDAL_COMBO:     return [0.0, 2.5]
	return [0.0, 0.0]


## 计算议题匹配加成倍率
static func get_topic_multiplier(card_a: MaterialCardDef, card_b: MaterialCardDef, district_topic: Enums.Topic) -> float:
	if district_topic == Enums.Topic.NONE:
		return 1.0
	var match_count := 0
	if card_a.topic == district_topic:
		match_count += 1
	if card_b.topic == district_topic:
		match_count += 1
	if match_count == 2:
		return 2.0
	if match_count == 1:
		return 1.5
	return 1.0


# ═══════════════════════════════════════════
#  广告投放
# ═══════════════════════════════════════════

## 投放广告，返回结算结果
func place_ad(player_id: StringName, card_a: MaterialCardDef, card_b: MaterialCardDef, district_idx: int) -> Dictionary:
	var district: Dictionary = districts[district_idx]
	var ad_type := get_ad_type(card_a.material_type, card_b.material_type)
	var strength := card_a.quality + card_b.quality
	var coeffs := get_ad_coefficients(ad_type)
	var topic_mult := get_topic_multiplier(card_a, card_b, district["topic"])

	var rally_power := int(strength * coeffs[0] * topic_mult)
	var attack_power := int(strength * coeffs[1] * topic_mult)

	# 记录空头支票
	if ad_type == Enums.AdType.EMPTY_CHECK:
		_turn_empty_checks.append({"player_id": player_id, "district_idx": district_idx})

	# 结算
	var rally_result := _resolve_rally(player_id, district_idx, rally_power)
	var attack_result := _resolve_attack(player_id, district_idx, attack_power)

	GameBus.ad_placed.emit(player_id, ad_type, district_idx)

	return {
		"ad_type": ad_type,
		"ad_name": Enums.ad_name(ad_type),
		"strength": strength,
		"topic_mult": topic_mult,
		"rally_power": rally_power,
		"attack_power": attack_power,
		"rally_claimed": rally_result["claimed"],
		"rally_eroded": rally_result["eroded"],
		"attack_hit": attack_result["hit"],
		"attack_neutralized": attack_result["neutralized"],
	}


# ═══════════════════════════════════════════
#  事实核查
# ═══════════════════════════════════════════

## 事实核查（打假），返回结果
func fact_check(player_id: StringName, cards: Array[MaterialCardDef], district_idx: int) -> Dictionary:
	var total_quality := 0
	var best_bonus := 1.0
	for card in cards:
		total_quality += card.quality
		if card.material_type == Enums.MaterialType.RECORD or card.material_type == Enums.MaterialType.DIRT:
			best_bonus = 1.5

	var influence := int(total_quality * best_bonus)

	# 检查是否能针对空头支票
	var countered := false
	for i in range(_turn_empty_checks.size() - 1, -1, -1):
		var ec: Dictionary = _turn_empty_checks[i]
		if ec["player_id"] != player_id and ec["district_idx"] == district_idx:
			countered = true
			_penalize_empty_check(ec["player_id"], district_idx)
			_turn_empty_checks.remove_at(i)
			break

	var attack_result := _resolve_attack(player_id, district_idx, influence)

	GameBus.fact_checked.emit(player_id, district_idx, countered)

	return {
		"influence": influence,
		"countered": countered,
		"attack_hit": attack_result["hit"],
		"attack_neutralized": attack_result["neutralized"],
	}


func _penalize_empty_check(target_player_id: StringName, district_idx: int) -> void:
	var voters: Array = districts[district_idx]["voters"]
	for voter: Voter in voters:
		if voter.owner_id == target_player_id:
			voter.loyalty = maxi(0, voter.loyalty - 2)
			if voter.loyalty == 0:
				voter.owner_id = &""


# ═══════════════════════════════════════════
#  结算逻辑（内部）
# ═══════════════════════════════════════════

func _resolve_rally(player_id: StringName, district_idx: int, power: int) -> Dictionary:
	if power <= 0:
		return {"claimed": 0, "eroded": 0}

	var voters: Array = districts[district_idx]["voters"]
	var claimed := 0
	var eroded := 0

	# Phase 1: 争取中立选民
	var neutrals: Array = []
	for v: Voter in voters:
		if v.is_neutral():
			neutrals.append(v)

	if neutrals.size() > 0:
		var share := power / neutrals.size()
		if share > 0:
			for v: Voter in neutrals:
				v.owner_id = player_id
				v.loyalty = share
				claimed += 1
			power -= share * neutrals.size()

	# Phase 2: 侵蚀对手选民
	if power > 0:
		var opponents: Array = []
		for v: Voter in voters:
			if not v.is_neutral() and v.owner_id != player_id:
				opponents.append(v)
		if opponents.size() > 0:
			var share := power / opponents.size()
			if share > 0:
				for v: Voter in opponents:
					v.loyalty -= share
					eroded += 1
					if v.loyalty <= 0:
						v.owner_id = &""
						v.loyalty = 0

	return {"claimed": claimed, "eroded": eroded}


func _resolve_attack(player_id: StringName, district_idx: int, power: int) -> Dictionary:
	if power <= 0:
		return {"hit": 0, "neutralized": 0}

	var voters: Array = districts[district_idx]["voters"]
	var hit := 0
	var neutralized := 0

	var opponents: Array = []
	for v: Voter in voters:
		if not v.is_neutral() and v.owner_id != player_id:
			opponents.append(v)

	if opponents.size() > 0:
		var share := power / opponents.size()
		if share > 0:
			for v: Voter in opponents:
				v.loyalty -= share
				hit += 1
				if v.loyalty <= 0:
					v.owner_id = &""
					v.loyalty = 0
					neutralized += 1

	return {"hit": hit, "neutralized": neutralized}


# ═══════════════════════════════════════════
#  回合结算
# ═══════════════════════════════════════════

## 所有有主选民忠诚度 -1，归零变中立
func tick_loyalty() -> void:
	for district in districts:
		for voter: Voter in district["voters"]:
			if not voter.is_neutral():
				voter.loyalty -= 1
				if voter.loyalty <= 0:
					voter.owner_id = &""
					voter.loyalty = 0


## 清除本回合空头支票记录
func clear_turn_data() -> void:
	_turn_empty_checks.clear()


# ═══════════════════════════════════════════
#  查询
# ═══════════════════════════════════════════

## 统计玩家控制的选民总数
func get_voter_count(player_id: StringName) -> int:
	var count := 0
	for district in districts:
		for voter: Voter in district["voters"]:
			if voter.owner_id == player_id:
				count += 1
	return count


## 根据声势等级计算抽牌数
func get_draw_count(player_id: StringName) -> int:
	var v := get_voter_count(player_id)
	if v >= 18: return 7
	if v >= 13: return 6
	if v >= 8:  return 5
	if v >= 4:  return 4
	return 3


## 统计选区内各方选民数和忠诚度
func get_district_info(district_idx: int) -> Dictionary:
	var district: Dictionary = districts[district_idx]
	var counts: Dictionary = {}   # player_id -> count
	var loyalty_sum: Dictionary = {} # player_id -> total loyalty
	var neutral := 0
	for voter: Voter in district["voters"]:
		if voter.is_neutral():
			neutral += 1
		else:
			counts[voter.owner_id] = counts.get(voter.owner_id, 0) + 1
			loyalty_sum[voter.owner_id] = loyalty_sum.get(voter.owner_id, 0) + voter.loyalty
	return {"counts": counts, "neutral": neutral, "loyalty": loyalty_sum}


## 计算最终选举结果
func count_votes() -> Dictionary:
	var player_tickets: Dictionary = {}
	var district_results: Array[Dictionary] = []

	for i in districts.size():
		var district: Dictionary = districts[i]
		var info := get_district_info(i)

		# 找出谁控制最多选民
		var best_player: StringName = &""
		var best_count := 0
		var tie := false

		for pid: StringName in info["counts"]:
			var c: int = info["counts"][pid]
			if c > best_count:
				best_count = c
				best_player = pid
				tie = false
			elif c == best_count and c > 0:
				tie = true

		var winner: StringName = &"" if tie or best_count == 0 else best_player
		var tickets: int = district["ticket_value"] if winner != &"" else 0

		if winner != &"":
			player_tickets[winner] = player_tickets.get(winner, 0) + tickets

		district_results.append({
			"name": district["name"],
			"winner": winner,
			"tickets": tickets if winner != &"" else 0,
			"info": info,
		})

	return {"player_tickets": player_tickets, "district_results": district_results}
