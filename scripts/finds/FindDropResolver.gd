extends RefCounted
class_name FindDropResolver

const CONFIG_PATH: String = "res://data/finds/drop_config.json"
const RESULT_EMPTY: String = "empty"
const RESULT_NORMAL: String = "normal"
const RESULT_RICH: String = "rich"
const RESULT_RARE: String = "rare"
const DEFAULT_RARITY_WEIGHTS: Dictionary = {
	"common": 750,
	"uncommon": 187,
	"rare": 32,
	"epic": 30,
	"legendary": 1
}

var config: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()


func set_rng(source_rng: RandomNumberGenerator) -> void:
	if source_rng != null:
		rng = source_rng


func set_seed(seed: int) -> void:
	rng.seed = seed


func load_config(path: String = CONFIG_PATH) -> bool:
	config.clear()
	if not FileAccess.file_exists(path):
		push_warning("Find drop config not found: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open find drop config: %s" % path)
		return false

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK:
		push_warning("Failed to parse find drop config: %s" % path)
		return false

	var parsed: Variant = json.data
	if parsed is Dictionary:
		config = parsed
		return true
	push_warning("Find drop config must contain an object: %s" % path)
	return false


func resolve_level_drop(depth: int, catalog, pity_state: Dictionary = {}) -> Dictionary:
	if config.is_empty():
		load_config()
	if catalog == null:
		return _make_empty_result(depth)

	var spawn_chance: float = _get_spawn_chance(depth)
	if rng.randf() > spawn_chance:
		return _make_empty_result(depth)

	var level_type: String = _pick_level_type()
	var item_count: int = 1
	if level_type == RESULT_RICH:
		item_count = rng.randi_range(_get_rich_item_min(), _get_rich_item_max())

	var available_items: Array[Dictionary] = catalog.get_available_items(depth)
	if available_items.is_empty():
		push_warning("No enabled find items for depth %d. Level treated as empty." % depth)
		return _make_empty_result(depth)

	var drop_items: Array[String] = []
	var drop_relics: Array[Dictionary] = []
	for _index: int in range(item_count):
		var picked_item: Dictionary = _pick_weighted_item(available_items, level_type, pity_state)
		if picked_item.is_empty():
			continue
		var item_id: String = str(picked_item.get("id", ""))
		if item_id.is_empty():
			continue
		drop_items.append(item_id)
		drop_relics.append({
			"item_id": item_id,
			"rarity": _pick_rarity(level_type, pity_state)
		})

	if drop_items.is_empty():
		return _make_empty_result(depth)

	return {
		"depth": depth,
		"level_type": level_type,
		"drop_resolved": true,
		"drop_claimed": false,
		"drop_items": drop_items,
		"drop_relics": drop_relics
	}


func _make_empty_result(depth: int) -> Dictionary:
	return {
		"depth": depth,
		"level_type": RESULT_EMPTY,
		"drop_resolved": true,
		"drop_claimed": true,
		"drop_items": [],
		"drop_relics": []
	}


func _get_spawn_chance(depth: int) -> float:
	var bands_variant: Variant = config.get("spawnChanceByDepth", [])
	if not (bands_variant is Array):
		return 0.0
	var bands: Array = bands_variant
	for band_variant: Variant in bands:
		if not (band_variant is Dictionary):
			continue
		var band: Dictionary = band_variant
		var min_depth: int = int(band.get("minDepth", 1))
		var max_depth: int = int(band.get("maxDepth", -1))
		if depth < min_depth:
			continue
		if max_depth >= 0 and depth > max_depth:
			continue
		return clampf(float(band.get("chance", 0.0)), 0.0, 1.0)
	return 0.0


func _pick_level_type() -> String:
	var weights_variant: Variant = config.get("levelTypeWeights", {})
	if not (weights_variant is Dictionary):
		return RESULT_NORMAL
	var weights: Dictionary = weights_variant
	var total_weight: int = 0
	for key_variant: Variant in weights.keys():
		total_weight += maxi(0, int(weights.get(key_variant, 0)))
	if total_weight <= 0:
		return RESULT_NORMAL

	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for key_variant: Variant in weights.keys():
		var key: String = str(key_variant)
		cursor += maxi(0, int(weights.get(key_variant, 0)))
		if roll <= cursor:
			if key == RESULT_RICH or key == RESULT_RARE:
				return key
			return RESULT_NORMAL
	return RESULT_NORMAL


func _get_rich_item_min() -> int:
	return maxi(1, int(config.get("richItemMin", 2)))


func _get_rich_item_max() -> int:
	return maxi(_get_rich_item_min(), int(config.get("richItemMax", 4)))


func _pick_weighted_item(available_items: Array[Dictionary], _level_type: String, _pity_state: Dictionary) -> Dictionary:
	var weighted_items: Array[Dictionary] = []
	var total_weight: float = 0.0
	for item: Dictionary in available_items:
		var weight: float = float(maxi(0, int(item.get("spawnWeight", 0))))
		if weight <= 0.0:
			continue
		weighted_items.append({
			"item": item,
			"weight": weight
		})
		total_weight += weight

	if weighted_items.is_empty() or total_weight <= 0.0:
		return {}

	var roll: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for weighted_variant: Dictionary in weighted_items:
		cursor += float(weighted_variant.get("weight", 0.0))
		if roll <= cursor:
			var item_variant: Variant = weighted_variant.get("item", {})
			if item_variant is Dictionary:
				return item_variant
	var fallback_variant: Variant = weighted_items[weighted_items.size() - 1].get("item", {})
	if fallback_variant is Dictionary:
		return fallback_variant
	return {}


func _pick_rarity(level_type: String, pity_state: Dictionary) -> String:
	var weights_variant: Variant = config.get("rarityWeights", DEFAULT_RARITY_WEIGHTS)
	var weights: Dictionary = DEFAULT_RARITY_WEIGHTS
	if weights_variant is Dictionary:
		weights = weights_variant

	var weighted_rarities: Array[Dictionary] = []
	var total_weight: float = 0.0
	for rarity_variant: Variant in DEFAULT_RARITY_WEIGHTS.keys():
		var rarity: String = str(rarity_variant)
		var weight: float = maxf(0.0, float(weights.get(rarity, DEFAULT_RARITY_WEIGHTS.get(rarity, 0))))
		weight *= _get_level_type_multiplier(rarity, level_type)
		weight *= _get_pity_multiplier(rarity, pity_state)
		if weight <= 0.0:
			continue
		weighted_rarities.append({
			"rarity": rarity,
			"weight": weight
		})
		total_weight += weight

	if weighted_rarities.is_empty() or total_weight <= 0.0:
		return "common"

	var roll: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for weighted_rarity: Dictionary in weighted_rarities:
		cursor += float(weighted_rarity.get("weight", 0.0))
		if roll <= cursor:
			return str(weighted_rarity.get("rarity", "common"))
	return str(weighted_rarities[weighted_rarities.size() - 1].get("rarity", "common"))


func _get_level_type_multiplier(rarity: String, level_type: String) -> float:
	if level_type != RESULT_RARE:
		return 1.0
	match rarity:
		"rare":
			return maxf(0.0, float(config.get("rareWeightMultiplier", 3.0)))
		"epic":
			return maxf(0.0, float(config.get("epicWeightMultiplier", 2.0)))
		"legendary":
			return maxf(0.0, float(config.get("legendaryWeightMultiplier", 1.5)))
		_:
			return 1.0


func _get_pity_multiplier(rarity: String, pity_state: Dictionary) -> float:
	if not bool(config.get("pityEnabled", true)):
		return 1.0
	var bonus: float = clampf(float(pity_state.get("rare_bonus", 0.0)), 0.0, float(config.get("pityMaxBonus", 0.35)))
	if bonus <= 0.0:
		return 1.0
	var valuable_variant: Variant = config.get("valuableRarities", [])
	if valuable_variant is Array:
		var valuable: Array = valuable_variant
		if valuable.has(rarity):
			return 1.0 + bonus
	return 1.0
