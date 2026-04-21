extends Node2D

const WINDOW_SIZE: Vector2i = Vector2i(420, 380)
const SCREEN_MARGIN: int = 0
const WINDOW_BOTTOM_OFFSET: int = 48

@onready var game_state: GameState = get_node("GameState") as GameState
@onready var board: BoardController = get_node("Board") as BoardController
@onready var miner: MinerAgent = get_node("Miner") as MinerAgent
@onready var house: Sprite2D = get_node("House") as Sprite2D
@onready var ore_label: Label = get_node("HUD/StatsRow/OreBox/Value") as Label
@onready var currency_label: Label = get_node("HUD/StatsRow/CurrencyBox/Value") as Label
@onready var energy_label: Label = get_node("HUD/StatsRow/EnergyBox/Value") as Label
@onready var floor_label: Label = get_node("HUD/StatsRow/FloorBox/Value") as Label
@onready var exit_button: TextureButton = get_node("HUD/ExitButton") as TextureButton


func _init() -> void:
	ProjectSettings.set_setting("display/window/size/transparent", true)
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)


func _enter_tree() -> void:
	_configure_window()


func _ready() -> void:
	board.setup(game_state)
	miner.setup(game_state, board, house.global_position)
	board.tile_clicked.connect(miner.handle_tile_click)
	game_state.stats_changed.connect(_refresh_hud)
	exit_button.pressed.connect(_quit_game)
	_refresh_hud()


func _configure_window() -> void:
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", true)
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)

	var window: Window = get_window()
	get_viewport().transparent_bg = true

	if window.is_embedded():
		push_warning("Desktop companion mode requires disabled Game Embedding. Use the Game tab dropdown -> disable 'Embed Game on Next Play', or run StartDesktopCompanion.bat.")
		window.transparent_bg = true
		return

	window.min_size = WINDOW_SIZE
	window.size = WINDOW_SIZE
	window.borderless = true
	window.unresizable = true
	window.always_on_top = true
	window.gui_embed_subwindows = false
	window.transparent = true
	window.transparent_bg = true

	var screen_id: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)
	var target_position: Vector2i = usable_rect.position + usable_rect.size - WINDOW_SIZE - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN) + Vector2i(0, WINDOW_BOTTOM_OFFSET)
	window.position = target_position

	var window_id: int = window.get_window_id()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, window_id)
	DisplayServer.window_set_size(WINDOW_SIZE, window_id)
	DisplayServer.window_set_position(target_position, window_id)


func _refresh_hud() -> void:
	ore_label.text = "%d" % game_state.carried_ore
	currency_label.text = "%d" % game_state.currency
	energy_label.text = "%d" % game_state.energy
	floor_label.text = "%d" % game_state.floor_number


func _quit_game() -> void:
	get_tree().quit()
