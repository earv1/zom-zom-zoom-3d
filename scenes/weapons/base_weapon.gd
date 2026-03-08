class_name BaseWeapon
extends Node3D

@export var weapon_id: StringName = &""

var car: Node3D
var level: int = 1
var base_damage: float = 1.0
var base_fire_rate: float = 1.0
var _timer: float = 0.0


func _process(delta: float) -> void:
	if not car:
		return
	_timer += delta
	var interval := 1.0 / (base_fire_rate * GameManager.fire_rate_multiplier)
	if _timer >= interval:
		_timer = 0.0
		fire()


func fire() -> void:
	pass


func level_up() -> void:
	level += 1
	_apply_level()


func _apply_level() -> void:
	pass


func get_damage() -> float:
	return base_damage * GameManager.damage_multiplier
