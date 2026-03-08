class_name WeaponManager
extends Node3D

var car: Node3D
var _weapons: Dictionary = {}


func _ready() -> void:
	car = get_parent() as Node3D
	for child in get_children():
		if child is BaseWeapon:
			child.car = car
			if child.weapon_id:
				_weapons[child.weapon_id] = child
	GameManager.weapon_unlocked.connect(add_weapon)
	GameManager.weapon_leveled_up.connect(upgrade_weapon)


func add_weapon(id: StringName, scene: PackedScene) -> void:
	if id in _weapons or not scene:
		return
	var weapon: BaseWeapon = scene.instantiate()
	weapon.weapon_id = id
	weapon.car = car
	add_child(weapon)
	_weapons[id] = weapon


func upgrade_weapon(id: StringName) -> void:
	if id in _weapons:
		_weapons[id].level_up()
