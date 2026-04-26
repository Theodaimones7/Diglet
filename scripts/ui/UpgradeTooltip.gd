extends PanelContainer
class_name UpgradeTooltip

var pending_text: String = ""

@onready var label: Label = get_node("Margin/Label") as Label


func _ready() -> void:
	_apply_text(pending_text)


func set_upgrade_tooltip_text(value: String) -> void:
	pending_text = value
	_apply_text(pending_text)


func _apply_text(value: String) -> void:
	if label == null:
		return
	label.text = value
