extends Node
class_name GameState

signal stats_changed

const MAX_ENERGY: int = 20

var carried_ore: int = 0
var currency: int = 0
var energy: int = MAX_ENERGY
var floor_number: int = 1


func reset() -> void:
	carried_ore = 0
	currency = 0
	energy = MAX_ENERGY
	floor_number = 1
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


func add_carried_ore(amount: int) -> void:
	if amount <= 0:
		return
	carried_ore += amount
	stats_changed.emit()


func convert_carried_ore() -> void:
	if carried_ore <= 0:
		return
	currency += carried_ore
	carried_ore = 0
	stats_changed.emit()


func next_floor() -> void:
	floor_number += 1
	stats_changed.emit()
