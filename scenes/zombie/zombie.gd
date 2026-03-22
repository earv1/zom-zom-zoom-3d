extends RigidBody3D

@export var car: Node3D
@export var fragment_scene: PackedScene
@export var speed: float = 8.0
@export var fragment_count: int = 14

@onready var _raycast: RayCast3D = $RayCast3D


func _ready() -> void:
	_raycast.add_exception(self)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


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

	# Raycast grounding — spring toward terrain surface
	if _raycast.is_colliding():
		var terrain_y := _raycast.get_collision_point().y + 0.5
		vel.y = (terrain_y - origin.y) * 15.0
	else:
		vel.y -= 20.0 * state.step

	state.linear_velocity = vel
	state.angular_velocity = Vector3.ZERO


func _on_body_entered(body: Node) -> void:
	if body == car:
		explode()


func explode() -> void:
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
	queue_free()
