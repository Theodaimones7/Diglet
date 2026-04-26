extends RefCounted
class_name RockLayerCatalog

const LAYER_EARTH: String = "earth"
const LAYER_CLAY: String = "clay"
const LAYER_SAND: String = "sand"
const LAYER_GRAVEL: String = "gravel"
const LAYER_LIMESTONE: String = "limestone"
const LAYER_SANDSTONE: String = "sandstone"
const LAYER_SLATE: String = "slate"
const LAYER_GRANITE: String = "granite"
const LAYER_BASALT: String = "basalt"
const LAYER_OBSIDIAN: String = "obsidian"
const LAYER_MAGMA: String = "magma"

const OPEN_END_DEPTH: int = 999999
const BOUNDARY_NOISE_METERS: int = 3

var fallback_texture: Texture2D = preload("res://assets/tiles/rock.png")
var sand_texture: Texture2D = preload("res://assets/tiles/sand.png")
var gravel_texture: Texture2D = preload("res://assets/tiles/gravel.png")
var limestone_texture: Texture2D = preload("res://assets/tiles/limestone.png")
var sandstone_texture: Texture2D = preload("res://assets/tiles/sandstone.png")
var slate_texture: Texture2D = preload("res://assets/tiles/Slate.png")
var granite_texture: Texture2D = preload("res://assets/tiles/granite.png")
var basalt_texture: Texture2D = preload("res://assets/tiles/basalte.png")
var obsidian_texture: Texture2D = preload("res://assets/tiles/obsidian.png")
var magma_texture: Texture2D = preload("res://assets/tiles/magma.png")

var layers: Array[RockLayerDefinition] = []
var layers_by_id: Dictionary = {}


class RockLayerDefinition:
	var id: String = ""
	var display_name: String = ""
	var start_depth_m: int = 0
	var end_depth_m: int = 0
	var texture: Texture2D
	var tint: Color = Color.WHITE
	var max_hp: int = 1
	var dig_time: float = 0.45
	var ore_reward_bonus_chance: float = 0.0

	func _init(
		layer_id: String,
		layer_display_name: String,
		layer_start_depth_m: int,
		layer_end_depth_m: int,
		layer_texture: Texture2D,
		layer_tint: Color,
		layer_max_hp: int,
		layer_dig_time: float,
		layer_ore_reward_bonus_chance: float
	) -> void:
		id = layer_id
		display_name = layer_display_name
		start_depth_m = layer_start_depth_m
		end_depth_m = layer_end_depth_m
		texture = layer_texture
		tint = layer_tint
		max_hp = maxi(1, layer_max_hp)
		dig_time = maxf(0.05, layer_dig_time)
		ore_reward_bonus_chance = clampf(layer_ore_reward_bonus_chance, 0.0, 0.95)


func _init() -> void:
	_add_layer(LAYER_EARTH, "Earth", 0, 5, fallback_texture, Color(0.60, 0.43, 0.27, 1.0), 1, 0.32, 0.0)
	_add_layer(LAYER_CLAY, "Clay", 5, 12, fallback_texture, Color(0.67, 0.36, 0.24, 1.0), 2, 0.36, 0.0)
	_add_layer(LAYER_SAND, "Sand", 12, 20, sand_texture, Color.WHITE, 2, 0.34, 0.05)
	_add_layer(LAYER_GRAVEL, "Gravel", 20, 35, gravel_texture, Color.WHITE, 3, 0.38, 0.08)
	_add_layer(LAYER_LIMESTONE, "Limestone", 35, 55, limestone_texture, Color.WHITE, 4, 0.42, 0.12)
	_add_layer(LAYER_SANDSTONE, "Sandstone", 55, 80, sandstone_texture, Color.WHITE, 5, 0.46, 0.16)
	_add_layer(LAYER_SLATE, "Slate", 80, 120, slate_texture, Color.WHITE, 7, 0.50, 0.22)
	_add_layer(LAYER_GRANITE, "Granite", 120, 170, granite_texture, Color.WHITE, 9, 0.55, 0.28)
	_add_layer(LAYER_BASALT, "Basalt", 170, 230, basalt_texture, Color.WHITE, 12, 0.61, 0.36)
	_add_layer(LAYER_OBSIDIAN, "Obsidian", 230, 300, obsidian_texture, Color.WHITE, 15, 0.68, 0.45)
	_add_layer(LAYER_MAGMA, "Magma Rock", 300, OPEN_END_DEPTH, magma_texture, Color.WHITE, 18, 0.76, 0.55)


func get_layer_for_depth(depth_m: int, column: int) -> RockLayerDefinition:
	var adjusted_depth_m: int = maxi(0, depth_m + _get_boundary_offset(column))
	for layer: RockLayerDefinition in layers:
		if adjusted_depth_m >= layer.start_depth_m and adjusted_depth_m < layer.end_depth_m:
			return layer
	return layers[layers.size() - 1]


func get_layer_by_id(layer_id: String) -> RockLayerDefinition:
	var definition_variant: Variant = layers_by_id.get(layer_id, null)
	var definition: RockLayerDefinition = definition_variant as RockLayerDefinition
	if definition != null:
		return definition
	return layers[0]


func has_layer(layer_id: String) -> bool:
	return layers_by_id.has(layer_id)


func _add_layer(
	layer_id: String,
	layer_display_name: String,
	layer_start_depth_m: int,
	layer_end_depth_m: int,
	layer_texture: Texture2D,
	layer_tint: Color,
	layer_max_hp: int,
	layer_dig_time: float,
	layer_ore_reward_bonus_chance: float
) -> void:
	var definition: RockLayerDefinition = RockLayerDefinition.new(
		layer_id,
		layer_display_name,
		layer_start_depth_m,
		layer_end_depth_m,
		layer_texture,
		layer_tint,
		layer_max_hp,
		layer_dig_time,
		layer_ore_reward_bonus_chance
	)
	layers.append(definition)
	layers_by_id[layer_id] = definition


func _get_boundary_offset(column: int) -> int:
	var safe_column: int = maxi(0, column)
	var hashed: int = int(abs((safe_column + 17) * 1103515245 + 12345))
	var spread: int = BOUNDARY_NOISE_METERS * 2 + 1
	return hashed % spread - BOUNDARY_NOISE_METERS
