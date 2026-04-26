extends Node
class_name GameState

signal stats_changed
signal energy_changed
signal currency_changed
signal inventory_changed
signal floor_changed
signal upgrades_changed
signal finds_changed
signal museum_changed
signal unlocks_changed

const FindItemCatalogScript = preload("res://scripts/finds/FindItemCatalog.gd")

const BASE_MAX_ENERGY: int = 20
const BASE_ORE_INVENTORY_CAPACITY: int = 30
const BASE_FIND_INVENTORY_CAPACITY: int = 30
const UPGRADE_PICKAXE: String = "pickaxe"
const UPGRADE_STAMINA: String = "stamina"
const UPGRADE_BAG: String = "bag"
const UPGRADE_FOCUS: String = "focus"
const UPGRADE_REFINERY: String = "refinery"
const BASE_UPGRADE_COSTS: Array[int] = [35, 80, 160, 310, 590]
const UPGRADE_MAX_LEVELS: Dictionary = {
	UPGRADE_PICKAXE: 8,
	UPGRADE_STAMINA: 8,
	UPGRADE_BAG: 8,
	UPGRADE_FOCUS: 5,
	UPGRADE_REFINERY: 5
}
const UPGRADE_COST_MULTIPLIERS: Dictionary = {
	UPGRADE_PICKAXE: 1.0,
	UPGRADE_STAMINA: 0.85,
	UPGRADE_BAG: 0.75,
	UPGRADE_FOCUS: 1.1,
	UPGRADE_REFINERY: 1.3
}
const UPGRADE_DISPLAY_NAMES: Dictionary = {
	UPGRADE_PICKAXE: "Pickaxe",
	UPGRADE_STAMINA: "Stamina",
	UPGRADE_BAG: "Bag",
	UPGRADE_FOCUS: "Focus",
	UPGRADE_REFINERY: "Refinery"
}
const UPGRADE_ORDER: Array[String] = [
	UPGRADE_PICKAXE,
	UPGRADE_STAMINA,
	UPGRADE_BAG,
	UPGRADE_FOCUS,
	UPGRADE_REFINERY
]
const DEFAULT_ORE_ICON: Texture2D = preload("res://assets/ui/icons/icon_ore.png")
const RESOURCE_ICON_TINTS: Dictionary = {
	"Copper": Color(0.96, 0.61, 0.32, 1.0),
	"Iron": Color(0.77, 0.82, 0.88, 1.0),
	"Crystal": Color(0.52, 0.98, 0.97, 1.0)
}
const TIER_COLORS: Dictionary = {
	"A": Color(0.98, 0.84, 0.26, 1.0),
	"B": Color(0.53, 0.64, 1.0, 1.0),
	"C": Color(0.46, 0.83, 0.38, 1.0),
	"D": Color(0.69, 0.71, 0.74, 1.0),
	"E": Color(0.48, 0.37, 0.28, 1.0)
}
const TIER_VALUES: Dictionary = {
	"A": 34,
	"B": 20,
	"C": 12,
	"D": 7,
	"E": 4
}
const FIND_RARITY_TO_MUSEUM_TIER: Dictionary = {
	"common": "E",
	"uncommon": "D",
	"rare": "C",
	"epic": "B",
	"legendary": "A"
}

var carried_ore_chunks: Dictionary = {}
var currency: int = 0
var energy: int = BASE_MAX_ENERGY
var floor_number: int = 1
var last_ore_chunk_label: String = ""
var upgrade_levels: Dictionary = {}
var find_catalog = FindItemCatalogScript.new()
var found_items: Array[Dictionary] = []
var next_find_instance_id: int = 1
var drop_pity_state: Dictionary = {}
var museum_items: Dictionary = {}
var collection_progress: Dictionary = {}
var activated_collection_bonuses: Dictionary = {}
var unlocks: Dictionary = {}


func _init() -> void:
	find_catalog.load_items()


func reset() -> void:
	carried_ore_chunks.clear()
	currency = 0
	upgrade_levels.clear()
	found_items.clear()
	next_find_instance_id = 1
	drop_pity_state.clear()
	museum_items.clear()
	collection_progress.clear()
	activated_collection_bonuses.clear()
	unlocks.clear()
	energy = get_max_energy()
	floor_number = 1
	last_ore_chunk_label = ""
	energy_changed.emit()
	currency_changed.emit()
	inventory_changed.emit()
	finds_changed.emit()
	museum_changed.emit()
	unlocks_changed.emit()
	floor_changed.emit()
	upgrades_changed.emit()
	stats_changed.emit()


func to_save_data() -> Dictionary:
	return {
		"carried_ore_chunks": _serialize_carried_ore_chunks(),
		"currency": currency,
		"energy": energy,
		"floor_number": floor_number,
		"found_items": _serialize_found_items(),
		"next_find_instance_id": next_find_instance_id,
		"drop_pity_state": drop_pity_state.duplicate(true),
		"museum_items": museum_items.duplicate(true),
		"collection_progress": collection_progress.duplicate(true),
		"activated_collection_bonuses": activated_collection_bonuses.duplicate(true),
		"unlocks": unlocks.duplicate(true),
		"last_ore_chunk_label": last_ore_chunk_label,
		"upgrade_levels": _serialize_upgrade_levels()
	}


func load_from_save_data(save_data: Dictionary) -> void:
	carried_ore_chunks.clear()
	found_items.clear()
	next_find_instance_id = 1
	drop_pity_state.clear()
	museum_items.clear()
	collection_progress.clear()
	activated_collection_bonuses.clear()
	unlocks.clear()

	var saved_chunks_variant: Variant = save_data.get("carried_ore_chunks", {})
	var converted_ore_currency: int = 0
	if saved_chunks_variant is Dictionary:
		var saved_chunks: Dictionary = saved_chunks_variant
		for label_variant: Variant in saved_chunks.keys():
			var label: String = str(label_variant).strip_edges()
			var amount: int = maxi(0, int(saved_chunks.get(label_variant, 0)))
			if label.is_empty() or amount <= 0:
				continue
			carried_ore_chunks[label] = amount
			converted_ore_currency += amount * _chunk_value_from_label(label)

	found_items = _read_found_items(save_data.get("found_items", []))
	next_find_instance_id = maxi(1, int(save_data.get("next_find_instance_id", 1)))
	next_find_instance_id = maxi(next_find_instance_id, _get_next_instance_id_after_loaded_items())
	_load_dictionary_field(drop_pity_state, save_data.get("drop_pity_state", {}))
	_load_dictionary_field(museum_items, save_data.get("museum_items", {}))
	_load_dictionary_field(collection_progress, save_data.get("collection_progress", {}))
	_load_dictionary_field(activated_collection_bonuses, save_data.get("activated_collection_bonuses", {}))
	_load_dictionary_field(unlocks, save_data.get("unlocks", {}))
	_backfill_museum_from_found_items()
	carried_ore_chunks.clear()

	_load_upgrade_levels(save_data.get("upgrade_levels", {}))
	currency = maxi(0, int(save_data.get("currency", 0)) + _apply_sell_multiplier(converted_ore_currency))
	energy = clampi(int(save_data.get("energy", get_max_energy())), 0, get_max_energy())
	floor_number = maxi(1, int(save_data.get("floor_number", 1)))
	last_ore_chunk_label = str(save_data.get("last_ore_chunk_label", ""))
	if not carried_ore_chunks.has(last_ore_chunk_label):
		last_ore_chunk_label = ""
	energy_changed.emit()
	currency_changed.emit()
	inventory_changed.emit()
	finds_changed.emit()
	museum_changed.emit()
	unlocks_changed.emit()
	floor_changed.emit()
	upgrades_changed.emit()
	stats_changed.emit()


func spend_energy(amount: int) -> void:
	var next_energy: int = clampi(energy - amount, 0, get_max_energy())
	if next_energy == energy:
		return
	energy = next_energy
	energy_changed.emit()
	stats_changed.emit()


func restore_energy() -> void:
	var max_energy: int = get_max_energy()
	if energy == max_energy:
		return
	energy = max_energy
	energy_changed.emit()
	stats_changed.emit()


func restore_energy_step(amount: int = 1) -> void:
	var max_energy: int = get_max_energy()
	if amount <= 0 or energy >= max_energy:
		return
	var next_energy: int = clampi(energy + amount, 0, max_energy)
	if next_energy == energy:
		return
	energy = next_energy
	energy_changed.emit()
	stats_changed.emit()


func add_carried_ore_chunk(resource_type: String, tier: String, amount: int = 1) -> bool:
	if resource_type.is_empty() or tier.is_empty():
		return false
	if amount <= 0:
		return false
	var chunk_label: String = "%s %s" % [resource_type, tier]
	if not carried_ore_chunks.has(chunk_label) and get_ore_inventory_stack_count() >= get_ore_inventory_capacity():
		return false
	var current_amount: int = int(carried_ore_chunks.get(chunk_label, 0))
	carried_ore_chunks[chunk_label] = current_amount + amount
	last_ore_chunk_label = chunk_label
	inventory_changed.emit()
	stats_changed.emit()
	return true


func convert_carried_ore() -> void:
	sell_all_carried_ore()


func next_floor() -> void:
	floor_number += 1
	floor_changed.emit()
	stats_changed.emit()


func add_found_item(item_id: String, found_depth: int) -> bool:
	if item_id.is_empty() or not find_catalog.has_item(item_id):
		return false
	if get_find_inventory_count() >= get_find_inventory_capacity():
		return false

	_record_museum_item(item_id, found_depth)
	var instance_id: String = _make_next_find_instance_id()
	var instance_data: Dictionary = {
		"instance_id": instance_id,
		"item_id": item_id,
		"found_depth": maxi(1, found_depth),
		"found_at": int(Time.get_unix_time_from_system())
	}
	found_items.append(instance_data)
	inventory_changed.emit()
	finds_changed.emit()
	stats_changed.emit()
	return true


func sell_found_item(instance_id: String) -> int:
	var item_index: int = _find_found_item_index(instance_id)
	if item_index < 0:
		return 0
	var instance_data: Dictionary = found_items[item_index]
	var item_id: String = str(instance_data.get("item_id", ""))
	var earned: int = _apply_sell_multiplier(find_catalog.get_value(item_id))
	if earned <= 0:
		return 0
	found_items.remove_at(item_index)
	currency += earned
	currency_changed.emit()
	inventory_changed.emit()
	finds_changed.emit()
	stats_changed.emit()
	return earned


func sell_all_found_items(rarity_filter: String = "") -> int:
	if found_items.is_empty():
		return 0

	var total_earned: int = 0
	var remaining_items: Array[Dictionary] = []
	for instance_data: Dictionary in found_items:
		var item_id: String = str(instance_data.get("item_id", ""))
		var item: Dictionary = find_catalog.get_item(item_id)
		var rarity: String = str(item.get("rarity", "common"))
		if not rarity_filter.is_empty() and rarity != rarity_filter:
			remaining_items.append(instance_data)
			continue
		total_earned += _apply_sell_multiplier(find_catalog.get_value(item_id))

	if total_earned <= 0:
		return 0
	found_items = remaining_items
	currency += total_earned
	currency_changed.emit()
	inventory_changed.emit()
	finds_changed.emit()
	stats_changed.emit()
	return total_earned


func get_find_inventory_entries(rarity_filter: String = "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for instance_data: Dictionary in found_items:
		var entry: Dictionary = find_catalog.make_inventory_entry(instance_data)
		if entry.is_empty():
			continue
		var rarity: String = str(entry.get("rarity", "common"))
		if not rarity_filter.is_empty() and rarity != rarity_filter:
			continue
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_find_inventory_entries"))
	return entries


func record_museum_item(item_id: String, found_depth: int) -> void:
	_record_museum_item(item_id, found_depth)


func get_museum_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item: Dictionary in find_catalog.get_all_items():
		var item_id: String = str(item.get("id", ""))
		if item.is_empty():
			continue

		var museum_variant: Variant = museum_items.get(item_id, {})
		var unlocked: bool = museum_items.has(item_id) and museum_variant is Dictionary
		var museum_data: Dictionary = {}
		if unlocked:
			museum_data = museum_variant
		var icon_texture: Texture2D = find_catalog.get_icon_texture(item)

		entries.append({
			"item_id": item_id,
			"name": str(item.get("name", item_id)) if unlocked else "???",
			"rarity": str(item.get("rarity", "common")),
			"type": str(item.get("type", "relic")),
			"count": maxi(1, int(museum_data.get("count", 1))) if unlocked else 0,
			"first_depth": maxi(1, int(museum_data.get("first_depth", 1))) if unlocked else 0,
			"last_depth": maxi(1, int(museum_data.get("last_depth", 1))) if unlocked else 0,
			"tiers": _read_museum_tiers(museum_data.get("tiers", {}), str(item.get("rarity", "common"))) if unlocked else {},
			"icon": icon_texture,
			"locked": not unlocked
		})
	entries.sort_custom(Callable(self, "_sort_museum_entries"))
	return entries


func get_museum_count() -> int:
	return museum_items.size()


func get_find_inventory_count() -> int:
	return found_items.size()


func get_find_inventory_capacity() -> int:
	return BASE_FIND_INVENTORY_CAPACITY + get_upgrade_level(UPGRADE_BAG) * 10


func get_total_find_sell_value(rarity_filter: String = "") -> int:
	var total_value: int = 0
	for entry: Dictionary in get_find_inventory_entries(rarity_filter):
		total_value += _apply_sell_multiplier(int(entry.get("value", 0)))
	return total_value


func record_find_drop_result(item_ids: Array[String]) -> void:
	var valuable_found: bool = false
	for item_id: String in item_ids:
		var item: Dictionary = find_catalog.get_item(item_id)
		var rarity: String = str(item.get("rarity", "common"))
		if rarity == "rare" or rarity == "epic" or rarity == "legendary":
			valuable_found = true
			break
	if valuable_found:
		drop_pity_state["rare_bonus"] = 0.0
	else:
		var current_bonus: float = float(drop_pity_state.get("rare_bonus", 0.0))
		drop_pity_state["rare_bonus"] = clampf(current_bonus + 0.05, 0.0, 0.35)
	stats_changed.emit()


func get_total_carried_chunks() -> int:
	var total: int = 0
	for amount_variant: Variant in carried_ore_chunks.values():
		total += int(amount_variant)
	return total


func get_carried_ore_summary() -> String:
	if carried_ore_chunks.is_empty():
		return "Empty"

	var entries: Array[String] = []
	for label_variant: Variant in carried_ore_chunks.keys():
		var label: String = str(label_variant)
		var amount: int = int(carried_ore_chunks.get(label, 0))
		entries.append("%s x%d" % [label, amount])

	entries.sort()
	return ", ".join(entries)


func get_ore_inventory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for label_variant: Variant in carried_ore_chunks.keys():
		var label: String = str(label_variant)
		var amount: int = int(carried_ore_chunks.get(label, 0))
		if amount <= 0:
			continue

		var parsed: Dictionary = _parse_chunk_label(label)
		var resource_type: String = str(parsed.get("resource_type", "Ore"))
		var tier: String = str(parsed.get("tier", "E"))
		var unit_price: int = _apply_sell_multiplier(get_unit_price_for_tier(tier))
		var total_price: int = _apply_sell_multiplier(amount * get_unit_price_for_tier(tier))
		var entry: Dictionary = {
			"resource_type": resource_type,
			"tier": tier,
			"quantity": amount,
			"unit_price": unit_price,
			"total_price": total_price,
			"icon": DEFAULT_ORE_ICON,
			"icon_modulate": get_resource_icon_tint(resource_type),
			"tier_color": get_tier_color(tier)
		}
		entries.append(entry)

	entries.sort_custom(Callable(self, "_sort_inventory_entries"))
	return entries


func get_ore_inventory_stack_count() -> int:
	return carried_ore_chunks.size()


func get_ore_inventory_capacity() -> int:
	return BASE_ORE_INVENTORY_CAPACITY + get_upgrade_level(UPGRADE_BAG) * 10


func get_total_sell_value() -> int:
	var total_value: int = 0
	for entry: Dictionary in get_ore_inventory_entries():
		total_value += int(entry.get("total_price", 0))
	return total_value


func get_unit_price_for_tier(tier: String) -> int:
	return int(TIER_VALUES.get(tier, 1))


func get_tier_color(tier: String) -> Color:
	var tier_color_variant: Variant = TIER_COLORS.get(tier, Color(0.58, 0.58, 0.58, 1.0))
	return tier_color_variant as Color


func get_resource_icon_tint(resource_type: String) -> Color:
	var tint_variant: Variant = RESOURCE_ICON_TINTS.get(resource_type, Color(0.85, 0.85, 0.85, 1.0))
	return tint_variant as Color


func sell_ore_stack(resource_type: String, tier: String) -> int:
	var chunk_label: String = _make_chunk_label(resource_type, tier)
	var amount: int = int(carried_ore_chunks.get(chunk_label, 0))
	if amount <= 0:
		return 0

	var earned: int = _apply_sell_multiplier(amount * get_unit_price_for_tier(tier))
	carried_ore_chunks.erase(chunk_label)
	currency += earned
	if last_ore_chunk_label == chunk_label:
		last_ore_chunk_label = ""
	currency_changed.emit()
	inventory_changed.emit()
	stats_changed.emit()
	return earned


func sell_all_carried_ore() -> int:
	if carried_ore_chunks.is_empty():
		return 0

	var total_earned: int = 0
	var labels: Array = carried_ore_chunks.keys()
	for label_variant: Variant in labels:
		var label: String = str(label_variant)
		var amount: int = int(carried_ore_chunks.get(label, 0))
		if amount <= 0:
			continue
		total_earned += _apply_sell_multiplier(amount * _chunk_value_from_label(label))

	carried_ore_chunks.clear()
	last_ore_chunk_label = ""
	currency += total_earned
	currency_changed.emit()
	inventory_changed.emit()
	stats_changed.emit()
	return total_earned


func _chunk_value_from_label(chunk_label: String) -> int:
	var parsed: Dictionary = _parse_chunk_label(chunk_label)
	var tier: String = str(parsed.get("tier", "E"))
	return get_unit_price_for_tier(tier)


func get_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for upgrade_id: String in UPGRADE_ORDER:
		result.append(upgrade_id)
	return result


func get_upgrade_display_name(upgrade_id: String) -> String:
	return str(UPGRADE_DISPLAY_NAMES.get(upgrade_id, upgrade_id.capitalize()))


func get_upgrade_level(upgrade_id: String) -> int:
	return clampi(int(upgrade_levels.get(upgrade_id, 0)), 0, get_upgrade_max_level(upgrade_id))


func get_upgrade_max_level(upgrade_id: String) -> int:
	return maxi(0, int(UPGRADE_MAX_LEVELS.get(upgrade_id, 0)))


func is_upgrade_maxed(upgrade_id: String) -> bool:
	return get_upgrade_level(upgrade_id) >= get_upgrade_max_level(upgrade_id)


func get_upgrade_cost(upgrade_id: String) -> int:
	if is_upgrade_maxed(upgrade_id):
		return 0
	var next_level: int = get_upgrade_level(upgrade_id) + 1
	var base_cost: int = _get_base_upgrade_cost(next_level)
	var multiplier: float = float(UPGRADE_COST_MULTIPLIERS.get(upgrade_id, 1.0))
	return maxi(1, int(roundf(float(base_cost) * multiplier)))


func can_purchase_upgrade(upgrade_id: String) -> bool:
	if is_upgrade_maxed(upgrade_id):
		return false
	return currency >= get_upgrade_cost(upgrade_id)


func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
	var cost: int = get_upgrade_cost(upgrade_id)
	var previous_max_energy: int = get_max_energy()
	currency = maxi(0, currency - cost)
	var next_level: int = get_upgrade_level(upgrade_id) + 1
	upgrade_levels[upgrade_id] = clampi(next_level, 0, get_upgrade_max_level(upgrade_id))
	var next_max_energy: int = get_max_energy()
	if upgrade_id == UPGRADE_STAMINA:
		energy = clampi(energy + (next_max_energy - previous_max_energy), 0, next_max_energy)
	else:
		energy = clampi(energy, 0, next_max_energy)
	currency_changed.emit()
	upgrades_changed.emit()
	if upgrade_id == UPGRADE_STAMINA:
		energy_changed.emit()
	stats_changed.emit()
	return true


func get_upgrade_effect_text(upgrade_id: String) -> String:
	var level: int = get_upgrade_level(upgrade_id)
	match upgrade_id:
		UPGRADE_PICKAXE:
			return "+%d rock, +%d ore damage" % [level, level * 2]
		UPGRADE_STAMINA:
			return "%d max energy" % get_max_energy()
		UPGRADE_BAG:
			return "%d find slots" % get_find_inventory_capacity()
		UPGRADE_FOCUS:
			return "+%d%% green, -%d%% speed" % [level * 4, level * 3]
		UPGRADE_REFINERY:
			return "+%d%% sell value" % [level * 8]
		_:
			return ""


func get_missing_currency_for_next_upgrade() -> int:
	var best_missing: int = 0
	for upgrade_id: String in UPGRADE_ORDER:
		if is_upgrade_maxed(upgrade_id):
			continue
		var missing: int = maxi(0, get_upgrade_cost(upgrade_id) - currency)
		if best_missing == 0 or missing < best_missing:
			best_missing = missing
	return best_missing


func get_max_energy() -> int:
	return BASE_MAX_ENERGY + get_upgrade_level(UPGRADE_STAMINA) * 5


func get_rock_damage() -> int:
	return 1 + get_upgrade_level(UPGRADE_PICKAXE)


func get_ore_damage_bonus() -> int:
	return 0


func get_focus_green_zone_bonus() -> float:
	return minf(0.2, float(get_upgrade_level(UPGRADE_FOCUS)) * 0.04)


func get_focus_speed_multiplier() -> float:
	return maxf(0.85, 1.0 - float(get_upgrade_level(UPGRADE_FOCUS)) * 0.03)


func get_sell_multiplier() -> float:
	return 1.0 + float(get_upgrade_level(UPGRADE_REFINERY)) * 0.08


func _get_base_upgrade_cost(level: int) -> int:
	var safe_level: int = maxi(1, level)
	if safe_level <= BASE_UPGRADE_COSTS.size():
		return BASE_UPGRADE_COSTS[safe_level - 1]
	var cost: int = BASE_UPGRADE_COSTS[BASE_UPGRADE_COSTS.size() - 1]
	for _extra_level: int in range(BASE_UPGRADE_COSTS.size() + 1, safe_level + 1):
		cost = maxi(cost + 1, int(roundf(float(cost) * 1.55)))
	return cost


func _apply_sell_multiplier(base_value: int) -> int:
	if base_value <= 0:
		return 0
	return maxi(1, int(roundf(float(base_value) * get_sell_multiplier())))


func _record_museum_item(item_id: String, found_depth: int) -> void:
	if item_id.is_empty() or not find_catalog.has_item(item_id):
		return

	var item: Dictionary = find_catalog.get_item(item_id)
	var rarity: String = str(item.get("rarity", "common"))
	var tier: String = str(FIND_RARITY_TO_MUSEUM_TIER.get(rarity, "E"))
	var safe_depth: int = maxi(1, found_depth)
	var museum_variant: Variant = museum_items.get(item_id, {})
	var museum_data: Dictionary = {}
	if museum_variant is Dictionary:
		museum_data = museum_variant

	var tiers: Dictionary = _read_museum_tiers(museum_data.get("tiers", {}), rarity)
	tiers[tier] = true
	museum_items[item_id] = {
		"item_id": item_id,
		"tiers": tiers,
		"count": maxi(0, int(museum_data.get("count", 0))) + 1,
		"first_depth": safe_depth if not museum_data.has("first_depth") else mini(safe_depth, int(museum_data.get("first_depth", safe_depth))),
		"last_depth": safe_depth
	}
	museum_changed.emit()
	stats_changed.emit()


func _backfill_museum_from_found_items() -> void:
	for instance_data: Dictionary in found_items:
		var item_id: String = str(instance_data.get("item_id", ""))
		if item_id.is_empty() or museum_items.has(item_id):
			continue
		_record_museum_item(item_id, int(instance_data.get("found_depth", 1)))


func _read_museum_tiers(source_variant: Variant, fallback_rarity: String = "common") -> Dictionary:
	var tiers: Dictionary = {}
	if source_variant is Dictionary:
		var source: Dictionary = source_variant
		for tier_variant: Variant in source.keys():
			var tier: String = str(tier_variant)
			if TIER_VALUES.has(tier) and bool(source.get(tier_variant, false)):
				tiers[tier] = true
	if tiers.is_empty():
		var fallback_tier: String = str(FIND_RARITY_TO_MUSEUM_TIER.get(fallback_rarity, "E"))
		tiers[fallback_tier] = true
	return tiers


func _make_chunk_label(resource_type: String, tier: String) -> String:
	return "%s %s" % [resource_type, tier]


func _parse_chunk_label(chunk_label: String) -> Dictionary:
	var cleaned_label: String = chunk_label.strip_edges()
	var separator_index: int = cleaned_label.rfind(" ")
	if separator_index < 0:
		return {
			"resource_type": cleaned_label,
			"tier": "E"
		}

	return {
		"resource_type": cleaned_label.substr(0, separator_index),
		"tier": cleaned_label.substr(separator_index + 1)
	}


func _sort_inventory_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_type: String = str(left.get("resource_type", ""))
	var right_type: String = str(right.get("resource_type", ""))
	if left_type == right_type:
		var left_tier: String = str(left.get("tier", "E"))
		var right_tier: String = str(right.get("tier", "E"))
		return _tier_rank(left_tier) < _tier_rank(right_tier)
	return left_type < right_type


func _tier_rank(tier: String) -> int:
	match tier:
		"A":
			return 0
		"B":
			return 1
		"C":
			return 2
		"D":
			return 3
		"E":
			return 4
		_:
			return 99


func _serialize_carried_ore_chunks() -> Dictionary:
	var serialized_chunks: Dictionary = {}
	for label_variant: Variant in carried_ore_chunks.keys():
		var label: String = str(label_variant)
		var amount: int = int(carried_ore_chunks.get(label, 0))
		if label.is_empty() or amount <= 0:
			continue
		serialized_chunks[label] = amount
	return serialized_chunks


func _serialize_upgrade_levels() -> Dictionary:
	var serialized_levels: Dictionary = {}
	for upgrade_id: String in UPGRADE_ORDER:
		var level: int = get_upgrade_level(upgrade_id)
		if level <= 0:
			continue
		serialized_levels[upgrade_id] = level
	return serialized_levels


func _serialize_found_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_data: Dictionary in found_items:
		var instance_id: String = str(instance_data.get("instance_id", ""))
		var item_id: String = str(instance_data.get("item_id", ""))
		if instance_id.is_empty() or item_id.is_empty():
			continue
		result.append({
			"instance_id": instance_id,
			"item_id": item_id,
			"found_depth": maxi(1, int(instance_data.get("found_depth", 1))),
			"found_at": maxi(0, int(instance_data.get("found_at", 0)))
		})
	return result


func _read_found_items(source_variant: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	if not (source_variant is Array):
		return result
	var source: Array = source_variant
	for instance_variant: Variant in source:
		if not (instance_variant is Dictionary):
			continue
		var instance_data: Dictionary = instance_variant
		var instance_id: String = str(instance_data.get("instance_id", "")).strip_edges()
		var item_id: String = str(instance_data.get("item_id", "")).strip_edges()
		if instance_id.is_empty() or item_id.is_empty() or seen_ids.has(instance_id):
			continue
		if not find_catalog.has_item(item_id):
			continue
		seen_ids[instance_id] = true
		result.append({
			"instance_id": instance_id,
			"item_id": item_id,
			"found_depth": maxi(1, int(instance_data.get("found_depth", 1))),
			"found_at": maxi(0, int(instance_data.get("found_at", 0)))
		})
	return result


func _load_dictionary_field(target: Dictionary, source_variant: Variant) -> void:
	target.clear()
	if not (source_variant is Dictionary):
		return
	var source: Dictionary = source_variant
	for key_variant: Variant in source.keys():
		target[key_variant] = source.get(key_variant)


func _make_next_find_instance_id() -> String:
	var instance_id: String = "find_%06d" % next_find_instance_id
	next_find_instance_id += 1
	return instance_id


func _get_next_instance_id_after_loaded_items() -> int:
	var next_id: int = 1
	for instance_data: Dictionary in found_items:
		var instance_id: String = str(instance_data.get("instance_id", ""))
		if not instance_id.begins_with("find_"):
			continue
		var numeric_part: String = instance_id.trim_prefix("find_")
		if not numeric_part.is_valid_int():
			continue
		next_id = maxi(next_id, int(numeric_part) + 1)
	return next_id


func _find_found_item_index(instance_id: String) -> int:
	for index: int in range(found_items.size()):
		var instance_data: Dictionary = found_items[index]
		if str(instance_data.get("instance_id", "")) == instance_id:
			return index
	return -1


func _sort_find_inventory_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_rarity: String = str(left.get("rarity", "common"))
	var right_rarity: String = str(right.get("rarity", "common"))
	var left_rank: int = _rarity_rank(left_rarity)
	var right_rank: int = _rarity_rank(right_rarity)
	if left_rank == right_rank:
		return str(left.get("name", "")) < str(right.get("name", ""))
	return left_rank > right_rank


func _sort_museum_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_locked: bool = bool(left.get("locked", false))
	var right_locked: bool = bool(right.get("locked", false))
	if left_locked != right_locked:
		return not left_locked
	var left_rarity: String = str(left.get("rarity", "common"))
	var right_rarity: String = str(right.get("rarity", "common"))
	var left_rank: int = _rarity_rank(left_rarity)
	var right_rank: int = _rarity_rank(right_rarity)
	if left_rank == right_rank:
		return str(left.get("item_id", "")) < str(right.get("item_id", "")) if left_locked else str(left.get("name", "")) < str(right.get("name", ""))
	return left_rank > right_rank


func _rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		"uncommon":
			return 1
		_:
			return 0


func _load_upgrade_levels(source_variant: Variant) -> void:
	upgrade_levels.clear()
	if not (source_variant is Dictionary):
		return
	var source: Dictionary = source_variant
	for upgrade_id: String in UPGRADE_ORDER:
		var level: int = clampi(int(source.get(upgrade_id, 0)), 0, get_upgrade_max_level(upgrade_id))
		if level <= 0:
			continue
		upgrade_levels[upgrade_id] = level
