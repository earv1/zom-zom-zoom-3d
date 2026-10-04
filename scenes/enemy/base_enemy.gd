class_name BaseEnemy
extends RigidBody3D

const XP_ORB: PackedScene = preload("res://scenes/enemy/xp_orb.tscn")

@export var car: Node3D
@export var fragment_scene: PackedScene
@export var speed: float = 55.0
@export var acceleration: float = 15.0
@export var max_health: int = 1
@export var xp_value: int = 5
@export var contact_damage: int = 10
@export var fragment_count: int = 10

@onready var _raycast: RayCast3D = $RayCast3D

var _health: int
var _dead: bool = false
var _collision_layer := 1
var _collision_mask := 1
var _spawner: EnemySpawner
var pool_key: String

const WARP_BUFFER := 30.0   # trigger warp this many units beyond the warp landing spot
const FOG_IN_TIME := 0.8   # seconds to materialise out of the fog


func _ready() -> void:
	_health = max_health
	_collision_layer = collision_layer
	_collision_mask = collision_mask
	add_to_group("enemies")
	_raycast.add_exception(self)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	# Drop back in if the enemy has wandered too far from the car.
	if car:
		var spawners := get_tree().get_nodes_in_group("enemy_spawner")
		var spawn_dist := 120.0
		if spawners.size() > 0:
			spawn_dist = (spawners[0] as EnemySpawner).spawn_radius * 3.0
		if global_position.distance_to(car.global_position) > spawn_dist + WARP_BUFFER:
			drop_near(car.global_position, spawn_dist)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not car:
		return

	var origin := state.transform.origin
	var to_car := car.global_position - origin
	to_car.y = 0.0
	var dir := to_car.normalized()

	var vel := state.linear_velocity
	var current_hspeed := Vector2(vel.x, vel.z).length()
	var target_speed := minf(current_hspeed + acceleration * state.step, speed)
	vel.x = dir.x * target_speed
	vel.z = dir.z * target_speed

	if _raycast.is_colliding():
		var terrain_y := _raycast.get_collision_point().y + 0.5
		vel.y = (terrain_y - origin.y) * 15.0
	else:
		vel.y -= 20.0 * state.step

	state.linear_velocity = vel
	state.angular_velocity = Vector3.ZERO


func take_damage(amount: int) -> void:
	if _dead:
		return
	var hit := GameManager.roll_hit(amount)
	var dealt := maxi(roundi(hit[0]), 1)
	DamageNumber.spawn(get_tree().current_scene, global_position, dealt, hit[1])
	_health -= dealt
	if _health <= 0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	GameManager.enemies_killed += 1
	_spawn_fragments()
	_spawn_xp_orb()
	_on_die()
	_return_to_pool()


## Spawns on the ground `radius` from `center`, materialising out of a fog puff.
func drop_near(center: Vector3, radius: float) -> void:
	var angle := randf() * TAU
	var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 60.0, pos + Vector3.DOWN * 120.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	pos.y = (hit.position.y if hit else center.y) + 0.6
	global_position = pos
	linear_velocity = Vector3.ZERO
	_fog_in()


func _fog_in() -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 10
	puff.lifetime = 1.4
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 1.2
	puff.direction = Vector3.UP
	puff.spread = 60.0
	puff.initial_velocity_min = 0.3
	puff.initial_velocity_max = 1.2
	puff.gravity = Vector3.ZERO
	puff.scale_amount_min = 1.5
	puff.scale_amount_max = 2.8
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.78, 0.76, 0.72, 0.45)
	quad.material = mat
	puff.mesh = quad
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D or child is RayCast3D):
			var visual := child as Node3D
			var full: Vector3 = visual.get_meta("full_scale", visual.scale)   # pooled enemies reuse this
			visual.set_meta("full_scale", full)
			visual.scale = full * 0.15
			create_tween().tween_property(visual, "scale", full, FOG_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reset_for_spawn(car_ref: Node3D) -> void:
	car = car_ref
	_health = ceili(max_health * GameManager.enemy_scale("enemy_health_exp"))
	_dead = false
	angular_velocity = Vector3.ZERO
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	freeze = false
	collision_layer = _collision_layer          # restored after sitting in the pool
	collision_mask = _collision_mask


func _return_to_pool() -> void:
	if _spawner:
		_spawner.recycle.call_deferred(self)
	else:
		queue_free.call_deferred()


func _on_body_entered(body: Node) -> void:
	if not visible or _dead:
		return
	if body == car:
		var ram := car.find_child("RamComponent", false) as Node
		if ram and ram.get("is_ramming"):
			die()
			return
		GameManager.take_damage(roundi(contact_damage * GameManager.enemy_scale("enemy_damage_exp")))
		die()


func _spawn_fragments() -> void:
	if not fragment_scene:
		return
	for i in fragment_count:
		var frag: RigidBody3D = fragment_scene.instantiate()
		get_tree().current_scene.add_child(frag)
		frag.global_position = global_position + Vector3(
			randf_range(-0.5, 0.5),
			randf_range(0.0, 0.6),
			randf_range(-0.5, 0.5)
		)
		frag.scale = Vector3.ONE * randf_range(0.4, 1.1)
		var impulse := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.6, 2.0),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(6.0, 14.0)
		frag.apply_impulse(impulse)


func _spawn_xp_orb() -> void:
	var orb: Node3D = XP_ORB.instantiate()
	orb.set("xp_value", xp_value)
	orb.set("car", car)
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector3.UP * 0.5


func _on_die() -> void:
	pass
