extends Node
class_name GameState

signal stats_changed

const MAX_ENERGY: int = 20
const ORE_INVENTORY_CAPACITY: int = 30
const DEFAULT_ORE_ICON: Texture2D = preload("res://assets/icon_ore.png")
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
	"A": 5,
	"B": 4,
	"C": 3,
	"D": 2,
	"E": 1
}

var carried_ore_chunks: Dictionary = {}
var currency: int = 0
var energy: int = MAX_ENERGY
var floor_number: int = 1
var last_ore_chunk_label: String = ""


func reset() -> void:
	carried_ore_chunks.clear()
	currency = 0
	energy = MAX_ENERGY
	floor_number = 1
	last_ore_chunk_label = ""
	stats_changed.emit()


func spend_energy(amount: int) -> void:
	var next_energy: int = clampi(energy - amount, 0, MAX_ENERGY)
	if next_energy == energy:
		return
	energy = next_energy
	stats_changed.emit()


func restore_energy() -> void:
	if energy == MAX_ENERGY:
		return
	energy = MAX_ENERGY
	stats_changed.emit()


func restore_energy_step(amount: int = 1) -> void:
	if amount <= 0 or energy >= MAX_ENERGY:
		return
	var next_energy: int = clampi(energy + amount, 0, MAX_ENERGY)
	if next_energy == energy:
		return
	energy = next_energy
	stats_changed.emit()


func add_carried_ore_chunk(resource_type: String, tier: String) -> void:
	if resource_type.is_empty() or tier.is_empty():
		return
	var chunk_label: String = "%s %s" % [resource_type, tier]
	var current_amount: int = int(carried_ore_chunks.get(chunk_label, 0))
	carried_ore_chunks[chunk_label] = current_amount + 1
	last_ore_chunk_label = chunk_label
	stats_changed.emit()


func convert_carried_ore() -> void:
	sell_all_carried_ore()


func next_floor() -> void:
	floor_number += 1
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
		var unit_price: int = get_unit_price_for_tier(tier)
		var total_price: int = amount * unit_price
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
	return ORE_INVENTORY_CAPACITY


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

	var earned: int = amount * get_unit_price_for_tier(tier)
	carried_ore_chunks.erase(chunk_label)
	currency += earned
	if last_ore_chunk_label == chunk_label:
		last_ore_chunk_label = ""
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
		total_earned += amount * _chunk_value_from_label(label)

	carried_ore_chunks.clear()
	last_ore_chunk_label = ""
	currency += total_earned
	stats_changed.emit()
	return total_earned


func _chunk_value_from_label(chunk_label: String) -> int:
	var parsed: Dictionary = _parse_chunk_label(chunk_label)
	var tier: String = str(parsed.get("tier", "E"))
	return get_unit_price_for_tier(tier)


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
