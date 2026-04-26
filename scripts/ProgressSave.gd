extends RefCounted
class_name ProgressSave

const SAVE_PATH: String = "user://progress.save"
const SAVE_VERSION: int = 3


static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_warning("Failed to open save file for reading: %s" % SAVE_PATH)
		return {}

	var raw_text: String = save_file.get_as_text()
	if raw_text.is_empty():
		return {}

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse save file: %s" % SAVE_PATH)
		return {}

	var parsed_data: Variant = json.data
	if parsed_data is Dictionary:
		return parsed_data
	return {}


static func save_progress(game_state: GameState, board: BoardController) -> void:
	if game_state == null or board == null:
		return

	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"game_state": game_state.to_save_data(),
		"board": board.to_save_data()
	}
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("Failed to open save file for writing: %s" % SAVE_PATH)
		return

	var serialized_payload: String = JSON.stringify(payload)
	save_file.store_string(serialized_payload)


static func get_section(save_data: Dictionary, section_name: String) -> Dictionary:
	var section_variant: Variant = save_data.get(section_name, {})
	if section_variant is Dictionary:
		return section_variant
	return {}
