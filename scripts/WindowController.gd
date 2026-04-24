extends Node2D

const ProgressSaveStore = preload("res://scripts/ProgressSave.gd")

const WINDOW_SIZE: Vector2i = Vector2i(532, 380)
const SCREEN_MARGIN: int = 0
const WINDOW_BOTTOM_OFFSET: int = 48
const DEPTH_SCALE_TOP: float = 4.0
const DEPTH_SCALE_HEIGHT: float = 224.0
const DEPTH_SCALE_MAX_LEVEL: int = 10
const FATIGUE_SCALE_TOP: float = 8.0
const FATIGUE_SCALE_HEIGHT: float = 188.0
const DRAG_AREA_POSITION: Vector2 = Vector2(24.0, 47.0)
const DRAG_AREA_SIZE: Vector2 = Vector2(424.0, 333.0)
const ACTION_BUTTON_HOVER_MODULATE: Color = Color(0.62, 0.62, 0.62, 1.0)
const ACTION_BUTTON_NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const ACTION_BUTTON_SHAKE_TIME: float = 0.18
const ACTION_BUTTON_SHAKE_MIN_ANGLE: float = 0.24
const ACTION_BUTTON_SHAKE_MAX_ANGLE: float = 0.4
const ACTION_BUTTON_SHAKE_SPRING_WAVES: float = 1.35
const ACTION_BUTTON_SHAKE_SPRING_DAMPING: float = 1.25
const ACTION_BUTTON_SHAKE_SPRING_BOOST: float = 1.45

@onready var game_state: GameState = get_node("GameState") as GameState
@onready var board: BoardController = get_node("Board") as BoardController
@onready var miner: MinerAgent = get_node("Miner") as MinerAgent
@onready var ore_mining: OreMiningComponent = get_node("OreMiningOverlay/OreMining") as OreMiningComponent
@onready var house: Sprite2D = get_node("House") as Sprite2D
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
@onready var fatigue_fill: ColorRect = get_node_or_null("HUD/FatigueScale/FatigueFill") as ColorRect
@onready var fatigue_value_label: Label = get_node_or_null("HUD/FatigueScale/FatigueValue") as Label

var is_dragging_window: bool = false
var drag_mouse_offset: Vector2i = Vector2i.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var action_button_slots: Array[Control] = []
var action_button_shake_timers: Array[float] = []
var action_button_shake_targets: Array[float] = []


func _init() -> void:
	ProjectSettings.set_setting("display/window/size/transparent", true)
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)


func _enter_tree() -> void:
	_configure_window()


func _ready() -> void:
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
	if exit_button != null:
		exit_button.pressed.connect(_quit_game)
	if ore_inventory_button != null:
		ore_inventory_button.pressed.connect(_toggle_ore_inventory_panel)
	_setup_action_button_hover(ore_inventory_button_slot, ore_inventory_button)
	if upgrade_shop_button != null:
		upgrade_shop_button.pressed.connect(_toggle_upgrade_shop_panel)
	_setup_action_button_hover(upgrade_shop_button_slot, upgrade_shop_button)
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
		money_label.text = "$%d" % game_state.currency

	if fatigue_fill == null or fatigue_value_label == null:
		return

	var fatigue_value: int = game_state.energy
	var fatigue_ratio: float = clampf(float(fatigue_value) / float(GameState.MAX_ENERGY), 0.0, 1.0)
	var fill_height: float = FATIGUE_SCALE_HEIGHT * fatigue_ratio
	fatigue_fill.position.y = FATIGUE_SCALE_TOP + FATIGUE_SCALE_HEIGHT - fill_height
	fatigue_fill.size.y = fill_height
	fatigue_value_label.text = str(fatigue_value)


func _update_depth_scale() -> void:
	if depth_marker == null or depth_marker_label == null:
		return
	var player_level: int = maxi(1, game_state.floor_number)
	var clamped_level: int = mini(player_level, DEPTH_SCALE_MAX_LEVEL)
	var depth_ratio: float = float(clamped_level) / float(DEPTH_SCALE_MAX_LEVEL)
	depth_marker.position.y = DEPTH_SCALE_TOP + depth_ratio * DEPTH_SCALE_HEIGHT
	depth_marker_label.text = "%d m" % player_level


func _setup_action_button_hover(slot: Control, button: TextureButton) -> void:
	if slot == null:
		return
	slot.modulate = ACTION_BUTTON_NORMAL_MODULATE
	slot.rotation = 0.0
	action_button_slots.append(slot)
	action_button_shake_timers.append(0.0)
	action_button_shake_targets.append(0.0)
	slot.mouse_entered.connect(_on_action_button_mouse_entered.bind(slot))
	slot.mouse_exited.connect(_on_action_button_mouse_exited.bind(slot))
	if button != null:
		button.mouse_entered.connect(_on_action_button_mouse_entered.bind(slot))
		button.mouse_exited.connect(_on_action_button_mouse_exited.bind(slot))


func _on_action_button_mouse_entered(slot: Control) -> void:
	var slot_index: int = action_button_slots.find(slot)
	if slot_index < 0:
		return
	if slot.modulate == ACTION_BUTTON_HOVER_MODULATE:
		return
	slot.modulate = ACTION_BUTTON_HOVER_MODULATE
	action_button_shake_timers[slot_index] = ACTION_BUTTON_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	action_button_shake_targets[slot_index] = rng.randf_range(
		ACTION_BUTTON_SHAKE_MIN_ANGLE,
		ACTION_BUTTON_SHAKE_MAX_ANGLE
	) * shake_sign


func _on_action_button_mouse_exited(slot: Control) -> void:
	if _is_mouse_inside_control(slot):
		return
	slot.modulate = ACTION_BUTTON_NORMAL_MODULATE


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
	var drag_area_rect: Rect2 = Rect2(DRAG_AREA_POSITION, DRAG_AREA_SIZE)
	return drag_area_rect.has_point(point)


func _move_window_to_mouse() -> void:
	var mouse_position: Vector2i = DisplayServer.mouse_get_position()
	var target_position: Vector2i = mouse_position - drag_mouse_offset
	get_window().position = target_position
