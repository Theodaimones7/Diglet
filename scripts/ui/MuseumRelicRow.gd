extends Control
class_name MuseumRelicRow

const TIER_ORDER: Array[String] = ["A", "B", "C", "D", "E"]
const LOCKED_TIER_COLOR: Color = Color(0.13, 0.09, 0.09, 0.82)
const ACTIVE_BG_COLOR: Color = Color(0.62, 0.29, 0.34, 0.98)
const HOVER_BG_COLOR: Color = Color(0.74, 0.39, 0.43, 1.0)
const LOCKED_ICON_COLOR: Color = Color(0.05, 0.05, 0.055, 1.0)
const UNLOCKED_ICON_COLOR: Color = Color.WHITE
const LOCKED_TEXT_COLOR: Color = Color(0.08, 0.06, 0.065, 1.0)
const UNLOCKED_TEXT_COLOR: Color = Color(1.0, 0.96, 0.9, 1.0)
const HOVER_SHAKE_TIME: float = 0.22
const HOVER_SHAKE_MIN_ANGLE: float = 0.05
const HOVER_SHAKE_MAX_ANGLE: float = 0.11
const HOVER_SHAKE_WAVES: float = 1.25
const HOVER_SHAKE_DAMPING: float = 1.45
const HOVER_SHAKE_BOOST: float = 1.0
const TIER_COLORS: Dictionary = {
	"E": Color(0.95, 0.22, 0.17, 1.0),
	"D": Color(0.95, 0.58, 0.19, 1.0),
	"C": Color(0.98, 0.86, 0.28, 1.0),
	"B": Color(0.37, 0.82, 0.34, 1.0),
	"A": Color(0.31, 0.79, 0.9, 1.0)
}

var background_style: StyleBoxFlat
var is_hovered: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hover_shake_timer: float = 0.0
var hover_shake_target: float = 0.0

@onready var background: Panel = get_node_or_null("Background") as Panel
@onready var icon_rect: TextureRect = get_node_or_null("Margin/HBox/IconSlot/IconFrame/Icon") as TextureRect
@onready var name_label: Label = get_node_or_null("Margin/HBox/NameLabel") as Label
@onready var tier_labels: Array[Label] = [
	get_node_or_null("Margin/HBox/Tiers/TierA") as Label,
	get_node_or_null("Margin/HBox/Tiers/TierB") as Label,
	get_node_or_null("Margin/HBox/Tiers/TierC") as Label,
	get_node_or_null("Margin/HBox/Tiers/TierD") as Label,
	get_node_or_null("Margin/HBox/Tiers/TierE") as Label
]


func _ready() -> void:
	rng.randomize()
	rotation = 0.0
	set_process(false)
	_center_pivot()
	resized.connect(_center_pivot)
	_setup_background_style()


func _process(delta: float) -> void:
	_update_hover_state()
	_update_hover_shake(delta)


func set_entry(entry: Dictionary) -> void:
	_cache_nodes()
	is_hovered = false
	hover_shake_timer = 0.0
	rotation = 0.0
	var icon_texture: Texture2D = entry.get("icon") as Texture2D
	if icon_texture == null:
		var icon_path: String = str(entry.get("icon_path", ""))
		if not icon_path.is_empty():
			icon_texture = load(icon_path) as Texture2D
	var tiers_variant: Variant = entry.get("tiers", {})
	var locked: bool = bool(entry.get("locked", false))
	var tiers: Dictionary = {}
	if tiers_variant is Dictionary:
		tiers = tiers_variant

	if icon_rect != null:
		icon_rect.texture = icon_texture
		icon_rect.self_modulate = LOCKED_ICON_COLOR if locked else UNLOCKED_ICON_COLOR
	if name_label != null:
		name_label.text = str(entry.get("name", "Unknown"))
		name_label.add_theme_color_override("font_color", LOCKED_TEXT_COLOR if locked else UNLOCKED_TEXT_COLOR)

	for index: int in range(tier_labels.size()):
		var label: Label = tier_labels[index]
		if label == null:
			continue
		label.visible = not locked
		var tier: String = TIER_ORDER[index]
		var active: bool = bool(tiers.get(tier, false))
		label.text = tier
		label.add_theme_color_override("font_color", _get_tier_color(tier) if active else LOCKED_TIER_COLOR)


func set_active(active: bool) -> void:
	set_process(active)
	if active:
		return
	is_hovered = false
	hover_shake_timer = 0.0
	rotation = 0.0
	if background_style != null:
		background_style.bg_color = ACTIVE_BG_COLOR


func _cache_nodes() -> void:
	if background == null:
		background = get_node_or_null("Background") as Panel
	if icon_rect == null:
		icon_rect = get_node_or_null("Margin/HBox/IconSlot/IconFrame/Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("Margin/HBox/NameLabel") as Label
	if tier_labels.is_empty() or tier_labels[0] == null:
		tier_labels = [
			get_node_or_null("Margin/HBox/Tiers/TierA") as Label,
			get_node_or_null("Margin/HBox/Tiers/TierB") as Label,
			get_node_or_null("Margin/HBox/Tiers/TierC") as Label,
			get_node_or_null("Margin/HBox/Tiers/TierD") as Label,
			get_node_or_null("Margin/HBox/Tiers/TierE") as Label
		]


func _setup_background_style() -> void:
	if background == null:
		return
	var panel_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style == null:
		return
	background_style = panel_style.duplicate() as StyleBoxFlat
	background_style.bg_color = ACTIVE_BG_COLOR
	background.add_theme_stylebox_override("panel", background_style)


func _update_hover_state() -> void:
	if background_style == null:
		return
	var hovered_now: bool = get_global_rect().has_point(get_global_mouse_position())
	if hovered_now == is_hovered:
		return
	is_hovered = hovered_now
	background_style.bg_color = HOVER_BG_COLOR if is_hovered else ACTIVE_BG_COLOR
	if is_hovered:
		_start_hover_shake()


func _get_tier_color(tier: String) -> Color:
	var color_variant: Variant = TIER_COLORS.get(tier, Color.WHITE)
	return color_variant as Color


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
