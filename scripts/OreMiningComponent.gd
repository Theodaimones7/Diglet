extends Node2D
class_name OreMiningComponent

signal hit_requested(cell: Vector2i, damage: int, quality_points: int, result_zone: int, manual: bool)
signal session_lock_changed(locked: bool)

const INVALID_CELL: Vector2i = Vector2i(-999, -999)
const RESULT_RED: int = 0
const RESULT_YELLOW: int = 1
const RESULT_GREEN: int = 2
const RESULT_FLASH_TIME: float = 0.38
const FRAME_WIDTH: float = 36.0
const FRAME_HEIGHT: float = 156.0
const FRAME_INNER_X: float = 9.0
const FRAME_INNER_Y: float = 9.0
const FRAME_INNER_WIDTH: float = 18.0
const FRAME_INNER_HEIGHT: float = 138.0
const BORDER_OFFSET_X: float = -12.0
const BORDER_OFFSET_Y: float = -3.0
const BORDER_WIDTH: float = 78.0
const BORDER_HEIGHT: float = 192.0
const DEBUG_MINING_VISUAL_LAYOUT: bool = false
const TIMER_FRAME_WIDTH: float = 21.0
const TIMER_FRAME_HEIGHT: float = 156.0
const TIMER_INNER_X: float = 0.0
const TIMER_INNER_Y: float = 0.0
const TIMER_FILL_WIDTH: float = 6.0
const DEBUG_MINING_PANEL_POSITION: bool = false
const DEBUG_PROCESS_LOG_STEP: float = 16.0
const MINER_GAP_X: float = 14.0
const FALLBACK_MINER_WIDTH: float = 32.0
const FALLBACK_MINER_HEIGHT: float = 36.0
const TIMER_FILL_HEIGHT: float = 138.0
const DAMAGE_POPUP_TIME: float = 0.95
const DAMAGE_POPUP_MIN_VELOCITY_X: float = 120.0
const DAMAGE_POPUP_MAX_VELOCITY_X: float = 170.0
const DAMAGE_POPUP_MIN_VELOCITY_Y: float = -105.0
const DAMAGE_POPUP_MAX_VELOCITY_Y: float = -65.0
const DAMAGE_POPUP_GRAVITY: float = 300.0
const HIT_SHAKE_TIME: float = 0.18
const HIT_SHAKE_MIN_ANGLE: float = 0.24
const HIT_SHAKE_MAX_ANGLE: float = 0.4
const HIT_SHAKE_SPRING_WAVES: float = 1.35
const HIT_SHAKE_SPRING_DAMPING: float = 1.25
const HIT_SHAKE_SPRING_BOOST: float = 1.45
const NEEDLE_WIDTH: float = 24.0
const NEEDLE_HEIGHT: float = 24.0
const NEEDLE_TIP_X: float = 22.5
const NEEDLE_CENTER_Y: float = 9.0
const PANEL_LAYOUT_WIDTH: float = 210.0
const TRACK_LEFT_X: float = 141.0
const TRACK_RIGHT_X: float = 177.0
const BACKDROP_LEFT_X: float = TRACK_LEFT_X + BORDER_OFFSET_X
const BACKDROP_RIGHT_X: float = BACKDROP_LEFT_X + BORDER_WIDTH
const TIMER_FRAME_LEFT_X: float = 171.0
const TIMER_FRAME_RIGHT_X: float = 192.0
const TIMER_TRACK_LEFT_X: float = 177.0
const TIMER_TRACK_RIGHT_X: float = 183.0
const LABEL_LEFT_X: float = 127.0
const LABEL_RIGHT_X: float = 185.0

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
var damage_popup_color: Color = Color.WHITE
var damage_popup_velocity: Vector2 = Vector2.ZERO
var hit_shake_timer: float = 0.0
var hit_shake_target_rotation: float = 0.0
var left_red_size: float = 0.0
var left_yellow_end: float = 0.0
var green_end: float = 0.0
var right_yellow_end: float = 1.0
var session_locked: bool = false
var last_debug_anchor_position: Vector2 = Vector2.INF
var last_debug_reason: String = ""
var last_visual_layout_signature: String = ""
var last_timer_debug_bucket: int = -1

@onready var panel: Control = get_node("Panel") as Control
@onready var result_label: Label = get_node("Panel/ResultLabel") as Label
@onready var damage_popup: Label = get_node("Panel/DamagePopup") as Label
@onready var hp_value_label: Label = get_node("Panel/HpValue") as Label
@onready var flash_rect: ColorRect = get_node("Panel/Flash") as ColorRect
@onready var timer_frame: TextureRect = get_node("Panel/TimerFrame") as TextureRect
@onready var timer_track: ColorRect = get_node("Panel/TimerTrack") as ColorRect
@onready var timer_fill: ColorRect = get_node("Panel/TimerTrack/TimerFill") as ColorRect
@onready var border: TextureRect = get_node("Panel/Border") as TextureRect
@onready var track: Control = get_node("Panel/Track") as Control
@onready var zone_mask: Control = get_node("Panel/Track/ZoneMask") as Control
@onready var red_top: ColorRect = get_node("Panel/Track/ZoneMask/RedTop") as ColorRect
@onready var yellow_top: ColorRect = get_node("Panel/Track/ZoneMask/YellowTop") as ColorRect
@onready var green_zone: ColorRect = get_node("Panel/Track/ZoneMask/GreenZone") as ColorRect
@onready var yellow_bottom: ColorRect = get_node("Panel/Track/ZoneMask/YellowBottom") as ColorRect
@onready var red_bottom: ColorRect = get_node("Panel/Track/ZoneMask/RedBottom") as ColorRect
@onready var frame_rect: TextureRect = get_node("Panel/Track/Frame") as TextureRect
@onready var needle: TextureRect = get_node("Panel/Track/Needle") as TextureRect
@onready var feedback_player: AudioStreamPlayer2D = get_node("FeedbackPlayer") as AudioStreamPlayer2D


func _ready() -> void:
	rng.randomize()
	visible = false
	panel.visible = false
	result_label.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	_update_panel_pivot()
	_apply_facing_layout()


func setup(board_controller: BoardController, tracked_node: Node2D) -> void:
	board = board_controller
	anchor_node = tracked_node
	_debug_log_simple("setup")


func set_facing_sign(value: int) -> void:
	facing_sign = 1 if value >= 0 else -1
	_apply_facing_layout()
	_debug_log_simple("set_facing_sign")


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
	damage_popup.visible = false
	flash_rect.visible = false
	_randomize_zone_layout()
	_apply_config_visuals()
	_update_hp_value()
	_debug_log_simple("begin_session")


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
	hit_shake_timer = 0.0
	hit_shake_target_rotation = 0.0
	panel.rotation = 0.0
	visible = false
	panel.visible = false
	result_label.visible = false
	damage_popup.visible = false
	flash_rect.visible = false
	_set_session_locked(false)


func get_base_damage() -> int:
	if active_config == null:
		return 1
	return maxi(1, active_config.base_damage)


func _process(delta: float) -> void:
	_update_hit_shake(delta)
	if anchor_node != null:
		global_position = _get_panel_anchor_position()
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
	round_active = true
	round_timer = maxf(0.75, float(active_config.round_duration))
	last_timer_debug_bucket = -1
	marker_position = rng.randf()
	marker_direction = 1.0 if rng.randf() >= 0.5 else -1.0
	_update_needle_position()
	_update_timer_fill()
	_debug_log_simple("start_round")


func _commit_round_result(result_zone: int, manual: bool) -> void:
	if active_config == null:
		return
	var config_snapshot = active_config
	_debug_log_round_result("before_commit", result_zone, manual)
	round_active = false
	session_timer = active_config.minigame_frequency
	last_timer_debug_bucket = -1
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
	_debug_log_simple("commit_round_result")


func _show_result_feedback(result_zone: int, total_damage: int, manual: bool, config_snapshot) -> void:
	var flash_color: Color = Color.WHITE
	if not manual:
		flash_color = Color(0.95, 0.56, 0.18, 1.0)
	else:
		match result_zone:
			RESULT_GREEN:
				flash_color = config_snapshot.green_tint
			RESULT_YELLOW:
				flash_color = config_snapshot.yellow_tint
			_:
				flash_color = config_snapshot.red_tint

	result_label.visible = false
	flash_rect.visible = false
	_start_hit_shake()
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

	if damage_popup_timer <= 0.0:
		if not round_active and result_timer <= 0.0:
			panel.visible = active_config != null
		return

	damage_popup_timer = maxf(0.0, damage_popup_timer - delta)
	if damage_popup_timer <= 0.0:
		damage_popup.visible = false
	else:
		var popup_ratio: float = damage_popup_timer / DAMAGE_POPUP_TIME
		damage_popup_velocity.y += DAMAGE_POPUP_GRAVITY * delta
		damage_popup.position += damage_popup_velocity * delta
		damage_popup.modulate = Color(damage_popup_color.r, damage_popup_color.g, damage_popup_color.b, popup_ratio)


func _apply_config_visuals() -> void:
	if active_config == null:
		return
	panel.modulate = Color.WHITE
	timer_track.color = Color(0.32, 0.32, 0.32, 1.0)
	hp_value_label.modulate = active_config.green_tint
	result_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	damage_popup.modulate = Color(1.0, 1.0, 1.0, 1.0)
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	(get_node("Panel/Backdrop") as ColorRect).color = Color(0.0, 0.0, 0.0, 0.0)

	var red_end_y: float = roundf(FRAME_INNER_HEIGHT * left_red_size)
	var yellow_top_end_y: float = roundf(FRAME_INNER_HEIGHT * left_yellow_end)
	var green_end_y: float = roundf(FRAME_INNER_HEIGHT * green_end)
	var yellow_bottom_end_y: float = roundf(FRAME_INNER_HEIGHT * right_yellow_end)
	var top_red_height: float = red_end_y
	var top_yellow_height: float = yellow_top_end_y - red_end_y
	var green_height: float = green_end_y - yellow_top_end_y
	var bottom_yellow_height: float = yellow_bottom_end_y - green_end_y
	var bottom_red_height: float = FRAME_INNER_HEIGHT - yellow_bottom_end_y

	track.size = Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	border.size = Vector2(BORDER_WIDTH, BORDER_HEIGHT)
	frame_rect.size = Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	timer_frame.size = Vector2(TIMER_FRAME_WIDTH, TIMER_FRAME_HEIGHT)
	timer_track.size = Vector2(TIMER_FILL_WIDTH, TIMER_FILL_HEIGHT)
	timer_fill.size = Vector2(TIMER_FILL_WIDTH, TIMER_FILL_HEIGHT)
	zone_mask.position = Vector2(FRAME_INNER_X, FRAME_INNER_Y)
	zone_mask.size = Vector2(FRAME_INNER_WIDTH, FRAME_INNER_HEIGHT)
	needle.size = Vector2(NEEDLE_WIDTH, NEEDLE_HEIGHT)
	needle.modulate = Color.WHITE
	timer_fill.color = Color(0.95, 0.48, 0.15, 1.0)
	red_top.position = Vector2.ZERO
	red_top.size = Vector2(FRAME_INNER_WIDTH, top_red_height)
	yellow_top.position = Vector2(0.0, red_top.position.y + red_top.size.y)
	yellow_top.size = Vector2(FRAME_INNER_WIDTH, top_yellow_height)
	green_zone.position = Vector2(0.0, yellow_top.position.y + yellow_top.size.y)
	green_zone.size = Vector2(FRAME_INNER_WIDTH, green_height)
	yellow_bottom.position = Vector2(0.0, green_zone.position.y + green_zone.size.y)
	yellow_bottom.size = Vector2(FRAME_INNER_WIDTH, bottom_yellow_height)
	red_bottom.position = Vector2(0.0, yellow_bottom.position.y + yellow_bottom.size.y)
	red_bottom.size = Vector2(FRAME_INNER_WIDTH, bottom_red_height)

	red_top.color = active_config.red_tint
	red_bottom.color = active_config.red_tint
	yellow_top.color = active_config.yellow_tint
	yellow_bottom.color = active_config.yellow_tint
	green_zone.color = active_config.green_tint
	_update_timer_fill()
	_debug_log_visual_layout("apply_config_visuals")


func _update_needle_position() -> void:
	if active_config == null:
		return
	var track_height: float = FRAME_INNER_HEIGHT
	var y_position: float = marker_position * track_height
	needle.position = Vector2(FRAME_INNER_X - NEEDLE_TIP_X, FRAME_INNER_Y + y_position - NEEDLE_CENTER_Y)


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
	var ratio: float = clampf(round_timer / duration, 0.0, 1.0)
	var fill_height: float = TIMER_FILL_HEIGHT * ratio
	timer_fill.position = Vector2(TIMER_INNER_X, TIMER_INNER_Y + (TIMER_FILL_HEIGHT - fill_height))
	timer_fill.size = Vector2(TIMER_FILL_WIDTH, fill_height)
	_debug_log_timer_fill(ratio, fill_height)


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


func _show_damage_popup(damage_amount: int, _popup_color: Color) -> void:
	damage_popup_timer = DAMAGE_POPUP_TIME
	damage_popup.visible = true
	damage_popup.text = "-%d" % damage_amount
	damage_popup_color = hp_value_label.modulate
	damage_popup.modulate = damage_popup_color
	damage_popup.position = _get_damage_popup_origin()
	var popup_direction: float = 1.0 if rng.randf() >= 0.5 else -1.0
	damage_popup_velocity = Vector2(
		rng.randf_range(DAMAGE_POPUP_MIN_VELOCITY_X, DAMAGE_POPUP_MAX_VELOCITY_X) * popup_direction,
		rng.randf_range(DAMAGE_POPUP_MIN_VELOCITY_Y, DAMAGE_POPUP_MAX_VELOCITY_Y)
	)


func _start_hit_shake() -> void:
	hit_shake_timer = HIT_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	hit_shake_target_rotation = rng.randf_range(HIT_SHAKE_MIN_ANGLE, HIT_SHAKE_MAX_ANGLE) * shake_sign


func _update_hit_shake(delta: float) -> void:
	if hit_shake_timer <= 0.0:
		panel.rotation = lerpf(panel.rotation, 0.0, clampf(delta * 24.0, 0.0, 1.0))
		return
	hit_shake_timer = maxf(0.0, hit_shake_timer - delta)
	var target_rotation: float = _get_hit_shake_rotation()
	panel.rotation = lerpf(panel.rotation, target_rotation, clampf(delta * 36.0, 0.0, 1.0))


func _get_hit_shake_rotation() -> float:
	if hit_shake_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - hit_shake_timer / HIT_SHAKE_TIME
	var spring_phase: float = progress * TAU * HIT_SHAKE_SPRING_WAVES
	var damping: float = pow(1.0 - progress, HIT_SHAKE_SPRING_DAMPING)
	return sin(spring_phase) * damping * hit_shake_target_rotation * HIT_SHAKE_SPRING_BOOST


func _update_panel_pivot() -> void:
	var visible_left: float = minf(BACKDROP_LEFT_X, LABEL_LEFT_X)
	var visible_right: float = maxf(BACKDROP_RIGHT_X, TIMER_FRAME_RIGHT_X)
	var visible_top: float = minf(BORDER_OFFSET_Y, 0.0)
	var visible_bottom: float = BORDER_OFFSET_Y + BORDER_HEIGHT
	panel.pivot_offset = Vector2((visible_left + visible_right) * 0.5, (visible_top + visible_bottom) * 0.5)


func _get_damage_popup_origin() -> Vector2:
	var hp_center: Vector2 = hp_value_label.position + hp_value_label.size * 0.5
	return hp_center - damage_popup.size * 0.5


func is_session_active() -> bool:
	return active_config != null


func _set_session_locked(value: bool) -> void:
	if session_locked == value:
		return
	session_locked = value
	session_lock_changed.emit(value)


func _unhandled_input(event: InputEvent) -> void:
	if not round_active:
		return
	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or mouse_event.is_echo():
		return

	_debug_log_simple("left_click_stop_before_commit")
	_debug_log_round_result("global_left_click", _resolve_zone(marker_position), true)
	_commit_round_result(_resolve_zone(marker_position), true)
	get_viewport().set_input_as_handled()


func _apply_facing_layout() -> void:
	var mirrored: bool = false
	_set_control_x(track, TRACK_LEFT_X, TRACK_RIGHT_X, mirrored)
	_set_control_x(border, BACKDROP_LEFT_X, BACKDROP_RIGHT_X, mirrored)
	_set_control_x(get_node("Panel/Backdrop") as Control, BACKDROP_LEFT_X, BACKDROP_RIGHT_X, mirrored)
	_set_control_x(flash_rect, BACKDROP_LEFT_X, BACKDROP_RIGHT_X, mirrored)
	_set_control_x(timer_frame, TIMER_FRAME_LEFT_X, TIMER_FRAME_RIGHT_X, mirrored)
	_set_control_x(timer_track, TIMER_TRACK_LEFT_X, TIMER_TRACK_RIGHT_X, mirrored)
	_set_control_x(result_label, LABEL_LEFT_X, LABEL_RIGHT_X, mirrored)
	_set_control_x(damage_popup, LABEL_LEFT_X, LABEL_RIGHT_X, mirrored)
	_center_control_under_track(hp_value_label, border)
	_debug_log_visual_layout("apply_facing_layout")


func _set_control_x(control: Control, left_x: float, right_x: float, mirrored: bool) -> void:
	var next_left: float = left_x
	var next_right: float = right_x
	if mirrored:
		next_left = PANEL_LAYOUT_WIDTH - right_x
		next_right = PANEL_LAYOUT_WIDTH - left_x
	control.offset_left = next_left
	control.offset_right = next_right


func _center_control_under_track(control: Control, track_control: Control) -> void:
	var control_width: float = control.offset_right - control.offset_left
	var track_center_x: float = (track_control.offset_left + track_control.offset_right) * 0.5
	var half_width: float = control_width * 0.5
	control.offset_left = track_center_x - half_width
	control.offset_right = track_center_x + half_width


func _get_panel_anchor_position() -> Vector2:
	var miner_bounds: Rect2 = _get_anchor_screen_bounds()
	var miner_screen_position: Vector2 = get_viewport().get_canvas_transform() * anchor_node.global_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_left: float = _get_visible_panel_left()
	var visible_right: float = _get_visible_panel_right()
	var left_side_x: float = miner_bounds.position.x - MINER_GAP_X - visible_right
	var right_side_x: float = miner_bounds.end.x + MINER_GAP_X - visible_left
	var min_anchor_x: float = -visible_left
	var max_anchor_x: float = viewport_size.x - visible_right
	var raw_target_x: float = _choose_anchor_x(left_side_x, right_side_x, min_anchor_x, max_anchor_x)
	var target_x: float = clampf(raw_target_x, min_anchor_x, max_anchor_x)
	var feet_y: float = miner_bounds.end.y
	var track_bottom_offset: float = panel.offset_top + border.offset_bottom
	var desired_anchor_y: float = feet_y - track_bottom_offset
	var min_anchor_y: float = -panel.offset_top
	var max_anchor_y: float = viewport_size.y - panel.offset_bottom
	var clamped_anchor_y: float = clampf(desired_anchor_y, min_anchor_y, max_anchor_y)
	var anchor_position: Vector2 = Vector2(target_x, clamped_anchor_y)
	_debug_log_anchor_position(
		anchor_position,
		miner_screen_position,
		miner_bounds,
		raw_target_x,
		target_x,
		desired_anchor_y,
		"process"
	)
	return anchor_position


func _debug_log_simple(reason: String) -> void:
	if not DEBUG_MINING_PANEL_POSITION or anchor_node == null:
		return
	var miner_bounds: Rect2 = _get_anchor_screen_bounds()
	var miner_screen_position: Vector2 = get_viewport().get_canvas_transform() * anchor_node.global_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_left: float = _get_visible_panel_left()
	var visible_right: float = _get_visible_panel_right()
	var left_side_x: float = miner_bounds.position.x - MINER_GAP_X - visible_right
	var right_side_x: float = miner_bounds.end.x + MINER_GAP_X - visible_left
	var min_anchor_x: float = -visible_left
	var max_anchor_x: float = viewport_size.x - visible_right
	var raw_target_x: float = _choose_anchor_x(left_side_x, right_side_x, min_anchor_x, max_anchor_x)
	var target_x: float = clampf(raw_target_x, min_anchor_x, max_anchor_x)
	var feet_y: float = miner_bounds.end.y
	var track_bottom_offset: float = panel.offset_top + border.offset_bottom
	var desired_anchor_y: float = feet_y - track_bottom_offset
	var min_anchor_y: float = -panel.offset_top
	var max_anchor_y: float = viewport_size.y - panel.offset_bottom
	var anchor_position: Vector2 = Vector2(
		target_x,
		clampf(desired_anchor_y, min_anchor_y, max_anchor_y)
	)
	_debug_log_anchor_position(
		anchor_position,
		miner_screen_position,
		miner_bounds,
		raw_target_x,
		target_x,
		desired_anchor_y,
		reason
	)


func _get_visible_panel_left() -> float:
	return panel.offset_left + minf(BACKDROP_LEFT_X, LABEL_LEFT_X)


func _get_visible_panel_right() -> float:
	return panel.offset_left + maxf(maxf(BACKDROP_RIGHT_X, TIMER_FRAME_RIGHT_X), LABEL_RIGHT_X)


func _choose_anchor_x(left_side_x: float, right_side_x: float, min_anchor_x: float, max_anchor_x: float) -> float:
	var preferred_x: float = left_side_x if facing_sign >= 0 else right_side_x
	var fallback_x: float = right_side_x if facing_sign >= 0 else left_side_x
	if preferred_x >= min_anchor_x and preferred_x <= max_anchor_x:
		return preferred_x
	if fallback_x >= min_anchor_x and fallback_x <= max_anchor_x:
		return fallback_x
	return preferred_x


func _debug_log_anchor_position(anchor_position: Vector2, miner_screen_position: Vector2, miner_bounds: Rect2, raw_target_x: float, target_x: float, desired_anchor_y: float, reason: String) -> void:
	if not DEBUG_MINING_PANEL_POSITION:
		return
	if reason == "process" and not panel.visible and active_cell == INVALID_CELL:
		return
	if reason == "process" and last_debug_anchor_position.is_finite() and last_debug_reason == reason:
		var delta: Vector2 = anchor_position - last_debug_anchor_position
		if absf(delta.x) < DEBUG_PROCESS_LOG_STEP and absf(delta.y) < DEBUG_PROCESS_LOG_STEP:
			return
	if reason == "set_facing_sign" and not panel.visible and active_cell == INVALID_CELL:
		return
	print(
		"[OreMiningAnchor] reason=", reason,
		" facing=", facing_sign,
		" active_cell=", active_cell,
		" miner_screen=", miner_screen_position,
		" miner_bounds=", miner_bounds,
		" raw_target_x=", raw_target_x,
		" target_x=", target_x,
		" desired_anchor_y=", desired_anchor_y,
		" final_anchor=", anchor_position,
		" panel_global=", global_position,
		" round_active=", round_active,
		" panel_visible=", panel.visible
	)
	last_debug_anchor_position = anchor_position
	last_debug_reason = reason


func _debug_log_visual_layout(reason: String) -> void:
	if not DEBUG_MINING_VISUAL_LAYOUT:
		return
	var signature: String = "%s|%s|%s|%s|%s|%s|%s" % [
		str(border.offset_left),
		str(border.offset_right),
		str(track.offset_left),
		str(track.offset_right),
		str(timer_frame.offset_left),
		str(timer_track.offset_left),
		str(hp_value_label.offset_left)
	]
	if signature == last_visual_layout_signature:
		return
	print(
		"[OreMiningComponent][Layout] reason=", reason,
		" facing=", facing_sign,
		" panel_width=", panel.offset_right - panel.offset_left,
		" border=(", border.offset_left, ",", border.offset_top, " -> ", border.offset_right, ",", border.offset_bottom, ")",
		" frame=(", track.offset_left, ",", track.offset_top, " -> ", track.offset_right, ",", track.offset_bottom, ")",
		" zones=(", zone_mask.offset_left, ",", zone_mask.offset_top, " -> ", zone_mask.offset_right, ",", zone_mask.offset_bottom, ")",
		" timer_frame=(", timer_frame.offset_left, ",", timer_frame.offset_top, " -> ", timer_frame.offset_right, ",", timer_frame.offset_bottom, ")",
		" timer_track=(", timer_track.offset_left, ",", timer_track.offset_top, " -> ", timer_track.offset_right, ",", timer_track.offset_bottom, ")",
		" hp=(", hp_value_label.offset_left, ",", hp_value_label.offset_top, " -> ", hp_value_label.offset_right, ",", hp_value_label.offset_bottom, ")"
	)
	last_visual_layout_signature = signature


func _debug_log_timer_fill(ratio: float, fill_height: float) -> void:
	if not DEBUG_MINING_VISUAL_LAYOUT:
		return
	if not round_active and ratio <= 0.0:
		return
	var bucket: int = int(floor(fill_height / 8.0))
	if bucket == last_timer_debug_bucket and round_active:
		return
	last_timer_debug_bucket = bucket
	print(
		"[OreMiningComponent][Timer] round_active=", round_active,
		" round_timer=", round_timer,
		" ratio=", ratio,
		" fill_height=", fill_height,
		" fill_pos=", timer_fill.position,
		" fill_size=", timer_fill.size
	)


func _debug_log_round_result(reason: String, result_zone: int, manual: bool) -> void:
	if not DEBUG_MINING_VISUAL_LAYOUT:
		return
	print(
		"[OreMiningComponent][Round] reason=", reason,
		" active_cell=", active_cell,
		" manual=", manual,
		" marker_position=", marker_position,
		" result_zone=", result_zone,
		" round_active=", round_active,
		" session_timer=", session_timer
	)


func _get_anchor_screen_bounds() -> Rect2:
	var anchor_screen_position: Vector2 = get_viewport().get_canvas_transform() * anchor_node.global_position
	if anchor_node is Sprite2D:
		var sprite: Sprite2D = anchor_node as Sprite2D
		var sprite_texture: Texture2D = sprite.texture
		if sprite_texture != null:
			var sprite_scale: Vector2 = sprite.global_scale
			var scaled_size: Vector2 = Vector2(
				sprite_texture.get_width() * absf(sprite_scale.x),
				sprite_texture.get_height() * absf(sprite_scale.y)
			)
			var offset: Vector2 = Vector2(sprite.offset.x * sprite_scale.x, sprite.offset.y * sprite_scale.y)
			var top_left: Vector2 = anchor_screen_position + offset
			if sprite.centered:
				top_left -= scaled_size * 0.5
			return Rect2(top_left, scaled_size)
	if anchor_node is AnimatedSprite2D:
		var animated_sprite: AnimatedSprite2D = anchor_node as AnimatedSprite2D
		var shadow_node: Sprite2D = animated_sprite.get_node_or_null("Shadow") as Sprite2D
		if shadow_node != null and shadow_node.texture != null:
			var shadow_screen_position: Vector2 = get_viewport().get_canvas_transform() * shadow_node.global_position
			var shadow_scale: Vector2 = shadow_node.global_scale
			var shadow_size: Vector2 = Vector2(
				shadow_node.texture.get_width() * absf(shadow_scale.x),
				shadow_node.texture.get_height() * absf(shadow_scale.y)
			)
			var shadow_offset: Vector2 = Vector2(shadow_node.offset.x * shadow_scale.x, shadow_node.offset.y * shadow_scale.y)
			var shadow_top_left: Vector2 = shadow_screen_position + shadow_offset
			if shadow_node.centered:
				shadow_top_left -= shadow_size * 0.5
			return Rect2(shadow_top_left, shadow_size)

		var sprite_scale: Vector2 = animated_sprite.global_scale
		var fallback_size: Vector2 = Vector2(
			FALLBACK_MINER_WIDTH * absf(sprite_scale.x),
			FALLBACK_MINER_HEIGHT * absf(sprite_scale.y)
		)
		var fallback_offset: Vector2 = Vector2(animated_sprite.offset.x * sprite_scale.x, animated_sprite.offset.y * sprite_scale.y)
		var fallback_top_left: Vector2 = anchor_screen_position + fallback_offset
		if animated_sprite.centered:
			fallback_top_left -= fallback_size * 0.5
		return Rect2(fallback_top_left, fallback_size)
	return Rect2(
		anchor_screen_position - Vector2(FALLBACK_MINER_WIDTH * 0.5, FALLBACK_MINER_HEIGHT * 0.5),
		Vector2(FALLBACK_MINER_WIDTH, FALLBACK_MINER_HEIGHT)
	)
