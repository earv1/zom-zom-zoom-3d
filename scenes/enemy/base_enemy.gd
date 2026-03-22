class_name BaseEnemy
extends RigidBody3D

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
var _spawner: EnemySpawner
var pool_key: String

const WARP_BUFFER := 30.0   # trigger warp this many units beyond the warp landing spot
const DROP_HEIGHT := 10.0   # units above ground to drop from
const BLOWBACK_RADIUS := 50.0
const BLOWBACK_FORCE := 40.0


func _ready() -> void:
	_health = max_health
	add_to_group("enemies")
	_raycast.add_exception(self)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	GameManager.damage_taken.connect(_on_car_damage_taken)


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
	_health -= amount
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


func drop_near(center: Vector3, radius: float) -> void:
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	var pos := center + offset
	pos.y += DROP_HEIGHT
	global_position = pos
	linear_velocity = Vector3.ZERO


func reset_for_spawn(car_ref: Node3D) -> void:
	car = car_ref
	_health = max_health
	_dead = false
	angular_velocity = Vector3.ZERO
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	freeze = false


func _return_to_pool() -> void:
	if _spawner:
		_spawner.recycle.call_deferred(self)
	else:
		queue_free.call_deferred()


func _on_body_entered(body: Node) -> void:
	if not visible or _dead:
		return
	if body == car:
		GameManager.take_damage(contact_damage)
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
	var orb_scene: PackedScene = load("res://scenes/enemy/xp_orb.tscn")
	if not orb_scene:
		return
	var orb: Node3D = orb_scene.instantiate()
	orb.set("xp_value", xp_value)
	orb.set("car", car)
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector3.UP * 0.5


func _on_car_damage_taken() -> void:
	if _dead or not car or not visible:
		return
	var dist := global_position.distance_to(car.global_position)
	if dist > BLOWBACK_RADIUS:
		return
	var away := global_position - car.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	linear_velocity = Vector3.ZERO
	apply_central_impulse(away.normalized() * BLOWBACK_FORCE + Vector3.UP * 10.0)


func _on_die() -> void:
	pass
