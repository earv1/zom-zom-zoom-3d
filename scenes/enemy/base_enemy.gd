class_name BaseEnemy
extends RigidBody3D

@export var car: Node3D
@export var fragment_scene: PackedScene
@export var speed: float = 8.0
@export var max_health: int = 1
@export var xp_value: int = 5
@export var contact_damage: int = 10
@export var fragment_count: int = 10

@onready var _raycast: RayCast3D = $RayCast3D

var _health: int
var _dead: bool = false
var _lifetime: float = 0.0
var _blink_mat: StandardMaterial3D
var _original_color: Color
var _spawner: EnemySpawner
var pool_key: String

const LIFETIME := 30.0
const BLINK_START := 25.0
const WARP_BUFFER := 30.0   # trigger warp this many units beyond the warp landing spot


func _ready() -> void:
	_health = max_health
	add_to_group("enemies")
	_raycast.add_exception(self)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Cache a unique material so blinking doesn't affect other enemies.
	var mesh := find_child("*") as MeshInstance3D
	if mesh:
		var src := mesh.get_active_material(0)
		if src:
			_blink_mat = src.duplicate() as StandardMaterial3D
			_original_color = _blink_mat.albedo_color
			mesh.set_surface_override_material(0, _blink_mat)


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= LIFETIME:
		_return_to_pool()
		return

	# Warp back toward the car if the enemy has wandered too far.
	if car:
		var spawners := get_tree().get_nodes_in_group("enemy_spawner")
		var spawn_dist := 120.0
		if spawners.size() > 0:
			spawn_dist = (spawners[0] as EnemySpawner).spawn_radius * 3.0
		if global_position.distance_to(car.global_position) > spawn_dist + WARP_BUFFER:
			var angle := randf() * TAU
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * spawn_dist
			global_position = car.global_position + offset
			global_position.y += 10.0
			linear_velocity = Vector3.ZERO  # drop cleanly from spawn height

	if _blink_mat and _lifetime >= BLINK_START:
		# Speed up blink rate as expiry approaches: 2 Hz → 10 Hz over 5 seconds.
		var frac := (_lifetime - BLINK_START) / (LIFETIME - BLINK_START)
		var hz := lerpf(2.0, 10.0, frac)
		var on := fmod(_lifetime * hz, 1.0) < 0.5
		_blink_mat.albedo_color = _original_color if on else Color.WHITE


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not car:
		return

	var origin := state.transform.origin
	var to_car := car.global_position - origin
	to_car.y = 0.0
	var dir := to_car.normalized()

	var vel := state.linear_velocity
	vel.x = dir.x * speed
	vel.z = dir.z * speed

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


func reset_for_spawn(pos: Vector3, car_ref: Node3D) -> void:
	# Position while still frozen so physics doesn't interfere.
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	car = car_ref
	_health = max_health
	_dead = false
	_lifetime = 0.0
	if _blink_mat:
		_blink_mat.albedo_color = _original_color
	# Enable after positioning.
	freeze = false
	visible = true
	process_mode = PROCESS_MODE_INHERIT


func _return_to_pool() -> void:
	if _spawner:
		_spawner.recycle(self)
	else:
		queue_free()


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


func _on_die() -> void:
	pass
