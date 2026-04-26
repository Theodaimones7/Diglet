extends Button
class_name UpgradeSlotButton

const TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/UpgradeTooltip.tscn")
const TOOLTIP_GAP: float = 8.0
const VIEWPORT_PADDING: float = 4.0
const SLOT_SHAKE_TIME: float = 0.22
const SLOT_SHAKE_MIN_ANGLE: float = 0.05
const SLOT_SHAKE_MAX_ANGLE: float = 0.11
const SLOT_SHAKE_WAVES: float = 1.25
const SLOT_SHAKE_DAMPING: float = 1.45
const TOOLTIP_SHAKE_TIME: float = 0.2
const TOOLTIP_SHAKE_MIN_ANGLE: float = 0.035
const TOOLTIP_SHAKE_MAX_ANGLE: float = 0.08
const TOOLTIP_SHAKE_WAVES: float = 1.2
const TOOLTIP_SHAKE_DAMPING: float = 1.5

var upgrade_tooltip_text: String = ""
var active_tooltip: Control
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var slot_shake_timer: float = 0.0
var slot_shake_target: float = 0.0
var tooltip_shake_timer: float = 0.0
var tooltip_shake_target: float = 0.0


func _ready() -> void:
	rng.randomize()
	rotation = 0.0
	_center_pivot()
	resized.connect(_center_pivot)
	tooltip_text = ""
	mouse_entered.connect(_request_upgrade_tooltip)
	mouse_exited.connect(_cancel_upgrade_tooltip)
	focus_entered.connect(_request_upgrade_tooltip)
	focus_exited.connect(_cancel_upgrade_tooltip)
	tree_exiting.connect(_cancel_upgrade_tooltip)


func _process(delta: float) -> void:
	_update_slot_shake(delta)
	if active_tooltip != null:
		_position_active_tooltip()
		_update_tooltip_shake(delta)


func set_upgrade_tooltip_text(value: String) -> void:
	upgrade_tooltip_text = value
	tooltip_text = ""
	if active_tooltip != null:
		active_tooltip.call("set_upgrade_tooltip_text", upgrade_tooltip_text)
		_position_active_tooltip()


func _request_upgrade_tooltip() -> void:
	if upgrade_tooltip_text.is_empty():
		return
	_start_slot_shake()
	_show_upgrade_tooltip()


func _cancel_upgrade_tooltip() -> void:
	_hide_upgrade_tooltip()


func _show_upgrade_tooltip() -> void:
	if upgrade_tooltip_text.is_empty() or active_tooltip != null:
		return
	var tooltip_node: Node = TOOLTIP_SCENE.instantiate()
	var tooltip: Control = tooltip_node as Control
	if tooltip == null:
		return
	tooltip.call("set_upgrade_tooltip_text", upgrade_tooltip_text)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.top_level = true
	add_child(tooltip)
	active_tooltip = tooltip
	_position_active_tooltip()
	_center_tooltip_pivot()
	_start_tooltip_shake()


func _hide_upgrade_tooltip() -> void:
	if active_tooltip == null:
		return
	active_tooltip.queue_free()
	active_tooltip = null
	tooltip_shake_timer = 0.0


func _position_active_tooltip() -> void:
	if active_tooltip == null:
		return
	var tooltip_size: Vector2 = active_tooltip.get_combined_minimum_size()
	if tooltip_size.x <= 0.0 or tooltip_size.y <= 0.0:
		tooltip_size = active_tooltip.size
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_position: Vector2 = global_position + Vector2(
		(size.x - tooltip_size.x) * 0.5,
		-tooltip_size.y - TOOLTIP_GAP
	)
	var max_x: float = maxf(VIEWPORT_PADDING, viewport_size.x - tooltip_size.x - VIEWPORT_PADDING)
	target_position.x = clampf(target_position.x, VIEWPORT_PADDING, max_x)
	target_position.y = maxf(VIEWPORT_PADDING, target_position.y)
	active_tooltip.global_position = target_position


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _center_tooltip_pivot() -> void:
	if active_tooltip == null:
		return
	active_tooltip.pivot_offset = active_tooltip.size * 0.5


func _start_slot_shake() -> void:
	slot_shake_timer = SLOT_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	slot_shake_target = rng.randf_range(SLOT_SHAKE_MIN_ANGLE, SLOT_SHAKE_MAX_ANGLE) * shake_sign


func _update_slot_shake(delta: float) -> void:
	if slot_shake_timer <= 0.0:
		rotation = lerpf(rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	slot_shake_timer = maxf(0.0, slot_shake_timer - delta)
	var target_rotation: float = _get_shake_rotation(slot_shake_timer, slot_shake_target, SLOT_SHAKE_TIME, SLOT_SHAKE_WAVES, SLOT_SHAKE_DAMPING)
	rotation = lerpf(rotation, target_rotation, clampf(delta * 22.0, 0.0, 1.0))


func _start_tooltip_shake() -> void:
	tooltip_shake_timer = TOOLTIP_SHAKE_TIME
	var shake_sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
	tooltip_shake_target = rng.randf_range(TOOLTIP_SHAKE_MIN_ANGLE, TOOLTIP_SHAKE_MAX_ANGLE) * shake_sign


func _update_tooltip_shake(delta: float) -> void:
	if active_tooltip == null:
		return
	if tooltip_shake_timer <= 0.0:
		active_tooltip.rotation = lerpf(active_tooltip.rotation, 0.0, clampf(delta * 18.0, 0.0, 1.0))
		return
	tooltip_shake_timer = maxf(0.0, tooltip_shake_timer - delta)
	var target_rotation: float = _get_shake_rotation(tooltip_shake_timer, tooltip_shake_target, TOOLTIP_SHAKE_TIME, TOOLTIP_SHAKE_WAVES, TOOLTIP_SHAKE_DAMPING)
	active_tooltip.rotation = lerpf(active_tooltip.rotation, target_rotation, clampf(delta * 22.0, 0.0, 1.0))


func _get_shake_rotation(active_timer: float, target_angle: float, total_time: float, waves: float, damping_power: float) -> float:
	if active_timer <= 0.0 or total_time <= 0.0:
		return 0.0
	var progress: float = 1.0 - active_timer / total_time
	var spring_phase: float = progress * TAU * waves
	var damping: float = pow(1.0 - progress, damping_power)
	return sin(spring_phase) * damping * target_angle
