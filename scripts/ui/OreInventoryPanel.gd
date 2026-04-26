extends Control
class_name FindInventoryPanel

const SELL_ALL_SHAKE_TIME: float = 0.24
const SELL_ALL_SHAKE_MIN_ANGLE: float = 0.08
const SELL_ALL_SHAKE_MAX_ANGLE: float = 0.16
const SELL_ALL_SHAKE_SPRING_WAVES: float = 1.0
const SELL_ALL_SHAKE_SPRING_DAMPING: float = 1.6
const SELL_ALL_SHAKE_SPRING_BOOST: float = 0.85
const PANEL_SHAKE_TIME: float = 0.34
const PANEL_SHAKE_MIN_ANGLE: float = 0.22
const PANEL_SHAKE_MAX_ANGLE: float = 0.38
const PANEL_SHAKE_SPRING_WAVES: float = 1.45
const PANEL_SHAKE_SPRING_DAMPING: float = 1.25
const PANEL_SHAKE_SPRING_BOOST: float = 1.2

@export var row_scene: PackedScene

var game_state: GameState
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var sell_all_shake_timer: float = 0.0
var sell_all_shake_target: float = 0.0
var sell_all_hovered: bool = false
var panel_shake_timer: float = 0.0
var panel_shake_target: float = 0.0

@onready var title_label: Label = get_node_or_null("PanelMargin/Layout/Header/TitleLabel") as Label
@onready var counter_label: Label = get_node_or_null("PanelMargin/Layout/Header/CountLabel") as Label
@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton
@onready var sell_all_button: Button = get_node_or_null("PanelMargin/Layout/SellBar/SellAllButton") as Button
@onready var total_label: Label = get_node_or_null("PanelMargin/Layout/SellBar/SellAllButton/Content/TotalLabel") as Label
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll") as ScrollContainer
@onready var list_container: VBoxContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows") as VBoxContainer
@onready var empty_label: Label = get_node_or_null("PanelMargin/Layout/ListFrame/EmptyLabel") as Label


func _ready() -> void:
	rng.randomize()
	visible = false
	rotation = 0.0
	_center_panel_pivot()
	resized.connect(_center_panel_pivot)
	if title_label != null:
		title_label.text = "Finds"
	if close_button != null:
		close_button.pressed.connect(close_panel)
	if sell_all_button != null:
		sell_all_button.rotation = 0.0
		_center_sell_all_pivot()
		sell_all_button.resized.connect(_center_sell_all_pivot)
		sell_all_button.pressed.connect(_on_sell_all_pressed)


func _process(delta: float) -> void:
	_update_panel_shake(delta)
	_update_sell_all_hover_state()
	_update_sell_all_button_shake(delta)


func setup(state: GameState) -> void:
	game_state = state
	var refresh_callable: Callable = Callable(self, "_refresh")
	if not game_state.inventory_changed.is_connected(refresh_callable):
		game_state.inventory_changed.connect(refresh_callable)
	if not game_state.finds_changed.is_connected(refresh_callable):
		game_state.finds_changed.connect(refresh_callable)
	if not game_state.upgrades_changed.is_connected(refresh_callable):
		game_state.upgrades_changed.connect(refresh_callable)
	_refresh()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	visible = true
	_start_panel_shake()
	_refresh()


func close_panel() -> void:
	visible = false
	panel_shake_timer = 0.0
	rotation = 0.0


func _on_sell_all_pressed() -> void:
	if game_state == null:
		return
	_start_sell_all_button_shake()
	game_state.sell_all_found_items()


func _on_row_sell_requested(instance_id: String) -> void:
	if game_state == null:
		return
	game_state.sell_found_item(instance_id)


func _refresh() -> void:
	if game_state == null or scroll_container == null or list_container == null or empty_label == null:
		return

	var previous_scroll: float = scroll_container.scroll_vertical
	for child: Node in list_container.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = game_state.get_find_inventory_entries()
	empty_label.visible = entries.is_empty()
	for entry: Dictionary in entries:
		var row: Control = row_scene.instantiate() as Control
		row.call("set_entry", entry)
		row.connect("sell_requested", _on_row_sell_requested)
		list_container.add_child(row)

	if counter_label != null:
		counter_label.text = "%d/%d" % [game_state.get_find_inventory_count(), game_state.get_find_inventory_capacity()]
	if total_label != null:
		total_label.text = "$%d" % game_state.get_total_find_sell_value()
	if sell_all_button != null:
		sell_all_button.disabled = entries.is_empty()
	call_deferred("_restore_scroll_position", previous_scroll)


func _restore_scroll_position(previous_scroll: float) -> void:
	if scroll_container == null:
		return
	var max_scroll: float = scroll_container.get_v_scroll_bar().max_value
	scroll_container.scroll_vertical = int(clampf(previous_scroll, 0.0, max_scroll))


func _center_panel_pivot() -> void:
	pivot_offset = size * 0.5


func _start_panel_shake() -> void:
	panel_shake_timer = PANEL_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	panel_shake_target = rng.randf_range(PANEL_SHAKE_MIN_ANGLE, PANEL_SHAKE_MAX_ANGLE) * shake_sign


func _update_panel_shake(delta: float) -> void:
	if panel_shake_timer <= 0.0:
		rotation = lerpf(rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	panel_shake_timer = maxf(0.0, panel_shake_timer - delta)
	var target_rotation: float = _get_panel_shake_rotation(panel_shake_timer, panel_shake_target)
	rotation = lerpf(rotation, target_rotation, clampf(delta * 20.0, 0.0, 1.0))


func _get_panel_shake_rotation(active_timer: float, target_angle: float) -> float:
	if active_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - active_timer / PANEL_SHAKE_TIME
	var spring_phase: float = progress * TAU * PANEL_SHAKE_SPRING_WAVES
	var damping: float = pow(1.0 - progress, PANEL_SHAKE_SPRING_DAMPING)
	return sin(spring_phase) * damping * target_angle * PANEL_SHAKE_SPRING_BOOST


func _center_sell_all_pivot() -> void:
	if sell_all_button == null:
		return
	sell_all_button.pivot_offset = sell_all_button.size * 0.5


func _start_sell_all_button_shake() -> void:
	if sell_all_button == null:
		return
	sell_all_shake_timer = SELL_ALL_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	sell_all_shake_target = rng.randf_range(SELL_ALL_SHAKE_MIN_ANGLE, SELL_ALL_SHAKE_MAX_ANGLE) * shake_sign


func _update_sell_all_button_shake(delta: float) -> void:
	if sell_all_button == null:
		return
	if sell_all_shake_timer <= 0.0:
		sell_all_button.rotation = lerpf(sell_all_button.rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	sell_all_shake_timer = maxf(0.0, sell_all_shake_timer - delta)
	var target_rotation: float = _get_sell_all_button_shake_rotation(sell_all_shake_timer, sell_all_shake_target)
	sell_all_button.rotation = lerpf(sell_all_button.rotation, target_rotation, clampf(delta * 20.0, 0.0, 1.0))


func _update_sell_all_hover_state() -> void:
	if sell_all_button == null:
		return
	var hovered_now: bool = _is_mouse_inside_sell_all_button()
	if sell_all_hovered == hovered_now:
		return
	sell_all_hovered = hovered_now
	if sell_all_hovered:
		_start_sell_all_button_shake()


func _is_mouse_inside_sell_all_button() -> bool:
	if sell_all_button == null:
		return false
	var mouse_position: Vector2 = sell_all_button.get_global_mouse_position()
	return sell_all_button.get_global_rect().has_point(mouse_position)


func _get_sell_all_button_shake_rotation(active_timer: float, target_angle: float) -> float:
	if active_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - active_timer / SELL_ALL_SHAKE_TIME
	var spring_phase: float = progress * TAU * SELL_ALL_SHAKE_SPRING_WAVES
	var damping: float = pow(1.0 - progress, SELL_ALL_SHAKE_SPRING_DAMPING)
	return sin(spring_phase) * damping * target_angle * SELL_ALL_SHAKE_SPRING_BOOST
