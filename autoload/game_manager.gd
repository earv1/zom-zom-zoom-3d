extends Node

var current_level: int = 1
var current_xp: int = 0
var elapsed_time: float = 0.0
var current_health: int = 100
var max_health: int = 100
var enemies_killed: int = 0

var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0

var unlocked_weapons: Array[StringName] = [&"front_gun"]
var weapon_levels: Dictionary = {}

var all_upgrades: Array = [
	preload("res://data/upgrades/upgrade_front_gun_lvl2.tres"),
	preload("res://data/upgrades/upgrade_front_gun_lvl3.tres"),
	preload("res://data/upgrades/unlock_garlic.tres"),
	preload("res://data/upgrades/upgrade_garlic_lvl2.tres"),
	preload("res://data/upgrades/upgrade_garlic_lvl3.tres"),
	preload("res://data/upgrades/unlock_side_rockets.tres"),
	preload("res://data/upgrades/upgrade_side_rockets_lvl2.tres"),
	preload("res://data/upgrades/stat_max_health.tres"),
	preload("res://data/upgrades/stat_speed.tres"),

	preload("res://data/upgrades/stat_damage_mult.tres"),
	preload("res://data/upgrades/stat_fire_rate.tres"),
]
var _is_game_over: bool = false

signal xp_changed(current: int, to_next: int)
signal level_changed(new_level: int)
signal health_changed(current: int, maximum: int)
signal level_up_triggered(choices: Array)
signal game_over()
signal weapon_unlocked(id: StringName, scene: PackedScene)
signal weapon_leveled_up(id: StringName)
signal damage_taken()


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if _is_game_over:
		return
	elapsed_time += delta


func _xp_to_next() -> int:
	return int(500 * pow(1.4, current_level - 1))


func add_xp(amount: int) -> void:
	current_xp += amount * 3
	var to_next := _xp_to_next()
	xp_changed.emit(current_xp, to_next)
	if current_xp >= to_next:
		current_xp -= to_next
		current_level += 1
		level_changed.emit(current_level)
		var choices := _pick_upgrade_choices()
		level_up_triggered.emit(choices)


func take_damage(amount: int) -> void:
	if _is_game_over:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damage_taken.emit()
	if current_health <= 0:
		_is_game_over = true
		game_over.emit()


func apply_upgrade(upgrade: Resource) -> void:
	var upg := upgrade as UpgradeData
	if not upg:
		return
	match upg.upgrade_type:
		UpgradeData.Type.UNLOCK_WEAPON:
			if upg.weapon_id not in unlocked_weapons:
				unlocked_weapons.append(upg.weapon_id)
			weapon_unlocked.emit(upg.weapon_id, upg.weapon_scene)
		UpgradeData.Type.WEAPON_LEVEL_UP:
			weapon_levels[upg.weapon_id] = weapon_levels.get(upg.weapon_id, 1) + 1
			weapon_leveled_up.emit(upg.weapon_id)
		UpgradeData.Type.STAT_BUFF:
			match upg.stat_target:
				UpgradeData.Stat.MAX_HEALTH:
					max_health += int(upg.stat_value)
					current_health = min(current_health + int(upg.stat_value), max_health)
					health_changed.emit(current_health, max_health)
				UpgradeData.Stat.SPEED:
					speed_multiplier += upg.stat_value
				UpgradeData.Stat.DAMAGE_MULT:
					damage_multiplier += upg.stat_value
				UpgradeData.Stat.FIRE_RATE:
					fire_rate_multiplier += upg.stat_value


func _pick_upgrade_choices() -> Array:
	var eligible: Array = []
	for upg in all_upgrades:
		if upg.is_available(self):
			eligible.append(upg)
	eligible.shuffle()
	return eligible.slice(0, min(3, eligible.size()))


func reset() -> void:
	current_level = 1
	current_xp = 0
	elapsed_time = 0.0
	current_health = 100
	max_health = 100
	enemies_killed = 0
	speed_multiplier = 1.0
	damage_multiplier = 1.0
	fire_rate_multiplier = 1.0
	unlocked_weapons = [&"front_gun"]
	weapon_levels = {}
	_is_game_over = false
