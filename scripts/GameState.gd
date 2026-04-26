extends Node
class_name GameState

signal stats_changed
signal energy_changed
signal currency_changed
signal inventory_changed
signal floor_changed
signal upgrades_changed

const BASE_MAX_ENERGY: int = 20
const BASE_ORE_INVENTORY_CAPACITY: int = 30
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

var carried_ore_chunks: Dictionary = {}
var currency: int = 0
var energy: int = BASE_MAX_ENERGY
var floor_number: int = 1
var last_ore_chunk_label: String = ""
var upgrade_levels: Dictionary = {}


func reset() -> void:
	carried_ore_chunks.clear()
	currency = 0
	upgrade_levels.clear()
	energy = get_max_energy()
	floor_number = 1
	last_ore_chunk_label = ""
	energy_changed.emit()
	currency_changed.emit()
	inventory_changed.emit()
	floor_changed.emit()
	upgrades_changed.emit()
	stats_changed.emit()


func to_save_data() -> Dictionary:
	return {
		"carried_ore_chunks": _serialize_carried_ore_chunks(),
		"currency": currency,
		"energy": energy,
		"floor_number": floor_number,
		"last_ore_chunk_label": last_ore_chunk_label,
		"upgrade_levels": _serialize_upgrade_levels()
	}


func load_from_save_data(save_data: Dictionary) -> void:
	carried_ore_chunks.clear()

	var saved_chunks_variant: Variant = save_data.get("carried_ore_chunks", {})
	if saved_chunks_variant is Dictionary:
		var saved_chunks: Dictionary = saved_chunks_variant
		for label_variant: Variant in saved_chunks.keys():
			var label: String = str(label_variant).strip_edges()
			var amount: int = maxi(0, int(saved_chunks.get(label_variant, 0)))
			if label.is_empty() or amount <= 0:
				continue
			carried_ore_chunks[label] = amount

	_load_upgrade_levels(save_data.get("upgrade_levels", {}))
	currency = maxi(0, int(save_data.get("currency", 0)))
	energy = clampi(int(save_data.get("energy", get_max_energy())), 0, get_max_energy())
	floor_number = maxi(1, int(save_data.get("floor_number", 1)))
	last_ore_chunk_label = str(save_data.get("last_ore_chunk_label", ""))
	if not carried_ore_chunks.has(last_ore_chunk_label):
		last_ore_chunk_label = ""
	energy_changed.emit()
	currency_changed.emit()
	inventory_changed.emit()
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
			return "%d ore stacks" % get_ore_inventory_capacity()
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
	return get_upgrade_level(UPGRADE_PICKAXE) * 2


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
