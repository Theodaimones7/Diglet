extends Control
class_name MuseumPanel

const ROW_HEIGHT: float = 69.0
const VISIBLE_ROW_BUFFER: int = 3
const PANEL_SHAKE_TIME: float = 0.34
const PANEL_SHAKE_MIN_ANGLE: float = 0.22
const PANEL_SHAKE_MAX_ANGLE: float = 0.38
const PANEL_SHAKE_SPRING_WAVES: float = 1.45
const PANEL_SHAKE_SPRING_DAMPING: float = 1.25
const PANEL_SHAKE_SPRING_BOOST: float = 1.2

@export var row_scene: PackedScene

var game_state: GameState
var needs_refresh: bool = true
var refresh_generation: int = 0
var is_refreshing: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var panel_shake_timer: float = 0.0
var panel_shake_target: float = 0.0
var pooled_rows: Array[Control] = []
var current_entries: Array[Dictionary] = []
var has_loaded_entries: bool = false
var rendered_start_index: int = -1
var rendered_end_index: int = -1

@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton
@onready var rarity_filter_option: OptionButton = get_node_or_null("PanelMargin/Layout/FilterBar/RarityFilter") as OptionButton
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll") as ScrollContainer
@onready var list_container: VBoxContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows") as VBoxContainer
@onready var top_spacer: Control = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows/TopSpacer") as Control
@onready var visible_rows_container: VBoxContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows/VisibleRows") as VBoxContainer
@onready var bottom_spacer: Control = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows/BottomSpacer") as Control
@onready var empty_label: Label = get_node_or_null("PanelMargin/Layout/ListFrame/EmptyLabel") as Label


func _ready() -> void:
	rng.randomize()
	visible = false
	rotation = 0.0
	_center_panel_pivot()
	resized.connect(_center_panel_pivot)
	if close_button != null:
		close_button.pressed.connect(close_panel)
	if scroll_container != null:
		scroll_container.resized.connect(_on_scroll_view_changed)
		var vertical_scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar() as VScrollBar
		if vertical_scroll_bar != null:
			vertical_scroll_bar.value_changed.connect(_on_scroll_changed)
	_setup_rarity_filter()


func _process(delta: float) -> void:
	_update_panel_shake(delta)
	if visible and has_loaded_entries:
		_update_visible_rows_if_needed(false)


func setup(state: GameState) -> void:
	game_state = state
	var refresh_callable: Callable = Callable(self, "_on_museum_changed")
	if not game_state.museum_changed.is_connected(refresh_callable):
		game_state.museum_changed.connect(refresh_callable)
	needs_refresh = true
	if visible:
		_refresh()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	visible = true
	_start_panel_shake()
	if needs_refresh or not has_loaded_entries:
		_refresh()
	else:
		_set_rows_active(true)
		_update_visible_rows_if_needed(true)


func close_panel() -> void:
	refresh_generation += 1
	if is_refreshing:
		needs_refresh = true
	is_refreshing = false
	_set_rows_active(false)
	visible = false
	panel_shake_timer = 0.0
	rotation = 0.0


func _on_museum_changed() -> void:
	needs_refresh = true
	if visible:
		_refresh()


func _refresh() -> void:
	if game_state == null or row_scene == null or scroll_container == null or list_container == null or visible_rows_container == null or top_spacer == null or bottom_spacer == null or empty_label == null:
		return

	refresh_generation += 1
	is_refreshing = true
	needs_refresh = false
	var previous_scroll: float = scroll_container.scroll_vertical
	_hide_rows_from_index(0)

	current_entries = game_state.get_museum_entries()
	var selected_filter: String = _get_selected_rarity_filter()
	if not selected_filter.is_empty():
		var filtered_entries: Array[Dictionary] = []
		for entry: Dictionary in current_entries:
			if str(entry.get("rarity", "common")) == selected_filter:
				filtered_entries.append(entry)
		current_entries = filtered_entries
	has_loaded_entries = true
	rendered_start_index = -1
	rendered_end_index = -1
	empty_label.visible = current_entries.is_empty()
	is_refreshing = false
	_restore_scroll_position(previous_scroll)
	_update_visible_rows_if_needed(true)
	call_deferred("_restore_scroll_position", previous_scroll)
	call_deferred("_update_visible_rows_if_needed", true)


func _get_or_create_row(row_index: int) -> Control:
	if row_index < pooled_rows.size():
		return pooled_rows[row_index]
	var row: Control = row_scene.instantiate() as Control
	if row == null:
		return null
	visible_rows_container.add_child(row)
	pooled_rows.append(row)
	return row


func _hide_rows_from_index(start_index: int) -> void:
	for index: int in range(start_index, pooled_rows.size()):
		var row: Control = pooled_rows[index]
		if row == null:
			continue
		row.visible = false
		row.call("set_active", false)


func _set_rows_active(active: bool) -> void:
	for row: Control in pooled_rows:
		if row == null or not row.visible:
			continue
		row.call("set_active", active)


func _get_row_count() -> int:
	return current_entries.size()


func _update_visible_rows_if_needed(force: bool) -> void:
	if scroll_container == null or top_spacer == null or bottom_spacer == null:
		return
	var entry_count: int = current_entries.size()
	if entry_count <= 0:
		top_spacer.custom_minimum_size = Vector2.ZERO
		bottom_spacer.custom_minimum_size = Vector2.ZERO
		_hide_rows_from_index(0)
		rendered_start_index = 0
		rendered_end_index = 0
		return

	var scroll_value: float = float(scroll_container.scroll_vertical)
	var viewport_height: float = maxf(ROW_HEIGHT, scroll_container.size.y)
	var max_start_index: int = maxi(0, entry_count - 1)
	var first_visible: int = clampi(int(floor(scroll_value / ROW_HEIGHT)) - VISIBLE_ROW_BUFFER, 0, max_start_index)
	var visible_capacity: int = int(ceil(viewport_height / ROW_HEIGHT)) + VISIBLE_ROW_BUFFER * 2 + 1
	var end_index: int = mini(entry_count, first_visible + visible_capacity)
	if not force and first_visible == rendered_start_index and end_index == rendered_end_index:
		return
	rendered_start_index = first_visible
	rendered_end_index = end_index

	top_spacer.custom_minimum_size = Vector2(0.0, float(first_visible) * ROW_HEIGHT)
	bottom_spacer.custom_minimum_size = Vector2(0.0, float(entry_count - end_index) * ROW_HEIGHT)

	var row_index: int = 0
	for entry_index: int in range(first_visible, end_index):
		var row: Control = _get_or_create_row(row_index)
		if row == null:
			continue
		var entry: Dictionary = current_entries[entry_index]
		row.call("set_entry", entry)
		row.visible = true
		row.call("set_active", visible)
		row_index += 1
	_hide_rows_from_index(row_index)


func _on_scroll_changed(_value: float) -> void:
	if visible:
		_update_visible_rows_if_needed(false)


func _on_scroll_view_changed() -> void:
	if visible:
		_update_visible_rows_if_needed(true)


func _setup_rarity_filter() -> void:
	if rarity_filter_option == null:
		return
	rarity_filter_option.clear()
	rarity_filter_option.add_item("All")
	rarity_filter_option.add_item("Common")
	rarity_filter_option.add_item("Uncommon")
	rarity_filter_option.add_item("Rare")
	rarity_filter_option.add_item("Epic")
	rarity_filter_option.add_item("Legendary")
	var selected_callable: Callable = Callable(self, "_on_rarity_filter_selected")
	if not rarity_filter_option.item_selected.is_connected(selected_callable):
		rarity_filter_option.item_selected.connect(selected_callable)


func _on_rarity_filter_selected(_index: int) -> void:
	needs_refresh = true
	if visible:
		_refresh()


func _get_selected_rarity_filter() -> String:
	if rarity_filter_option == null:
		return ""
	match rarity_filter_option.selected:
		1:
			return "common"
		2:
			return "uncommon"
		3:
			return "rare"
		4:
			return "epic"
		5:
			return "legendary"
		_:
			return ""


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
