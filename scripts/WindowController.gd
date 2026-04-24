extends Node2D

const ProgressSaveStore = preload("res://scripts/ProgressSave.gd")
const MoneyWavyTextEffect = preload("res://ui/effects/wavy_text_effect.gd")

const WINDOW_CONTENT_SIZE: Vector2i = Vector2i(532, 380)
const WINDOW_TOP_PADDING: int = 32
const WINDOW_SIZE: Vector2i = Vector2i(WINDOW_CONTENT_SIZE.x, WINDOW_CONTENT_SIZE.y + WINDOW_TOP_PADDING)
const SCREEN_MARGIN: int = 0
const WINDOW_BOTTOM_OFFSET: int = 48
const DEPTH_SCALE_TOP: float = 7.0
const DEPTH_SCALE_HEIGHT: float = 195.0
const DEPTH_MARKER_CENTER_OFFSET: float = 11.0
const DEPTH_SCALE_MAX_LEVEL: int = 10
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
@onready var minimize_button: TextureButton = get_node_or_null("HUD/HBoxContainer/MinimizeButton") as TextureButton
@onready var exit_button: TextureButton = get_node_or_null("HUD/HBoxContainer/ExitButton") as TextureButton
@onready var depth_marker: Control = get_node_or_null("HUD/DepthScale/DepthMarker") as Control
@onready var depth_marker_label: Label = get_node_or_null("HUD/DepthScale/DepthMarker/DepthMarkerLabel") as Label
@onready var money_label: RichTextLabel = get_node_or_null("HUD/TextureRect/Money") as RichTextLabel
@onready var ore_inventory_button_slot: Control = get_node_or_null("HUD/ActionButtons/OreInventoryButtonSlot") as Control
@onready var ore_inventory_button: TextureButton = get_node_or_null("HUD/ActionButtons/OreInventoryButtonSlot/OreInventoryButton") as TextureButton
@onready var ore_inventory_panel: Control = get_node_or_null("OreInventoryOverlay/OreInventoryPanel") as Control
@onready var upgrade_shop_button_slot: Control = get_node_or_null("HUD/ActionButtons/UpgradeShopButtonSlot") as Control
@onready var upgrade_shop_button: TextureButton = get_node_or_null("HUD/ActionButtons/UpgradeShopButtonSlot/UpgradeShopButton") as TextureButton
@onready var upgrade_shop_panel: Control = get_node_or_null("UpgradeShopOverlay/UpgradeShopPanel") as Control
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


func _init() -> void:
	ProjectSettings.set_setting("display/window/size/transparent", true)
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)


func _enter_tree() -> void:
	_configure_window()


func _ready() -> void:
	_apply_window_top_padding()
	rng.randomize()
	var saved_progress: Dictionary = ProgressSaveStore.load_progress()
	var saved_game_state: Dictionary = ProgressSaveStore.get_section(saved_progress, "game_state")
	var saved_board_state: Dictionary = ProgressSaveStore.get_section(saved_progress, "board")
	game_state.load_from_save_data(saved_game_state)
	board.setup(game_state, saved_board_state)
	miner.setup(game_state, board, house.global_position, ore_mining)
	board.tile_clicked.connect(miner.handle_tile_click)
	ore_mining.session_lock_changed.connect(board.set_input_locked)
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
	_setup_money_label()
	game_state.stats_changed.connect(_update_hud)
	game_state.stats_changed.connect(_update_depth_scale)
	game_state.stats_changed.connect(_save_progress)
	board.state_changed.connect(_save_progress)
	if ore_inventory_panel != null:
		ore_inventory_panel.call("setup", game_state)
	_update_hud()
	_update_depth_scale()
	_save_progress()


func _process(delta: float) -> void:
	_update_action_button_hover_states()
	_update_action_button_shakes(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		is_dragging_window = false


func _unhandled_input(event: InputEvent) -> void:
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


func _quit_game() -> void:
	_save_progress()
	get_tree().quit()


func _minimize_game() -> void:
	_save_progress()
	get_window().mode = Window.MODE_MINIMIZED


func _save_progress() -> void:
	if not is_node_ready():
		return
	ProgressSaveStore.save_progress(game_state, board)


func _update_hud() -> void:
	if money_label != null:
		_set_money_amount(game_state.currency)

	if fatigue_fill == null or fatigue_value_label == null:
		return

	_set_fatigue_amount(game_state.energy)


func _set_fatigue_amount(target_energy: int) -> void:
	var clamped_energy: int = clampi(target_energy, 0, GameState.MAX_ENERGY)
	var target_height: float = _get_fatigue_fill_height(clamped_energy)
	_apply_fatigue_fill_height(fatigue_fill, target_height)
	fatigue_value_label.text = str(clamped_energy)

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


func _stop_fatigue_chase_tween() -> void:
	if fatigue_chase_tween != null and fatigue_chase_tween.is_valid():
		fatigue_chase_tween.kill()
	fatigue_chase_tween = null


func _get_fatigue_fill_height(energy_value: int) -> float:
	var clamped_energy: int = clampi(energy_value, 0, GameState.MAX_ENERGY)
	var fatigue_ratio: float = clampf(float(clamped_energy) / float(GameState.MAX_ENERGY), 0.0, 1.0)
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
	var clamped_level: int = mini(player_level, DEPTH_SCALE_MAX_LEVEL)
	var depth_ratio: float = float(clamped_level) / float(DEPTH_SCALE_MAX_LEVEL)
	depth_marker.position.y = DEPTH_SCALE_TOP + depth_ratio * DEPTH_SCALE_HEIGHT - DEPTH_MARKER_CENTER_OFFSET
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


func _is_mouse_inside_control(control: Control) -> bool:
	var mouse_position: Vector2 = control.get_global_mouse_position()
	return control.get_global_rect().has_point(mouse_position)


func _toggle_ore_inventory_panel() -> void:
	if ore_inventory_panel == null:
		return
	ore_inventory_panel.call("toggle_panel")


func _toggle_upgrade_shop_panel() -> void:
	if upgrade_shop_panel == null:
		return
	upgrade_shop_panel.call("toggle_panel")


func _is_point_in_drag_area(point: Vector2) -> bool:
	var padded_drag_position: Vector2 = DRAG_AREA_POSITION + Vector2(0.0, float(WINDOW_TOP_PADDING))
	var drag_area_rect: Rect2 = Rect2(padded_drag_position, DRAG_AREA_SIZE)
	return drag_area_rect.has_point(point)


func _move_window_to_mouse() -> void:
	var mouse_position: Vector2i = DisplayServer.mouse_get_position()
	var target_position: Vector2i = mouse_position - drag_mouse_offset
	get_window().position = target_position
