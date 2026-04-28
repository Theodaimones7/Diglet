extends AnimatedSprite2D
class_name MinerAgent

enum MinerMode {
	IDLE,
	MOVING,
	MINING,
	MOVING_TO_RELIC,
	COLLECTING_RELIC,
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
const REWARD_POPUP_DURATION: float = 1.0
const REWARD_POPUP_START_POSITION: Vector2 = Vector2(0.0, -34.0)
const REWARD_POPUP_END_POSITION: Vector2 = Vector2(0.0, -50.0)
const EMOJI_POPUP_DURATION: float = 0.85
const EMOJI_POPUP_START_POSITION: Vector2 = Vector2(0.0, -34.0)
const EMOJI_POPUP_END_POSITION: Vector2 = Vector2(0.0, -58.0)
const BONUS_POPUP_DURATION: float = 0.9
const BONUS_POPUP_START_POSITION: Vector2 = Vector2(0.0, -22.0)
const BONUS_POPUP_END_POSITION: Vector2 = Vector2(0.0, -44.0)
const DONUT_FEEDBACK_DURATION: float = 1.0
const DONUT_EFFECT_START_POSITION: Vector2 = Vector2(0.0, -43.0)
const DONUT_EFFECT_END_POSITION: Vector2 = Vector2(0.0, -57.0)
const BOB_STRIKE_ICON: String = "🍩?"
const BOB_HAPPY_ICON: String = "😊"
const WHIP_JUMP_HEIGHT: float = 18.0
const WHIP_JUMP_UP_TIME: float = 0.12
const WHIP_JUMP_DOWN_TIME: float = 0.16
const WHIP_EFFECT_START_POSITION: Vector2 = Vector2(-28.0, -24.0)
const WHIP_EFFECT_END_POSITION: Vector2 = Vector2(21.0, -7.0)
const WHIP_EFFECT_TIME: float = 1.0
const WHIP_EFFECT_SCALE: float = 1.5
const FIND_RARITY_TO_TIER: Dictionary = {
	"common": "E",
	"uncommon": "D",
	"rare": "C",
	"epic": "B",
	"legendary": "A"
}
const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_ATTACK: StringName = &"attack"
const ANIMATION_SLEEP: StringName = &"sleep"
const ANIMATION_FALL: StringName = &"fall"
const ANIMATION_BOB_FINDS: StringName = &"bob_finds"

var game_state: GameState
var board: BoardController
var home_position: Vector2 = Vector2.ZERO
var mode: MinerMode = MinerMode.IDLE
var target_cell: Vector2i = INVALID_CELL
var target_relic_id: String = ""
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
var run_speed_multiplier: float = 1.0
var dig_speed_multiplier: float = 1.0
var bob_buff_timer: float = 0.0
var donut_bonus_loot_chance: float = 0.0
var happy_bonus_loot_chance: float = 0.0
var bob_strike_active: bool = false
var bob_happy_active: bool = false
var bob_bonus_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var whip_jump_tween: Tween = null
var whip_effect_tween: Tween = null
var donut_effect_tween: Tween = null
var donut_feedback_timer: float = 0.0
var emoji_popup_tween: Tween = null
var bonus_popup_tween: Tween = null

var ore_mining

@onready var sleep_z_1: Label = $SleepZ1 as Label
@onready var sleep_z_2: Label = $SleepZ2 as Label
@onready var sleep_z_3: Label = $SleepZ3 as Label
@onready var reward_popup: Node2D = get_node_or_null("RewardPopup") as Node2D
@onready var reward_icon: Sprite2D = get_node_or_null("RewardPopup/Icon") as Sprite2D
@onready var reward_label: Label = get_node_or_null("RewardPopup/NameLabel") as Label
@onready var reward_tier_label: Label = get_node_or_null("RewardPopup/TierLabel") as Label
@onready var whip_effect: Sprite2D = get_node_or_null("WhipEffect") as Sprite2D
@onready var donut_effect: Sprite2D = get_node_or_null("DonutEffect") as Sprite2D
@onready var emoji_popup: Label = get_node_or_null("EmojiPopup") as Label
@onready var state_icon: Label = get_node_or_null("StateIcon") as Label
@onready var bonus_popup: Label = get_node_or_null("BonusPopup") as Label


func _ready() -> void:
	bob_bonus_rng.randomize()
	sleep_z_labels = [sleep_z_1, sleep_z_2, sleep_z_3]
	sleep_z_tweens.resize(sleep_z_labels.size())
	_hide_sleep_z_effect()
	if reward_popup != null:
		reward_popup.visible = false
	if emoji_popup != null:
		emoji_popup.visible = false
	if bonus_popup != null:
		bonus_popup.visible = false
	_update_bob_state_icon()
	_hide_whip_effect()
	_hide_donut_effect()


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
	if bob_strike_active:
		return
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
	_update_bob_buff(delta)
	_update_donut_feedback(delta)
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
	if bob_strike_active and mode != MinerMode.DESCENDING:
		_enter_bob_strike_idle()
		_update_character_animation()
		return

	if game_state.energy <= 0 and mode != MinerMode.RETURNING_HOME and mode != MinerMode.RESTING and mode != MinerMode.DESCENDING:
		_go_home()

	match mode:
		MinerMode.IDLE:
			_pick_next_target()
		MinerMode.MOVING:
			_process_movement(delta, false)
		MinerMode.MOVING_TO_RELIC:
			_process_movement(delta, false)
		MinerMode.MINING:
			_process_mining(delta)
		MinerMode.COLLECTING_RELIC:
			pass
		MinerMode.RETURNING_HOME:
			_process_movement(delta, true)
		MinerMode.RESTING:
			_process_rest(delta)
		MinerMode.DESCENDING:
			pass

	if mode != MinerMode.MINING and mode != MinerMode.COLLECTING_RELIC:
		ore_mining.cancel_session()
	elif mode == MinerMode.MINING and not board.is_ore_cell_mineable(target_cell):
		ore_mining.cancel_session()

	_update_character_animation()


func _process_movement(delta: float, returning_home: bool) -> void:
	var to_target: Vector2 = target_position - position
	if to_target.length() <= ARRIVE_DISTANCE:
		position = target_position
		if returning_home:
			_start_rest()
		else:
			if mode == MinerMode.MOVING_TO_RELIC:
				_arrive_at_target_relic()
			else:
				_arrive_at_target_cell()
		return

	_face_direction(to_target)
	position += to_target.normalized() * MOVE_SPEED * run_speed_multiplier * delta


func _process_mining(delta: float) -> void:
	if bob_strike_active:
		_enter_bob_strike_idle()
		return
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
	if bob_strike_active:
		_enter_bob_strike_idle()
		return
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
	if bob_strike_active:
		_enter_bob_strike_idle()
		return
	if board.is_reveal_active():
		mode = MinerMode.IDLE
		target_cell = INVALID_CELL
		return

	if game_state.energy <= 0:
		_go_home()
		return

	var next_relic_id: String = board.choose_next_collectable_relic_id()
	if not next_relic_id.is_empty():
		_move_to_relic(next_relic_id)
		return

	var next_cell: Vector2i = board.choose_next_auto_target()
	if next_cell == INVALID_CELL:
		_go_home()
		return

	_move_to_cell(next_cell)


func _move_to_cell(cell: Vector2i) -> void:
	target_cell = cell
	target_relic_id = ""
	target_position = _get_cell_stand_position(cell)
	_face_direction(target_position - position)
	ore_mining.cancel_session()
	mode = MinerMode.MOVING


func _move_to_relic(relic_id: String) -> void:
	target_cell = INVALID_CELL
	target_relic_id = relic_id
	target_position = board.get_relic_collect_world_position(relic_id, position)
	_face_direction(target_position - position)
	ore_mining.cancel_session()
	mode = MinerMode.MOVING_TO_RELIC


func _arrive_at_target_relic() -> void:
	if target_relic_id.is_empty():
		_pick_next_target()
		return
	if board.request_relic_collection(target_relic_id):
		mode = MinerMode.COLLECTING_RELIC
		play(ANIMATION_IDLE)
	else:
		target_relic_id = ""
		_pick_next_target()


func _get_target_mining_interval() -> float:
	if bob_strike_active:
		return INF
	if board == null or not board.is_valid_cell(target_cell):
		return MINING_INTERVAL
	if board.is_ore_cell_mineable(target_cell):
		return MINING_INTERVAL
	return board.get_rock_dig_time(target_cell) / dig_speed_multiplier


func has_active_bob_buff() -> bool:
	return bob_buff_timer > 0.0


func get_bob_buff_time_left() -> float:
	return bob_buff_timer


func has_active_speed_boost() -> bool:
	return has_active_bob_buff()


func get_speed_boost_time_left() -> float:
	return get_bob_buff_time_left()


func apply_whip_boost(run_multiplier: float, dig_multiplier: float, duration: float) -> void:
	_apply_bob_buff(run_multiplier, dig_multiplier, 0.0, duration)


func play_whip_feedback() -> void:
	_play_whip_feedback()


func apply_donut_boost(run_multiplier: float, bonus_loot_chance: float, duration: float) -> void:
	_apply_bob_buff(run_multiplier, 1.0, bonus_loot_chance, duration)
	_play_donut_feedback()


func show_bob_emoji(emoji: String) -> void:
	_play_emoji_popup(emoji)


func set_bob_relationship_state(strike_active: bool, happy_active: bool) -> void:
	bob_strike_active = strike_active
	bob_happy_active = happy_active
	happy_bonus_loot_chance = 0.1 if bob_happy_active else 0.0
	_update_bob_state_icon()
	if bob_strike_active:
		_enter_bob_strike_idle()


func _apply_bob_buff(run_multiplier: float, dig_multiplier: float, bonus_loot_chance: float, duration: float) -> void:
	var safe_run_multiplier: float = maxf(1.0, run_multiplier)
	var safe_dig_multiplier: float = maxf(1.0, dig_multiplier)
	var safe_duration: float = maxf(0.0, duration)
	run_speed_multiplier = safe_run_multiplier
	dig_speed_multiplier = safe_dig_multiplier
	donut_bonus_loot_chance = clampf(bonus_loot_chance, 0.0, 1.0)
	bob_buff_timer = safe_duration
	if mode == MinerMode.MINING and mining_timer > 0.0:
		mining_timer /= safe_dig_multiplier
	if ore_mining != null and ore_mining.has_method("set_speed_boost_multiplier"):
		ore_mining.call("set_speed_boost_multiplier", dig_speed_multiplier)


func _enter_bob_strike_idle() -> void:
	target_cell = INVALID_CELL
	target_relic_id = ""
	pickaxe_swing_timer = 0.0
	mining_timer = 0.0
	if ore_mining != null:
		ore_mining.cancel_session()
	if mode != MinerMode.IDLE:
		mode = MinerMode.IDLE


func _go_home(_interrupt_minigame: bool = true) -> void:
	board.clear_selection()
	target_cell = INVALID_CELL
	target_relic_id = ""
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
	target_relic_id = ""
	board.set_input_locked(false)
	_pick_next_target()


func resume_after_relic_collection() -> void:
	target_relic_id = ""
	if mode == MinerMode.COLLECTING_RELIC:
		_pick_next_target()


func show_find_reward(item: Dictionary, duration: float = REWARD_POPUP_DURATION) -> void:
	if reward_popup == null or reward_icon == null or reward_label == null:
		await get_tree().create_timer(maxf(0.01, duration)).timeout
		return

	var item_id: String = str(item.get("id", "Find"))
	var asset_path: String = str(item.get("assetPath", ""))
	var item_name: String = str(item.get("name", item_id))
	var rarity: String = str(item.get("rarity", "common"))
	var icon_texture: Texture2D = null
	if not asset_path.is_empty():
		icon_texture = load(asset_path) as Texture2D

	reward_icon.texture = icon_texture
	reward_label.text = item_name
	reward_label.add_theme_color_override("font_color", _get_reward_rarity_color(rarity))
	if reward_tier_label != null:
		var reward_tier: String = _get_reward_tier_for_rarity(rarity)
		reward_tier_label.text = "Tier %s" % reward_tier
		reward_tier_label.add_theme_color_override("font_color", _get_reward_tier_color(reward_tier))
	reward_popup.position = REWARD_POPUP_START_POSITION
	reward_popup.modulate = Color.WHITE
	reward_popup.visible = true

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(reward_popup, "position", REWARD_POPUP_END_POSITION, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward_popup, "modulate", Color(1.0, 1.0, 1.0, 0.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	reward_popup.visible = false
	reward_popup.modulate = Color.WHITE


func handle_relic_hit_requested(_damage: int) -> void:
	if board != null and not target_relic_id.is_empty():
		_face_direction(board.get_relic_center_world_position(target_relic_id) - position)
		board.play_relic_hit_feedback(target_relic_id)
	_start_pickaxe_swing()
	if game_state != null and game_state.energy > 0:
		game_state.spend_energy(1)


func _get_reward_rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.35, 0.95, 0.42, 1.0)
		"rare":
			return Color(0.36, 0.62, 1.0, 1.0)
		"epic":
			return Color(0.77, 0.38, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.78, 0.22, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


func _get_reward_tier_for_rarity(rarity: String) -> String:
	var tier_variant: Variant = FIND_RARITY_TO_TIER.get(rarity, "E")
	return str(tier_variant)


func _get_reward_tier_color(tier: String) -> Color:
	match tier:
		"A":
			return Color(0.98, 0.84, 0.26, 1.0)
		"B":
			return Color(0.53, 0.64, 1.0, 1.0)
		"C":
			return Color(0.46, 0.83, 0.38, 1.0)
		"D":
			return Color(0.69, 0.71, 0.74, 1.0)
		_:
			return Color(0.48, 0.37, 0.28, 1.0)


func _finish_ladder_fall_animation() -> void:
	ladder_falling = false
	play(ANIMATION_IDLE)


func _update_bob_buff(delta: float) -> void:
	if bob_buff_timer <= 0.0:
		return

	bob_buff_timer = maxf(0.0, bob_buff_timer - delta)
	if bob_buff_timer > 0.0:
		return

	run_speed_multiplier = 1.0
	dig_speed_multiplier = 1.0
	donut_bonus_loot_chance = 0.0
	if ore_mining != null and ore_mining.has_method("set_speed_boost_multiplier"):
		ore_mining.call("set_speed_boost_multiplier", dig_speed_multiplier)


func _update_bob_state_icon() -> void:
	if state_icon == null:
		return
	if bob_strike_active:
		state_icon.text = BOB_STRIKE_ICON
		state_icon.visible = true
	elif bob_happy_active:
		state_icon.text = BOB_HAPPY_ICON
		state_icon.visible = true
	else:
		state_icon.visible = false


func _try_apply_bob_bonus_loot(resource_type: String, tier: String) -> void:
	var total_bonus_chance: float = clampf(donut_bonus_loot_chance + happy_bonus_loot_chance, 0.0, 1.0)
	if total_bonus_chance <= 0.0:
		return
	if bob_bonus_rng.randf() > total_bonus_chance:
		return
	game_state.add_carried_ore_chunk(resource_type, tier, 1)
	var source_text: String = "Happy Bob" if bob_happy_active and donut_bonus_loot_chance <= 0.0 else "Donut"
	if bob_happy_active and donut_bonus_loot_chance > 0.0:
		source_text = "Donut + Happy"
	_play_bonus_popup("+1 Ore\n%s" % source_text)


func _play_bonus_popup(text: String) -> void:
	if bonus_popup == null:
		return
	if bonus_popup_tween != null:
		bonus_popup_tween.kill()
	bonus_popup.text = text
	bonus_popup.position = BONUS_POPUP_START_POSITION
	bonus_popup.scale = Vector2.ONE
	bonus_popup.modulate = Color(1.0, 0.9, 0.45, 1.0)
	bonus_popup.visible = true
	bonus_popup_tween = create_tween()
	bonus_popup_tween.set_parallel(true)
	bonus_popup_tween.tween_property(bonus_popup, "position", BONUS_POPUP_END_POSITION, BONUS_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bonus_popup_tween.tween_property(bonus_popup, "scale", Vector2(1.12, 1.12), BONUS_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bonus_popup_tween.tween_property(bonus_popup, "modulate", Color(1.0, 0.9, 0.45, 0.0), BONUS_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bonus_popup_tween.finished.connect(_hide_bonus_popup)


func _hide_bonus_popup() -> void:
	if bonus_popup == null:
		return
	bonus_popup.visible = false
	bonus_popup.modulate = Color(1.0, 0.9, 0.45, 0.0)
	bonus_popup_tween = null


func _update_donut_feedback(delta: float) -> void:
	if donut_feedback_timer <= 0.0:
		return

	donut_feedback_timer = maxf(0.0, donut_feedback_timer - delta)
	if donut_feedback_timer <= 0.0:
		_update_character_animation()


func _play_donut_feedback() -> void:
	donut_feedback_timer = DONUT_FEEDBACK_DURATION
	_play_whip_jump()
	_play_donut_effect()
	if sprite_frames != null and sprite_frames.has_animation(ANIMATION_BOB_FINDS):
		play(ANIMATION_BOB_FINDS)


func _play_donut_effect() -> void:
	if donut_effect == null:
		return
	if donut_effect_tween != null:
		donut_effect_tween.kill()
	donut_effect.visible = true
	donut_effect.position = DONUT_EFFECT_START_POSITION
	donut_effect.scale = Vector2(1.35, 1.35)
	donut_effect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	donut_effect_tween = create_tween()
	donut_effect_tween.set_parallel(true)
	donut_effect_tween.tween_property(donut_effect, "position", DONUT_EFFECT_END_POSITION, DONUT_FEEDBACK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	donut_effect_tween.tween_property(donut_effect, "scale", Vector2(1.65, 1.65), DONUT_FEEDBACK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	donut_effect_tween.tween_property(donut_effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), DONUT_FEEDBACK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	donut_effect_tween.finished.connect(_hide_donut_effect)


func _hide_donut_effect() -> void:
	if donut_effect == null:
		return
	donut_effect.visible = false
	donut_effect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	donut_effect_tween = null


func _play_whip_feedback() -> void:
	_play_whip_jump()
	_play_whip_effect()


func _play_emoji_popup(emoji: String) -> void:
	if emoji_popup == null:
		return
	if emoji_popup_tween != null:
		emoji_popup_tween.kill()
	emoji_popup.text = emoji
	emoji_popup.position = EMOJI_POPUP_START_POSITION
	emoji_popup.scale = Vector2.ONE
	emoji_popup.modulate = Color(1.0, 1.0, 1.0, 1.0)
	emoji_popup.visible = true
	emoji_popup_tween = create_tween()
	emoji_popup_tween.set_parallel(true)
	emoji_popup_tween.tween_property(emoji_popup, "position", EMOJI_POPUP_END_POSITION, EMOJI_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emoji_popup_tween.tween_property(emoji_popup, "scale", Vector2(1.22, 1.22), EMOJI_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	emoji_popup_tween.tween_property(emoji_popup, "modulate", Color(1.0, 1.0, 1.0, 0.0), EMOJI_POPUP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	emoji_popup_tween.finished.connect(_hide_emoji_popup)


func _hide_emoji_popup() -> void:
	if emoji_popup == null:
		return
	emoji_popup.visible = false
	emoji_popup.modulate = Color(1.0, 1.0, 1.0, 0.0)
	emoji_popup_tween = null


func _play_whip_jump() -> void:
	if mode == MinerMode.DESCENDING:
		return
	if whip_jump_tween != null:
		whip_jump_tween.kill()
	var start_offset: Vector2 = offset
	whip_jump_tween = create_tween()
	whip_jump_tween.tween_property(self, "offset", start_offset + Vector2(0.0, -WHIP_JUMP_HEIGHT), WHIP_JUMP_UP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	whip_jump_tween.tween_property(self, "offset", start_offset, WHIP_JUMP_DOWN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	whip_jump_tween.finished.connect(_on_whip_jump_finished)


func _on_whip_jump_finished() -> void:
	whip_jump_tween = null


func _play_whip_effect() -> void:
	if whip_effect == null:
		return
	if whip_effect_tween != null:
		whip_effect_tween.kill()
	var direction: float = -float(facing_sign)
	whip_effect.visible = true
	whip_effect.position = Vector2(WHIP_EFFECT_START_POSITION.x * direction, WHIP_EFFECT_START_POSITION.y)
	whip_effect.scale = Vector2(direction * WHIP_EFFECT_SCALE, WHIP_EFFECT_SCALE)
	whip_effect.rotation = -0.65 * direction
	whip_effect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	whip_effect_tween = create_tween()
	whip_effect_tween.set_parallel(true)
	whip_effect_tween.tween_property(whip_effect, "position", Vector2(WHIP_EFFECT_END_POSITION.x * direction, WHIP_EFFECT_END_POSITION.y), WHIP_EFFECT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	whip_effect_tween.tween_property(whip_effect, "rotation", 0.35 * direction, WHIP_EFFECT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	whip_effect_tween.tween_property(whip_effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), WHIP_EFFECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	whip_effect_tween.finished.connect(_hide_whip_effect)


func _hide_whip_effect() -> void:
	if whip_effect == null:
		return
	whip_effect.visible = false
	whip_effect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	whip_effect_tween = null


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
	if donut_feedback_timer > 0.0:
		if animation != ANIMATION_BOB_FINDS and sprite_frames != null and sprite_frames.has_animation(ANIMATION_BOB_FINDS):
			play(ANIMATION_BOB_FINDS)
		return

	if pickaxe_swing_timer > 0.0:
		if animation != ANIMATION_ATTACK:
			play(ANIMATION_ATTACK)
		return

	match mode:
		MinerMode.DESCENDING:
			var next_animation: StringName = ANIMATION_FALL if ladder_falling else ANIMATION_IDLE
			if animation != next_animation:
				play(next_animation)
		MinerMode.MOVING, MinerMode.MOVING_TO_RELIC, MinerMode.RETURNING_HOME:
			if animation != ANIMATION_WALK:
				play(ANIMATION_WALK)
		MinerMode.COLLECTING_RELIC:
			if animation != ANIMATION_IDLE:
				play(ANIMATION_IDLE)
		MinerMode.RESTING:
			if animation != ANIMATION_SLEEP:
				play(ANIMATION_SLEEP)
		_:
			if animation != ANIMATION_IDLE:
				play(ANIMATION_IDLE)


func _on_ore_hit_requested(cell: Vector2i, damage: int, quality_points: int, _result_zone: int, _manual: bool) -> void:
	if bob_strike_active:
		_enter_bob_strike_idle()
		return
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
		_try_apply_bob_bonus_loot(outcome.resource_type, outcome.tier)
		ore_mining.cancel_session()
		if mode == MinerMode.MINING:
			_pick_next_target()
