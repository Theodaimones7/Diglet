extends Control
class_name MuseumPanel

const ROWS_PER_FRAME: int = 28
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

@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton
@onready var rarity_filter_option: OptionButton = get_node_or_null("PanelMargin/Layout/FilterBar/RarityFilter") as OptionButton
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll") as ScrollContainer
@onready var list_container: VBoxContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows") as VBoxContainer
@onready var empty_label: Label = get_node_or_null("PanelMargin/Layout/ListFrame/EmptyLabel") as Label


func _ready() -> void:
	rng.randomize()
	visible = false
	rotation = 0.0
	_center_panel_pivot()
	resized.connect(_center_panel_pivot)
	if close_button != null:
		close_button.pressed.connect(close_panel)
	_setup_rarity_filter()


func _process(delta: float) -> void:
	_update_panel_shake(delta)


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
	if needs_refresh or _get_row_count() <= 0:
		_refresh()


func close_panel() -> void:
	visible = false
	panel_shake_timer = 0.0
	rotation = 0.0


func _on_museum_changed() -> void:
	needs_refresh = true
	if visible:
		_refresh()


func _refresh() -> void:
	if game_state == null or row_scene == null or scroll_container == null or list_container == null or empty_label == null:
		return

	refresh_generation += 1
	var generation: int = refresh_generation
	is_refreshing = true
	needs_refresh = false
	var previous_scroll: float = scroll_container.scroll_vertical
	for child: Node in list_container.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = game_state.get_museum_entries()
	var selected_filter: String = _get_selected_rarity_filter()
	if not selected_filter.is_empty():
		var filtered_entries: Array[Dictionary] = []
		for entry: Dictionary in entries:
			if str(entry.get("rarity", "common")) == selected_filter:
				filtered_entries.append(entry)
		entries = filtered_entries
	empty_label.visible = entries.is_empty()
	_populate_rows(entries, previous_scroll, generation)


func _populate_rows(entries: Array[Dictionary], previous_scroll: float, generation: int) -> void:
	var rows_this_frame: int = 0
	for entry: Dictionary in entries:
		if generation != refresh_generation:
			return
		var row: Control = row_scene.instantiate() as Control
		row.call("set_entry", entry)
		list_container.add_child(row)
		rows_this_frame += 1
		if rows_this_frame >= ROWS_PER_FRAME:
			rows_this_frame = 0
			await get_tree().process_frame

	if generation != refresh_generation:
		return
	is_refreshing = false
	call_deferred("_restore_scroll_position", previous_scroll)


func _get_row_count() -> int:
	if list_container == null:
		return 0
	return list_container.get_child_count()


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
