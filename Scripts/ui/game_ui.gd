## 主 UI 控制器：管理游戏流程和玩家交互
extends Control

const MAX_TURNS := 10
const FIRST_DRAW := 5
const TURN_DRAW := 2
const GRID_W := 10
const GRID_H := 10

enum Phase { IDLE, DRAW, PLAYER_TURN, AI_TURN, SETTLEMENT, GAME_OVER }

var _phase: Phase = Phase.IDLE
var _current_turn := 0
var _player: PlayerState
var _ai: PlayerState
var _shape_templates: Array[CardShape] = []

@onready var _board_view: BoardView = %BoardView
@onready var _hand_view: HandView = %HandView
@onready var _preview_view: PreviewView = %PreviewView
@onready var _status_label: Label = %StatusLabel
@onready var _info_label: Label = %InfoLabel
@onready var _rotate_btn: Button = %RotateButton
@onready var _end_turn_btn: Button = %EndTurnButton
@onready var _ai_timer: Timer = %AITimer
@onready var _move_up_btn: Button = %MoveUpButton
@onready var _move_down_btn: Button = %MoveDownButton
@onready var _move_left_btn: Button = %MoveLeftButton
@onready var _move_right_btn: Button = %MoveRightButton
@onready var _switch_card_btn: Button = %SwitchCardButton


func _ready() -> void:
	_board_view.cell_clicked.connect(_on_cell_clicked)
	_board_view.cell_hovered.connect(_on_cell_hovered)
	_hand_view.selection_changed.connect(_on_selection_changed)
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_ai_timer.timeout.connect(_on_ai_timer)
	_ai_timer.one_shot = true

	# 方向按钮
	_move_up_btn.pressed.connect(func() -> void: _preview_view.move_active_card(Vector2i(0, -1)))
	_move_down_btn.pressed.connect(func() -> void: _preview_view.move_active_card(Vector2i(0, 1)))
	_move_left_btn.pressed.connect(func() -> void: _preview_view.move_active_card(Vector2i(-1, 0)))
	_move_right_btn.pressed.connect(func() -> void: _preview_view.move_active_card(Vector2i(1, 0)))
	_switch_card_btn.pressed.connect(_on_switch_card_pressed)

	_preview_view.placements_changed.connect(_on_placements_changed)

	_setup_game()
	_start_turn()


func _input(event: InputEvent) -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_TAB:
			_on_switch_card_pressed()
			get_viewport().set_input_as_handled()
		KEY_W, KEY_UP:
			_preview_view.move_active_card(Vector2i(0, -1))
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			_preview_view.move_active_card(Vector2i(0, 1))
			get_viewport().set_input_as_handled()
		KEY_A, KEY_LEFT:
			_preview_view.move_active_card(Vector2i(-1, 0))
			get_viewport().set_input_as_handled()
		KEY_D, KEY_RIGHT:
			_preview_view.move_active_card(Vector2i(1, 0))
			get_viewport().set_input_as_handled()
		KEY_R:
			# R = 旋转预览区中当前激活的单张卡牌
			_preview_view.rotate_active_card()
			get_viewport().set_input_as_handled()
		KEY_Q:
			# Q = 旋转整体重叠图案
			_on_rotate_pressed()
			get_viewport().set_input_as_handled()


# ─── 初始化 ───

func _setup_game() -> void:
	BoardManager.setup()
	_create_shape_templates()
	_setup_deck()

	_player = PlayerState.new(Enums.CellOwner.PLAYER_A, "玩家")
	_ai = PlayerState.new(Enums.CellOwner.PLAYER_B, "AI")

	_update_status()


func _create_shape_templates() -> void:
	_shape_templates = [
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0)]),
		CardShape.create([Vector2i(0, 0), Vector2i(0, 1)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]),
		CardShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]),
		CardShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]),
		CardShape.create([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]),
	]


func _setup_deck() -> void:
	var pool: Array[CardDef] = []
	var shape_names: Array[String] = [
		"横线2", "竖线2", "横线3", "角落", "小L",
		"横线4", "L形", "T形", "田字", "Z形", "十字",
	]
	var counts: Array[int] = [3, 3, 5, 4, 4, 3, 3, 3, 3, 3, 2]

	var card_idx := 0
	for i in _shape_templates.size():
		var count: int = counts[i]
		for j in count:
			var card_id: StringName = &"card_%d" % card_idx
			var cname: String = shape_names[i]
			pool.append(CardDef.create(card_id, cname, _shape_templates[i]))
			card_idx += 1
	CardSystem.setup_deck(pool)


# ─── 回合流程 ───

func _start_turn() -> void:
	_current_turn += 1
	if _current_turn > MAX_TURNS:
		_game_over()
		return

	GameBus.turn_started.emit(_current_turn)

	_phase = Phase.DRAW
	var draw_count := FIRST_DRAW if _current_turn == 1 else TURN_DRAW
	CardSystem.draw_for_player(_player, draw_count)
	CardSystem.draw_for_player(_ai, draw_count)

	_start_player_turn()


func _start_player_turn() -> void:
	_phase = Phase.PLAYER_TURN
	_player.reset_turn()
	_hand_view.set_enabled(true)
	_hand_view.update_hand(_player.hand)
	_preview_view.clear_preview()
	_board_view.hide_preview()
	_set_offset_buttons_enabled(false)
	_rotate_btn.disabled = false
	_end_turn_btn.disabled = false
	_update_status()
	_info_label.text = "选择2~4张牌，R单卡旋转 Q整体旋转 WASD移动 点棋盘放置"


func _start_ai_turn() -> void:
	_phase = Phase.AI_TURN
	_hand_view.set_enabled(false)
	_set_offset_buttons_enabled(false)
	_rotate_btn.disabled = true
	_end_turn_btn.disabled = true
	_board_view.hide_preview()
	_info_label.text = "AI 思考中..."
	_update_status()
	_ai.reset_turn()
	_ai_timer.start(0.5)


func _do_ai_action() -> void:
	if _ai.can_spend_ap(1) and _ai.hand.size() >= 2:
		_ai_publish_article()
		_board_view.refresh()
		_update_status()

		if _ai.can_spend_ap(1) and _ai.hand.size() >= 2:
			_ai_timer.start(0.3)
			return

	_settlement()


func _settlement() -> void:
	_phase = Phase.SETTLEMENT
	var discard_p := _player.discard_to_limit()
	var discard_ai := _ai.discard_to_limit()
	if discard_p.size() > 0:
		CardSystem.discard(discard_p)
	if discard_ai.size() > 0:
		CardSystem.discard(discard_ai)

	GameBus.turn_ended.emit(_current_turn)
	_update_status()
	_start_turn()


func _game_over() -> void:
	_phase = Phase.GAME_OVER
	_hand_view.set_enabled(false)
	_set_offset_buttons_enabled(false)
	_rotate_btn.disabled = true
	_end_turn_btn.disabled = true
	_board_view.hide_preview()

	var counts := BoardManager.count_cells()
	var a: int = counts[Enums.CellOwner.PLAYER_A]
	var b: int = counts[Enums.CellOwner.PLAYER_B]

	if a > b:
		_info_label.text = "游戏结束！你获胜！（%d vs %d）" % [a, b]
		GameBus.game_ended.emit(Enums.CellOwner.PLAYER_A)
	elif b > a:
		_info_label.text = "游戏结束！AI 获胜！（%d vs %d）" % [b, a]
		GameBus.game_ended.emit(Enums.CellOwner.PLAYER_B)
	else:
		_info_label.text = "游戏结束！平局！（%d vs %d）" % [a, b]
		GameBus.game_ended.emit(Enums.CellOwner.NEUTRAL)

	_status_label.text = "游戏结束 | 玩家: %d格 | AI: %d格" % [a, b]


# ─── 玩家交互 ───

func _on_selection_changed(selected_indices: Array[int]) -> void:
	if _phase != Phase.PLAYER_TURN:
		return

	_rebuild_placements()
	var placements := _preview_view.get_placements()

	if placements.size() >= 2 or selected_indices.size() >= 2:
		_preview_view.update_preview(_get_current_placements())
		_set_offset_buttons_enabled(true)
		var active := _preview_view.get_active_card()
		_info_label.text = "卡牌%d激活 | R单卡旋转 Q整体旋转 WASD移动 Tab切换 | 点棋盘放置" % (active + 1)
	else:
		_preview_view.clear_preview()
		_board_view.hide_preview()
		_set_offset_buttons_enabled(false)
		var count := selected_indices.size()
		if count == 0:
			_info_label.text = "选择2~4张牌，R单卡旋转 Q整体旋转 WASD移动 点棋盘放置"
		else:
			_info_label.text = "再选 %d 张牌（已选 %d）" % [2 - count, count]


func _on_cell_hovered(pos: Vector2i) -> void:
	if _phase != Phase.PLAYER_TURN:
		return

	var placements := _preview_view.get_placements()
	if placements.size() < 2 or pos.x < 0:
		_board_view.hide_preview()
		return

	# 用归一化的 power_map，鼠标位置 = 重叠图案左上角
	var norm_map := _preview_view.get_normalized_power_map()
	if norm_map.is_empty():
		_board_view.hide_preview()
		return

	var board_power_map := {}
	var all_valid := true
	for p: Vector2i in norm_map:
		var board_pos := p + pos
		if not BoardManager.is_in_bounds(board_pos.x, board_pos.y):
			all_valid = false
			break
		board_power_map[board_pos] = norm_map[p]

	if all_valid:
		_board_view.show_preview(board_power_map, _player.player_id)
	else:
		_board_view.hide_preview()


func _on_cell_clicked(pos: Vector2i) -> void:
	if _phase != Phase.PLAYER_TURN:
		return

	var placements := _preview_view.get_placements()

	if placements.size() < 2:
		_info_label.text = "至少选择2张牌！"
		return

	if not _player.can_spend_ap(1):
		_info_label.text = "行动点不足！"
		return

	# 用归一化 power_map 放置，鼠标位置 = 重叠图案左上角
	var norm_map := _preview_view.get_normalized_power_map()

	if norm_map.is_empty():
		_info_label.text = "没有有效重叠！调整卡牌位置"
		return

	if not ShapeResolver.validate_bounds(norm_map, pos, GRID_W, GRID_H):
		_info_label.text = "超出棋盘边界！换个位置"
		return

	# 直接用归一化 power_map 逐格应用，不走 resolve_article
	_player.spend_ap(1)
	var cells_affected := 0
	var cells_flipped := 0
	var total_power := 0
	for p: Vector2i in norm_map:
		var board_pos := p + pos
		var power: int = norm_map[p]
		total_power += power
		var cell_result: Dictionary = BoardManager.apply_power(board_pos.x, board_pos.y, _player.player_id, power)
		cells_affected += 1
		if cell_result["flipped"]:
			cells_flipped += 1
	var result := {
		"cells_affected": cells_affected,
		"cells_flipped": cells_flipped,
		"total_power": total_power,
		"cards_used": placements.size(),
	}

	# 移除使用的手牌
	var indices := _hand_view.get_selected_indices()
	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	var used_cards: Array[CardDef] = []
	for idx in sorted_indices:
		used_cards.append(_player.hand[idx])
		_player.hand.remove_at(idx)
	CardSystem.discard(used_cards)

	GameBus.article_published.emit(_player.player_id, result)

	_board_view.refresh()
	_board_view.hide_preview()
	_hand_view.clear_selection()
	_hand_view.update_hand(_player.hand)
	_preview_view.clear_preview()
	_set_offset_buttons_enabled(false)
	_update_status()

	_info_label.text = "生效 %d 格，翻色 %d 格 | AP %d/%d" % [
		result["cells_affected"], result["cells_flipped"],
		_player.action_points, _player.max_action_points,
	]

	if not _player.can_spend_ap(1) or _player.hand.size() < 2:
		await get_tree().create_timer(0.5).timeout
		_start_ai_turn()


func _on_rotate_pressed() -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	# 旋转整体重叠图案
	_preview_view.rotate_all()


func _on_end_turn_pressed() -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	_start_ai_turn()


func _on_switch_card_pressed() -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	var placements := _preview_view.get_placements()
	if placements.size() < 2:
		return
	var active := _preview_view.get_active_card()
	var next := (active + 1) % placements.size()
	_preview_view.set_active_card(next)
	_info_label.text = "卡牌%d激活 | R单卡旋转 Q整体旋转 WASD移动 Tab切换 | 点棋盘放置" % (next + 1)


func _on_placements_changed() -> void:
	# 叠放变化后刷新棋盘预览
	var hover := _board_view.get_hover_pos()
	_on_cell_hovered(hover)


func _on_ai_timer() -> void:
	_do_ai_action()


# ─── 工具方法 ───

func _get_current_placements() -> Array[ShapeResolver.CardPlacement]:
	var result: Array[ShapeResolver.CardPlacement] = []
	var indices := _hand_view.get_selected_indices()
	for i in indices.size():
		var idx: int = indices[i]
		var card: CardDef = _player.hand[idx]
		var rot := _hand_view.get_card_rotation(idx)
		var placement := ShapeResolver.CardPlacement.new(card, rot)
		placement.offset = Vector2i.ZERO
		result.append(placement)
	return result


func _rebuild_placements() -> void:
	var placements := _get_current_placements()
	# preview_view 会持有这些 placements
	if placements.size() >= 2:
		_preview_view.update_preview(placements)


func _set_offset_buttons_enabled(enabled: bool) -> void:
	_move_up_btn.disabled = not enabled
	_move_down_btn.disabled = not enabled
	_move_left_btn.disabled = not enabled
	_move_right_btn.disabled = not enabled
	_switch_card_btn.disabled = not enabled
	_rotate_btn.disabled = not enabled


func _update_status() -> void:
	if _phase == Phase.GAME_OVER:
		return
	var counts := BoardManager.count_cells()
	_status_label.text = "第 %d/%d 回合 | AP: %d/%d | 玩家: %d格 | AI: %d格 | 中立: %d格" % [
		_current_turn, MAX_TURNS,
		_player.action_points if _player else 0, 3,
		counts[Enums.CellOwner.PLAYER_A],
		counts[Enums.CellOwner.PLAYER_B],
		counts[Enums.CellOwner.NEUTRAL],
	]


# ─── AI 逻辑 ───

func _ai_publish_article() -> void:
	var card_count := 2
	if _ai.hand.size() >= 3 and randi() % 3 == 0:
		card_count = 3

	var indices: Array[int] = []
	var available := range(_ai.hand.size())
	available.shuffle()
	for i in card_count:
		indices.append(available[i])

	var placements: Array[ShapeResolver.CardPlacement] = []
	for idx in indices:
		var card: CardDef = _ai.hand[idx]
		var rot := randi() % 4
		placements.append(ShapeResolver.CardPlacement.new(card, rot))

	placements[0].offset = Vector2i.ZERO
	for i in range(1, placements.size()):
		placements[i].offset = Vector2i(randi_range(-1, 1), randi_range(-1, 1))

	var overlap := ShapeResolver.compute_overlap(placements)
	var power_map := ShapeResolver.compute_power_map(overlap)

	if power_map.is_empty():
		_ai.action_points = 0
		return

	var best_pos := Vector2i.ZERO
	var best_score := -999.0

	for _attempt in 20:
		var test_pos := Vector2i(randi() % GRID_W, randi() % GRID_H)
		if not ShapeResolver.validate_bounds(power_map, test_pos, GRID_W, GRID_H):
			continue
		var score := _ai_score(power_map, test_pos)
		if score > best_score:
			best_score = score
			best_pos = test_pos

	if best_score <= 0:
		_ai.action_points = 0
		return

	_ai.spend_ap(1)
	ShapeResolver.resolve_article(placements, best_pos, BoardManager, _ai.player_id)

	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()
	var used: Array[CardDef] = []
	for idx in sorted_indices:
		used.append(_ai.hand[idx])
		_ai.hand.remove_at(idx)
	CardSystem.discard(used)


func _ai_score(power_map: Dictionary, grid_pos: Vector2i) -> float:
	var score := 0.0
	for pos: Vector2i in power_map:
		var board_pos := pos + grid_pos
		if not BoardManager.is_in_bounds(board_pos.x, board_pos.y):
			return -999.0
		var power: int = power_map[pos]
		var cell_owner := BoardManager.get_cell_owner(board_pos.x, board_pos.y)
		var loyalty := BoardManager.get_loyalty(board_pos.x, board_pos.y)
		if cell_owner == Enums.CellOwner.NEUTRAL:
			score += power * 2.0
		elif cell_owner == _ai.player_id:
			score += power * 0.5
		else:
			if loyalty <= power:
				score += power * 3.0
			else:
				score += power * 1.0
	return score
