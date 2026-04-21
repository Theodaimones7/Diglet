extends Sprite2D
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
const CELL_STAND_OFFSET_RATIO: float = 0.25

var game_state: GameState
var board: BoardController
var home_position: Vector2 = Vector2.ZERO
var mode: MinerMode = MinerMode.IDLE
var target_cell: Vector2i = INVALID_CELL
var target_position: Vector2 = Vector2.ZERO
var mining_timer: float = 0.0
var rest_timer: float = 0.0
var pickaxe_swing_timer: float = 0.0
var facing_sign: int = 1

@onready var pickaxe: Sprite2D = get_node("Pickaxe") as Sprite2D


func setup(state: GameState, board_controller: BoardController, base_position: Vector2) -> void:
	game_state = state
	board = board_controller
	home_position = base_position
	position = home_position
	_pick_next_target()


func handle_tile_click(cell: Vector2i) -> void:
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

	if game_state == null or board == null:
		return

	if game_state.energy <= 0 and mode != MinerMode.RETURNING_HOME and mode != MinerMode.RESTING:
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

	mining_timer -= delta
	if mining_timer > 0.0:
		return

	game_state.spend_energy(1)
	_face_direction(board.get_cell_world_position(target_cell) - position)
	_start_pickaxe_swing()
	var mined_type: int = board.apply_pickaxe(target_cell)
	if mined_type == BoardController.MINE_ORE:
		game_state.add_carried_ore(1)

	if game_state.energy <= 0:
		_go_home()
		return

	if mined_type == BoardController.MINE_NONE or not board.is_cell_mineable(target_cell):
		_pick_next_target()
	else:
		mining_timer = MINING_INTERVAL


func _process_rest(delta: float) -> void:
	rest_timer -= delta
	if rest_timer > 0.0:
		return

	game_state.convert_carried_ore()
	game_state.restore_energy_step(1)
	if game_state.energy >= GameState.MAX_ENERGY:
		_pick_next_target()
	else:
		rest_timer = REST_TICK_TIME


func _arrive_at_target_cell() -> void:
	if board.is_visible_ladder(target_cell):
		_descend()
		return

	if board.is_cell_mineable(target_cell):
		mode = MinerMode.MINING
		mining_timer = MINING_INTERVAL
	else:
		_pick_next_target()


func _pick_next_target() -> void:
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
	mode = MinerMode.MOVING


func _go_home() -> void:
	board.clear_selection()
	target_cell = INVALID_CELL
	target_position = home_position
	_face_direction(target_position - position)
	mode = MinerMode.RETURNING_HOME


func _start_rest() -> void:
	mode = MinerMode.RESTING
	rest_timer = REST_TICK_TIME


func _descend() -> void:
	mode = MinerMode.DESCENDING
	board.clear_selection()
	board.descend_to_next_floor()
	position = home_position
	_pick_next_target()


func _face_direction(direction: Vector2) -> void:
	if absf(direction.x) < 0.05:
		return
	facing_sign = 1 if direction.x >= 0.0 else -1
	flip_h = facing_sign < 0
	pickaxe.position = Vector2(11.0 * float(facing_sign), 2.0)
	pickaxe.scale = Vector2(float(facing_sign), 1.0)


func _start_pickaxe_swing() -> void:
	pickaxe_swing_timer = PICKAXE_SWING_TIME


func _get_cell_stand_position(cell: Vector2i) -> Vector2:
	var cell_center: Vector2 = board.get_cell_world_position(cell)
	var approach_side: int = -1 if position.x < cell_center.x else 1
	var stand_offset: Vector2 = Vector2(float(BoardController.TILE_SIZE) * CELL_STAND_OFFSET_RATIO * float(approach_side), 0.0)
	return cell_center + stand_offset


func _update_pickaxe_animation(delta: float) -> void:
	if pickaxe == null:
		return

	var base_rotation: float = deg_to_rad(42.0) * float(facing_sign)
	if pickaxe_swing_timer <= 0.0:
		pickaxe.rotation = base_rotation
		return

	pickaxe_swing_timer = maxf(0.0, pickaxe_swing_timer - delta)
	var progress: float = 1.0 - (pickaxe_swing_timer / PICKAXE_SWING_TIME)
	var swing: float = sin(progress * PI)
	pickaxe.rotation = base_rotation + (swing * deg_to_rad(82.0) * float(facing_sign))
