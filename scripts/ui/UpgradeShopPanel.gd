extends Control
class_name UpgradeShopPanel

@onready var close_button: TextureButton = get_node_or_null("PanelMargin/Layout/Header/CloseButton") as TextureButton


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_panel)


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	visible = true


func close_panel() -> void:
	visible = false
