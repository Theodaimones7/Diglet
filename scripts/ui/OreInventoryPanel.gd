extends Control
class_name OreInventoryPanel

@export var row_scene: PackedScene

var game_state: GameState

@onready var title_label: Label = get_node_or_null("PanelMargin/Layout/Header/TitleLabel") as Label
@onready var counter_label: Label = get_node_or_null("PanelMargin/Layout/Header/CountLabel") as Label
@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton
@onready var sell_all_button: Button = get_node_or_null("PanelMargin/Layout/SellBar/SellAllButton") as Button
@onready var total_label: Label = get_node_or_null("PanelMargin/Layout/SellBar/SellAllButton/Content/TotalLabel") as Label
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll") as ScrollContainer
@onready var list_container: VBoxContainer = get_node_or_null("PanelMargin/Layout/ListFrame/Scroll/Rows") as VBoxContainer
@onready var empty_label: Label = get_node_or_null("PanelMargin/Layout/ListFrame/EmptyLabel") as Label


func _ready() -> void:
	visible = false
	if title_label != null:
		title_label.text = "Ore Inventory"
	if close_button != null:
		close_button.pressed.connect(close_panel)
	if sell_all_button != null:
		sell_all_button.pressed.connect(_on_sell_all_pressed)


func setup(state: GameState) -> void:
	game_state = state
	var refresh_callable: Callable = Callable(self, "_refresh")
	if not game_state.stats_changed.is_connected(refresh_callable):
		game_state.stats_changed.connect(refresh_callable)
	_refresh()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false


func _on_sell_all_pressed() -> void:
	if game_state == null:
		return
	game_state.sell_all_carried_ore()


func _on_row_sell_requested(resource_type: String, tier: String) -> void:
	if game_state == null:
		return
	game_state.sell_ore_stack(resource_type, tier)


func _refresh() -> void:
	if game_state == null or scroll_container == null or list_container == null or empty_label == null:
		return

	var previous_scroll: float = scroll_container.scroll_vertical
	for child: Node in list_container.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = game_state.get_ore_inventory_entries()
	empty_label.visible = entries.is_empty()
	for entry: Dictionary in entries:
		var row: Control = row_scene.instantiate() as Control
		row.call("set_entry", entry)
		row.connect("sell_requested", _on_row_sell_requested)
		list_container.add_child(row)

	if counter_label != null:
		counter_label.text = "%d/%d" % [game_state.get_ore_inventory_stack_count(), game_state.get_ore_inventory_capacity()]
	if total_label != null:
		total_label.text = "$%d" % game_state.get_total_sell_value()
	if sell_all_button != null:
		sell_all_button.disabled = entries.is_empty()
	call_deferred("_restore_scroll_position", previous_scroll)


func _restore_scroll_position(previous_scroll: float) -> void:
	if scroll_container == null:
		return
	var max_scroll: float = scroll_container.get_v_scroll_bar().max_value
	scroll_container.scroll_vertical = int(clampf(previous_scroll, 0.0, max_scroll))
