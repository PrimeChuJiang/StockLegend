## 测试场景脚本：验证 WorldActor → PlayerActor 的 Phase 切换流程。
## 通过 GameBus 信号驱动 UI 更新，Button 发出 player_ended_turn 信号结束玩家回合。
extends Node

@onready var turn_manager: TurnManager = $TurnManager
@onready var turn_label: Label = $CanvasLayer/Panel/VBox/TurnLabel
@onready var actor_label: Label = $CanvasLayer/Panel/VBox/ActorLabel
@onready var phase_label: Label = $CanvasLayer/Panel/VBox/PhaseLabel
@onready var ap_label: Label = $CanvasLayer/Panel/VBox/APLabel
@onready var log_box: RichTextLabel = $CanvasLayer/Panel/VBox/LogBox
@onready var gather_button: Button = $CanvasLayer/Panel/VBox/GatherButton
@onready var end_turn_button: Button = $CanvasLayer/Panel/VBox/EndTurnButton

var _player_state: PlayerState
var _world_actor: WorldActor
var _player_actor: PlayerActor

func _ready() -> void:
	_connect_signals()
	_setup_actors()
	turn_manager.start_game()

func _connect_signals() -> void:
	GameBus.turn_started.connect(func(n: int) -> void:
		turn_label.text = "回合：%d" % n
		_log("[b]══ 回合 %d 开始 ══[/b]" % n))

	GameBus.turn_ended.connect(func(n: int) -> void:
		_log("[b]══ 回合 %d 结束 ══[/b]" % n))

	GameBus.actor_turn_started.connect(_on_actor_turn_started)
	GameBus.actor_turn_ended.connect(_on_actor_turn_ended)

	GameBus.world_phase_started.connect(func(phase: Enums.WorldPhase) -> void:
		phase_label.text = "世界阶段：%s" % Enums.WorldPhase.keys()[phase]
		_log("  [color=cyan]▶ 世界阶段：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.world_phase_ended.connect(func(phase: Enums.WorldPhase) -> void:
		_log("  [color=cyan]■ 世界阶段结束：%s[/color]" % Enums.WorldPhase.keys()[phase]))

	GameBus.action_points_changed.connect(func(new_val: int, max_val: int) -> void:
		ap_label.text = "行动值：%d / %d" % [new_val, max_val]
		_log("  行动值变化：%d / %d" % [new_val, max_val]))

	gather_button.pressed.connect(_on_gather_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func _setup_actors() -> void:
	_player_state = PlayerState.new()
	_world_actor = WorldActor.new()
	_player_actor = PlayerActor.new(_player_state)

	turn_manager.actors = [_world_actor, _player_actor]
	turn_manager.setup({"scene_tree": get_tree()})

func _on_actor_turn_started(actor_type: Enums.ActorType) -> void:
	var is_player := actor_type == Enums.ActorType.PLAYER
	gather_button.disabled = not is_player
	end_turn_button.disabled = not is_player
	match actor_type:
		Enums.ActorType.WORLD:
			actor_label.text = "当前行动者：世界"
			phase_label.text = "阶段：—"
			_log("[color=yellow]【世界回合】开始[/color]")
		Enums.ActorType.PLAYER:
			actor_label.text = "当前行动者：玩家"
			phase_label.text = "阶段：玩家回合"
			_log("[color=green]【玩家回合】开始，等待操作...[/color]")

func _on_actor_turn_ended(actor_type: Enums.ActorType) -> void:
	gather_button.disabled = true
	end_turn_button.disabled = true
	match actor_type:
		Enums.ActorType.WORLD:
			_log("[color=yellow]【世界回合】结束[/color]")
		Enums.ActorType.PLAYER:
			_log("[color=green]【玩家回合】结束[/color]")

func _on_gather_pressed() -> void:
	_player_actor.try_gather_material({})

func _on_end_turn_pressed() -> void:
	_log("[color=gray]  → 玩家点击结束回合[/color]")
	GameBus.player_ended_turn.emit()

func _log(text: String) -> void:
	log_box.append_text(text + "\n")
