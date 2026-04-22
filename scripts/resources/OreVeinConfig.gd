extends Resource
class_name OreVeinConfig

const RESULT_RED: int = 0
const RESULT_YELLOW: int = 1
const RESULT_GREEN: int = 2

@export var resource_type: String = "Copper"
@export var min_hp: int = 50
@export var max_hp: int = 79
@export var base_damage: int = 12
@export var minigame_frequency: float = 1.2
@export var round_duration: float = 1.65
@export var reaction_move_speed: float = 1.5
@export var bar_vertical: bool = false
@export_range(0.05, 0.9, 0.01) var red_zone_size: float = 0.44
@export_range(0.05, 0.9, 0.01) var yellow_zone_size: float = 0.34
@export_range(0.05, 0.9, 0.01) var green_zone_size: float = 0.22
@export var red_bonus_damage: int = 3
@export var yellow_bonus_damage: int = 9
@export var green_bonus_damage: int = 18
@export var red_quality_points: int = 0
@export var yellow_quality_points: int = 1
@export var green_quality_points: int = 2
@export var quality_score_influence: float = 0.08
@export var quality_random_spread: float = 0.16
@export var max_quality_bonus: float = 0.48
@export var ore_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var panel_tint: Color = Color(0.12, 0.12, 0.16, 0.92)
@export var red_tint: Color = Color(0.85, 0.2, 0.2, 1.0)
@export var yellow_tint: Color = Color(0.96, 0.75, 0.18, 1.0)
@export var green_tint: Color = Color(0.26, 0.84, 0.4, 1.0)
@export var result_sound: AudioStream
@export var perfect_sound: AudioStream
@export var tier_band_rules: Array[Resource] = []


func roll_max_hp(rng: RandomNumberGenerator) -> int:
	var safe_min_hp: int = mini(min_hp, max_hp)
	var safe_max_hp: int = maxi(min_hp, max_hp)
	return rng.randi_range(safe_min_hp, safe_max_hp)


func get_bonus_damage(result_zone: int) -> int:
	match result_zone:
		RESULT_GREEN:
			return green_bonus_damage
		RESULT_YELLOW:
			return yellow_bonus_damage
		_:
			return red_bonus_damage


func get_quality_points(result_zone: int) -> int:
	match result_zone:
		RESULT_GREEN:
			return green_quality_points
		RESULT_YELLOW:
			return yellow_quality_points
		_:
			return red_quality_points


func resolve_reward_tier(max_hp_value: int, quality_score: int, rng: RandomNumberGenerator) -> String:
	var matching_rule: Resource = _find_rule(max_hp_value)
	var available_tiers_variant: Variant = matching_rule.get("tiers")
	var available_tiers: PackedStringArray = available_tiers_variant as PackedStringArray
	if available_tiers.is_empty():
		return "E"

	var rule_min_hp: int = int(matching_rule.get("min_hp"))
	var rule_max_hp: int = int(matching_rule.get("max_hp"))
	var hp_span: int = maxi(1, rule_max_hp - rule_min_hp)
	var hp_progress: float = clampf(float(max_hp_value - rule_min_hp) / float(hp_span), 0.0, 1.0)
	var quality_bonus: float = clampf(float(quality_score) * quality_score_influence, 0.0, max_quality_bonus)
	var random_shift: float = rng.randf_range(-quality_random_spread, quality_random_spread)
	var final_progress: float = clampf(hp_progress + quality_bonus + random_shift, 0.0, 1.0)
	var slot_count: int = available_tiers.size()
	var picked_slot: int = clampi(int(floor(final_progress * float(slot_count))), 0, slot_count - 1)
	return available_tiers[picked_slot]


func get_zone_layout() -> Vector3:
	var safe_red: float = maxf(0.01, red_zone_size)
	var safe_yellow: float = maxf(0.01, yellow_zone_size)
	var safe_green: float = maxf(0.01, green_zone_size)
	var total: float = safe_red + safe_yellow + safe_green
	return Vector3(safe_red / total, safe_yellow / total, safe_green / total)


func _find_rule(max_hp_value: int) -> Resource:
	for rule_resource: Resource in tier_band_rules:
		if rule_resource == null:
			continue
		var min_hp_value: int = int(rule_resource.get("min_hp"))
		var max_hp_rule_value: int = int(rule_resource.get("max_hp"))
		if max_hp_value >= min_hp_value and max_hp_value <= max_hp_rule_value:
			return rule_resource

	if not tier_band_rules.is_empty():
		var fallback_rule: Resource = tier_band_rules[tier_band_rules.size() - 1]
		if fallback_rule != null:
			return fallback_rule

	var default_rule: Resource = preload("res://scripts/resources/OreTierBandRule.gd").new() as Resource
	return default_rule
