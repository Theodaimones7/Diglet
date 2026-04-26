extends RefCounted
class_name FindItemCatalog

const ITEMS_PATH: String = "res://data/finds/items.json"
const VALID_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS: Dictionary = {
	"common": Color(0.82, 0.78, 0.68, 1.0),
	"uncommon": Color(0.32, 0.86, 0.32, 1.0),
	"rare": Color(0.28, 0.58, 1.0, 1.0),
	"epic": Color(0.68, 0.34, 1.0, 1.0),
	"legendary": Color(1.0, 0.73, 0.18, 1.0)
}

var items: Array[Dictionary] = []
var items_by_id: Dictionary = {}
var icon_cache: Dictionary = {}
var loaded: bool = false


func load_items(path: String = ITEMS_PATH) -> bool:
	items.clear()
	items_by_id.clear()
	icon_cache.clear()
	loaded = false

	if not FileAccess.file_exists(path):
		push_warning("Find items file not found: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open find items file: %s" % path)
		return false

	var raw_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(raw_text)
	if parse_error != OK:
		push_warning("Failed to parse find items file: %s" % path)
		return false

	var parsed: Variant = json.data
	if not (parsed is Array):
		push_warning("Find items file must contain an array: %s" % path)
		return false

	var source: Array = parsed
	for item_variant: Variant in source:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		if not _is_valid_item(item):
			continue
		var item_id: String = str(item.get("id", ""))
		if items_by_id.has(item_id):
			push_warning("Duplicate find item id skipped: %s" % item_id)
			continue
		items.append(item)
		items_by_id[item_id] = item

	loaded = true
	return true


func get_item(item_id: String) -> Dictionary:
	var item_variant: Variant = items_by_id.get(item_id, {})
	if item_variant is Dictionary:
		return item_variant
	return {}


func get_all_items(include_disabled: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		var enabled: bool = bool(item.get("enabled", true))
		if include_disabled or enabled:
			result.append(item)
	return result


func get_icon_texture(item: Dictionary) -> Texture2D:
	var item_id: String = str(item.get("id", ""))
	if item_id.is_empty():
		return null
	var cached_variant: Variant = icon_cache.get(item_id, null)
	if cached_variant is Texture2D:
		return cached_variant
	var asset_path: String = str(item.get("assetPath", ""))
	if asset_path.is_empty():
		return null
	var icon_texture: Texture2D = load(asset_path) as Texture2D
	if icon_texture != null:
		icon_cache[item_id] = icon_texture
	return icon_texture


func has_item(item_id: String) -> bool:
	return items_by_id.has(item_id)


func get_available_items(depth: int, include_disabled: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		var enabled: bool = bool(item.get("enabled", true))
		if not include_disabled and not enabled:
			continue
		var min_depth: int = int(item.get("minDepth", 1))
		var max_depth: int = int(item.get("maxDepth", -1))
		if depth < min_depth:
			continue
		if max_depth >= 0 and depth > max_depth:
			continue
		result.append(item)
	return result


func get_value(item_id: String) -> int:
	var item: Dictionary = get_item(item_id)
	return maxi(0, int(item.get("value", 0)))


func get_rarity_color(rarity: String) -> Color:
	var color_variant: Variant = RARITY_COLORS.get(rarity, RARITY_COLORS.get("common"))
	return color_variant as Color


func make_inventory_entry(instance_data: Dictionary) -> Dictionary:
	var item_id: String = str(instance_data.get("item_id", ""))
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return {}

	var rarity: String = str(item.get("rarity", "common"))
	var icon_texture: Texture2D = get_icon_texture(item)

	return {
		"instance_id": str(instance_data.get("instance_id", "")),
		"item_id": item_id,
		"name": str(item.get("name", item_id)),
		"rarity": rarity,
		"value": int(item.get("value", 0)),
		"type": str(item.get("type", "relic")),
		"found_depth": int(instance_data.get("found_depth", 1)),
		"icon": icon_texture,
		"rarity_color": get_rarity_color(rarity)
	}


func validate_depth_coverage(depths: Array[int]) -> bool:
	var valid: bool = true
	for depth: int in depths:
		if get_available_items(depth).is_empty():
			push_warning("No enabled find items available for depth %d" % depth)
			valid = false
	return valid


func _is_valid_item(item: Dictionary) -> bool:
	var item_id: String = str(item.get("id", "")).strip_edges()
	if item_id.is_empty():
		push_warning("Find item skipped: empty id")
		return false

	var asset_path: String = str(item.get("assetPath", ""))
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		push_warning("Find item skipped due to missing asset path: %s" % item_id)
		return false

	var rarity: String = str(item.get("rarity", ""))
	if not VALID_RARITIES.has(rarity):
		push_warning("Find item skipped due to invalid rarity: %s" % item_id)
		return false

	var min_depth: int = int(item.get("minDepth", 1))
	var max_depth: int = int(item.get("maxDepth", -1))
	if min_depth < 1:
		push_warning("Find item skipped due to invalid minDepth: %s" % item_id)
		return false
	if max_depth >= 0 and max_depth < min_depth:
		push_warning("Find item skipped due to invalid maxDepth: %s" % item_id)
		return false
	if int(item.get("spawnWeight", 0)) <= 0:
		push_warning("Find item skipped due to invalid spawnWeight: %s" % item_id)
		return false
	return true
