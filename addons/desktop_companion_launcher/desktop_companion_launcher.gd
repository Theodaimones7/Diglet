@tool
extends EditorPlugin

const GAME_EMBED_MODE_SETTING: String = "run/window_placement/game_embed_mode"
const GAME_EMBED_DISABLED: int = -1


func _enter_tree() -> void:
	var editor_interface: EditorInterface = get_editor_interface()
	var editor_settings: EditorSettings = editor_interface.get_editor_settings()
	if editor_settings.has_setting(GAME_EMBED_MODE_SETTING):
		var current_value: int = int(editor_settings.get_setting(GAME_EMBED_MODE_SETTING))
		if current_value != GAME_EMBED_DISABLED:
			editor_settings.set_setting(GAME_EMBED_MODE_SETTING, GAME_EMBED_DISABLED)
			print("Desktop Companion Launcher: disabled Godot game embedding for native companion window launch.")
