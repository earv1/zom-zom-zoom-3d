class_name FrontGun
extends BaseWeapon

var _spread_mode: bool = false


func _ready() -> void:
	base_damage = 1.0
	base_fire_rate = 1.5


func fire() -> void:
	var nearest := _get_nearest_enemy()
	if _spread_mode:
		_fire_projectile(0.0, nearest)
		_fire_projectile(-0.2, nearest)
		_fire_projectile(0.2, nearest)
	else:
		_fire_projectile(0.0, nearest)


const FRONT_COS := cos(deg_to_rad(20.0))  # ~0.94
const BACK_COS := cos(deg_to_rad(180.0 - 40.0))  # ~-0.77
const FRONT_RANGE := 60.0
const BACK_RANGE := 15.0

func _get_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := INF
	var forward := -car.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := (e as Node3D).global_position - car.global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		var dot := to_enemy.normalized().dot(forward)
		# Front cone: within 20° of forward, back cone: within 40° of rear
		if dot < FRONT_COS and dot > BACK_COS:
			continue
		var max_range := FRONT_RANGE if dot >= FRONT_COS else BACK_RANGE
		if dist > max_range:
			continue
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = e as Node3D
	return nearest


func _fire_projectile(x_offset: float, nearest: Node3D) -> void:
	var base_dir := -car.global_basis.z
	base_dir.y = 0.0
	base_dir = base_dir.normalized()
	if is_instance_valid(nearest):
		var to_enemy := nearest.global_position - car.global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.001:
			base_dir = to_enemy.normalized()

	var dir := (base_dir + car.global_basis.x * x_offset).normalized()
	_spawn_projectile(dir, 40.0, nearest)


func _apply_level() -> void:
	match level:
		2:
			base_damage = 1.5
		3:
			base_damage = 1.5
			_spread_mode = true
