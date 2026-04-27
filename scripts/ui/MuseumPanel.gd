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
const DEPTH_FILTER_ZONES: Array[Dictionary] = [
	{"min_depth": 1, "max_depth": 20, "label": "Depths 1-20"},
	{"min_depth": 21, "max_depth": 50, "label": "Depths 21-50"},
	{"min_depth": 51, "max_depth": 100, "label": "Depths 51-100"},
	{"min_depth": 101, "max_depth": 200, "label": "Depths 101-200"},
	{"min_depth": 201, "max_depth": -1, "label": "Depths 201+"}
]

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
@onready var title_label: Label = get_node_or_null("PanelMargin/Layout/Header/TitleLabel") as Label
@onready var depth_filter_option: OptionButton = get_node_or_null("PanelMargin/Layout/FilterBar/DepthFilter") as OptionButton
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
	_setup_depth_filter()


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
	_update_depth_filter_labels()
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
	_select_current_depth_filter()
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

	_update_depth_filter_labels()
	current_entries = _get_entries_for_current_screen()
	has_loaded_entries = true
	rendered_start_index = -1
	rendered_end_index = -1
	empty_label.visible = current_entries.is_empty()
	_update_header_state()
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


func _setup_depth_filter() -> void:
	if depth_filter_option == null:
		return
	depth_filter_option.clear()
	depth_filter_option.add_item("All depths")
	for zone: Dictionary in DEPTH_FILTER_ZONES:
		depth_filter_option.add_item(str(zone.get("label", "Depths")))
	var selected_callable: Callable = Callable(self, "_on_depth_filter_selected")
	if not depth_filter_option.item_selected.is_connected(selected_callable):
		depth_filter_option.item_selected.connect(selected_callable)


func _on_depth_filter_selected(_index: int) -> void:
	needs_refresh = true
	if visible:
		_refresh()


func _select_current_depth_filter() -> void:
	if depth_filter_option == null or game_state == null:
		return
	var previous_selection: int = depth_filter_option.selected
	var current_depth: int = maxi(1, game_state.floor_number)
	for zone_index: int in range(DEPTH_FILTER_ZONES.size()):
		var zone: Dictionary = DEPTH_FILTER_ZONES[zone_index]
		var min_depth: int = int(zone.get("min_depth", 1))
		var max_depth: int = int(zone.get("max_depth", -1))
		if current_depth < min_depth:
			continue
		if max_depth >= 0 and current_depth > max_depth:
			continue
		depth_filter_option.select(zone_index + 1)
		if depth_filter_option.selected != previous_selection:
			needs_refresh = true
		return
	depth_filter_option.select(0)
	if depth_filter_option.selected != previous_selection:
		needs_refresh = true


func _get_entries_for_current_screen() -> Array[Dictionary]:
	if depth_filter_option == null:
		return game_state.get_museum_entries()
	var selected_index: int = depth_filter_option.selected
	if selected_index <= 0:
		return game_state.get_museum_entries()
	var zone_index: int = selected_index - 1
	if zone_index < 0 or zone_index >= DEPTH_FILTER_ZONES.size():
		return game_state.get_museum_entries()
	var zone: Dictionary = DEPTH_FILTER_ZONES[zone_index]
	var min_depth: int = int(zone.get("min_depth", 1))
	var max_depth: int = int(zone.get("max_depth", -1))
	return game_state.get_museum_entries_for_depth_range(min_depth, max_depth)


func _update_header_state() -> void:
	if title_label != null:
		title_label.text = _get_selected_depth_title()
	if empty_label != null:
		empty_label.text = "No relics in this depth"


func _update_depth_filter_labels() -> void:
	if depth_filter_option == null or game_state == null:
		return
	var previous_selection: int = depth_filter_option.selected
	depth_filter_option.clear()
	var all_progress: Dictionary = _get_total_progress()
	depth_filter_option.add_item("All depths (%d / %d)" % [int(all_progress.get("unlocked", 0)), int(all_progress.get("total", 0))])
	for zone: Dictionary in DEPTH_FILTER_ZONES:
		var min_depth: int = int(zone.get("min_depth", 1))
		var max_depth: int = int(zone.get("max_depth", -1))
		var entries: Array[Dictionary] = game_state.get_museum_entries_for_depth_range(min_depth, max_depth)
		var unlocked_count: int = 0
		for entry: Dictionary in entries:
			if not bool(entry.get("locked", false)):
				unlocked_count += 1
		depth_filter_option.add_item("%s (%d / %d)" % [str(zone.get("label", _format_depth_title(min_depth, max_depth))), unlocked_count, entries.size()])
	if previous_selection >= 0 and previous_selection < depth_filter_option.item_count:
		depth_filter_option.select(previous_selection)


func _get_total_progress() -> Dictionary:
	var entries: Array[Dictionary] = game_state.get_museum_entries()
	var unlocked_count: int = 0
	for entry: Dictionary in entries:
		if not bool(entry.get("locked", false)):
			unlocked_count += 1
	return {
		"unlocked": unlocked_count,
		"total": entries.size()
	}


func _get_selected_depth_title() -> String:
	if depth_filter_option == null or depth_filter_option.selected <= 0:
		return "Museum"
	var zone_index: int = depth_filter_option.selected - 1
	if zone_index < 0 or zone_index >= DEPTH_FILTER_ZONES.size():
		return "Museum"
	var zone: Dictionary = DEPTH_FILTER_ZONES[zone_index]
	return str(zone.get("label", "Museum"))


func _format_depth_title(min_depth: int, max_depth: int) -> String:
	if max_depth < 0:
		return "Depths %d+" % maxi(1, min_depth)
	return "Depths %d-%d" % [maxi(1, min_depth), maxi(1, max_depth)]


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
