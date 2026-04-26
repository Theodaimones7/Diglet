extends AnimatedSprite2D
class_name MinerAgent

enum MinerMode {
	IDLE,
	MOVING,
	MINING,
	RETURNING_HOME,
	RESTING,
	DESCENDING
}

const INVALID_CELL: Vector2i = Vector2i(-999, -999)
const MOVE_SPEED: float = 120.0
const MINING_INTERVAL: float = 0.45
const REST_TICK_TIME: float = 0.18
const ARRIVE_DISTANCE: float = 3.0
const PICKAXE_SWING_TIME: float = 0.22
const CELL_STAND_OFFSET_RATIO: float = 1.0
const LADDER_FADE_DURATION: float = 0.32
const LADDER_FALL_DURATION: float = 1.65
const LADDER_FALL_LAND_DURATION: float = 0.12
const LADDER_FALL_REBOUND_DURATION: float = 0.16
const LADDER_FALL_LAND_DIP: float = 7.0
const LADDER_FALL_START_Y: float = -96.0
const LADDER_LAND_SQUASH_DURATION: float = 0.07
const LADDER_LAND_STRETCH_DURATION: float = 0.13
const LADDER_LAND_RECOVER_DURATION: float = 0.2
const LADDER_LAND_SQUASH_X: float = 1.14
const LADDER_LAND_SQUASH_Y: float = 0.84
const LADDER_LAND_STRETCH_X: float = 0.96
const LADDER_LAND_STRETCH_Y: float = 1.06
const LADDER_FALL_STRETCH_X: float = 0.96
const LADDER_FALL_STRETCH_Y: float = 1.08
const SLEEP_Z_INTERVAL: float = 0.72
const SLEEP_Z_DURATION: float = 2.1
const SLEEP_Z_START_POSITION: Vector2 = Vector2(7.0, -25.0)
const SLEEP_Z_DRIFT: Vector2 = Vector2(15.0, -36.0)
const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_ATTACK: StringName = &"attack"
const ANIMATION_SLEEP: StringName = &"sleep"
const ANIMATION_FALL: StringName = &"fall"

var game_state: GameState
var board: BoardController
var home_position: Vector2 = Vector2.ZERO
var mode: MinerMode = MinerMode.IDLE
var target_cell: Vector2i = INVALID_CELL
var target_position: Vector2 = Vector2.ZERO
var mining_timer: float = 0.0
var rest_timer: float = 0.0
var pickaxe_swing_timer: float = 0.0
var sleep_z_timer: float = 0.0
var sleep_z_index: int = 0
var facing_sign: int = 1
var descend_tween: Tween = null
var ladder_falling: bool = false
var sleep_z_labels: Array[Label] = []
var sleep_z_tweens: Array[Tween] = []

var ore_mining

@onready var sleep_z_1: Label = $SleepZ1 as Label
@onready var sleep_z_2: Label = $SleepZ2 as Label
@onready var sleep_z_3: Label = $SleepZ3 as Label


func _ready() -> void:
	sleep_z_labels = [sleep_z_1, sleep_z_2, sleep_z_3]
	sleep_z_tweens.resize(sleep_z_labels.size())
	_hide_sleep_z_effect()


func setup(state: GameState, board_controller: BoardController, base_position: Vector2, mining_component) -> void:
	game_state = state
	board = board_controller
	ore_mining = mining_component
	home_position = base_position
	position = home_position
	play(ANIMATION_IDLE)
	ore_mining.setup(board_controller, self)
	ore_mining.set_facing_sign(facing_sign)
	if not ore_mining.hit_requested.is_connected(_on_ore_hit_requested):
		ore_mining.hit_requested.connect(_on_ore_hit_requested)
	_pick_next_target()


func handle_tile_click(cell: Vector2i) -> void:
	if mode == MinerMode.DESCENDING:
		return

	if game_state.energy <= 0:
		_go_home()
		return

	if board.is_visible_ladder(cell):
		board.clear_selection()
		_move_to_cell(cell)
		return

	if board.is_rock_cell(cell):
		board.select_cell(cell)
		_pick_next_target()


func _process(delta: float) -> void:
	_update_pickaxe_animation(delta)
	_update_sleep_z_effect(delta)

	if game_state == null or board == null:
		return
	if board.is_reveal_active() and mode != MinerMode.DESCENDING:
		ore_mining.cancel_session()
		pickaxe_swing_timer = 0.0
		mode = MinerMode.IDLE
		_update_character_animation()
		return

	if game_state.energy <= 0 and mode != MinerMode.RETURNING_HOME and mode != MinerMode.RESTING and mode != MinerMode.DESCENDING:
		_go_home()

	match mode:
		MinerMode.IDLE:
			_pick_next_target()
		MinerMode.MOVING:
			_process_movement(delta, false)
		MinerMode.MINING:
			_process_mining(delta)
		MinerMode.RETURNING_HOME:
			_process_movement(delta, true)
		MinerMode.RESTING:
			_process_rest(delta)
		MinerMode.DESCENDING:
			pass

	if mode != MinerMode.MINING or not board.is_ore_cell_mineable(target_cell):
		ore_mining.cancel_session()

	_update_character_animation()


func _process_movement(delta: float, returning_home: bool) -> void:
	var to_target: Vector2 = target_position - position
	if to_target.length() <= ARRIVE_DISTANCE:
		position = target_position
		if returning_home:
			_start_rest()
		else:
			_arrive_at_target_cell()
		return

	_face_direction(to_target)
	position += to_target.normalized() * MOVE_SPEED * delta


func _process_mining(delta: float) -> void:
	if game_state.energy <= 0:
		_go_home()
		return

	if board.is_ore_cell_mineable(target_cell):
		ore_mining.begin_session(target_cell)
		return

	mining_timer -= delta
	if mining_timer > 0.0:
		return

	game_state.spend_energy(1)
	_face_direction(board.get_cell_world_position(target_cell) - position)
	_start_pickaxe_swing()
	var rock_damage: int = game_state.get_rock_damage()
	var outcome = board.apply_pickaxe(target_cell, rock_damage, 0)

	if game_state.energy <= 0:
		_go_home()
		return

	if outcome.mine_type == BoardController.MINE_NONE or not board.is_cell_mineable(target_cell):
		_pick_next_target()
	else:
		mining_timer = _get_target_mining_interval()


func _process_rest(delta: float) -> void:
	rest_timer -= delta
	if rest_timer > 0.0:
		return

	game_state.restore_energy_step(1)
	if game_state.energy >= game_state.get_max_energy():
		_pick_next_target()
	else:
		rest_timer = REST_TICK_TIME


func _arrive_at_target_cell() -> void:
	if board.is_visible_ladder(target_cell):
		_descend()
		return

	if board.is_cell_mineable(target_cell):
		mode = MinerMode.MINING
		mining_timer = 0.0 if board.is_ore_cell_mineable(target_cell) else _get_target_mining_interval()
		if board.is_ore_cell_mineable(target_cell):
			ore_mining.begin_session(target_cell)
	else:
		_pick_next_target()


func _pick_next_target() -> void:
	if board.is_reveal_active():
		mode = MinerMode.IDLE
		target_cell = INVALID_CELL
		return

	if game_state.energy <= 0:
		_go_home()
		return

	var next_cell: Vector2i = board.choose_next_auto_target()
	if next_cell == INVALID_CELL:
		_go_home()
		return

	_move_to_cell(next_cell)


func _move_to_cell(cell: Vector2i) -> void:
	target_cell = cell
	target_position = _get_cell_stand_position(cell)
	_face_direction(target_position - position)
	ore_mining.cancel_session()
	mode = MinerMode.MOVING


func _get_target_mining_interval() -> float:
	if board == null or not board.is_valid_cell(target_cell):
		return MINING_INTERVAL
	if board.is_ore_cell_mineable(target_cell):
		return MINING_INTERVAL
	return board.get_rock_dig_time(target_cell)


func _go_home(_interrupt_minigame: bool = true) -> void:
	board.clear_selection()
	target_cell = INVALID_CELL
	target_position = home_position
	_face_direction(target_position - position)
	ore_mining.cancel_session()
	mode = MinerMode.RETURNING_HOME


func _start_rest() -> void:
	mode = MinerMode.RESTING
	rest_timer = REST_TICK_TIME
	sleep_z_timer = 0.0


func _descend() -> void:
	mode = MinerMode.DESCENDING
	board.clear_selection()
	ore_mining.cancel_session()
	pickaxe_swing_timer = 0.0
	board.set_input_locked(true)

	if descend_tween != null:
		descend_tween.kill()
		descend_tween = null

	var ladder_world_position: Vector2 = board.get_cell_world_position(target_cell)
	var base_scale: Vector2 = scale
	play(ANIMATION_IDLE)
	descend_tween = create_tween()
	descend_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), LADDER_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await descend_tween.finished
	descend_tween = null

	board.descend_to_next_floor()

	global_position = Vector2(ladder_world_position.x, LADDER_FALL_START_Y)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2(base_scale.x * LADDER_FALL_STRETCH_X, base_scale.y * LADDER_FALL_STRETCH_Y)
	ladder_falling = true
	play(ANIMATION_FALL)
	descend_tween = create_tween()
	var land_position: Vector2 = ladder_world_position + Vector2(0.0, LADDER_FALL_LAND_DIP)
	var fall_duration: float = LADDER_FALL_DURATION - LADDER_FALL_REBOUND_DURATION - LADDER_FALL_LAND_DURATION * 2.0
	descend_tween.tween_property(self, "global_position", land_position, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await descend_tween.finished
	descend_tween = null

	_finish_ladder_fall_animation()
	descend_tween = create_tween()
	var squash_scale: Vector2 = Vector2(base_scale.x * LADDER_LAND_SQUASH_X, base_scale.y * LADDER_LAND_SQUASH_Y)
	var stretch_scale: Vector2 = Vector2(base_scale.x * LADDER_LAND_STRETCH_X, base_scale.y * LADDER_LAND_STRETCH_Y)
	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(self, "scale", squash_scale, LADDER_LAND_SQUASH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", stretch_scale, LADDER_LAND_STRETCH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scale_tween.tween_property(self, "scale", base_scale, LADDER_LAND_RECOVER_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	descend_tween.tween_property(self, "global_position", ladder_world_position, LADDER_FALL_REBOUND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	descend_tween.tween_property(self, "global_position", land_position, LADDER_FALL_LAND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	descend_tween.tween_property(self, "global_position", ladder_world_position, LADDER_FALL_LAND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await descend_tween.finished
	descend_tween = null
	scale = base_scale

	target_cell = INVALID_CELL
	board.set_input_locked(false)
	_pick_next_target()


func _finish_ladder_fall_animation() -> void:
	ladder_falling = false
	play(ANIMATION_IDLE)


func _face_direction(direction: Vector2) -> void:
	if absf(direction.x) < 0.05:
		return
	facing_sign = 1 if direction.x >= 0.0 else -1
	flip_h = facing_sign > 0
	ore_mining.set_facing_sign(facing_sign)


func _start_pickaxe_swing() -> void:
	pickaxe_swing_timer = PICKAXE_SWING_TIME
	play(ANIMATION_ATTACK)
	set_frame_and_progress(0, 0.0)


func _get_cell_stand_position(cell: Vector2i) -> Vector2:
	var cell_center: Vector2 = board.get_cell_world_position(cell)
	if board.is_visible_ladder(cell):
		return cell_center

	var approach_side: int = -1 if position.x < cell_center.x else 1
	var stand_offset: Vector2 = Vector2(float(BoardController.TILE_SIZE) * CELL_STAND_OFFSET_RATIO * float(approach_side), 0.0)
	return cell_center + stand_offset


func _update_pickaxe_animation(delta: float) -> void:
	if pickaxe_swing_timer <= 0.0:
		return

	pickaxe_swing_timer = maxf(0.0, pickaxe_swing_timer - delta)


func _update_sleep_z_effect(delta: float) -> void:
	if sleep_z_labels.is_empty():
		return

	if mode != MinerMode.RESTING:
		_hide_sleep_z_effect()
		return

	sleep_z_timer -= delta
	if sleep_z_timer > 0.0:
		return

	sleep_z_timer = SLEEP_Z_INTERVAL
	_spawn_sleep_z()


func _spawn_sleep_z() -> void:
	var label_index: int = sleep_z_index % sleep_z_labels.size()
	sleep_z_index += 1
	var z_label: Label = sleep_z_labels[label_index]
	if z_label == null:
		return

	var active_tween: Tween = sleep_z_tweens[label_index]
	if active_tween != null:
		active_tween.kill()

	var side_offset: float = 2.0 * float(label_index)
	z_label.visible = true
	z_label.position = SLEEP_Z_START_POSITION + Vector2(side_offset, -side_offset)
	z_label.scale = Vector2.ONE * (1.0 - 0.1 * float(label_index))
	z_label.rotation = 0.0
	z_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var drift_position: Vector2 = SLEEP_Z_START_POSITION + SLEEP_Z_DRIFT + Vector2(side_offset * 1.5, -side_offset)
	var tween: Tween = create_tween()
	sleep_z_tweens[label_index] = tween
	tween.set_parallel(true)
	tween.tween_property(z_label, "position", drift_position, SLEEP_Z_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(z_label, "scale", z_label.scale * 1.25, SLEEP_Z_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(z_label, "rotation", -0.18, SLEEP_Z_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(z_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), SLEEP_Z_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_sleep_z_finished.bind(label_index))


func _hide_sleep_z_effect() -> void:
	for label_index: int in range(sleep_z_labels.size()):
		var z_label: Label = sleep_z_labels[label_index]
		if z_label != null:
			z_label.visible = false
			z_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var active_tween: Tween = sleep_z_tweens[label_index]
		if active_tween != null:
			active_tween.kill()
			sleep_z_tweens[label_index] = null


func _on_sleep_z_finished(label_index: int) -> void:
	if label_index < 0 or label_index >= sleep_z_labels.size():
		return

	var z_label: Label = sleep_z_labels[label_index]
	if z_label != null:
		z_label.visible = false
	sleep_z_tweens[label_index] = null


func _update_character_animation() -> void:
	if pickaxe_swing_timer > 0.0:
		if animation != ANIMATION_ATTACK:
			play(ANIMATION_ATTACK)
		return

	match mode:
		MinerMode.DESCENDING:
			var next_animation: StringName = ANIMATION_FALL if ladder_falling else ANIMATION_IDLE
			if animation != next_animation:
				play(next_animation)
		MinerMode.MOVING, MinerMode.RETURNING_HOME:
			if animation != ANIMATION_WALK:
				play(ANIMATION_WALK)
		MinerMode.RESTING:
			if animation != ANIMATION_SLEEP:
				play(ANIMATION_SLEEP)
		_:
			if animation != ANIMATION_IDLE:
				play(ANIMATION_IDLE)


func _on_ore_hit_requested(cell: Vector2i, damage: int, quality_points: int, _result_zone: int, _manual: bool) -> void:
	if board == null or not board.is_ore_cell_mineable(cell):
		return

	_face_direction(board.get_cell_world_position(cell) - position)
	_start_pickaxe_swing()
	if game_state.energy > 0:
		game_state.spend_energy(1)

	var total_damage: int = maxi(1, damage)
	var outcome = board.apply_pickaxe(cell, total_damage, quality_points, _result_zone)
	if outcome.mine_type == BoardController.MINE_ORE and outcome.broke_target:
		game_state.add_carried_ore_chunk(outcome.resource_type, outcome.tier, outcome.reward_chunk_count)
		ore_mining.cancel_session()
		if mode == MinerMode.MINING:
			_pick_next_target()
