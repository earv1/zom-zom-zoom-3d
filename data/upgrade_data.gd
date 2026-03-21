class_name UpgradeData
extends Resource

enum Type { UNLOCK_WEAPON, WEAPON_LEVEL_UP, STAT_BUFF }
enum Stat { MAX_HEALTH, SPEED, PICKUP_RADIUS, DAMAGE_MULT, FIRE_RATE }

@export var upgrade_type: Type
@export var display_name: String
@export var description: String
@export var icon_color: Color = Color.WHITE

@export var weapon_id: StringName
@export var weapon_scene: PackedScene
@export var required_level: int = 0

@export var stat_target: Stat
@export var stat_value: float


func is_available(gm: Variant) -> bool:
	match upgrade_type:
		Type.UNLOCK_WEAPON:
			return weapon_id not in gm.unlocked_weapons
		Type.WEAPON_LEVEL_UP:
			if weapon_id not in gm.unlocked_weapons:
				return false
			var current_level: int = gm.weapon_levels.get(weapon_id, 1)
			return current_level == required_level
		Type.STAT_BUFF:
			return true
	return false
