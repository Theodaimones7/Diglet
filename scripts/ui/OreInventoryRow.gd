extends Control
class_name OreInventoryRow

signal sell_requested(resource_type: String, tier: String)

const BASE_BG_COLOR: Color = Color(0.38, 0.52, 0.2, 0.98)
const HOVER_BG_COLOR: Color = Color(0.48, 0.63, 0.25, 1.0)
const HOVER_SHAKE_TIME: float = 0.22
const HOVER_SHAKE_MIN_ANGLE: float = 0.05
const HOVER_SHAKE_MAX_ANGLE: float = 0.11
const HOVER_SHAKE_WAVES: float = 1.25
const HOVER_SHAKE_DAMPING: float = 1.45
const HOVER_SHAKE_BOOST: float = 1.0

var resource_type: String = ""
var tier: String = "E"
var is_hovered: bool = false
var background_style: StyleBoxFlat
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hover_shake_timer: float = 0.0
var hover_shake_target: float = 0.0

@onready var background: Panel = get_node_or_null("Background") as Panel
@onready var tier_label: Label = get_node_or_null("Margin/HBox/IconSlot/TierLabel") as Label
@onready var count_label: Label = get_node_or_null("Margin/HBox/IconSlot/CountLabel") as Label
@onready var icon_rect: TextureRect = get_node_or_null("Margin/HBox/IconSlot/IconFrame/Icon") as TextureRect
@onready var name_label: Label = get_node_or_null("Margin/HBox/Info/NameLabel") as Label
@onready var total_price_label: Label = get_node_or_null("Margin/HBox/SellButton/Content/PriceLabel") as Label
@onready var sell_button: Button = get_node_or_null("Margin/HBox/SellButton") as Button


func _ready() -> void:
	rng.randomize()
	rotation = 0.0
	_cache_nodes()
	_center_pivot()
	resized.connect(_center_pivot)
	_setup_background_style()
	if sell_button != null:
		sell_button.pressed.connect(_on_sell_pressed)


func set_entry(entry: Dictionary) -> void:
	_cache_nodes()
	resource_type = str(entry.get("resource_type", "Ore"))
	tier = str(entry.get("tier", "E"))
	var quantity: int = int(entry.get("quantity", 0))
	var total_price: int = int(entry.get("total_price", 0))
	var icon_texture: Texture2D = entry.get("icon") as Texture2D
	var icon_modulate_variant: Variant = entry.get("icon_modulate", Color.WHITE)
	var icon_modulate: Color = icon_modulate_variant as Color
	var tier_color_variant: Variant = entry.get("tier_color", Color.WHITE)
	var tier_color: Color = tier_color_variant as Color

	if name_label != null:
		name_label.text = resource_type
	if tier_label != null:
		tier_label.text = tier
		tier_label.add_theme_color_override("font_color", tier_color)
	if count_label != null:
		count_label.text = "x%d" % quantity
	if total_price_label != null:
		total_price_label.text = "$%d" % total_price
	if icon_rect != null:
		icon_rect.texture = icon_texture
		icon_rect.modulate = icon_modulate
	if sell_button != null:
		sell_button.disabled = quantity <= 0


func _process(delta: float) -> void:
	_update_hover_state()
	_update_hover_shake(delta)


func _cache_nodes() -> void:
	if background == null:
		background = get_node_or_null("Background") as Panel
	if tier_label == null:
		tier_label = get_node_or_null("Margin/HBox/IconSlot/TierLabel") as Label
	if count_label == null:
		count_label = get_node_or_null("Margin/HBox/IconSlot/CountLabel") as Label
	if icon_rect == null:
		icon_rect = get_node_or_null("Margin/HBox/IconSlot/IconFrame/Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("Margin/HBox/Info/NameLabel") as Label
	if total_price_label == null:
		total_price_label = get_node_or_null("Margin/HBox/SellButton/Content/PriceLabel") as Label
	if sell_button == null:
		sell_button = get_node_or_null("Margin/HBox/SellButton") as Button


func _on_sell_pressed() -> void:
	sell_requested.emit(resource_type, tier)


func _update_hover_state() -> void:
	var hovered_now: bool = _is_mouse_inside_slot()
	if is_hovered == hovered_now:
		return
	is_hovered = hovered_now
	if is_hovered:
		_apply_hover_state()
	else:
		_apply_normal_state()


func _apply_hover_state() -> void:
	if background_style != null:
		background_style.bg_color = HOVER_BG_COLOR
	_start_hover_shake()


func _apply_normal_state() -> void:
	if background_style != null:
		background_style.bg_color = BASE_BG_COLOR


func _is_mouse_inside_slot() -> bool:
	var mouse_position: Vector2 = get_global_mouse_position()
	return get_global_rect().has_point(mouse_position)


func _setup_background_style() -> void:
	if background == null:
		return
	var panel_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null:
		return
	background_style = panel_style.duplicate() as StyleBoxFlat
	background_style.bg_color = BASE_BG_COLOR
	background.add_theme_stylebox_override("panel", background_style)


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _start_hover_shake() -> void:
	hover_shake_timer = HOVER_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	hover_shake_target = rng.randf_range(HOVER_SHAKE_MIN_ANGLE, HOVER_SHAKE_MAX_ANGLE) * shake_sign


func _update_hover_shake(delta: float) -> void:
	if hover_shake_timer <= 0.0:
		rotation = lerpf(rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	hover_shake_timer = maxf(0.0, hover_shake_timer - delta)
	var target_rotation: float = _get_hover_shake_rotation(hover_shake_timer, hover_shake_target)
	rotation = lerpf(rotation, target_rotation, clampf(delta * 22.0, 0.0, 1.0))


func _get_hover_shake_rotation(active_timer: float, target_angle: float) -> float:
	if active_timer <= 0.0:
		return 0.0
	var progress: float = 1.0 - active_timer / HOVER_SHAKE_TIME
	var spring_phase: float = progress * TAU * HOVER_SHAKE_WAVES
	var damping: float = pow(1.0 - progress, HOVER_SHAKE_DAMPING)
	return sin(spring_phase) * damping * target_angle * HOVER_SHAKE_BOOST
