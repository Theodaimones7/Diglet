extends Resource
class_name OreTierBandRule

@export var min_hp: int = 50
@export var max_hp: int = 79
@export var tiers: PackedStringArray = PackedStringArray(["E", "D", "C"])


func matches(hp_value: int) -> bool:
	return hp_value >= min_hp and hp_value <= max_hp
