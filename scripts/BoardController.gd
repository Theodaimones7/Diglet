@tool
extends Node2D
class_name BoardController

const FindItemCatalogScript = preload("res://scripts/finds/FindItemCatalog.gd")
const FindDropResolverScript = preload("res://scripts/finds/FindDropResolver.gd")

signal tile_clicked(cell: Vector2i)
signal ore_chunk_mined(resource_type: String, tier: String, cell: Vector2i)
signal find_drop_ready
signal relic_collection_requested(relic_id: String, item_ids: Array[String])
signal state_changed

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 4
const TILE_SIZE: int = 52
const TEXTURE_TILE_SIZE: int = 44
const CRUSH_STAGE_FRAME_WIDTH: int = 44
const CRUSH_STAGE_FRAME_HEIGHT: int = 43
const VISIBLE_TILE_SIZE: int = 40
const TILE_SOURCE_INSET: int = 2
const TILE_EDGE_OVERLAP: float = 2.0
const TILE_TEXTURE_SCALE: float = (float(TILE_SIZE) + TILE_EDGE_OVERLAP) / float(VISIBLE_TILE_SIZE)
const CELL_COUNT: int = GRID_WIDTH * GRID_HEIGHT
const INVALID_CELL: Vector2i = Vector2i(-999, -999)

const MINE_NONE: int = 0
const MINE_ROCK: int = 1
const MINE_ORE: int = 2
const HP_BAR_VISIBLE_TIME: float = 0.85
const NEXT_LEVEL_TINT: Color = Color(0.2, 0.2, 0.24, 1.0)
const REVEAL_GROUP_DELAY: float = 0.095
const REVEAL_TILE_DURATION: float = 0.86
const REVEAL_START_EXTRA_DEPTH: float = 160.0
const REVEAL_OVERSHOOT: float = 42.0
const REVEAL_SETTLE_DIP: float = 16.0
const REVEAL_SETTLE_REBOUND: float = 8.0
const REVEAL_SETTLE_FINAL_DIP: float = 3.0
const REVEAL_CENTER: Vector2 = Vector2(float(GRID_WIDTH - 1) * 0.5, float(GRID_HEIGHT - 1) * 0.5)
const HIT_SHAKE_TIME: float = 0.18
const HIT_SHAKE_MIN_ANGLE: float = 0.24
const HIT_SHAKE_MAX_ANGLE: float = 0.4
const HIT_SHAKE_SPRING_WAVES: float = 1.35
const HIT_SHAKE_SPRING_DAMPING: float = 1.25
const HIT_SHAKE_SPRING_BOOST: float = 1.45
const HIT_PARTICLE_AMOUNT: int = 14
const HIT_PARTICLE_LIFETIME: float = 0.42
const HIT_PARTICLE_SPEED_MIN: float = 72.0
const HIT_PARTICLE_SPEED_MAX: float = 132.0
const HIT_PARTICLE_GRAVITY: Vector2 = Vector2(0.0, 230.0)
const HIT_PARTICLE_ROCK_COLOR: Color = Color(0.72, 0.62, 0.48, 1.0)
const HIT_PARTICLE_ORE_COLOR: Color = Color(0.95, 0.76, 0.28, 1.0)
const RELIC_CELL_SPAN: int = 2
const RELIC_VISIBLE_SIZE: float = float(TILE_SIZE * RELIC_CELL_SPAN) - 8.0
const RELIC_COLLECT_DISTANCE: float = 18.0

var rock_texture: Texture2D = preload("res://assets/tiles/rock.png")
var crush_stage_texture: Texture2D = preload("res://assets/tiles/crush stage.png")
var ore_texture: Texture2D = preload("res://assets/tiles/ore_tiles.png")
var ladder_texture: Texture2D = preload("res://assets/props/ladder.png")
var ore_definitions: Array[Resource] = [
	preload("res://data/ores/copper_vein_config.tres") as Resource,
	preload("res://data/ores/iron_vein_config.tres") as Resource,
	preload("res://data/ores/crystal_vein_config.tres") as Resource
]

var game_state: GameState
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rock_present: Array[bool] = []
var rock_hp: Array[int] = []
var ore_present: Array[bool] = []
var ore_deposit_ids: Array[int] = []
var ore_deposits: Array[OreDeposit] = []
var rock_layer_ids: Array[String] = []
var rock_sprites: Array[Sprite2D] = []
var crush_stage_sprites: Array[Sprite2D] = []
var ore_sprites: Array[Sprite2D] = []
var next_level_sprites: Array[Sprite2D] = []
var hp_bar_roots: Array[Node2D] = []
var hp_bar_fills: Array[ColorRect] = []
var hp_bar_timers: Array[float] = []
var cell_shake_timers: Array[float] = []
var cell_shake_targets: Array[float] = []
var ladder_sprite: Sprite2D
var ladder_cell: Vector2i = INVALID_CELL
var selected_cell: Vector2i = INVALID_CELL
var next_floor_layout: FloorLayout
var input_locked: bool = false
var reveal_tween: Tween = null
var reveal_active: bool = false
var hit_particle_texture: Texture2D = null
var rock_layer_catalog: RockLayerCatalog = RockLayerCatalog.new()
var find_catalog
var find_drop_resolver = FindDropResolverScript.new()
var current_find_drop: Dictionary = {}
var relic_sprites: Dictionary = {}
var active_relic_id: String = ""

@onready var preview_layer: Node2D = get_node("PreviewLayer") as Node2D
@onready var ore_layer: Node2D = get_node("OreLayer") as Node2D
@onready var relic_layer: Node2D = get_node_or_null("RelicLayer") as Node2D
@onready var ladder_layer: Node2D = get_node("LadderLayer") as Node2D
@onready var rock_layer: Node2D = get_node("RockLayer") as Node2D


func _get_rock_source_rect() -> Rect2:
	return Rect2(
		float(TILE_SOURCE_INSET),
		float(TILE_SOURCE_INSET),
		float(VISIBLE_TILE_SIZE),
		float(VISIBLE_TILE_SIZE)
	)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var source_rect: Rect2 = _get_rock_source_rect()
	var preview_size: float = float(VISIBLE_TILE_SIZE) * TILE_TEXTURE_SCALE
	var preview_offset: float = (preview_size - float(TILE_SIZE)) * 0.5
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell_position: Vector2 = Vector2(float(x * TILE_SIZE) - preview_offset, float(y * TILE_SIZE) - preview_offset)
			var target_rect: Rect2 = Rect2(cell_position, Vector2(preview_size, preview_size))
			draw_texture_rect_region(rock_texture, target_rect, source_rect)


class OreDeposit:
	var cells: Array[Vector2i] = []
	var config: Resource
	var max_hp: int = 50
	var current_hp: int = 50
	var quality_score: int = 0


class MiningHitOutcome:
	var mine_type: int = MINE_NONE
	var applied_damage: int = 0
	var broke_target: bool = false
	var resource_type: String = ""
	var tier: String = ""
	var reward_label: String = ""
	var reward_chunk_count: int = 0


class FloorLayout:
	var ore_present: Array[bool] = []
	var ore_deposit_ids: Array[int] = []
	var ore_deposits: Array[OreDeposit] = []
	var ladder_cell: Vector2i = Vector2i.ZERO


func setup(state: GameState, saved_state: Dictionary = {}) -> void:
	game_state = state
	rng.randomize()
	find_catalog = game_state.find_catalog if game_state != null else FindItemCatalogScript.new()
	if find_catalog != null and not find_catalog.loaded:
		find_catalog.load_items()
	find_drop_resolver.set_rng(rng)
	find_drop_resolver.load_config()
	_build_tile_nodes()
	if not load_from_save_data(saved_state):
		generate_floor()
	else:
		_build_relic_sprites()
		_play_floor_reveal()
		if has_pending_completed_relic_reward():
			find_drop_ready.emit()


func to_save_data() -> Dictionary:
	return {
		"rock_present": _serialize_bool_array(rock_present),
		"rock_hp": _serialize_int_array(rock_hp),
		"rock_layer_ids": _serialize_string_array(rock_layer_ids),
		"ore_present": _serialize_bool_array(ore_present),
		"ore_deposit_ids": _serialize_int_array(ore_deposit_ids),
		"ore_deposits": _serialize_ore_deposits(),
		"ladder_cell": _serialize_cell(ladder_cell),
		"current_find_drop": current_find_drop.duplicate(true)
	}


func load_from_save_data(save_data: Dictionary) -> bool:
	if save_data.is_empty():
		return false

	var loaded_rock_present: Array[bool] = _read_bool_array(save_data.get("rock_present", []), CELL_COUNT)
	var loaded_rock_hp: Array[int] = _read_int_array(save_data.get("rock_hp", []), CELL_COUNT)
	var loaded_rock_layer_ids: Array[String] = _read_string_array(save_data.get("rock_layer_ids", []), CELL_COUNT)
	var loaded_ore_present: Array[bool] = _read_bool_array(save_data.get("ore_present", []), CELL_COUNT)
	var loaded_ore_deposit_ids: Array[int] = _read_int_array(save_data.get("ore_deposit_ids", []), CELL_COUNT)
	var loaded_ladder_cell: Vector2i = _read_cell(save_data.get("ladder_cell", {}), INVALID_CELL)
	var loaded_find_drop: Dictionary = _read_find_drop(save_data.get("current_find_drop", {}))

	if loaded_rock_present.size() != CELL_COUNT:
		return false
	if loaded_rock_hp.size() != CELL_COUNT:
		return false
	if loaded_rock_layer_ids.size() != CELL_COUNT:
		loaded_rock_layer_ids = _create_default_rock_layer_ids()
	if not _validate_rock_layer_ids(loaded_rock_layer_ids):
		return false
	if loaded_ore_present.size() != CELL_COUNT:
		loaded_ore_present = _create_empty_ore_present()
	if loaded_ore_deposit_ids.size() != CELL_COUNT:
		loaded_ore_deposit_ids = _create_empty_ore_deposit_ids()
	if not is_valid_cell(loaded_ladder_cell):
		return false

	rock_present = loaded_rock_present
	rock_hp = loaded_rock_hp
	rock_layer_ids = loaded_rock_layer_ids
	ore_present = _create_empty_ore_present()
	ore_deposit_ids = _create_empty_ore_deposit_ids()
	ore_deposits.clear()
	ladder_cell = loaded_ladder_cell
	current_find_drop = loaded_find_drop
	if current_find_drop.is_empty():
		current_find_drop = _resolve_current_floor_drop()
	_update_relic_reveal_state()
	selected_cell = INVALID_CELL
	for index: int in range(hp_bar_timers.size()):
		hp_bar_timers[index] = 0.0
		hp_bar_roots[index].visible = false
	_update_visuals()
	return true


func _process(delta: float) -> void:
	for index: int in range(hp_bar_timers.size()):
		if hp_bar_timers[index] <= 0.0:
			continue
		hp_bar_timers[index] = maxf(0.0, hp_bar_timers[index] - delta)
		if hp_bar_timers[index] <= 0.0:
			var bar_root: Node2D = hp_bar_roots[index]
			bar_root.visible = false

	_update_cell_shakes(delta)


func generate_floor() -> void:
	var floor_layout: FloorLayout = next_floor_layout
	if floor_layout == null:
		floor_layout = _create_floor_layout()
	next_floor_layout = _create_floor_layout()

	rock_present.clear()
	rock_hp.clear()
	rock_layer_ids.clear()
	ore_present.clear()
	ore_deposit_ids.clear()
	ore_deposits.clear()
	current_find_drop = _resolve_current_floor_drop()
	selected_cell = INVALID_CELL

	for index: int in range(CELL_COUNT):
		var cell: Vector2i = _index_to_cell(index)
		var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_layer_for_cell(cell, 0)
		rock_present.append(true)
		rock_hp.append(rock_layer.max_hp)
		rock_layer_ids.append(rock_layer.id)
		ore_present.append(false)
		ore_deposit_ids.append(-1)
		hp_bar_timers[index] = 0.0
		hp_bar_roots[index].visible = false

	ore_deposits.clear()
	ladder_cell = floor_layout.ladder_cell
	_update_relic_reveal_state()
	_build_relic_sprites()
	_update_visuals()
	_play_floor_reveal()
	if has_pending_completed_relic_reward():
		find_drop_ready.emit()
	state_changed.emit()


func get_cell_world_position(cell: Vector2i) -> Vector2:
	var local_position: Vector2 = Vector2(
		float(cell.x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
		float(cell.y * TILE_SIZE) + float(TILE_SIZE) * 0.5
	)
	return to_global(local_position)


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func is_rock_cell(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	var index: int = _cell_to_index(cell)
	return rock_present[index]


func is_visible_ladder(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	if cell != ladder_cell:
		return false
	var index: int = _cell_to_index(cell)
	return not rock_present[index]


func is_cell_mineable(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	var index: int = _cell_to_index(cell)
	if rock_present[index]:
		return true
	return false


func is_ore_cell_mineable(_cell: Vector2i) -> bool:
	return false


func get_ore_deposit_id(cell: Vector2i) -> int:
	if not is_valid_cell(cell):
		return -1
	var index: int = _cell_to_index(cell)
	if not ore_present[index]:
		return -1
	return ore_deposit_ids[index]


func get_ore_config_for_cell(cell: Vector2i):
	var deposit_id: int = get_ore_deposit_id(cell)
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return null
	return ore_deposits[deposit_id].config


func get_ore_current_hp(cell: Vector2i) -> int:
	var deposit_id: int = get_ore_deposit_id(cell)
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return 0
	return ore_deposits[deposit_id].current_hp


func get_ore_max_hp(cell: Vector2i) -> int:
	var deposit_id: int = get_ore_deposit_id(cell)
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return 0
	return ore_deposits[deposit_id].max_hp


func get_rock_dig_time(cell: Vector2i) -> float:
	if not is_valid_cell(cell):
		return 0.45
	var index: int = _cell_to_index(cell)
	var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_rock_layer_for_index(index)
	return rock_layer.dig_time


func apply_pickaxe(cell: Vector2i, damage: int = 1, _quality_points: int = 0, _result_zone: int = -1) -> MiningHitOutcome:
	var outcome: MiningHitOutcome = MiningHitOutcome.new()
	if not is_valid_cell(cell):
		return outcome

	var index: int = _cell_to_index(cell)
	if rock_present[index]:
		var rock_damage: int = maxi(1, damage)
		var rock_max_hp: int = _get_rock_max_hp(index)
		rock_hp[index] = maxi(0, rock_hp[index] - rock_damage)
		outcome.applied_damage = rock_damage
		_show_hp_bar(index, rock_hp[index], rock_max_hp)
		if rock_hp[index] <= 0:
			rock_present[index] = false
		_update_visuals()
		_update_relic_reveal_state()
		_play_hit_feedback(cell, MINE_ROCK)
		state_changed.emit()
		outcome.mine_type = MINE_ROCK
		return outcome

	return outcome


func select_cell(cell: Vector2i) -> void:
	selected_cell = cell
	_update_rock_highlight()


func clear_selection() -> void:
	selected_cell = INVALID_CELL
	_update_rock_highlight()


func set_input_locked(value: bool) -> void:
	input_locked = value


func is_reveal_active() -> bool:
	return reveal_active


func descend_to_next_floor() -> void:
	game_state.next_floor()
	generate_floor()


func has_unclaimed_find_drop() -> bool:
	return has_pending_completed_relic_reward()


func has_pending_completed_relic_reward() -> bool:
	var relic: Dictionary = _get_pending_completed_relic()
	if relic.is_empty():
		return false
	if bool(relic.get("drop_claimed", false)):
		return false
	if not bool(relic.get("minigame_completed", false)):
		return false
	return not str(relic.get("item_id", "")).is_empty()


func get_current_find_drop_items() -> Array[String]:
	var result: Array[String] = []
	if not has_pending_completed_relic_reward():
		return result
	var relic: Dictionary = _get_active_relic_data()
	var item_id: String = str(relic.get("item_id", ""))
	if not item_id.is_empty():
		result.append(item_id)
	return result


func claim_current_find_drop_to_inventory() -> bool:
	if game_state == null or not has_pending_completed_relic_reward():
		return false
	var depth: int = int(current_find_drop.get("depth", game_state.floor_number))
	var item_ids: Array[String] = get_current_find_drop_items()
	if game_state.get_find_inventory_count() + item_ids.size() > game_state.get_find_inventory_capacity():
		return false
	var claimed_any: bool = false
	for item_id: String in item_ids:
		if game_state.add_found_item(item_id, depth):
			claimed_any = true
	if claimed_any:
		_mark_current_find_drop_claimed(item_ids)
	return claimed_any


func sell_current_find_drop() -> int:
	if game_state == null or find_catalog == null or not has_pending_completed_relic_reward():
		return 0
	var item_ids: Array[String] = get_current_find_drop_items()
	var total_value: int = 0
	var depth: int = int(current_find_drop.get("depth", game_state.floor_number))
	for item_id: String in item_ids:
		var base_value: int = find_catalog.get_value(item_id)
		if base_value > 0:
			total_value += maxi(1, int(roundf(float(base_value) * game_state.get_sell_multiplier())))
		game_state.record_museum_item(item_id, depth)
	if total_value <= 0:
		return 0
	game_state.currency += total_value
	game_state.currency_changed.emit()
	game_state.stats_changed.emit()
	_mark_current_find_drop_claimed(item_ids)
	return total_value


func _mark_current_find_drop_claimed(item_ids: Array[String]) -> void:
	_set_active_relic_field("drop_claimed", true)
	_set_active_relic_field("collected", true)
	current_find_drop["drop_claimed"] = _are_all_relics_claimed()
	_hide_active_relic_sprite()
	if game_state != null:
		game_state.record_find_drop_result(item_ids)
	active_relic_id = ""
	state_changed.emit()


func _are_all_relics_claimed() -> bool:
	var relics: Array[Dictionary] = _get_relics()
	if relics.is_empty():
		return true
	for relic: Dictionary in relics:
		if not bool(relic.get("drop_claimed", false)):
			return false
	return true


func get_next_collectable_relic_id() -> String:
	_update_relic_reveal_state()
	var relics: Array[Dictionary] = _get_relics()
	for relic: Dictionary in relics:
		if bool(relic.get("revealed", false)) and not bool(relic.get("collected", false)) and not bool(relic.get("minigame_completed", false)):
			return str(relic.get("relic_id", ""))
	return ""


func get_relic_center_world_position(relic_id: String) -> Vector2:
	var relic: Dictionary = _get_relic_by_id(relic_id)
	if relic.is_empty():
		return global_position
	var local_position: Vector2 = _read_vector2(relic.get("position", {}), Vector2.ZERO)
	return to_global(local_position)


func get_relic_collect_world_position(relic_id: String, approach_world_position: Vector2) -> Vector2:
	var relic: Dictionary = _get_relic_by_id(relic_id)
	if relic.is_empty():
		return global_position
	var approach_local_position: Vector2 = to_local(approach_world_position)
	return to_global(_get_relic_collect_local_position(relic, approach_local_position))


func request_relic_collection(relic_id: String) -> bool:
	var relic: Dictionary = _get_relic_by_id(relic_id)
	if relic.is_empty():
		return false
	if not bool(relic.get("revealed", false)) or bool(relic.get("collected", false)):
		return false
	active_relic_id = relic_id
	var item_ids: Array[String] = [str(relic.get("item_id", ""))]
	relic_collection_requested.emit(relic_id, item_ids)
	return true


func complete_active_relic_minigame() -> void:
	if active_relic_id.is_empty():
		return
	_set_active_relic_field("minigame_completed", true)
	find_drop_ready.emit()
	state_changed.emit()


func choose_next_auto_target() -> Vector2i:
	var selected_target: Vector2i = selected_cell
	if selected_target != INVALID_CELL and is_cell_mineable(selected_target):
		return selected_target

	if _is_floor_fully_excavated() and is_visible_ladder(ladder_cell):
		return ladder_cell

	var rocks: Array[Vector2i] = []
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			if is_rock_cell(cell):
				rocks.append(cell)

	if rocks.is_empty():
		return INVALID_CELL

	var picked_index: int = rng.randi_range(0, rocks.size() - 1)
	var picked_cell: Vector2i = rocks[picked_index]
	return picked_cell


func choose_next_collectable_relic_id() -> String:
	return get_next_collectable_relic_id()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked or reveal_active:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var local_position: Vector2 = to_local(mouse_event.position)
	if local_position.x < 0.0 or local_position.y < 0.0:
		return
	if local_position.x >= float(GRID_WIDTH * TILE_SIZE) or local_position.y >= float(GRID_HEIGHT * TILE_SIZE):
		return

	var cell: Vector2i = Vector2i(
		int(floor(local_position.x / float(TILE_SIZE))),
		int(floor(local_position.y / float(TILE_SIZE)))
	)
	tile_clicked.emit(cell)
	get_viewport().set_input_as_handled()


func _build_tile_nodes() -> void:
	if not rock_sprites.is_empty():
		return

	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var cell_position: Vector2 = Vector2(
				float(x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
				float(y * TILE_SIZE) + float(TILE_SIZE) * 0.5
			)

			var next_level_sprite: Sprite2D = Sprite2D.new()
			next_level_sprite.texture = rock_texture
			next_level_sprite.region_enabled = true
			next_level_sprite.region_rect = _get_rock_source_rect()
			next_level_sprite.position = cell_position
			next_level_sprite.scale = Vector2(TILE_TEXTURE_SCALE, TILE_TEXTURE_SCALE)
			next_level_sprite.z_index = 0
			next_level_sprite.modulate = NEXT_LEVEL_TINT
			preview_layer.add_child(next_level_sprite)
			next_level_sprites.append(next_level_sprite)

			var ore_sprite: Sprite2D = Sprite2D.new()
			ore_sprite.texture = ore_texture
			ore_sprite.region_enabled = true
			ore_sprite.region_rect = Rect2(0.0, 0.0, float(TEXTURE_TILE_SIZE), float(TEXTURE_TILE_SIZE))
			ore_sprite.position = cell_position
			ore_sprite.scale = Vector2(TILE_TEXTURE_SCALE, TILE_TEXTURE_SCALE)
			ore_sprite.z_index = 1
			ore_layer.add_child(ore_sprite)
			ore_sprites.append(ore_sprite)

			var rock_sprite: Sprite2D = Sprite2D.new()
			rock_sprite.texture = rock_texture
			rock_sprite.region_enabled = true
			rock_sprite.region_rect = _get_rock_source_rect()
			rock_sprite.position = cell_position
			rock_sprite.scale = Vector2(TILE_TEXTURE_SCALE, TILE_TEXTURE_SCALE)
			rock_sprite.z_index = 3
			rock_layer.add_child(rock_sprite)
			rock_sprites.append(rock_sprite)

			var crush_stage_sprite: Sprite2D = Sprite2D.new()
			crush_stage_sprite.texture = crush_stage_texture
			crush_stage_sprite.region_enabled = true
			crush_stage_sprite.region_rect = Rect2(0.0, 0.0, float(CRUSH_STAGE_FRAME_WIDTH), float(CRUSH_STAGE_FRAME_HEIGHT))
			crush_stage_sprite.position = cell_position
			crush_stage_sprite.scale = Vector2(TILE_TEXTURE_SCALE, TILE_TEXTURE_SCALE)
			crush_stage_sprite.z_index = 4
			crush_stage_sprite.visible = false
			rock_layer.add_child(crush_stage_sprite)
			crush_stage_sprites.append(crush_stage_sprite)

			var bar_root: Node2D = Node2D.new()
			bar_root.position = cell_position + Vector2(-14.0, -24.0)
			bar_root.z_index = 12
			bar_root.visible = false
			add_child(bar_root)
			hp_bar_roots.append(bar_root)
			cell_shake_timers.append(0.0)
			cell_shake_targets.append(0.0)

			var bar_back: ColorRect = ColorRect.new()
			bar_back.position = Vector2.ZERO
			bar_back.size = Vector2(28.0, 4.0)
			bar_back.color = Color(0.05, 0.04, 0.04, 0.85)
			bar_root.add_child(bar_back)

			var bar_fill: ColorRect = ColorRect.new()
			bar_fill.position = Vector2(1.0, 1.0)
			bar_fill.size = Vector2(26.0, 2.0)
			bar_fill.color = Color(0.75, 0.18, 0.12, 1.0)
			bar_root.add_child(bar_fill)
			hp_bar_fills.append(bar_fill)
			hp_bar_timers.append(0.0)

	ladder_sprite = Sprite2D.new()
	ladder_sprite.texture = ladder_texture
	ladder_sprite.scale = Vector2(TILE_TEXTURE_SCALE, TILE_TEXTURE_SCALE)
	ladder_sprite.z_index = 2
	ladder_layer.add_child(ladder_sprite)


func _get_priority_ore_cell() -> Vector2i:
	return INVALID_CELL


func _is_deposit_fully_uncovered(deposit_id: int) -> bool:
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return false

	var deposit: OreDeposit = ore_deposits[deposit_id]
	for cell: Vector2i in deposit.cells:
		if rock_present[_cell_to_index(cell)]:
			return false
	return true


func _is_floor_fully_excavated() -> bool:
	for index: int in range(CELL_COUNT):
		if rock_present[index]:
			return false
	return true


func _update_visuals() -> void:
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var index: int = _cell_to_index(cell)
			var rock_sprite: Sprite2D = rock_sprites[index]
			var crush_stage_sprite: Sprite2D = crush_stage_sprites[index]
			var ore_sprite: Sprite2D = ore_sprites[index]
			var crush_stage_frame: int = _rock_crush_stage_frame(index)
			var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_rock_layer_for_index(index)

			rock_sprite.visible = rock_present[index]
			rock_sprite.texture = rock_layer.texture
			rock_sprite.self_modulate = rock_layer.tint
			rock_sprite.region_rect = _get_rock_source_rect()
			crush_stage_sprite.visible = rock_present[index] and crush_stage_frame >= 0
			if crush_stage_frame >= 0:
				crush_stage_sprite.region_rect = Rect2(float(crush_stage_frame * CRUSH_STAGE_FRAME_WIDTH), 0.0, float(CRUSH_STAGE_FRAME_WIDTH), float(CRUSH_STAGE_FRAME_HEIGHT))
			ore_sprite.visible = false
			ore_sprite.region_rect = Rect2(float(_ore_mask(cell) * TEXTURE_TILE_SIZE), 0.0, float(TEXTURE_TILE_SIZE), float(TEXTURE_TILE_SIZE))
			ore_sprite.modulate = _get_ore_tint(index)
			_update_next_level_preview_cell(cell, index)

	ladder_sprite.position = Vector2(
		float(ladder_cell.x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
		float(ladder_cell.y * TILE_SIZE) + float(TILE_SIZE) * 0.5
	)
	ladder_sprite.visible = is_visible_ladder(ladder_cell)
	_update_rock_highlight()


func _play_floor_reveal() -> void:
	if Engine.is_editor_hint():
		return

	if reveal_tween != null:
		reveal_tween.kill()
		reveal_tween = null
	_reset_reveal_transforms()

	reveal_active = true
	_update_relic_layer_reveal_visibility()
	reveal_tween = create_tween()
	reveal_tween.set_parallel(true)

	var start_y: float = _get_reveal_start_y()
	var revealed_any: bool = false
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var index: int = _cell_to_index(cell)
			var delay: float = _get_reveal_delay(cell)
			revealed_any = _queue_reveal_node(next_level_sprites[index], delay, start_y) or revealed_any
			revealed_any = _queue_reveal_node(ore_sprites[index], delay, start_y) or revealed_any
			revealed_any = _queue_reveal_node(rock_sprites[index], delay, start_y) or revealed_any
			revealed_any = _queue_reveal_node(crush_stage_sprites[index], delay, start_y) or revealed_any

	if ladder_sprite.visible:
		var ladder_delay: float = _get_reveal_delay(ladder_cell)
		revealed_any = _queue_reveal_node(ladder_sprite, ladder_delay, start_y) or revealed_any

	if not revealed_any:
		_finish_floor_reveal()
		return

	reveal_tween.chain().tween_callback(Callable(self, "_finish_floor_reveal"))


func _queue_reveal_node(node: Node2D, delay: float, start_y: float) -> bool:
	if not node.visible:
		return false

	var final_position: Vector2 = node.position
	var start_position: Vector2 = Vector2(final_position.x, start_y)
	var overshoot_position: Vector2 = final_position + Vector2(0.0, -REVEAL_OVERSHOOT)
	var settle_dip_position: Vector2 = final_position + Vector2(0.0, REVEAL_SETTLE_DIP)
	var rebound_position: Vector2 = final_position + Vector2(0.0, -REVEAL_SETTLE_REBOUND)
	var final_dip_position: Vector2 = final_position + Vector2(0.0, REVEAL_SETTLE_FINAL_DIP)
	var rise_duration: float = REVEAL_TILE_DURATION * 0.52
	var first_settle_duration: float = REVEAL_TILE_DURATION * 0.2
	var rebound_duration: float = REVEAL_TILE_DURATION * 0.14
	var final_dip_duration: float = REVEAL_TILE_DURATION * 0.08
	var final_settle_duration: float = REVEAL_TILE_DURATION * 0.06
	var reveal_color: Color = node.self_modulate
	if reveal_color.a <= 0.0:
		reveal_color.a = 1.0
	var start_color: Color = reveal_color
	start_color.a = 0.0

	node.position = start_position
	node.self_modulate = start_color
	reveal_tween.tween_property(node, "position", overshoot_position, rise_duration).from(start_position).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(node, "position", settle_dip_position, first_settle_duration).from(overshoot_position).set_delay(delay + rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(node, "position", rebound_position, rebound_duration).from(settle_dip_position).set_delay(delay + rise_duration + first_settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(node, "position", final_dip_position, final_dip_duration).from(rebound_position).set_delay(delay + rise_duration + first_settle_duration + rebound_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(node, "position", final_position, final_settle_duration).from(final_dip_position).set_delay(delay + rise_duration + first_settle_duration + rebound_duration + final_dip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(node, "self_modulate", reveal_color, rise_duration * 0.72).from(start_color).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return true


func _finish_floor_reveal() -> void:
	reveal_active = false
	reveal_tween = null
	_reset_reveal_transforms()
	_update_relic_layer_reveal_visibility()
	_update_relic_sprite_visibility()


func _reset_reveal_transforms() -> void:
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var index: int = _cell_to_index(cell)
			var cell_position: Vector2 = Vector2(
				float(x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
				float(y * TILE_SIZE) + float(TILE_SIZE) * 0.5
			)
			_reset_reveal_node(next_level_sprites[index], cell_position)
			_reset_reveal_node(ore_sprites[index], cell_position)
			_reset_reveal_node(rock_sprites[index], cell_position)
			_reset_reveal_node(crush_stage_sprites[index], cell_position)

	if ladder_sprite != null:
		var ladder_position: Vector2 = Vector2(
			float(ladder_cell.x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
			float(ladder_cell.y * TILE_SIZE) + float(TILE_SIZE) * 0.5
		)
		_reset_reveal_node(ladder_sprite, ladder_position)


func _reset_reveal_node(node: Node2D, target_position: Vector2) -> void:
	node.position = target_position
	node.rotation = 0.0
	if node.self_modulate.a < 1.0:
		node.self_modulate.a = 1.0


func _get_reveal_delay(cell: Vector2i) -> float:
	var cell_center: Vector2 = Vector2(float(cell.x), float(cell.y))
	var distance: float = absf(cell_center.x - REVEAL_CENTER.x) + absf(cell_center.y - REVEAL_CENTER.y)
	var centered_distance: float = maxf(0.0, distance - 1.0)
	return floorf(centered_distance) * REVEAL_GROUP_DELAY


func _get_reveal_start_y() -> float:
	var viewport_height: float = get_viewport_rect().size.y
	if viewport_height <= 0.0:
		return float(GRID_HEIGHT * TILE_SIZE) + REVEAL_START_EXTRA_DEPTH
	var offscreen_local: Vector2 = to_local(Vector2(global_position.x, viewport_height + REVEAL_START_EXTRA_DEPTH))
	return offscreen_local.y


func _create_floor_layout() -> FloorLayout:
	var layout: FloorLayout = FloorLayout.new()
	for index: int in range(CELL_COUNT):
		layout.ore_present.append(false)
		layout.ore_deposit_ids.append(-1)

	_place_ladder_in_layout(layout)
	return layout


func _place_deposit_in_layout(layout: FloorLayout) -> void:
	var size: int = rng.randi_range(2, 4)
	for attempt: int in range(64):
		var start_cell: Vector2i = Vector2i(rng.randi_range(0, GRID_WIDTH - 1), rng.randi_range(0, GRID_HEIGHT - 1))
		if layout.ore_present[_cell_to_index(start_cell)]:
			continue

		var cells: Array[Vector2i] = [start_cell]
		var frontier: Array[Vector2i] = [start_cell]

		while cells.size() < size and not frontier.is_empty():
			var source_index: int = rng.randi_range(0, frontier.size() - 1)
			var source_cell: Vector2i = frontier[source_index]
			var candidates: Array[Vector2i] = _free_layout_neighbors(source_cell, cells, layout.ore_present)
			if candidates.is_empty():
				frontier.remove_at(source_index)
				continue

			var next_index: int = rng.randi_range(0, candidates.size() - 1)
			var next_cell: Vector2i = candidates[next_index]
			cells.append(next_cell)
			frontier.append(next_cell)

		if cells.size() == size:
			var deposit_id: int = layout.ore_deposits.size()
			var deposit: OreDeposit = OreDeposit.new()
			deposit.cells = cells
			deposit.config = _pick_random_ore_definition()
			deposit.max_hp = _roll_depth_scaled_deposit_hp(deposit.config)
			deposit.current_hp = deposit.max_hp
			deposit.quality_score = 0
			layout.ore_deposits.append(deposit)
			for cell: Vector2i in cells:
				var index: int = _cell_to_index(cell)
				layout.ore_present[index] = true
				layout.ore_deposit_ids[index] = deposit_id
			return


func _place_ladder_in_layout(layout: FloorLayout) -> void:
	var candidates: Array[Vector2i] = []
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			candidates.append(cell)

	if candidates.is_empty():
		layout.ladder_cell = Vector2i(GRID_WIDTH - 1, GRID_HEIGHT - 1)
		return

	var picked_index: int = rng.randi_range(0, candidates.size() - 1)
	layout.ladder_cell = candidates[picked_index]


func _free_layout_neighbors(cell: Vector2i, blocked_cells: Array[Vector2i], layout_ore_present: Array[bool]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0)
	]

	for offset: Vector2i in offsets:
		var candidate: Vector2i = cell + offset
		if is_valid_cell(candidate) and not layout_ore_present[_cell_to_index(candidate)] and not blocked_cells.has(candidate):
			result.append(candidate)

	return result


func _update_next_level_preview_cell(cell: Vector2i, index: int) -> void:
	var sprite: Sprite2D = next_level_sprites[index]
	var next_layer: RockLayerCatalog.RockLayerDefinition = _get_layer_for_cell(cell, 1)
	sprite.visible = not rock_present[index]
	sprite.texture = next_layer.texture
	sprite.self_modulate = next_layer.tint
	sprite.region_rect = _get_rock_source_rect()


func _update_rock_highlight() -> void:
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var index: int = _cell_to_index(cell)
			var sprite: Sprite2D = rock_sprites[index]
			var crush_stage_sprite: Sprite2D = crush_stage_sprites[index]
			if cell == selected_cell and rock_present[index]:
				sprite.modulate = Color(1.25, 1.12, 0.72, 1.0)
				crush_stage_sprite.modulate = Color(1.25, 1.12, 0.72, 1.0)
			else:
				sprite.modulate = Color.WHITE
				crush_stage_sprite.modulate = Color.WHITE


func _show_hp_bar(index: int, current_hp: int, max_hp: int) -> void:
	var fill: ColorRect = hp_bar_fills[index]
	var safe_max_hp: int = maxi(1, max_hp)
	var hp_ratio: float = clampf(float(current_hp) / float(safe_max_hp), 0.0, 1.0)
	fill.size = Vector2(26.0 * hp_ratio, 2.0)
	fill.color = Color(0.75, 0.18, 0.12, 1.0) if hp_ratio <= 0.35 else Color(0.95, 0.68, 0.16, 1.0)
	hp_bar_roots[index].visible = current_hp > 0
	hp_bar_timers[index] = HP_BAR_VISIBLE_TIME


func _play_hit_feedback(cell: Vector2i, mine_type: int) -> void:
	if Engine.is_editor_hint() or not is_valid_cell(cell):
		return
	var index: int = _cell_to_index(cell)
	_start_cell_shake(index)
	_spawn_hit_particles(cell, mine_type)


func _start_cell_shake(index: int) -> void:
	cell_shake_timers[index] = HIT_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	cell_shake_targets[index] = rng.randf_range(HIT_SHAKE_MIN_ANGLE, HIT_SHAKE_MAX_ANGLE) * shake_sign


func _update_cell_shakes(delta: float) -> void:
	for index: int in range(cell_shake_timers.size()):
		var shake_timer: float = cell_shake_timers[index]
		if shake_timer <= 0.0:
			_apply_cell_rotation(index, lerpf(_get_cell_rotation(index), 0.0, clampf(delta * 24.0, 0.0, 1.0)))
			continue
		shake_timer = maxf(0.0, shake_timer - delta)
		cell_shake_timers[index] = shake_timer
		var target_rotation: float = _get_cell_shake_rotation(shake_timer, cell_shake_targets[index])
		_apply_cell_rotation(index, lerpf(_get_cell_rotation(index), target_rotation, clampf(delta * 36.0, 0.0, 1.0)))


func _get_cell_shake_rotation(shake_timer: float, target_angle: float) -> float:
	if shake_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - shake_timer / HIT_SHAKE_TIME
	var spring_phase: float = progress * TAU * HIT_SHAKE_SPRING_WAVES
	var damping: float = pow(1.0 - progress, HIT_SHAKE_SPRING_DAMPING)
	return sin(spring_phase) * damping * target_angle * HIT_SHAKE_SPRING_BOOST


func _apply_cell_rotation(index: int, rotation_value: float) -> void:
	next_level_sprites[index].rotation = rotation_value
	ore_sprites[index].rotation = rotation_value
	rock_sprites[index].rotation = rotation_value
	crush_stage_sprites[index].rotation = rotation_value


func _get_cell_rotation(index: int) -> float:
	return rock_sprites[index].rotation


func _spawn_hit_particles(cell: Vector2i, mine_type: int) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = _get_hit_particle_texture()
	particles.position = Vector2(
		float(cell.x * TILE_SIZE) + float(TILE_SIZE) * 0.5,
		float(cell.y * TILE_SIZE) + float(TILE_SIZE) * 0.5
	)
	particles.z_index = 14
	particles.one_shot = true
	particles.amount = HIT_PARTICLE_AMOUNT
	particles.lifetime = HIT_PARTICLE_LIFETIME
	particles.explosiveness = 0.95
	particles.randomness = 0.55
	particles.local_coords = false
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 85.0
	particles.gravity = HIT_PARTICLE_GRAVITY
	particles.initial_velocity_min = HIT_PARTICLE_SPEED_MIN
	particles.initial_velocity_max = HIT_PARTICLE_SPEED_MAX
	particles.scale_amount_min = 1.6
	particles.scale_amount_max = 3.4
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.color = HIT_PARTICLE_ORE_COLOR if mine_type == MINE_ORE else HIT_PARTICLE_ROCK_COLOR
	add_child(particles)
	particles.emitting = true
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(HIT_PARTICLE_LIFETIME + 0.2)
	cleanup_timer.timeout.connect(particles.queue_free)


func _get_hit_particle_texture() -> Texture2D:
	if hit_particle_texture != null:
		return hit_particle_texture
	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	hit_particle_texture = ImageTexture.create_from_image(image)
	return hit_particle_texture


func _rock_crush_stage_frame(index: int) -> int:
	var rock_max_hp: int = _get_rock_max_hp(index)
	if rock_hp[index] >= rock_max_hp:
		return -1
	if rock_hp[index] > rock_max_hp / 2:
		return 0
	return 1


func _ore_mask(cell: Vector2i) -> int:
	var mask: int = 0
	if _has_ore_neighbor(cell, Vector2i(0, -1)):
		mask |= 1
	if _has_ore_neighbor(cell, Vector2i(1, 0)):
		mask |= 2
	if _has_ore_neighbor(cell, Vector2i(0, 1)):
		mask |= 4
	if _has_ore_neighbor(cell, Vector2i(-1, 0)):
		mask |= 8
	return mask


func _has_ore_neighbor(cell: Vector2i, offset: Vector2i) -> bool:
	var candidate: Vector2i = cell + offset
	if not is_valid_cell(candidate):
		return false
	return ore_present[_cell_to_index(candidate)]


func _cell_to_index(cell: Vector2i) -> int:
	return cell.y * GRID_WIDTH + cell.x


func _index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % GRID_WIDTH, floori(float(index) / float(GRID_WIDTH)))


func _clear_deposit(deposit_id: int) -> void:
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return
	var deposit: OreDeposit = ore_deposits[deposit_id]
	for cell: Vector2i in deposit.cells:
		var index: int = _cell_to_index(cell)
		ore_present[index] = false
		ore_deposit_ids[index] = -1
		hp_bar_roots[index].visible = false
		hp_bar_timers[index] = 0.0
	deposit.current_hp = 0


func _get_ore_tint(index: int) -> Color:
	if not ore_present[index]:
		return Color.WHITE
	var deposit_id: int = ore_deposit_ids[index]
	if deposit_id < 0 or deposit_id >= ore_deposits.size():
		return Color.WHITE
	var deposit: OreDeposit = ore_deposits[deposit_id]
	if deposit.config == null:
		return Color.WHITE
	return deposit.config.ore_tint


func _pick_random_ore_definition() -> Resource:
	if ore_definitions.is_empty():
		return preload("res://data/ores/copper_vein_config.tres") as Resource
	var floor: int = 1
	if game_state != null:
		floor = maxi(1, game_state.floor_number)
	var roll: float = rng.randf()
	var picked_index: int = 0
	if floor < 5:
		if roll < 0.7:
			picked_index = 0
		elif roll < 0.95:
			picked_index = mini(1, ore_definitions.size() - 1)
		else:
			picked_index = mini(2, ore_definitions.size() - 1)
	elif floor < 10:
		if roll < 0.25:
			picked_index = 0
		elif roll < 0.8:
			picked_index = mini(1, ore_definitions.size() - 1)
		else:
			picked_index = mini(2, ore_definitions.size() - 1)
	else:
		if roll < 0.12:
			picked_index = 0
		elif roll < 0.42:
			picked_index = mini(1, ore_definitions.size() - 1)
		else:
			picked_index = mini(2, ore_definitions.size() - 1)
	return ore_definitions[picked_index]


func _get_deposit_count_for_floor() -> int:
	if game_state == null:
		return 2
	var floor: int = maxi(1, game_state.floor_number)
	if floor >= 12:
		return 3
	if floor >= 6 and rng.randf() < 0.5:
		return 3
	return 2


func _get_rock_max_hp(index: int) -> int:
	var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_rock_layer_for_index(index)
	return rock_layer.max_hp


func _get_rock_layer_for_index(index: int) -> RockLayerCatalog.RockLayerDefinition:
	if index >= 0 and index < rock_layer_ids.size():
		return rock_layer_catalog.get_layer_by_id(rock_layer_ids[index])
	var cell: Vector2i = _index_to_cell(index)
	return _get_layer_for_cell(cell, 0)


func _get_layer_for_cell(cell: Vector2i, floor_offset: int) -> RockLayerCatalog.RockLayerDefinition:
	var depth_m: int = _get_cell_depth_m(cell, floor_offset)
	return rock_layer_catalog.get_layer_for_depth(depth_m, cell.x)


func _get_cell_depth_m(cell: Vector2i, floor_offset: int) -> int:
	var floor: int = 1
	if game_state != null:
		floor = maxi(1, game_state.floor_number)
	return maxi(0, floor + floor_offset + cell.y)


func _create_default_rock_layer_ids() -> Array[String]:
	var result: Array[String] = []
	for index: int in range(CELL_COUNT):
		var cell: Vector2i = _index_to_cell(index)
		var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_layer_for_cell(cell, 0)
		result.append(rock_layer.id)
	return result


func _resolve_current_floor_drop() -> Dictionary:
	var depth: int = 1
	if game_state != null:
		depth = maxi(1, game_state.floor_number)
	var pity_state: Dictionary = {}
	if game_state != null:
		pity_state = game_state.drop_pity_state
	if find_catalog == null:
		return {
			"depth": depth,
			"level_type": "empty",
			"drop_resolved": true,
			"drop_claimed": true,
			"drop_items": []
		}
	var resolved_drop: Dictionary = find_drop_resolver.resolve_level_drop(depth, find_catalog, pity_state)
	var drop_items: Array[String] = _read_string_list(resolved_drop.get("drop_items", []))
	if game_state != null:
		if drop_items.is_empty():
			game_state.record_find_drop_result([])
	return {
		"depth": depth,
		"level_type": str(resolved_drop.get("level_type", "empty")),
		"drop_resolved": true,
		"drop_claimed": drop_items.is_empty(),
		"buried_relics": _create_buried_relics(drop_items, depth)
	}


func _read_find_drop(source_variant: Variant) -> Dictionary:
	if not (source_variant is Dictionary):
		return {}
	var source: Dictionary = source_variant
	var depth: int = maxi(1, int(source.get("depth", 1)))
	var relics: Array[Dictionary] = _read_buried_relics(source.get("buried_relics", []), depth)
	if relics.is_empty():
		var legacy_items: Array[String] = _read_string_list(source.get("drop_items", []))
		relics = _create_buried_relics(legacy_items, depth)
	return {
		"depth": depth,
		"level_type": str(source.get("level_type", "empty")),
		"drop_resolved": bool(source.get("drop_resolved", true)),
		"drop_claimed": bool(source.get("drop_claimed", relics.is_empty())),
		"buried_relics": relics
	}


func _create_empty_ore_present() -> Array[bool]:
	var result: Array[bool] = []
	for _index: int in range(CELL_COUNT):
		result.append(false)
	return result


func _create_empty_ore_deposit_ids() -> Array[int]:
	var result: Array[int] = []
	for _index: int in range(CELL_COUNT):
		result.append(-1)
	return result


func _get_relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var relics_variant: Variant = current_find_drop.get("buried_relics", [])
	if not (relics_variant is Array):
		return result
	var relics: Array = relics_variant
	for relic_variant: Variant in relics:
		if relic_variant is Dictionary:
			result.append(relic_variant)
	return result


func _get_relic_by_id(relic_id: String) -> Dictionary:
	for relic: Dictionary in _get_relics():
		if str(relic.get("relic_id", "")) == relic_id:
			return relic
	return {}


func _get_active_relic_data() -> Dictionary:
	if active_relic_id.is_empty():
		return _get_pending_completed_relic()
	return _get_relic_by_id(active_relic_id)


func _get_pending_completed_relic() -> Dictionary:
	for relic: Dictionary in _get_relics():
		if bool(relic.get("minigame_completed", false)) and not bool(relic.get("drop_claimed", false)):
			active_relic_id = str(relic.get("relic_id", ""))
			return relic
	return {}


func _set_active_relic_field(field_name: String, value: Variant) -> void:
	if active_relic_id.is_empty():
		return
	var relics_variant: Variant = current_find_drop.get("buried_relics", [])
	if not (relics_variant is Array):
		return
	var relics: Array = relics_variant
	for index: int in range(relics.size()):
		var relic_variant: Variant = relics[index]
		if not (relic_variant is Dictionary):
			continue
		var relic: Dictionary = relic_variant
		if str(relic.get("relic_id", "")) != active_relic_id:
			continue
		relic[field_name] = value
		relics[index] = relic
		current_find_drop["buried_relics"] = relics
		return


func _create_buried_relics(item_ids: Array[String], depth: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var placement_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	placement_rng.seed = maxi(1, depth) * 7919 + item_ids.size() * 97
	for index: int in range(item_ids.size()):
		var item_id: String = item_ids[index]
		if item_id.is_empty():
			continue
		if find_catalog != null and not find_catalog.has_item(item_id):
			continue
		var top_left_cell: Vector2i = _roll_relic_top_left_cell(index, placement_rng)
		var local_position: Vector2 = _get_relic_center_from_top_left(top_left_cell)
		result.append({
			"relic_id": "relic_%02d" % index,
			"item_id": item_id,
			"top_left_cell": _serialize_cell(top_left_cell),
			"covered_cells": _serialize_relic_covered_cells(top_left_cell),
			"position": _serialize_vector2(local_position),
			"revealed": false,
			"minigame_completed": false,
			"collected": false,
			"drop_claimed": false
		})
	return result


func _read_buried_relics(source_variant: Variant, depth: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	var default_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	default_rng.seed = 1000 + maxi(1, depth)
	for index: int in range(source.size()):
		var relic_variant: Variant = source[index]
		if not (relic_variant is Dictionary):
			continue
		var relic: Dictionary = relic_variant
		var item_id: String = str(relic.get("item_id", ""))
		if item_id.is_empty():
			continue
		if find_catalog != null and not find_catalog.has_item(item_id):
			continue
		var top_left_cell: Vector2i = _read_relic_top_left_cell(relic, index, default_rng)
		var local_position: Vector2 = _get_relic_center_from_top_left(top_left_cell)
		result.append({
			"relic_id": str(relic.get("relic_id", "relic_%02d" % index)),
			"item_id": item_id,
			"top_left_cell": _serialize_cell(top_left_cell),
			"covered_cells": _serialize_relic_covered_cells(top_left_cell),
			"position": _serialize_vector2(local_position),
			"revealed": bool(relic.get("revealed", false)),
			"minigame_completed": bool(relic.get("minigame_completed", false)),
			"collected": bool(relic.get("collected", false)),
			"drop_claimed": bool(relic.get("drop_claimed", false))
		})
	return result


func _read_string_list(source_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	for value_variant: Variant in source:
		var value: String = str(value_variant)
		if value.is_empty():
			continue
		result.append(value)
	return result


func _roll_relic_top_left_cell(index: int, source_rng: RandomNumberGenerator = null) -> Vector2i:
	var placement_rng: RandomNumberGenerator = source_rng if source_rng != null else rng
	var max_x: int = maxi(0, GRID_WIDTH - RELIC_CELL_SPAN)
	var max_y: int = maxi(0, GRID_HEIGHT - RELIC_CELL_SPAN)
	var x_value: int = placement_rng.randi_range(0, max_x)
	var y_value: int = placement_rng.randi_range(0, max_y)
	if index > 0:
		x_value = (x_value + index * RELIC_CELL_SPAN) % (max_x + 1)
		y_value = (y_value + index) % (max_y + 1)
	return Vector2i(x_value, y_value)


func _read_relic_top_left_cell(relic: Dictionary, index: int, source_rng: RandomNumberGenerator) -> Vector2i:
	var fallback_cell: Vector2i = _roll_relic_top_left_cell(index, source_rng)
	var top_left_variant: Variant = relic.get("top_left_cell", {})
	if top_left_variant is Dictionary:
		var top_left_cell: Vector2i = _read_cell(top_left_variant, fallback_cell)
		return _clamp_relic_top_left_cell(top_left_cell)

	var position_variant: Variant = relic.get("position", {})
	if position_variant is Dictionary:
		var local_position: Vector2 = _read_vector2(position_variant, _get_relic_center_from_top_left(fallback_cell))
		var derived_cell: Vector2i = Vector2i(
			int(floor(local_position.x / float(TILE_SIZE))) - RELIC_CELL_SPAN / 2,
			int(floor(local_position.y / float(TILE_SIZE))) - RELIC_CELL_SPAN / 2
		)
		return _clamp_relic_top_left_cell(derived_cell)
	return fallback_cell


func _clamp_relic_top_left_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, maxi(0, GRID_WIDTH - RELIC_CELL_SPAN)),
		clampi(cell.y, 0, maxi(0, GRID_HEIGHT - RELIC_CELL_SPAN))
	)


func _get_relic_center_from_top_left(top_left_cell: Vector2i) -> Vector2:
	var clamped_cell: Vector2i = _clamp_relic_top_left_cell(top_left_cell)
	var span_size: float = float(TILE_SIZE * RELIC_CELL_SPAN)
	return Vector2(
		float(clamped_cell.x * TILE_SIZE) + span_size * 0.5,
		float(clamped_cell.y * TILE_SIZE) + span_size * 0.5
	)


func _get_relic_collect_local_position(relic: Dictionary, approach_local_position: Vector2) -> Vector2:
	var top_left_cell: Vector2i = _get_relic_cover_cell(relic)
	var relic_center: Vector2 = _get_relic_center_from_top_left(top_left_cell)
	var span_size: float = float(TILE_SIZE * RELIC_CELL_SPAN)
	var side_offset: float = span_size * 0.5 + RELIC_COLLECT_DISTANCE
	var candidates: Array[Vector2] = [
		relic_center + Vector2(-side_offset, 0.0),
		relic_center + Vector2(side_offset, 0.0),
		relic_center + Vector2(0.0, -side_offset),
		relic_center + Vector2(0.0, side_offset)
	]

	var best_position: Vector2 = candidates[0]
	var best_distance: float = approach_local_position.distance_squared_to(best_position)
	for index: int in range(1, candidates.size()):
		var candidate: Vector2 = candidates[index]
		var distance: float = approach_local_position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_position = candidate
	return best_position


func _get_relic_cover_cell(relic: Dictionary) -> Vector2i:
	return _clamp_relic_top_left_cell(_read_cell(relic.get("top_left_cell", {}), Vector2i.ZERO))


func _get_relic_covered_cells(relic: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cells_variant: Variant = relic.get("covered_cells", [])
	if cells_variant is Array:
		var cells: Array = cells_variant
		for cell_variant: Variant in cells:
			var cell: Vector2i = _read_cell(cell_variant, INVALID_CELL)
			if is_valid_cell(cell) and not result.has(cell):
				result.append(cell)
	if not result.is_empty():
		return result

	var top_left_cell: Vector2i = _get_relic_cover_cell(relic)
	for y_offset: int in range(RELIC_CELL_SPAN):
		for x_offset: int in range(RELIC_CELL_SPAN):
			var covered_cell: Vector2i = top_left_cell + Vector2i(x_offset, y_offset)
			if is_valid_cell(covered_cell):
				result.append(covered_cell)
	return result


func _serialize_relic_covered_cells(top_left_cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y_offset: int in range(RELIC_CELL_SPAN):
		for x_offset: int in range(RELIC_CELL_SPAN):
			var covered_cell: Vector2i = top_left_cell + Vector2i(x_offset, y_offset)
			if is_valid_cell(covered_cell):
				result.append(_serialize_cell(covered_cell))
	return result


func _update_relic_reveal_state() -> void:
	var relics_variant: Variant = current_find_drop.get("buried_relics", [])
	if not (relics_variant is Array):
		return
	var relics: Array = relics_variant
	for index: int in range(relics.size()):
		var relic_variant: Variant = relics[index]
		if not (relic_variant is Dictionary):
			continue
		var relic: Dictionary = relic_variant
		if bool(relic.get("collected", false)):
			continue
		if _are_relic_cells_uncovered(relic):
			relic["revealed"] = true
			relics[index] = relic
	current_find_drop["buried_relics"] = relics
	_update_relic_sprite_visibility()


func _are_relic_cells_uncovered(relic: Dictionary) -> bool:
	var covered_cells: Array[Vector2i] = _get_relic_covered_cells(relic)
	if covered_cells.is_empty():
		return false
	for covered_cell: Vector2i in covered_cells:
		var cover_index: int = _cell_to_index(covered_cell)
		if cover_index < 0 or cover_index >= rock_present.size():
			return false
		if rock_present[cover_index]:
			return false
	return true


func _build_relic_sprites() -> void:
	if relic_layer == null:
		return
	for child: Node in relic_layer.get_children():
		child.queue_free()
	relic_sprites.clear()
	for relic: Dictionary in _get_relics():
		var item_id: String = str(relic.get("item_id", ""))
		var item: Dictionary = find_catalog.get_item(item_id) if find_catalog != null else {}
		var asset_path: String = str(item.get("assetPath", ""))
		var texture: Texture2D = load(asset_path) as Texture2D
		if texture == null:
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.position = _read_vector2(relic.get("position", {}), Vector2.ZERO)
		var max_side: float = float(maxi(texture.get_width(), texture.get_height()))
		var scale_value: float = RELIC_VISIBLE_SIZE / maxf(1.0, max_side)
		sprite.scale = Vector2(scale_value, scale_value)
		sprite.z_index = 2
		sprite.visible = false
		relic_layer.add_child(sprite)
		relic_sprites[str(relic.get("relic_id", ""))] = sprite
	_update_relic_sprite_visibility()


func _update_relic_sprite_visibility() -> void:
	_update_relic_layer_reveal_visibility()
	for relic: Dictionary in _get_relics():
		var relic_id: String = str(relic.get("relic_id", ""))
		var sprite: Sprite2D = relic_sprites.get(relic_id) as Sprite2D
		if sprite == null:
			continue
		sprite.visible = not bool(relic.get("collected", false))
		sprite.self_modulate = Color.WHITE if bool(relic.get("revealed", false)) else Color(0.72, 0.68, 0.6, 0.92)


func _update_relic_layer_reveal_visibility() -> void:
	if relic_layer == null:
		return
	relic_layer.visible = not reveal_active


func _hide_active_relic_sprite() -> void:
	var sprite: Sprite2D = relic_sprites.get(active_relic_id) as Sprite2D
	if sprite != null:
		sprite.visible = false


func _serialize_vector2(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


func _read_vector2(source_variant: Variant, fallback: Vector2) -> Vector2:
	if not (source_variant is Dictionary):
		return fallback
	var source: Dictionary = source_variant
	return Vector2(float(source.get("x", fallback.x)), float(source.get("y", fallback.y)))


func _validate_rock_layer_ids(layer_ids: Array[String]) -> bool:
	if layer_ids.size() != CELL_COUNT:
		return false
	for layer_id: String in layer_ids:
		if not rock_layer_catalog.has_layer(layer_id):
			return false
	return true


func _roll_depth_scaled_deposit_hp(config: Resource) -> int:
	if config == null:
		return 50
	var floor: int = 1
	if game_state != null:
		floor = maxi(1, game_state.floor_number)
	var base_hp: int = int(config.call("roll_max_hp", rng))
	var resource_type: String = str(config.get("resource_type"))
	var hp_cap: int = _get_depth_hp_cap(resource_type)
	return mini(hp_cap, base_hp + floor * 3)


func _get_depth_hp_cap(resource_type: String) -> int:
	match resource_type:
		"Copper":
			return 150
		"Iron":
			return 230
		"Crystal":
			return 320
		_:
			return 220


func _roll_reward_chunk_count(deposit: OreDeposit, result_zone: int) -> int:
	var base_chunks: int = 1
	if deposit.cells.size() >= 4:
		base_chunks = 3
	elif deposit.cells.size() >= 3:
		base_chunks = 2
	var bonus_chance: float = 0.0
	match result_zone:
		OreVeinConfig.RESULT_GREEN:
			bonus_chance = 0.25
		OreVeinConfig.RESULT_YELLOW:
			bonus_chance = 0.1
		_:
			bonus_chance = 0.0
	bonus_chance = clampf(bonus_chance + _get_deposit_layer_reward_bonus_chance(deposit), 0.0, 0.95)
	if rng.randf() < bonus_chance:
		base_chunks += 1
	return base_chunks


func _get_deposit_layer_reward_bonus_chance(deposit: OreDeposit) -> float:
	if deposit == null or deposit.cells.is_empty():
		return 0.0

	var total_bonus_chance: float = 0.0
	var counted_cells: int = 0
	for cell: Vector2i in deposit.cells:
		if not is_valid_cell(cell):
			continue
		var index: int = _cell_to_index(cell)
		var rock_layer: RockLayerCatalog.RockLayerDefinition = _get_rock_layer_for_index(index)
		total_bonus_chance += rock_layer.ore_reward_bonus_chance
		counted_cells += 1

	if counted_cells <= 0:
		return 0.0
	return clampf(total_bonus_chance / float(counted_cells), 0.0, 0.95)


func _serialize_bool_array(source: Array[bool]) -> Array[bool]:
	var result: Array[bool] = []
	for value: bool in source:
		result.append(value)
	return result


func _serialize_int_array(source: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in source:
		result.append(value)
	return result


func _serialize_string_array(source: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in source:
		result.append(value)
	return result


func _serialize_ore_deposits() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deposit: OreDeposit in ore_deposits:
		var serialized_cells: Array[Dictionary] = []
		for cell: Vector2i in deposit.cells:
			serialized_cells.append(_serialize_cell(cell))
		var config_path: String = ""
		if deposit.config != null:
			config_path = deposit.config.resource_path
		result.append({
			"cells": serialized_cells,
			"config_path": config_path,
			"max_hp": deposit.max_hp,
			"current_hp": deposit.current_hp,
			"quality_score": deposit.quality_score
		})
	return result


func _serialize_cell(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _read_bool_array(source_variant: Variant, expected_size: int) -> Array[bool]:
	var result: Array[bool] = []
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	if source.size() != expected_size:
		return result
	for value_variant: Variant in source:
		result.append(bool(value_variant))
	return result


func _read_int_array(source_variant: Variant, expected_size: int) -> Array[int]:
	var result: Array[int] = []
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	if source.size() != expected_size:
		return result
	for value_variant: Variant in source:
		result.append(int(value_variant))
	return result


func _read_string_array(source_variant: Variant, expected_size: int) -> Array[String]:
	var result: Array[String] = []
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	if source.size() != expected_size:
		return result
	for value_variant: Variant in source:
		result.append(str(value_variant))
	return result


func _read_ore_deposits(source_variant: Variant) -> Array[OreDeposit]:
	var result: Array[OreDeposit] = []
	if not (source_variant is Array):
		return result

	var source: Array = source_variant
	for deposit_variant: Variant in source:
		if not (deposit_variant is Dictionary):
			return []
		var deposit_data: Dictionary = deposit_variant
		var cells: Array[Vector2i] = _read_cells(deposit_data.get("cells", []))
		if cells.is_empty():
			return []

		var deposit: OreDeposit = OreDeposit.new()
		deposit.cells = cells
		deposit.config = _load_ore_config(str(deposit_data.get("config_path", "")))
		deposit.max_hp = maxi(1, int(deposit_data.get("max_hp", 1)))
		deposit.current_hp = clampi(int(deposit_data.get("current_hp", deposit.max_hp)), 0, deposit.max_hp)
		deposit.quality_score = maxi(0, int(deposit_data.get("quality_score", 0)))
		result.append(deposit)
	return result


func _read_cells(source_variant: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not (source_variant is Array):
		return result

	var source: Array = source_variant
	for cell_variant: Variant in source:
		var cell: Vector2i = _read_cell(cell_variant, INVALID_CELL)
		if not is_valid_cell(cell):
			return []
		if result.has(cell):
			return []
		result.append(cell)
	return result


func _read_cell(source_variant: Variant, fallback: Vector2i) -> Vector2i:
	if not (source_variant is Dictionary):
		return fallback
	var source: Dictionary = source_variant
	return Vector2i(int(source.get("x", fallback.x)), int(source.get("y", fallback.y)))


func _validate_loaded_floor(loaded_ore_present: Array[bool], loaded_ore_deposit_ids: Array[int], loaded_ore_deposits: Array[OreDeposit]) -> bool:
	var seen_cells: Dictionary = {}
	for deposit_index: int in range(loaded_ore_deposits.size()):
		var deposit: OreDeposit = loaded_ore_deposits[deposit_index]
		for cell: Vector2i in deposit.cells:
			var index: int = _cell_to_index(cell)
			if seen_cells.has(index):
				return false
			seen_cells[index] = true
			if not loaded_ore_present[index]:
				return false
			if loaded_ore_deposit_ids[index] != deposit_index:
				return false

	for index: int in range(CELL_COUNT):
		if not loaded_ore_present[index]:
			if loaded_ore_deposit_ids[index] != -1:
				return false
			continue
		var deposit_id: int = loaded_ore_deposit_ids[index]
		if deposit_id < 0 or deposit_id >= loaded_ore_deposits.size():
			return false
	return true


func _load_ore_config(config_path: String) -> Resource:
	if not config_path.is_empty():
		var loaded_config: Resource = load(config_path) as Resource
		if loaded_config != null:
			return loaded_config
	return preload("res://data/ores/copper_vein_config.tres") as Resource
