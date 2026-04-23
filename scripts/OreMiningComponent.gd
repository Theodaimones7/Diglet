extends Node2D
class_name OreMiningComponent

signal hit_requested(cell: Vector2i, damage: int, quality_points: int, result_zone: int, manual: bool)
signal session_lock_changed(locked: bool)

const INVALID_CELL: Vector2i = Vector2i(-999, -999)
const RESULT_RED: int = 0
const RESULT_YELLOW: int = 1
const RESULT_GREEN: int = 2
const RESULT_FLASH_TIME: float = 0.38
const TRACK_LENGTH: float = 176.0
const TRACK_THICKNESS: float = 18.0
const BACK_OFFSET_X: float = 30.0
const BACK_OFFSET_Y: float = -22.0
const TIMER_FILL_HEIGHT: float = 178.0
const DAMAGE_POPUP_TIME: float = 0.55
const DAMAGE_POPUP_RISE: float = 16.0
const NEEDLE_WIDTH: float = 10.0
const NEEDLE_HEIGHT: float = 8.0
const STOP_BUTTON_BASE_SCALE: Vector2 = Vector2(1.0, 1.0)
const STOP_BUTTON_PULSE_SCALE: Vector2 = Vector2(1.12, 1.12)
const STOP_BUTTON_PULSE_TIME: float = 0.42
const PANEL_LAYOUT_WIDTH: float = 168.0
const TRACK_LEFT_X: float = 72.0
const TRACK_RIGHT_X: float = 94.0
const BACKDROP_LEFT_X: float = 72.0
const BACKDROP_RIGHT_X: float = 94.0
const TIMER_TRACK_LEFT_X: float = 58.0
const TIMER_TRACK_RIGHT_X: float = 66.0
const BUTTON_LEFT_X: float = -2.0
const BUTTON_RIGHT_X: float = 62.0
const LABEL_LEFT_X: float = 0.0
const LABEL_RIGHT_X: float = 58.0
const HP_LEFT_X: float = 52.0
const HP_RIGHT_X: float = 114.0

var board: BoardController
var anchor_node: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_cell: Vector2i = INVALID_CELL
var active_deposit_id: int = -1
var active_config = null
var facing_sign: int = 1
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
var stop_button_tween: Tween
var left_red_size: float = 0.0
var left_yellow_end: float = 0.0
var green_end: float = 0.0
var right_yellow_end: float = 1.0
var session_locked: bool = false

@onready var panel: Control = get_node("Panel") as Control
@onready var result_label: Label = get_node("Panel/ResultLabel") as Label
@onready var stop_button: TextureButton = get_node("Panel/StopButton") as TextureButton
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
	stop_button.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	damage_popup_base_position = damage_popup.position
	stop_button.pressed.connect(_on_stop_button_pressed)
	_apply_facing_layout()


func setup(board_controller: BoardController, tracked_node: Node2D) -> void:
	board = board_controller
	anchor_node = tracked_node


func set_facing_sign(value: int) -> void:
	facing_sign = 1 if value >= 0 else -1
	_apply_facing_layout()


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
	_set_session_locked(true)
	if deposit_id == active_deposit_id and active_config == ore_config:
		return

	active_deposit_id = deposit_id
	active_config = ore_config
	round_active = false
	round_timer = 0.0
	session_timer = 0.0
	pending_bonus_damage = 0
	pending_quality_points = 0
	panel.visible = false
	visible = false
	result_label.visible = false
	stop_button.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	_stop_stop_button_animation()
	_randomize_zone_layout()
	_apply_config_visuals()
	_update_hp_value()


func cancel_session() -> void:
	active_cell = INVALID_CELL
	active_deposit_id = -1
	active_config = null
	round_active = false
	round_timer = 0.0
	session_timer = 0.0
	pending_bonus_damage = 0
	pending_quality_points = 0
	result_timer = 0.0
	visible = false
	panel.visible = false
	result_label.visible = false
	stop_button.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	_stop_stop_button_animation()
	_set_session_locked(false)


func get_base_damage() -> int:
	if active_config == null:
		return 1
	return maxi(1, active_config.base_damage)


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

	session_timer = maxf(0.0, session_timer - delta)
	if session_timer <= 0.0:
		_start_round()

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
	_randomize_zone_layout()
	_apply_config_visuals()
	visible = true
	panel.visible = true
	result_label.visible = false
	flash_rect.visible = false
	stop_button.visible = true
	round_active = true
	round_timer = maxf(0.75, float(active_config.round_duration))
	marker_position = rng.randf()
	marker_direction = 1.0 if rng.randf() >= 0.5 else -1.0
	_update_needle_position()
	_update_timer_fill()
	_start_stop_button_animation()


func _commit_round_result(result_zone: int, manual: bool) -> void:
	if active_config == null:
		return
	var config_snapshot = active_config
	round_active = false
	session_timer = active_config.minigame_frequency
	panel.visible = true
	visible = true
	result_timer = RESULT_FLASH_TIME
	stop_button.visible = false
	_stop_stop_button_animation()
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
		if not round_active and result_timer <= 0.0:
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

	var top_red_height: float = TRACK_LENGTH * left_red_size
	var top_yellow_height: float = TRACK_LENGTH * (left_yellow_end - left_red_size)
	var green_height: float = TRACK_LENGTH * (green_end - left_yellow_end)
	var bottom_yellow_height: float = TRACK_LENGTH * (right_yellow_end - green_end)
	var bottom_red_height: float = TRACK_LENGTH * (1.0 - right_yellow_end)

	track.size = Vector2(TRACK_THICKNESS + 4.0, TRACK_LENGTH + 4.0)
	needle.size = Vector2(NEEDLE_WIDTH, NEEDLE_HEIGHT)
	needle.color = Color(0.16, 0.86, 0.34, 1.0)
	timer_fill.color = Color(0.95, 0.48, 0.15, 1.0)
	red_top.position = Vector2(2.0, 2.0)
	red_top.size = Vector2(TRACK_THICKNESS, top_red_height)
	yellow_top.position = Vector2(2.0, red_top.position.y + red_top.size.y)
	yellow_top.size = Vector2(TRACK_THICKNESS, top_yellow_height)
	green_zone.position = Vector2(2.0, yellow_top.position.y + yellow_top.size.y)
	green_zone.size = Vector2(TRACK_THICKNESS, green_height)
	yellow_bottom.position = Vector2(2.0, green_zone.position.y + green_zone.size.y)
	yellow_bottom.size = Vector2(TRACK_THICKNESS, bottom_yellow_height)
	red_bottom.position = Vector2(2.0, yellow_bottom.position.y + yellow_bottom.size.y)
	red_bottom.size = Vector2(TRACK_THICKNESS, bottom_red_height)

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

	if progress <= left_red_size or progress > right_yellow_end:
		return RESULT_RED
	if progress <= left_yellow_end or progress > green_end:
		return RESULT_YELLOW
	return RESULT_GREEN


func _randomize_zone_layout() -> void:
	if active_config == null:
		left_red_size = 0.0
		left_yellow_end = 0.0
		green_end = 1.0
		right_yellow_end = 1.0
		return

	var normalized_layout: Vector3 = active_config.get_zone_layout()
	var yellow_side: float = normalized_layout.y * 0.5
	var movable_group_size: float = normalized_layout.y + normalized_layout.z
	var start_limit: float = maxf(0.0, 1.0 - movable_group_size)
	var yellow_start: float = rng.randf_range(0.0, start_limit)

	left_red_size = yellow_start
	left_yellow_end = yellow_start + yellow_side
	green_end = left_yellow_end + normalized_layout.z
	right_yellow_end = green_end + yellow_side


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


func is_session_active() -> bool:
	return active_config != null


func _on_stop_button_pressed() -> void:
	if not round_active:
		return
	_commit_round_result(_resolve_zone(marker_position), true)
	get_viewport().set_input_as_handled()


func _start_stop_button_animation() -> void:
	_stop_stop_button_animation()
	stop_button.scale = STOP_BUTTON_BASE_SCALE
	stop_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	stop_button_tween = create_tween()
	stop_button_tween.set_loops()
	stop_button_tween.set_parallel(true)
	stop_button_tween.tween_property(stop_button, "scale", STOP_BUTTON_PULSE_SCALE, STOP_BUTTON_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stop_button_tween.tween_property(stop_button, "modulate", Color(1.0, 0.9, 0.55, 1.0), STOP_BUTTON_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stop_button_tween.chain().set_parallel(true)
	stop_button_tween.tween_property(stop_button, "scale", STOP_BUTTON_BASE_SCALE, STOP_BUTTON_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stop_button_tween.tween_property(stop_button, "modulate", Color(1.0, 1.0, 1.0, 1.0), STOP_BUTTON_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_stop_button_animation() -> void:
	if stop_button_tween != null:
		stop_button_tween.kill()
		stop_button_tween = null
	stop_button.scale = STOP_BUTTON_BASE_SCALE
	stop_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _set_session_locked(value: bool) -> void:
	if session_locked == value:
		return
	session_locked = value
	session_lock_changed.emit(value)


func _apply_facing_layout() -> void:
	var mirrored: bool = facing_sign < 0
	_set_control_x(track, TRACK_LEFT_X, TRACK_RIGHT_X, mirrored)
	_set_control_x(get_node("Panel/Backdrop") as Control, BACKDROP_LEFT_X, BACKDROP_RIGHT_X, mirrored)
	_set_control_x(flash_rect, BACKDROP_LEFT_X, BACKDROP_RIGHT_X, mirrored)
	_set_control_x(timer_track, TIMER_TRACK_LEFT_X, TIMER_TRACK_RIGHT_X, mirrored)
	_set_control_x(result_label, LABEL_LEFT_X, LABEL_RIGHT_X, mirrored)
	_set_control_x(stop_button, BUTTON_LEFT_X, BUTTON_RIGHT_X, mirrored)
	_set_control_x(damage_popup, LABEL_LEFT_X, LABEL_RIGHT_X, mirrored)
	_set_control_x(hp_value_label, HP_LEFT_X, HP_RIGHT_X, mirrored)


func _set_control_x(control: Control, left_x: float, right_x: float, mirrored: bool) -> void:
	var next_left: float = left_x
	var next_right: float = right_x
	if mirrored:
		next_left = PANEL_LAYOUT_WIDTH - right_x
		next_right = PANEL_LAYOUT_WIDTH - left_x
	control.offset_left = next_left
	control.offset_right = next_right
