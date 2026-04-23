extends Control
class_name OreInventoryRow

signal sell_requested(resource_type: String, tier: String)

const BASE_BG_COLOR: Color = Color(0.40, 0.67, 0.88, 0.98)
const HOVER_BG_COLOR: Color = Color(0.46, 0.73, 0.92, 1.0)

var resource_type: String = ""
var tier: String = "E"

@onready var background: ColorRect = get_node_or_null("Background") as ColorRect
@onready var tier_label: Label = get_node_or_null("Margin/HBox/IconFrame/TierLabel") as Label
@onready var count_label: Label = get_node_or_null("Margin/HBox/IconFrame/CountLabel") as Label
@onready var icon_rect: TextureRect = get_node_or_null("Margin/HBox/IconFrame/Icon") as TextureRect
@onready var name_label: Label = get_node_or_null("Margin/HBox/Info/NameLabel") as Label
@onready var total_price_label: Label = get_node_or_null("Margin/HBox/SellButton/Content/PriceLabel") as Label
@onready var sell_button: Button = get_node_or_null("Margin/HBox/SellButton") as Button


func _ready() -> void:
	_cache_nodes()
	if background != null:
		background.color = BASE_BG_COLOR
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
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


func _cache_nodes() -> void:
	if background == null:
		background = get_node_or_null("Background") as ColorRect
	if tier_label == null:
		tier_label = get_node_or_null("Margin/HBox/IconFrame/TierLabel") as Label
	if count_label == null:
		count_label = get_node_or_null("Margin/HBox/IconFrame/CountLabel") as Label
	if icon_rect == null:
		icon_rect = get_node_or_null("Margin/HBox/IconFrame/Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("Margin/HBox/Info/NameLabel") as Label
	if total_price_label == null:
		total_price_label = get_node_or_null("Margin/HBox/SellButton/Content/PriceLabel") as Label
	if sell_button == null:
		sell_button = get_node_or_null("Margin/HBox/SellButton") as Button


func _on_sell_pressed() -> void:
	sell_requested.emit(resource_type, tier)


func _on_mouse_entered() -> void:
	if background != null:
		background.color = HOVER_BG_COLOR


func _on_mouse_exited() -> void:
	if background != null:
		background.color = BASE_BG_COLOR
