extends Node2D
class_name OreMiningComponent

signal hit_requested(cell: Vector2i, damage: int, quality_points: int, result_zone: int, manual: bool)

const INVALID_CELL: Vector2i = Vector2i(-999, -999)
const RESULT_RED: int = 0
const RESULT_YELLOW: int = 1
const RESULT_GREEN: int = 2
const RESULT_FLASH_TIME: float = 0.38
const TRACK_LENGTH: float = 88.0
const TRACK_THICKNESS: float = 28.0
const BACK_OFFSET_X: float = 30.0
const BACK_OFFSET_Y: float = -22.0
const TIMER_FILL_HEIGHT: float = 90.0
const DAMAGE_POPUP_TIME: float = 0.55
const DAMAGE_POPUP_RISE: float = 16.0
const NEEDLE_WIDTH: float = 10.0
const NEEDLE_HEIGHT: float = 8.0

var board: BoardController
var anchor_node: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_cell: Vector2i = INVALID_CELL
var active_deposit_id: int = -1
var active_config = null
var facing_sign: int = 1
var session_paused: bool = false
var round_active: bool = false
var round_timer: float = 0.0
var session_timer: float = 0.0
var marker_position: float = 0.5
var marker_direction: float = 1.0
var pending_bonus_damage: int = 0
var pending_quality_points: int = 0
var result_timer: float = 0.0
var damage_popup_timer: float = 0.0
var damage_popup_base_position: Vector2 = Vector2.ZERO
var damage_popup_color: Color = Color.WHITE

@onready var panel: Control = get_node("Panel") as Control
@onready var result_label: Label = get_node("Panel/ResultLabel") as Label
@onready var damage_popup: Label = get_node("Panel/DamagePopup") as Label
@onready var hp_value_label: Label = get_node("Panel/HpValue") as Label
@onready var flash_rect: ColorRect = get_node("Panel/Flash") as ColorRect
@onready var timer_track: ColorRect = get_node("Panel/TimerTrack") as ColorRect
@onready var timer_fill: ColorRect = get_node("Panel/TimerTrack/TimerFill") as ColorRect
@onready var track: ColorRect = get_node("Panel/Track") as ColorRect
@onready var red_top: ColorRect = get_node("Panel/Track/RedTop") as ColorRect
@onready var yellow_top: ColorRect = get_node("Panel/Track/YellowTop") as ColorRect
@onready var green_zone: ColorRect = get_node("Panel/Track/GreenZone") as ColorRect
@onready var yellow_bottom: ColorRect = get_node("Panel/Track/YellowBottom") as ColorRect
@onready var red_bottom: ColorRect = get_node("Panel/Track/RedBottom") as ColorRect
@onready var needle: ColorRect = get_node("Panel/Track/Needle") as ColorRect
@onready var feedback_player: AudioStreamPlayer2D = get_node("FeedbackPlayer") as AudioStreamPlayer2D


func _ready() -> void:
	rng.randomize()
	visible = false
	panel.visible = false
	result_label.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	damage_popup_base_position = damage_popup.position
	set_process_input(true)


func setup(board_controller: BoardController, tracked_node: Node2D) -> void:
	board = board_controller
	anchor_node = tracked_node


func set_facing_sign(value: int) -> void:
	facing_sign = 1 if value >= 0 else -1


func begin_session(cell: Vector2i) -> void:
	if board == null:
		return
	if not board.is_ore_cell_mineable(cell):
		cancel_session()
		return

	var deposit_id: int = board.get_ore_deposit_id(cell)
	var ore_config = board.get_ore_config_for_cell(cell)
	if deposit_id < 0 or ore_config == null:
		cancel_session()
		return

	active_cell = cell
	if deposit_id == active_deposit_id and active_config == ore_config:
		return

	active_deposit_id = deposit_id
	active_config = ore_config
	session_paused = false
	round_active = false
	round_timer = 0.0
	session_timer = 0.0
	pending_bonus_damage = 0
	pending_quality_points = 0
	panel.visible = false
	visible = false
	result_label.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	_apply_config_visuals()
	_update_hp_value()


func cancel_session() -> void:
	active_cell = INVALID_CELL
	active_deposit_id = -1
	active_config = null
	session_paused = false
	round_active = false
	round_timer = 0.0
	session_timer = 0.0
	pending_bonus_damage = 0
	pending_quality_points = 0
	result_timer = 0.0
	visible = false
	panel.visible = false
	result_label.visible = false
	damage_popup.visible = false
	flash_rect.visible = false


func get_base_damage() -> int:
	if active_config == null:
		return 1
	return maxi(1, active_config.base_damage)


func pause_session() -> void:
	if active_config == null:
		return
	session_paused = true


func resume_session() -> void:
	if active_config == null:
		return
	session_paused = false


func _process(delta: float) -> void:
	if anchor_node != null:
		global_position = anchor_node.global_position + Vector2(-BACK_OFFSET_X * float(facing_sign), BACK_OFFSET_Y)
	_update_feedback(delta)
	_update_hp_value()

	if active_config == null or board == null:
		return
	if active_cell == INVALID_CELL or not board.is_ore_cell_mineable(active_cell):
		cancel_session()
		return

	if round_active:
		_process_round(delta)
		return
	if session_paused:
		return

	session_timer = maxf(0.0, session_timer - delta)
	if session_timer <= 0.0:
		_start_round()


func _input(event: InputEvent) -> void:
	if not round_active:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_commit_round_result(_resolve_zone(marker_position), true)
	get_viewport().set_input_as_handled()


func _process_round(delta: float) -> void:
	round_timer = maxf(0.0, round_timer - delta)
	marker_position += marker_direction * active_config.reaction_move_speed * delta
	if marker_position >= 1.0:
		marker_position = 1.0
		marker_direction = -1.0
	elif marker_position <= 0.0:
		marker_position = 0.0
		marker_direction = 1.0

	_update_needle_position()
	_update_timer_fill()
	if round_timer <= 0.0:
		_commit_round_result(RESULT_RED, false)


func _start_round() -> void:
	if active_config == null:
		return
	visible = true
	panel.visible = true
	result_label.visible = false
	flash_rect.visible = false
	round_active = true
	round_timer = maxf(0.75, float(active_config.round_duration))
	marker_position = rng.randf()
	marker_direction = 1.0 if rng.randf() >= 0.5 else -1.0
	_update_needle_position()
	_update_timer_fill()


func _commit_round_result(result_zone: int, manual: bool) -> void:
	if active_config == null:
		return
	var config_snapshot = active_config
	round_active = false
	session_timer = active_config.minigame_frequency
	panel.visible = true
	visible = true
	result_timer = RESULT_FLASH_TIME
	_update_timer_fill()

	var bonus_damage: int = 0
	var quality_points: int = 0
	if manual:
		bonus_damage = active_config.get_bonus_damage(result_zone)
		quality_points = active_config.get_quality_points(result_zone)

	var total_damage: int = maxi(1, active_config.base_damage + bonus_damage)
	pending_bonus_damage = bonus_damage
	pending_quality_points = quality_points
	hit_requested.emit(active_cell, total_damage, quality_points, result_zone, manual)
	_show_result_feedback(result_zone, total_damage, manual, config_snapshot)


func _show_result_feedback(result_zone: int, total_damage: int, manual: bool, config_snapshot) -> void:
	var result_text: String = ""
	var flash_color: Color = Color.WHITE
	if not manual:
		result_text = "AUTO"
		flash_color = Color(0.95, 0.56, 0.18, 1.0)
	else:
		match result_zone:
			RESULT_GREEN:
				result_text = "PERF"
				flash_color = config_snapshot.green_tint
			RESULT_YELLOW:
				result_text = "GOOD"
				flash_color = config_snapshot.yellow_tint
			_:
				result_text = "WEAK"
				flash_color = config_snapshot.red_tint

	result_label.text = result_text
	result_label.visible = true
	flash_rect.visible = true
	flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.42)
	_show_damage_popup(total_damage, flash_color)
	_play_result_sound(result_zone if manual else RESULT_RED)


func _play_result_sound(result_zone: int) -> void:
	if active_config == null:
		return
	var stream_to_play: AudioStream = active_config.perfect_sound if result_zone == RESULT_GREEN else active_config.result_sound
	if stream_to_play == null:
		return
	feedback_player.stream = stream_to_play
	feedback_player.play()


func _update_feedback(delta: float) -> void:
	if result_timer > 0.0:
		result_timer = maxf(0.0, result_timer - delta)
		if result_timer <= 0.0:
			result_label.visible = false
			flash_rect.visible = false
		else:
			var fade_ratio: float = result_timer / RESULT_FLASH_TIME
			var base_color: Color = flash_rect.color
			flash_rect.color = Color(base_color.r, base_color.g, base_color.b, 0.42 * fade_ratio)

	if damage_popup_timer <= 0.0:
		if not round_active and result_timer <= 0.0 and not session_paused:
			panel.visible = active_config != null
		return

	damage_popup_timer = maxf(0.0, damage_popup_timer - delta)
	if damage_popup_timer <= 0.0:
		damage_popup.visible = false
	else:
		var popup_ratio: float = damage_popup_timer / DAMAGE_POPUP_TIME
		damage_popup.modulate = Color(damage_popup_color.r, damage_popup_color.g, damage_popup_color.b, popup_ratio)
		damage_popup.position = damage_popup_base_position + Vector2(0.0, (1.0 - popup_ratio) * -DAMAGE_POPUP_RISE)


func _apply_config_visuals() -> void:
	if active_config == null:
		return
	panel.modulate = Color.WHITE
	track.color = Color(0.08, 0.08, 0.1, 0.92)
	timer_track.color = Color(0.08, 0.08, 0.1, 0.96)
	hp_value_label.modulate = active_config.green_tint
	result_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	damage_popup.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	(get_node("Panel/Backdrop") as ColorRect).color = active_config.panel_tint

	var normalized_layout: Vector3 = active_config.get_zone_layout()
	var red_total: float = normalized_layout.x
	var yellow_total: float = normalized_layout.y
	var green_total: float = normalized_layout.z
	var red_side: float = red_total * 0.5
	var yellow_side: float = yellow_total * 0.5

	track.size = Vector2(TRACK_THICKNESS + 4.0, TRACK_LENGTH + 4.0)
	needle.size = Vector2(NEEDLE_WIDTH, NEEDLE_HEIGHT)
	needle.color = Color(0.16, 0.86, 0.34, 1.0)
	timer_fill.color = Color(0.95, 0.48, 0.15, 1.0)
	red_top.position = Vector2(2.0, 2.0)
	red_top.size = Vector2(TRACK_THICKNESS, TRACK_LENGTH * red_side)
	yellow_top.position = Vector2(2.0, red_top.position.y + red_top.size.y)
	yellow_top.size = Vector2(TRACK_THICKNESS, TRACK_LENGTH * yellow_side)
	green_zone.position = Vector2(2.0, yellow_top.position.y + yellow_top.size.y)
	green_zone.size = Vector2(TRACK_THICKNESS, TRACK_LENGTH * green_total)
	yellow_bottom.position = Vector2(2.0, green_zone.position.y + green_zone.size.y)
	yellow_bottom.size = Vector2(TRACK_THICKNESS, TRACK_LENGTH * yellow_side)
	red_bottom.position = Vector2(2.0, yellow_bottom.position.y + yellow_bottom.size.y)
	red_bottom.size = Vector2(TRACK_THICKNESS, TRACK_LENGTH * red_side)

	red_top.color = active_config.red_tint
	red_bottom.color = active_config.red_tint
	yellow_top.color = active_config.yellow_tint
	yellow_bottom.color = active_config.yellow_tint
	green_zone.color = active_config.green_tint
	_update_timer_fill()


func _update_needle_position() -> void:
	if active_config == null:
		return
	var track_height: float = TRACK_LENGTH
	var y_position: float = marker_position * track_height
	needle.position = Vector2(-NEEDLE_WIDTH + 1.0, 2.0 + y_position - (needle.size.y * 0.5))


func _resolve_zone(progress: float) -> int:
	if active_config == null:
		return RESULT_RED

	var normalized_layout: Vector3 = active_config.get_zone_layout()
	var red_side: float = normalized_layout.x * 0.5
	var yellow_side: float = normalized_layout.y * 0.5
	var left_red_end: float = red_side
	var left_yellow_end: float = left_red_end + yellow_side
	var green_end: float = left_yellow_end + normalized_layout.z
	var right_yellow_end: float = green_end + yellow_side

	if progress <= left_red_end or progress > right_yellow_end:
		return RESULT_RED
	if progress <= left_yellow_end or progress > green_end:
		return RESULT_YELLOW
	return RESULT_GREEN


func _update_timer_fill() -> void:
	if active_config == null:
		return
	var duration: float = maxf(0.01, float(active_config.round_duration))
	var ratio: float = clampf(round_timer / duration, 0.0, 1.0) if round_active else 0.0
	var fill_height: float = TIMER_FILL_HEIGHT * ratio
	timer_fill.position = Vector2(1.0, 1.0 + (TIMER_FILL_HEIGHT - fill_height))
	timer_fill.size = Vector2(6.0, fill_height)


func _update_hp_value() -> void:
	if board == null or active_cell == INVALID_CELL or not board.is_ore_cell_mineable(active_cell):
		hp_value_label.text = ""
		if not round_active and result_timer <= 0.0 and damage_popup_timer <= 0.0:
			panel.visible = false
			visible = false
		return

	var current_hp: int = board.get_ore_current_hp(active_cell)
	hp_value_label.text = str(current_hp)
	panel.visible = true
	visible = true


func _show_damage_popup(damage_amount: int, popup_color: Color) -> void:
	damage_popup_timer = DAMAGE_POPUP_TIME
	damage_popup.visible = true
	damage_popup.text = str(damage_amount)
	damage_popup_color = popup_color
	damage_popup.modulate = popup_color
	damage_popup.position = damage_popup_base_position
