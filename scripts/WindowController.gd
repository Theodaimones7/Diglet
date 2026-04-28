extends Node2D

const ProgressSaveStore = preload("res://scripts/ProgressSave.gd")
const MoneyWavyTextEffect = preload("res://ui/effects/wavy_text_effect.gd")
const WHIP_CURSOR_TEXTURE: Texture2D = preload("res://assets/Whip/Whip1.png")

const WINDOW_CONTENT_SIZE: Vector2i = Vector2i(532, 380)
const WINDOW_TOP_PADDING: int = 32
const WINDOW_SIZE: Vector2i = Vector2i(WINDOW_CONTENT_SIZE.x, WINDOW_CONTENT_SIZE.y + WINDOW_TOP_PADDING)
const SCREEN_MARGIN: int = 0
const WINDOW_BOTTOM_OFFSET: int = 48
const DEPTH_SCALE_TOP: float = 7.0
const DEPTH_SCALE_HEIGHT: float = 195.0
const DEPTH_MARKER_CENTER_OFFSET: float = 11.0
const DEPTH_SCALE_SEGMENT_SIZE: int = 10
const FATIGUE_SCALE_TOP: float = 8.0
const FATIGUE_SCALE_HEIGHT: float = 188.0
const DRAG_AREA_POSITION: Vector2 = Vector2(24.0, 47.0)
const DRAG_AREA_SIZE: Vector2 = Vector2(424.0, 333.0)
const ACTION_BUTTON_HOVER_MODULATE: Color = Color(0.62, 0.62, 0.62, 1.0)
const ACTION_BUTTON_NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const ACTION_BUTTON_HOVER_SCALE: Vector2 = Vector2(1.12, 1.12)
const ACTION_BUTTON_NORMAL_SCALE: Vector2 = Vector2.ONE
const ACTION_BUTTON_SHAKE_TIME: float = 0.18
const ACTION_BUTTON_SHAKE_MIN_ANGLE: float = 0.24
const ACTION_BUTTON_SHAKE_MAX_ANGLE: float = 0.4
const ACTION_BUTTON_SHAKE_SPRING_WAVES: float = 1.35
const ACTION_BUTTON_SHAKE_SPRING_DAMPING: float = 1.25
const ACTION_BUTTON_SHAKE_SPRING_BOOST: float = 1.45
const BOB_ACTION_MENU_SHIFT: float = 100.0
const BOB_ACTION_MENU_TWEEN_TIME: float = 0.28
const WHIP_RUN_MULTIPLIER: float = 1.5
const WHIP_DIG_MULTIPLIER: float = 1.5
const WHIP_BOOST_DURATION: float = 15.0
const WHIP_CURSOR_HOTSPOT: Vector2 = Vector2(6.0, 6.0)
const WHIP_CURSOR_SCALE: int = 2
const WHIP_BOB_TARGET_RADIUS: float = 58.0
const DONUT_RUN_MULTIPLIER: float = 1.1
const DONUT_BONUS_LOOT_CHANCE: float = 0.25
const DONUT_BOOST_DURATION: float = 25.0
const DONUT_CURSOR_HOTSPOT: Vector2 = Vector2(8.0, 8.0)
const DONUT_CURSOR_SCALE: int = 2
const BOB_RELATIONSHIP_MIN: int = 0
const BOB_RELATIONSHIP_MAX: int = 10
const BOB_RELATIONSHIP_INITIAL: int = 5
const BOB_RELATIONSHIP_FILLED_HEART: String = "❤️"
const BOB_RELATIONSHIP_EMPTY_HEART: String = "🤍"
const BOB_WHIP_EMOJI: String = "😠"
const BOB_DONUT_EMOJI: String = "😋"
const WHIP_EFFECT_TOOLTIP: String = "Whip\nSpeed Boost\n+50% Run\n+50% Dig\n-1 ❤️"
const DONUT_EFFECT_TOOLTIP: String = "Donut\nLoot Boost\n+25% Bonus Loot\n+10% Run\n+1 ❤️"
const MONEY_ANIMATION_DURATION: float = 0.45
const FATIGUE_CHASE_DELAY: float = 0.12
const FATIGUE_CHASE_DURATION: float = 0.28

@onready var game_state: GameState = get_node("GameState") as GameState
@onready var board: BoardController = get_node("Board") as BoardController
@onready var miner: MinerAgent = get_node("Miner") as MinerAgent
@onready var ore_mining: OreMiningComponent = get_node("OreMiningOverlay/OreMining") as OreMiningComponent
@onready var house: Sprite2D = get_node("House") as Sprite2D
@onready var hud_layer: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
@onready var ore_inventory_overlay: CanvasLayer = get_node_or_null("OreInventoryOverlay") as CanvasLayer
@onready var ore_mining_overlay: CanvasLayer = get_node_or_null("OreMiningOverlay") as CanvasLayer
@onready var upgrade_shop_overlay: CanvasLayer = get_node_or_null("UpgradeShopOverlay") as CanvasLayer
@onready var museum_overlay: CanvasLayer = get_node_or_null("MuseumOverlay") as CanvasLayer
@onready var minimize_button: TextureButton = get_node_or_null("HUD/HBoxContainer/MinimizeButton") as TextureButton
@onready var exit_button: TextureButton = get_node_or_null("HUD/HBoxContainer/ExitButton") as TextureButton
@onready var depth_label_top: Label = get_node_or_null("HUD/DepthScale/DepthLabelTop") as Label
@onready var depth_label_bottom: Label = get_node_or_null("HUD/DepthScale/DepthLabelBottom") as Label
@onready var depth_marker: Control = get_node_or_null("HUD/DepthScale/DepthMarker") as Control
@onready var depth_marker_label: Label = get_node_or_null("HUD/DepthScale/DepthMarker/DepthMarkerLabel") as Label
@onready var money_label: RichTextLabel = get_node_or_null("HUD/TextureRect/Money") as RichTextLabel
@onready var ore_inventory_button_slot: Control = get_node_or_null("HUD/ActionButtons/OreInventoryButtonSlot") as Control
@onready var ore_inventory_button: TextureButton = get_node_or_null("HUD/ActionButtons/OreInventoryButtonSlot/OreInventoryButton") as TextureButton
@onready var ore_inventory_panel: Control = get_node_or_null("OreInventoryOverlay/OreInventoryPanel") as Control
@onready var upgrade_shop_button_slot: Control = get_node_or_null("HUD/ActionButtons/UpgradeShopButtonSlot") as Control
@onready var upgrade_shop_button: TextureButton = get_node_or_null("HUD/ActionButtons/UpgradeShopButtonSlot/UpgradeShopButton") as TextureButton
@onready var upgrade_shop_panel: Control = get_node_or_null("UpgradeShopOverlay/UpgradeShopPanel") as Control
@onready var museum_button_slot: Control = get_node_or_null("HUD/ActionButtons/MuseumButtonSlot") as Control
@onready var museum_button: TextureButton = get_node_or_null("HUD/ActionButtons/MuseumButtonSlot/MuseumButton") as TextureButton
@onready var museum_panel: Control = get_node_or_null("MuseumOverlay/MuseumPanel") as Control
@onready var bob_action_buttons: Control = get_node_or_null("HUD/ActionButtons2") as Control
@onready var bob_button_slot: Control = get_node_or_null("HUD/ActionButtons2/Bobbutton") as Control
@onready var bob_button: TextureButton = get_node_or_null("HUD/ActionButtons2/Bobbutton/BobButton") as TextureButton
@onready var whip_button_slot: Control = get_node_or_null("HUD/ActionButtons2/Whipbutton") as Control
@onready var whip_button: TextureButton = get_node_or_null("HUD/ActionButtons2/Whipbutton/WhipShopButton") as TextureButton
@onready var whip_cooldown_label: Label = get_node_or_null("HUD/ActionButtons2/Whipbutton/CooldownLabel") as Label
@onready var donut_button_slot: Control = get_node_or_null("HUD/ActionButtons2/DonutButtonSlot") as Control
@onready var donut_button: TextureButton = get_node_or_null("HUD/ActionButtons2/DonutButtonSlot/DonutButton") as TextureButton
@onready var donut_cooldown_label: Label = get_node_or_null("HUD/ActionButtons2/DonutButtonSlot/CooldownLabel") as Label
@onready var fatigue_scale: Control = get_node_or_null("HUD/FatigueScale") as Control
@onready var fatigue_chase_fill: ColorRect = get_node_or_null("HUD/FatigueScale/FatigueChaseFill") as ColorRect
@onready var fatigue_fill: ColorRect = get_node_or_null("HUD/FatigueScale/FatigueFill") as ColorRect
@onready var fatigue_value_label: Label = get_node_or_null("HUD/FatigueScale/FatigueValue") as Label

var is_dragging_window: bool = false
var drag_mouse_offset: Vector2i = Vector2i.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var action_button_slots: Array[Control] = []
var action_button_shake_timers: Array[float] = []
var action_button_shake_targets: Array[float] = []
var action_button_hovered: Array[bool] = []
var displayed_currency: int = -1
var money_target_currency: int = -1
var money_tween: Tween = null
var displayed_energy: int = -1
var fatigue_chase_tween: Tween = null
var fatigue_shake_timer: float = 0.0
var fatigue_shake_target: float = 0.0
var bob_action_menu_expanded: bool = false
var bob_action_menu_open_position: Vector2 = Vector2.ZERO
var bob_action_menu_tween: Tween = null
var whip_targeting_active: bool = false
var donut_targeting_active: bool = false
var whip_cursor_texture: Texture2D = null
var donut_cursor_texture: Texture2D = null
var bob_interaction_previous_board_input_locked: bool = false
var bob_relationship_hearts: int = BOB_RELATIONSHIP_INITIAL


func _init() -> void:
	ProjectSettings.set_setting("display/window/size/transparent", true)
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)


func _enter_tree() -> void:
	_configure_window()


func _ready() -> void:
	_apply_window_top_padding()
	_setup_whip_cursor_texture()
	_setup_donut_cursor_texture()
	rng.randomize()
	var saved_progress: Dictionary = ProgressSaveStore.load_progress()
	var saved_game_state: Dictionary = ProgressSaveStore.get_section(saved_progress, "game_state")
	var saved_board_state: Dictionary = ProgressSaveStore.get_section(saved_progress, "board")
	var saved_window_state: Dictionary = ProgressSaveStore.get_section(saved_progress, "window")
	_load_window_save_data(saved_window_state)
	game_state.load_from_save_data(saved_game_state)
	board.setup(game_state, saved_board_state)
	miner.setup(game_state, board, house.global_position, ore_mining)
	_sync_bob_relationship_state()
	board.tile_clicked.connect(miner.handle_tile_click)
	board.find_drop_ready.connect(_show_find_reward_popup)
	board.relic_collection_requested.connect(_on_relic_collection_requested)
	ore_mining.session_lock_changed.connect(board.set_input_locked)
	ore_mining.relic_hit_requested.connect(_on_relic_hit_requested)
	ore_mining.relic_session_completed.connect(_on_relic_collection_succeeded)
	if minimize_button != null:
		minimize_button.pressed.connect(_minimize_game)
		_setup_action_button_hover(minimize_button, minimize_button)
	if exit_button != null:
		exit_button.pressed.connect(_quit_game)
		_setup_action_button_hover(exit_button, exit_button)
	if ore_inventory_button != null:
		ore_inventory_button.pressed.connect(_toggle_ore_inventory_panel)
	_setup_action_button_hover(ore_inventory_button_slot, ore_inventory_button)
	if upgrade_shop_button != null:
		upgrade_shop_button.pressed.connect(_toggle_upgrade_shop_panel)
	_setup_action_button_hover(upgrade_shop_button_slot, upgrade_shop_button)
	if museum_button != null:
		museum_button.pressed.connect(_toggle_museum_panel)
	_setup_action_button_hover(museum_button_slot, museum_button)
	_setup_bob_action_menu()
	_setup_money_label()
	game_state.currency_changed.connect(_update_money_hud)
	game_state.energy_changed.connect(_update_energy_hud)
	game_state.floor_changed.connect(_update_depth_scale)
	game_state.stats_changed.connect(_save_progress)
	board.state_changed.connect(_save_progress)
	if ore_inventory_panel != null:
		ore_inventory_panel.call("setup", game_state)
	if upgrade_shop_panel != null:
		upgrade_shop_panel.call("setup", game_state)
	if museum_panel != null:
		museum_panel.call("setup", game_state)
	_setup_player_panel_overlay_sync()
	_setup_fatigue_scale()
	_update_hud()
	_update_depth_scale()
	call_deferred("_show_find_reward_popup")
	_save_progress()


func _process(delta: float) -> void:
	_update_bob_action_button_states()
	_update_action_button_hover_states()
	_update_action_button_shakes(delta)
	_update_fatigue_shake(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_dragging_window = false
		_cancel_bob_interaction_targeting()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_bob_interaction_targeting_input(event):
		return

	if _handle_sleeping_bob_wake_input(event):
		return

	if get_window().is_embedded():
		return

	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_button_event.pressed:
			if _is_point_in_drag_area(mouse_button_event.position):
				is_dragging_window = true
				var window_position: Vector2i = get_window().position
				var mouse_position: Vector2i = DisplayServer.mouse_get_position()
				drag_mouse_offset = mouse_position - window_position
				get_viewport().set_input_as_handled()
		else:
			is_dragging_window = false
	elif event is InputEventMouseMotion:
		if not is_dragging_window:
			return
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging_window = false
			return
		_move_window_to_mouse()
		get_viewport().set_input_as_handled()


func _handle_sleeping_bob_wake_input(event: InputEvent) -> bool:
	if miner == null or not (event is InputEventMouseButton):
		return false

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button_event.pressed or mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if miner.try_wake_from_sleep_at_screen_point(mouse_button_event.position):
		get_viewport().set_input_as_handled()
		return true
	return false


func _configure_window() -> void:
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)

	var window: Window = get_window()
	get_viewport().transparent_bg = true

	if window.is_embedded():
		push_warning("Desktop companion mode requires disabled Game Embedding. Use the Game tab dropdown -> disable 'Embed Game on Next Play', or run StartDesktopCompanion.bat.")
		window.transparent_bg = true
		return

	window.min_size = WINDOW_SIZE
	window.size = WINDOW_SIZE
	window.borderless = true
	window.unresizable = true
	window.always_on_top = true
	window.gui_embed_subwindows = false
	window.transparent = true
	window.transparent_bg = true

	var screen_id: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)
	var target_position: Vector2i = usable_rect.position + usable_rect.size - WINDOW_SIZE - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN) + Vector2i(0, WINDOW_BOTTOM_OFFSET)
	window.position = target_position

	var window_id: int = window.get_window_id()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, window_id)
	DisplayServer.window_set_size(WINDOW_SIZE, window_id)
	DisplayServer.window_set_position(target_position, window_id)


func _apply_window_top_padding() -> void:
	if get_window().is_embedded():
		return

	var visual_offset: Vector2 = Vector2(0.0, float(WINDOW_TOP_PADDING))
	house.position += visual_offset
	board.position += visual_offset
	miner.position += visual_offset

	var layer_offset: Vector2 = Vector2(0.0, float(WINDOW_TOP_PADDING))
	if hud_layer != null:
		hud_layer.offset = layer_offset
	if ore_inventory_overlay != null:
		ore_inventory_overlay.offset = layer_offset
	if ore_mining_overlay != null:
		ore_mining_overlay.offset = layer_offset
	if upgrade_shop_overlay != null:
		upgrade_shop_overlay.offset = layer_offset
	if museum_overlay != null:
		museum_overlay.offset = layer_offset


func _quit_game() -> void:
	_save_progress()
	get_tree().quit()


func _minimize_game() -> void:
	_save_progress()
	get_window().mode = Window.MODE_MINIMIZED


func _save_progress() -> void:
	if not is_node_ready():
		return
	ProgressSaveStore.save_progress(game_state, board, _to_window_save_data())


func _to_window_save_data() -> Dictionary:
	return {
		"bob_relationship_hearts": bob_relationship_hearts
	}


func _load_window_save_data(save_data: Dictionary) -> void:
	var hearts_variant: Variant = save_data.get("bob_relationship_hearts", BOB_RELATIONSHIP_INITIAL)
	bob_relationship_hearts = clampi(int(hearts_variant), BOB_RELATIONSHIP_MIN, BOB_RELATIONSHIP_MAX)


func _update_hud() -> void:
	_update_money_hud()
	_update_energy_hud()


func _update_money_hud() -> void:
	if money_label != null:
		_set_money_amount(game_state.currency)


func _update_energy_hud() -> void:
	if fatigue_fill == null or fatigue_value_label == null:
		return

	_set_fatigue_amount(game_state.energy)


func _set_fatigue_amount(target_energy: int) -> void:
	var max_energy: int = game_state.get_max_energy()
	var clamped_energy: int = clampi(target_energy, 0, max_energy)
	var target_height: float = _get_fatigue_fill_height(clamped_energy)
	var should_shake: bool = displayed_energy >= 0 and clamped_energy < displayed_energy
	_apply_fatigue_fill_height(fatigue_fill, target_height)
	fatigue_value_label.text = str(clamped_energy)
	if should_shake:
		_start_fatigue_spend_shake()

	if fatigue_chase_fill == null:
		displayed_energy = clamped_energy
		return

	if displayed_energy < 0 or clamped_energy >= displayed_energy:
		_stop_fatigue_chase_tween()
		_apply_fatigue_fill_height(fatigue_chase_fill, target_height)
		displayed_energy = clamped_energy
		return

	_stop_fatigue_chase_tween()
	var start_height: float = clampf(fatigue_chase_fill.size.y, 0.0, FATIGUE_SCALE_HEIGHT)
	fatigue_chase_tween = create_tween()
	fatigue_chase_tween.set_trans(Tween.TRANS_CUBIC)
	fatigue_chase_tween.set_ease(Tween.EASE_OUT)
	fatigue_chase_tween.tween_interval(FATIGUE_CHASE_DELAY)
	fatigue_chase_tween.tween_method(_apply_fatigue_chase_tween_height, start_height, target_height, FATIGUE_CHASE_DURATION)
	displayed_energy = clamped_energy


func _setup_fatigue_scale() -> void:
	if fatigue_scale == null:
		return
	fatigue_scale.rotation = 0.0
	_center_action_button_pivot(fatigue_scale)
	fatigue_scale.resized.connect(_center_action_button_pivot.bind(fatigue_scale))


func _start_fatigue_spend_shake() -> void:
	if fatigue_scale == null:
		return
	fatigue_shake_timer = ACTION_BUTTON_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	fatigue_shake_target = rng.randf_range(
		ACTION_BUTTON_SHAKE_MIN_ANGLE,
		ACTION_BUTTON_SHAKE_MAX_ANGLE
	) * shake_sign


func _update_fatigue_shake(delta: float) -> void:
	if fatigue_scale == null:
		return
	if fatigue_shake_timer <= 0.0:
		fatigue_scale.rotation = lerpf(fatigue_scale.rotation, 0.0, clampf(delta * 24.0, 0.0, 1.0))
		return
	fatigue_shake_timer = maxf(0.0, fatigue_shake_timer - delta)
	var target_rotation: float = _get_action_button_shake_rotation(
		fatigue_shake_timer,
		fatigue_shake_target
	)
	fatigue_scale.rotation = lerpf(fatigue_scale.rotation, target_rotation, clampf(delta * 36.0, 0.0, 1.0))


func _stop_fatigue_chase_tween() -> void:
	if fatigue_chase_tween != null and fatigue_chase_tween.is_valid():
		fatigue_chase_tween.kill()
	fatigue_chase_tween = null


func _get_fatigue_fill_height(energy_value: int) -> float:
	var max_energy: int = game_state.get_max_energy()
	var clamped_energy: int = clampi(energy_value, 0, max_energy)
	var fatigue_ratio: float = clampf(float(clamped_energy) / float(maxi(1, max_energy)), 0.0, 1.0)
	return FATIGUE_SCALE_HEIGHT * fatigue_ratio


func _apply_fatigue_chase_tween_height(fill_height: float) -> void:
	if fatigue_chase_fill == null:
		return
	_apply_fatigue_fill_height(fatigue_chase_fill, fill_height)


func _apply_fatigue_fill_height(fill: ColorRect, fill_height: float) -> void:
	var clamped_height: float = clampf(fill_height, 0.0, FATIGUE_SCALE_HEIGHT)
	fill.position.y = FATIGUE_SCALE_TOP + FATIGUE_SCALE_HEIGHT - clamped_height
	fill.size.y = clamped_height


func _setup_money_label() -> void:
	if money_label == null:
		return
	money_label.bbcode_enabled = true
	var effects: Array[RichTextEffect] = []
	for effect_variant: Variant in money_label.custom_effects:
		var effect: RichTextEffect = effect_variant as RichTextEffect
		if effect != null:
			effects.append(effect)
	effects.append(MoneyWavyTextEffect.new() as RichTextEffect)
	money_label.custom_effects = effects
	displayed_currency = game_state.currency
	money_target_currency = game_state.currency
	_apply_money_text(displayed_currency)


func _set_money_amount(target_currency: int) -> void:
	if money_label == null:
		return
	if displayed_currency < 0:
		displayed_currency = target_currency
		money_target_currency = target_currency
		_apply_money_text(target_currency)
		return
	if money_target_currency == target_currency and money_tween != null and money_tween.is_valid():
		return
	if displayed_currency == target_currency and money_target_currency == target_currency:
		return

	if money_tween != null and money_tween.is_valid():
		money_tween.kill()

	money_target_currency = target_currency
	var start_currency: float = float(displayed_currency)
	var end_currency: float = float(target_currency)
	money_tween = create_tween()
	money_tween.set_trans(Tween.TRANS_CUBIC)
	money_tween.set_ease(Tween.EASE_OUT)
	money_tween.tween_method(_apply_money_tween_value, start_currency, end_currency, MONEY_ANIMATION_DURATION)
	money_tween.finished.connect(_on_money_tween_finished.bind(target_currency))


func _apply_money_tween_value(value: float) -> void:
	var rounded_value: int = int(roundf(value))
	_apply_money_text(rounded_value)


func _apply_money_text(currency: int) -> void:
	displayed_currency = currency
	money_label.text = _wrap_money_wavy("$%d" % currency)


func _on_money_tween_finished(final_currency: int) -> void:
	displayed_currency = final_currency
	_apply_money_text(final_currency)


func _wrap_money_wavy(text: String) -> String:
	return "[wavy amp=1.5 speed=1.6 phase=0.25 pulse=0.4 pulse_speed=2.4 glow_amp=0.12 glow_speed=2.0]%s[/wavy]" % text


func _update_depth_scale() -> void:
	if depth_marker == null or depth_marker_label == null:
		return
	var player_level: int = maxi(1, game_state.floor_number)
	var segment_index: int = floori(float(player_level) / float(DEPTH_SCALE_SEGMENT_SIZE))
	var segment_start: int = segment_index * DEPTH_SCALE_SEGMENT_SIZE
	var segment_end: int = segment_start + DEPTH_SCALE_SEGMENT_SIZE
	var segment_progress: int = player_level - segment_start
	var depth_ratio: float = clampf(float(segment_progress) / float(DEPTH_SCALE_SEGMENT_SIZE), 0.0, 1.0)
	depth_marker.position.y = DEPTH_SCALE_TOP + depth_ratio * DEPTH_SCALE_HEIGHT - DEPTH_MARKER_CENTER_OFFSET
	if depth_label_top != null:
		depth_label_top.text = "%d m" % segment_start
	if depth_label_bottom != null:
		depth_label_bottom.text = "%d m" % segment_end
	depth_marker_label.text = "%d m" % player_level


func _setup_action_button_hover(slot: Control, button: TextureButton) -> void:
	if slot == null:
		return
	slot.modulate = ACTION_BUTTON_NORMAL_MODULATE
	slot.rotation = 0.0
	slot.scale = ACTION_BUTTON_NORMAL_SCALE
	_center_action_button_pivot(slot)
	slot.resized.connect(_center_action_button_pivot.bind(slot))
	action_button_slots.append(slot)
	action_button_shake_timers.append(0.0)
	action_button_shake_targets.append(0.0)
	action_button_hovered.append(false)
	if button != null:
		button.button_down.connect(_on_action_button_pressed.bind(slot))


func _setup_bob_action_menu() -> void:
	if bob_action_buttons == null:
		return

	bob_action_menu_open_position = bob_action_buttons.position
	bob_action_buttons.position = _get_bob_action_menu_closed_position()
	_setup_action_button_hover(bob_button_slot, bob_button)
	_setup_action_button_hover(whip_button_slot, whip_button)
	_setup_action_button_hover(donut_button_slot, donut_button)
	_set_bob_action_menu_child_state(whip_button_slot, whip_button, false)
	_set_bob_action_menu_child_state(donut_button_slot, donut_button, false)
	if bob_button != null:
		bob_button.pressed.connect(_toggle_bob_action_menu)
	if whip_button != null:
		whip_button.pressed.connect(_activate_whip_targeting)
	if donut_button != null:
		donut_button.pressed.connect(_activate_donut_targeting)
	_set_bob_action_cooldown_label(whip_cooldown_label, false, 0.0)
	_set_bob_action_cooldown_label(donut_cooldown_label, false, 0.0)
	_update_bob_relationship_tooltip()
	_update_bob_action_button_states()


func _set_bob_action_menu_child_state(slot: Control, button: TextureButton, enabled: bool) -> void:
	if slot != null:
		slot.visible = enabled
		if not enabled:
			var hidden_modulate: Color = slot.modulate
			hidden_modulate.a = 0.0
			slot.modulate = hidden_modulate
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if button != null:
		var disabled: bool = not enabled
		if button == whip_button:
			disabled = disabled or not _can_start_bob_interaction(true) or donut_targeting_active
		elif button == donut_button:
			disabled = disabled or not _can_start_bob_interaction(false) or whip_targeting_active
		button.disabled = disabled
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _get_bob_action_menu_closed_position() -> Vector2:
	return bob_action_menu_open_position + Vector2(BOB_ACTION_MENU_SHIFT, 0.0)


func _toggle_bob_action_menu() -> void:
	_set_bob_action_menu_expanded(not bob_action_menu_expanded)


func _set_bob_action_menu_expanded(expanded: bool) -> void:
	if bob_action_buttons == null:
		return

	bob_action_menu_expanded = expanded
	_update_bob_action_button_states()
	if bob_action_menu_tween != null:
		bob_action_menu_tween.kill()

	var target_position: Vector2 = bob_action_menu_open_position if expanded else _get_bob_action_menu_closed_position()
	var target_alpha: float = 1.0 if expanded else 0.0
	if expanded:
		_set_bob_action_menu_child_state(whip_button_slot, whip_button, true)
		_set_bob_action_menu_child_state(donut_button_slot, donut_button, true)

	bob_action_menu_tween = create_tween()
	bob_action_menu_tween.set_parallel(true)
	bob_action_menu_tween.set_trans(Tween.TRANS_CUBIC)
	bob_action_menu_tween.set_ease(Tween.EASE_OUT)
	bob_action_menu_tween.tween_property(bob_action_buttons, "position", target_position, BOB_ACTION_MENU_TWEEN_TIME)
	if whip_button_slot != null:
		bob_action_menu_tween.tween_property(whip_button_slot, "modulate:a", target_alpha, BOB_ACTION_MENU_TWEEN_TIME)
	if donut_button_slot != null:
		bob_action_menu_tween.tween_property(donut_button_slot, "modulate:a", target_alpha, BOB_ACTION_MENU_TWEEN_TIME)

	if not expanded:
		bob_action_menu_tween.finished.connect(_disable_bob_action_menu_children_after_collapse)


func _disable_bob_action_menu_children_after_collapse() -> void:
	if bob_action_menu_expanded:
		return
	_set_bob_action_menu_child_state(whip_button_slot, whip_button, false)
	_set_bob_action_menu_child_state(donut_button_slot, donut_button, false)


func _center_action_button_pivot(slot: Control) -> void:
	slot.pivot_offset = slot.size * 0.5


func _on_action_button_pressed(slot: Control) -> void:
	var slot_index: int = action_button_slots.find(slot)
	if slot_index < 0:
		return
	_start_action_button_shake(slot_index)


func _start_action_button_shake(slot_index: int) -> void:
	action_button_shake_timers[slot_index] = ACTION_BUTTON_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	action_button_shake_targets[slot_index] = rng.randf_range(
		ACTION_BUTTON_SHAKE_MIN_ANGLE,
		ACTION_BUTTON_SHAKE_MAX_ANGLE
	) * shake_sign


func _update_action_button_hover_states() -> void:
	for slot_index in action_button_slots.size():
		var slot: Control = action_button_slots[slot_index]
		var is_hovered: bool = _is_mouse_inside_control(slot)
		if action_button_hovered[slot_index] == is_hovered:
			continue
		action_button_hovered[slot_index] = is_hovered
		if is_hovered:
			slot.modulate = ACTION_BUTTON_HOVER_MODULATE
			slot.scale = ACTION_BUTTON_HOVER_SCALE
			_start_action_button_shake(slot_index)
		else:
			slot.modulate = ACTION_BUTTON_NORMAL_MODULATE
			slot.scale = ACTION_BUTTON_NORMAL_SCALE


func _update_action_button_shakes(delta: float) -> void:
	for slot_index in action_button_slots.size():
		var slot: Control = action_button_slots[slot_index]
		var shake_timer: float = action_button_shake_timers[slot_index]
		if shake_timer <= 0.0:
			slot.rotation = lerpf(slot.rotation, 0.0, clampf(delta * 24.0, 0.0, 1.0))
			continue
		shake_timer = maxf(0.0, shake_timer - delta)
		action_button_shake_timers[slot_index] = shake_timer
		var target_rotation: float = _get_action_button_shake_rotation(
			shake_timer,
			action_button_shake_targets[slot_index]
		)
		slot.rotation = lerpf(slot.rotation, target_rotation, clampf(delta * 36.0, 0.0, 1.0))


func _get_action_button_shake_rotation(shake_timer: float, target_angle: float) -> float:
	if shake_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - shake_timer / ACTION_BUTTON_SHAKE_TIME
	var spring_phase: float = progress * TAU * ACTION_BUTTON_SHAKE_SPRING_WAVES
	var damping: float = pow(1.0 - progress, ACTION_BUTTON_SHAKE_SPRING_DAMPING)
	return sin(spring_phase) * damping * target_angle * ACTION_BUTTON_SHAKE_SPRING_BOOST


func _activate_whip_targeting() -> void:
	if not _can_start_bob_interaction(true) or whip_targeting_active:
		return
	_lock_board_for_bob_interaction_targeting()
	whip_targeting_active = true
	Input.set_custom_mouse_cursor(whip_cursor_texture, Input.CURSOR_ARROW, WHIP_CURSOR_HOTSPOT * float(WHIP_CURSOR_SCALE))
	_update_bob_action_button_states()


func _activate_donut_targeting() -> void:
	if not _can_start_bob_interaction(false) or donut_targeting_active:
		return
	_lock_board_for_bob_interaction_targeting()
	donut_targeting_active = true
	Input.set_custom_mouse_cursor(donut_cursor_texture, Input.CURSOR_ARROW, DONUT_CURSOR_HOTSPOT * float(DONUT_CURSOR_SCALE))
	_update_bob_action_button_states()


func _setup_whip_cursor_texture() -> void:
	var source_image: Image = WHIP_CURSOR_TEXTURE.get_image()
	if source_image == null:
		whip_cursor_texture = WHIP_CURSOR_TEXTURE
		return
	var target_size: Vector2i = source_image.get_size() * WHIP_CURSOR_SCALE
	source_image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	whip_cursor_texture = ImageTexture.create_from_image(source_image)


func _setup_donut_cursor_texture() -> void:
	if donut_button == null or donut_button.texture_normal == null:
		return
	var source_image: Image = donut_button.texture_normal.get_image()
	if source_image == null:
		donut_cursor_texture = donut_button.texture_normal
		return
	var target_size: Vector2i = source_image.get_size() * DONUT_CURSOR_SCALE
	source_image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	donut_cursor_texture = ImageTexture.create_from_image(source_image)


func _cancel_bob_interaction_targeting() -> void:
	if not whip_targeting_active and not donut_targeting_active:
		return
	whip_targeting_active = false
	donut_targeting_active = false
	Input.set_custom_mouse_cursor(null)
	_restore_board_after_bob_interaction_targeting()
	_update_bob_action_button_states()


func _handle_bob_interaction_targeting_input(event: InputEvent) -> bool:
	if not whip_targeting_active and not donut_targeting_active:
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_cancel_bob_interaction_targeting()
			get_viewport().set_input_as_handled()
			return true
		return false
	if not (event is InputEventMouseButton):
		return false

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button_event.pressed:
		return true
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		_cancel_bob_interaction_targeting()
		get_viewport().set_input_as_handled()
		return true

	if _is_point_on_bob(mouse_button_event.position):
		if whip_targeting_active:
			_apply_whip_to_bob()
		elif donut_targeting_active:
			_apply_donut_to_bob()
	else:
		_cancel_bob_interaction_targeting()
	get_viewport().set_input_as_handled()
	return true


func _is_point_on_bob(point: Vector2) -> bool:
	if miner == null:
		return false
	return point.distance_to(miner.global_position) <= WHIP_BOB_TARGET_RADIUS


func _apply_whip_to_bob() -> void:
	if miner == null or _is_bob_striking():
		_cancel_bob_interaction_targeting()
		return
	whip_targeting_active = false
	Input.set_custom_mouse_cursor(null)
	_restore_board_after_bob_interaction_targeting()
	_set_bob_relationship_hearts(bob_relationship_hearts - 1)
	miner.show_bob_emoji(BOB_WHIP_EMOJI)
	miner.play_whip_feedback()
	if _is_bob_striking():
		_update_bob_action_button_states()
		return
	miner.apply_whip_boost(WHIP_RUN_MULTIPLIER, WHIP_DIG_MULTIPLIER, WHIP_BOOST_DURATION)
	_update_bob_action_button_states()


func _apply_donut_to_bob() -> void:
	if miner == null:
		_cancel_bob_interaction_targeting()
		return
	donut_targeting_active = false
	Input.set_custom_mouse_cursor(null)
	_restore_board_after_bob_interaction_targeting()
	_set_bob_relationship_hearts(bob_relationship_hearts + 1)
	miner.show_bob_emoji(BOB_DONUT_EMOJI)
	miner.apply_donut_boost(DONUT_RUN_MULTIPLIER, DONUT_BONUS_LOOT_CHANCE, DONUT_BOOST_DURATION)
	_update_bob_action_button_states()


func _lock_board_for_bob_interaction_targeting() -> void:
	if board == null:
		return
	bob_interaction_previous_board_input_locked = board.input_locked
	board.set_input_locked(true)


func _restore_board_after_bob_interaction_targeting() -> void:
	if board == null:
		return
	board.set_input_locked(bob_interaction_previous_board_input_locked)


func _can_start_bob_interaction(is_whip: bool = false) -> bool:
	if not bob_action_menu_expanded:
		return false
	if miner == null:
		return false
	if miner.has_active_bob_buff():
		return false
	if is_whip and _is_bob_striking():
		return false
	return true


func _update_bob_action_button_states() -> void:
	var has_active_boost: bool = miner != null and miner.has_active_bob_buff()
	var boost_time_left: float = miner.get_bob_buff_time_left() if miner != null else 0.0
	var is_striking: bool = _is_bob_striking()
	if whip_button != null:
		whip_button.disabled = not bob_action_menu_expanded or whip_targeting_active or donut_targeting_active or has_active_boost or is_striking
		if whip_targeting_active:
			whip_button.tooltip_text = "%s\nClick Bob" % WHIP_EFFECT_TOOLTIP
		elif is_striking:
			whip_button.tooltip_text = "%s\nBob is on Strike" % WHIP_EFFECT_TOOLTIP
		elif has_active_boost:
			whip_button.tooltip_text = "%s\nBob is boosted: %.0fs" % [WHIP_EFFECT_TOOLTIP, ceilf(boost_time_left)]
		else:
			whip_button.tooltip_text = WHIP_EFFECT_TOOLTIP
	if donut_button != null:
		donut_button.disabled = not bob_action_menu_expanded or whip_targeting_active or donut_targeting_active or has_active_boost
		if donut_targeting_active:
			donut_button.tooltip_text = "%s\nFeed Bob" % DONUT_EFFECT_TOOLTIP
		elif has_active_boost:
			donut_button.tooltip_text = "%s\nBob is boosted: %.0fs" % [DONUT_EFFECT_TOOLTIP, ceilf(boost_time_left)]
		else:
			donut_button.tooltip_text = DONUT_EFFECT_TOOLTIP
	_set_bob_action_cooldown_label(whip_cooldown_label, has_active_boost, boost_time_left)
	_set_bob_action_cooldown_label(donut_cooldown_label, has_active_boost, boost_time_left)


func _set_bob_action_cooldown_label(label: Label, visible: bool, time_left: float) -> void:
	if label == null:
		return
	label.visible = visible
	if not visible:
		label.text = ""
		return
	label.text = "%.0fs" % ceilf(time_left)


func _set_bob_relationship_hearts(value: int) -> void:
	bob_relationship_hearts = clampi(value, BOB_RELATIONSHIP_MIN, BOB_RELATIONSHIP_MAX)
	_sync_bob_relationship_state()
	_update_bob_relationship_tooltip()
	_save_progress()


func _sync_bob_relationship_state() -> void:
	if miner == null:
		return
	miner.set_bob_relationship_state(_is_bob_striking(), _is_bob_happy())


func _is_bob_striking() -> bool:
	return bob_relationship_hearts <= BOB_RELATIONSHIP_MIN


func _is_bob_happy() -> bool:
	return bob_relationship_hearts >= BOB_RELATIONSHIP_MAX


func _update_bob_relationship_tooltip() -> void:
	if bob_button == null:
		return
	var state_text: String = "Normal"
	var bonus_text: String = ""
	if _is_bob_striking():
		state_text = "Strike 🍩?"
		bonus_text = "Whip blocked\nDonut available"
	elif _is_bob_happy():
		state_text = "Happy Bob 😊"
		bonus_text = "+10% Passive Bonus Loot"
	bob_button.tooltip_text = "Bob\n%s\nRelationship: %d/%d\nState: %s" % [
		_get_bob_relationship_hearts_text(),
		bob_relationship_hearts,
		BOB_RELATIONSHIP_MAX,
		state_text,
	]
	if not bonus_text.is_empty():
		bob_button.tooltip_text += "\n%s" % bonus_text


func _get_bob_relationship_hearts_text() -> String:
	var result: String = ""
	for index: int in range(BOB_RELATIONSHIP_MAX):
		if index < bob_relationship_hearts:
			result += BOB_RELATIONSHIP_FILLED_HEART
		else:
			result += BOB_RELATIONSHIP_EMPTY_HEART
	return result


func _is_mouse_inside_control(control: Control) -> bool:
	var mouse_position: Vector2 = control.get_global_mouse_position()
	return control.get_global_rect().has_point(mouse_position)


func _toggle_ore_inventory_panel() -> void:
	if ore_inventory_panel == null:
		return
	if ore_inventory_panel.visible:
		ore_inventory_panel.call("close_panel")
	else:
		_close_player_panels_except(ore_inventory_panel)
		ore_inventory_panel.call("open_panel")


func _setup_player_panel_overlay_sync() -> void:
	if ore_inventory_panel != null:
		var ore_visibility_callable: Callable = Callable(self, "_sync_player_panel_overlays")
		if not ore_inventory_panel.visibility_changed.is_connected(ore_visibility_callable):
			ore_inventory_panel.visibility_changed.connect(ore_visibility_callable)
	if upgrade_shop_panel != null:
		var upgrade_visibility_callable: Callable = Callable(self, "_sync_player_panel_overlays")
		if not upgrade_shop_panel.visibility_changed.is_connected(upgrade_visibility_callable):
			upgrade_shop_panel.visibility_changed.connect(upgrade_visibility_callable)
	if museum_panel != null:
		var museum_visibility_callable: Callable = Callable(self, "_sync_player_panel_overlays")
		if not museum_panel.visibility_changed.is_connected(museum_visibility_callable):
			museum_panel.visibility_changed.connect(museum_visibility_callable)
	_sync_player_panel_overlays()


func _sync_player_panel_overlays() -> void:
	if ore_inventory_overlay != null and ore_inventory_panel != null:
		ore_inventory_overlay.visible = ore_inventory_panel.visible
	if upgrade_shop_overlay != null and upgrade_shop_panel != null:
		upgrade_shop_overlay.visible = upgrade_shop_panel.visible
	if museum_overlay != null and museum_panel != null:
		museum_overlay.visible = museum_panel.visible


func _show_find_reward_popup() -> void:
	if board == null or miner == null:
		return
	if not board.has_unclaimed_find_drop():
		board.set_input_locked(false)
		miner.resume_after_relic_collection()
		return
	_close_player_panels_except(null)

	var drop_entries: Array[Dictionary] = board.get_current_find_drop_entries()
	if drop_entries.is_empty():
		board.set_input_locked(false)
		miner.resume_after_relic_collection()
		return

	var first_entry: Dictionary = drop_entries[0]
	var first_item_id: String = str(first_entry.get("item_id", ""))
	var rarity: String = str(first_entry.get("rarity", "common"))
	var reward_item: Dictionary = {}
	if game_state.find_catalog != null:
		reward_item = game_state.find_catalog.get_item(first_item_id).duplicate(true)
		reward_item["rarity"] = rarity

	var claimed: bool = board.claim_current_find_drop_to_inventory()
	if not claimed:
		board.sell_current_find_drop()
		_update_money_hud()
	_save_progress()

	await miner.show_find_reward(reward_item)
	board.set_input_locked(false)
	miner.resume_after_relic_collection()


func _on_relic_collection_requested(_relic_id: String, _item_ids: Array[String]) -> void:
	if ore_mining == null:
		return
	board.set_input_locked(true)
	ore_mining.begin_relic_session()


func _on_relic_hit_requested(damage: int) -> void:
	if miner == null:
		return
	miner.handle_relic_hit_requested(damage)


func _on_relic_collection_succeeded() -> void:
	if ore_mining != null:
		ore_mining.cancel_session()
	board.complete_active_relic_minigame()
	_save_progress()


func _on_relic_collection_failed() -> void:
	board.set_input_locked(false)
	miner.resume_after_relic_collection()


func _toggle_upgrade_shop_panel() -> void:
	if upgrade_shop_panel == null:
		return
	if upgrade_shop_panel.visible:
		upgrade_shop_panel.call("close_panel")
	else:
		_close_player_panels_except(upgrade_shop_panel)
		upgrade_shop_panel.call("open_panel")


func _toggle_museum_panel() -> void:
	if museum_panel == null:
		return
	if museum_panel.visible:
		museum_panel.call("close_panel")
	else:
		_close_player_panels_except(museum_panel)
		museum_panel.call("open_panel")


func _close_player_panels_except(active_panel: Control) -> void:
	if ore_inventory_panel != null and ore_inventory_panel != active_panel:
		ore_inventory_panel.call("close_panel")
	if upgrade_shop_panel != null and upgrade_shop_panel != active_panel:
		upgrade_shop_panel.call("close_panel")
	if museum_panel != null and museum_panel != active_panel:
		museum_panel.call("close_panel")


func _is_point_in_drag_area(point: Vector2) -> bool:
	var padded_drag_position: Vector2 = DRAG_AREA_POSITION + Vector2(0.0, float(WINDOW_TOP_PADDING))
	var drag_area_rect: Rect2 = Rect2(padded_drag_position, DRAG_AREA_SIZE)
	return drag_area_rect.has_point(point)


func _move_window_to_mouse() -> void:
	var mouse_position: Vector2i = DisplayServer.mouse_get_position()
	var target_position: Vector2i = mouse_position - drag_mouse_offset
	get_window().position = target_position
