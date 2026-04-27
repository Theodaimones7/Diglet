extends Control
class_name UpgradeShopPanel

const PANEL_SHAKE_TIME: float = 0.34
const PANEL_SHAKE_MIN_ANGLE: float = 0.22
const PANEL_SHAKE_MAX_ANGLE: float = 0.38
const PANEL_SHAKE_SPRING_WAVES: float = 1.45
const PANEL_SHAKE_SPRING_DAMPING: float = 1.25
const PANEL_SHAKE_SPRING_BOOST: float = 1.2
const SLOT_TEXT_COLOR: Color = Color(0.94, 0.86, 0.68, 1.0)
const SLOT_DISABLED_TEXT_COLOR: Color = Color(0.62, 0.58, 0.48, 1.0)
const SLOT_MAX_TEXT_COLOR: Color = Color(0.93, 0.68, 0.34, 1.0)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var game_state: GameState
var panel_shake_timer: float = 0.0
var panel_shake_target: float = 0.0
var upgrade_buttons: Dictionary = {}
var upgrade_display_nodes: Dictionary = {}

@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton
@onready var pickaxe_button: Button = get_node_or_null("PanelMargin/Layout/Body/ListFrame/Scroll/Rows/PickaxeUpgrade") as Button
@onready var stamina_button: Button = get_node_or_null("PanelMargin/Layout/Body/ListFrame/Scroll/Rows/StaminaUpgrade") as Button
@onready var bag_button: Button = get_node_or_null("PanelMargin/Layout/Body/ListFrame/Scroll/Rows/BagUpgrade") as Button
@onready var focus_button: Button = get_node_or_null("PanelMargin/Layout/Body/ListFrame/Scroll/Rows/FocusUpgrade") as Button
@onready var refinery_button: Button = get_node_or_null("PanelMargin/Layout/Body/ListFrame/Scroll/Rows/RefineryUpgrade") as Button


func _ready() -> void:
	rng.randomize()
	visible = false
	rotation = 0.0
	_center_panel_pivot()
	resized.connect(_center_panel_pivot)
	if close_button != null:
		close_button.pressed.connect(close_panel)
	_register_upgrade_buttons()


func setup(state: GameState) -> void:
	game_state = state
	var refresh_callable: Callable = Callable(self, "_refresh")
	if not game_state.currency_changed.is_connected(refresh_callable):
		game_state.currency_changed.connect(refresh_callable)
	if not game_state.upgrades_changed.is_connected(refresh_callable):
		game_state.upgrades_changed.connect(refresh_callable)
	_refresh()


func _process(delta: float) -> void:
	_update_panel_shake(delta)


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


func _center_panel_pivot() -> void:
	pivot_offset = size * 0.5


func _start_panel_shake() -> void:
	panel_shake_timer = PANEL_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	panel_shake_target = rng.randf_range(PANEL_SHAKE_MIN_ANGLE, PANEL_SHAKE_MAX_ANGLE) * shake_sign


func _register_upgrade_buttons() -> void:
	upgrade_buttons.clear()
	upgrade_display_nodes.clear()
	_register_upgrade_button(GameState.UPGRADE_PICKAXE, pickaxe_button)
	_register_upgrade_button(GameState.UPGRADE_STAMINA, stamina_button)
	_register_upgrade_button(GameState.UPGRADE_BAG, bag_button)
	_register_upgrade_button(GameState.UPGRADE_FOCUS, focus_button)
	_register_upgrade_button(GameState.UPGRADE_REFINERY, refinery_button)


func _register_upgrade_button(upgrade_id: String, button: Button) -> void:
	if button == null:
		return
	upgrade_buttons[upgrade_id] = button
	upgrade_display_nodes[upgrade_id] = {
		"name": button.get_node_or_null("Content/Info/NameLabel") as Label,
		"meta": button.get_node_or_null("Content/Info/MetaLabel") as Label,
		"cost": button.get_node_or_null("Content/CostLabel") as Label
	}
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))


func _on_upgrade_pressed(upgrade_id: String) -> void:
	if game_state == null:
		return
	if game_state.purchase_upgrade(upgrade_id):
		_start_panel_shake()
	_refresh()


func _refresh() -> void:
	if game_state == null:
		return

	for upgrade_id_variant: Variant in upgrade_buttons.keys():
		var upgrade_id: String = str(upgrade_id_variant)
		var button: Button = upgrade_buttons.get(upgrade_id) as Button
		if button == null:
			continue
		var level: int = game_state.get_upgrade_level(upgrade_id)
		var max_level: int = game_state.get_upgrade_max_level(upgrade_id)
		var display_name: String = _get_upgrade_slot_name(upgrade_id)
		if game_state.is_upgrade_maxed(upgrade_id):
			_set_upgrade_slot_text(upgrade_id, display_name, level, max_level, "MAX")
			_set_upgrade_slot_tooltip(button, _get_upgrade_tooltip(upgrade_id, level, max_level))
			button.disabled = true
			_set_upgrade_slot_text_color(upgrade_id, SLOT_MAX_TEXT_COLOR)
		else:
			var cost: int = game_state.get_upgrade_cost(upgrade_id)
			_set_upgrade_slot_text(upgrade_id, display_name, level, max_level, "$%d" % cost)
			_set_upgrade_slot_tooltip(button, _get_upgrade_tooltip(upgrade_id, level, max_level))
			button.disabled = not game_state.can_purchase_upgrade(upgrade_id)
			_set_upgrade_slot_text_color(upgrade_id, SLOT_DISABLED_TEXT_COLOR if button.disabled else SLOT_TEXT_COLOR)


func _set_upgrade_slot_text(upgrade_id: String, display_name: String, level: int, max_level: int, cost_text: String) -> void:
	var display_nodes: Dictionary = upgrade_display_nodes.get(upgrade_id, {}) as Dictionary
	var name_label: Label = display_nodes.get("name") as Label
	var meta_label: Label = display_nodes.get("meta") as Label
	var cost_label: Label = display_nodes.get("cost") as Label
	if name_label != null:
		name_label.text = display_name
	if meta_label != null:
		meta_label.text = cost_text
	if cost_label != null:
		cost_label.text = ""


func _set_upgrade_slot_text_color(upgrade_id: String, color: Color) -> void:
	var display_nodes: Dictionary = upgrade_display_nodes.get(upgrade_id, {}) as Dictionary
	var name_label: Label = display_nodes.get("name") as Label
	var meta_label: Label = display_nodes.get("meta") as Label
	var cost_label: Label = display_nodes.get("cost") as Label
	if name_label != null:
		name_label.add_theme_color_override("font_color", color)
	if meta_label != null:
		meta_label.add_theme_color_override("font_color", color)
	if cost_label != null:
		cost_label.add_theme_color_override("font_color", color)


func _set_upgrade_slot_tooltip(button: Button, tooltip_value: String) -> void:
	var upgrade_slot_button: UpgradeSlotButton = button as UpgradeSlotButton
	if upgrade_slot_button != null:
		upgrade_slot_button.set_upgrade_tooltip_text(tooltip_value)
		return
	button.tooltip_text = tooltip_value


func _get_upgrade_slot_name(upgrade_id: String) -> String:
	match upgrade_id:
		GameState.UPGRADE_PICKAXE:
			return "Pickaxe Power"
		GameState.UPGRADE_STAMINA:
			return "Max Energy"
		GameState.UPGRADE_BAG:
			return "Bag Capacity"
		GameState.UPGRADE_FOCUS:
			return "Green Zone"
		GameState.UPGRADE_REFINERY:
			return "Sell Value"
		_:
			return game_state.get_upgrade_display_name(upgrade_id)


func _get_upgrade_tooltip(upgrade_id: String, level: int, max_level: int) -> String:
	var stat_name: String = _get_upgrade_slot_name(upgrade_id)
	if level >= max_level:
		return "%s:\nMAX" % stat_name
	var value_text: String = _get_upgrade_value_text(upgrade_id, level, level + 1)
	return "%s:\n%s" % [stat_name, value_text]


func _get_upgrade_value_text(upgrade_id: String, current_level: int, next_level: int) -> String:
	match upgrade_id:
		GameState.UPGRADE_PICKAXE:
			var current_rock: int = 1 + current_level
			var next_rock: int = 1 + next_level
			return "%d -> %d" % [current_rock, next_rock]
		GameState.UPGRADE_STAMINA:
			var current_energy: int = GameState.BASE_MAX_ENERGY + current_level * 5
			var next_energy: int = GameState.BASE_MAX_ENERGY + next_level * 5
			return "%d -> %d" % [current_energy, next_energy]
		GameState.UPGRADE_BAG:
			var current_capacity: int = GameState.BASE_ORE_INVENTORY_CAPACITY + current_level * 10
			var next_capacity: int = GameState.BASE_ORE_INVENTORY_CAPACITY + next_level * 10
			return "%d -> %d" % [current_capacity, next_capacity]
		GameState.UPGRADE_FOCUS:
			var current_green: int = mini(20, current_level * 4)
			var next_green: int = mini(20, next_level * 4)
			return "%d%% -> %d%%" % [current_green, next_green]
		GameState.UPGRADE_REFINERY:
			var current_sell: int = current_level * 8
			var next_sell: int = next_level * 8
			return "+%d%% -> +%d%%" % [current_sell, next_sell]
		_:
			return game_state.get_upgrade_effect_text(upgrade_id)


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
