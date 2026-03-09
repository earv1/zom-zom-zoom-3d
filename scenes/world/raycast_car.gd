extends RigidBody3D
class_name RaycastCar

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var max_speed := 20.0
@export var accel_curve : Curve
@export var tire_turn_speed := 4.0
@export var tire_max_turn_degrees := 25

@export var skid_marks: Array[GPUParticles3D]
@export var anti_roll_strength := 3000.0
@export var roll_damping := 20.0
@export var show_debug := false

@onready var total_wheels := wheels.size()

var motor_input := 0
var hand_break := false
var is_slipping := false
var _prev_hand_break := false

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("handbreak"):
		hand_break = true
		is_slipping = true
	elif event.is_action_released("handbreak"):
		hand_break = false
		is_slipping = false

	if event.is_action_pressed("accelerate"):
		motor_input = 1
	elif event.is_action_released("accelerate"):
		motor_input = 0

	if event.is_action_pressed("decelerate"):
		motor_input = -1
	elif event.is_action_released("decelerate"):
		motor_input = 0


func _basic_steering_rotation(wheel: RaycastWheel, delta: float) -> void:
	if not wheel.is_steer: return

	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	if turn_input:
		wheel.rotation.y = clampf(wheel.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)


func _physics_process(delta: float) -> void:
	if show_debug: DebugDraw.draw_arrow_ray(global_position, linear_velocity, 2.5, 0.5, Color.GREEN)

	var id := 0
	var grounded := false
	for wheel in wheels:
		wheel.apply_wheel_physics(self)
		_basic_steering_rotation(wheel, delta)

		if Input.is_action_pressed("brake"):
			wheel.is_braking = true
		else:
			wheel.is_braking = false

		# Skid marks
		skid_marks[id].global_position = wheel.get_collision_point() + Vector3.UP * 0.01
		skid_marks[id].look_at(skid_marks[id].global_position + global_basis.z)

		if not hand_break and wheel.grip_factor < 0.2:
			is_slipping = false
			skid_marks[id].emitting = false

		if hand_break and not skid_marks[id].emitting:
			skid_marks[id].emitting = true

		if wheel.is_colliding():
			grounded = true

		id += 1

	var turn_input := Input.get_axis("turn_right", "turn_left")

	# Drift kick: snap rear out when handbrake first pressed while moving and turning
	if hand_break and not _prev_hand_break and linear_velocity.length() > 4.0 and absf(turn_input) > 0.1:
		apply_torque_impulse(global_basis.y * turn_input * mass * 1.8)

	# Drift steering: direct rotational control during drift so arrow keys steer the arc
	if hand_break and grounded:
		apply_torque(global_basis.y * turn_input * mass * 3.6)

	_prev_hand_break = hand_break

	if grounded:
		center_of_mass = Vector3.ZERO

		# Roll/pitch damping: resist tipping without affecting yaw (turning)
		apply_torque(Vector3(-angular_velocity.x, 0.0, -angular_velocity.z) * mass * roll_damping)

		# Anti-roll bars: compare compression between paired wheels per axle
		# wheels order: FL, FR, RL, RR
		if wheels.size() == 4:
			_apply_anti_roll(wheels[0], wheels[1])  # front axle
			_apply_anti_roll(wheels[2], wheels[3])  # rear axle
	else:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3.DOWN*1.5


func _apply_anti_roll(left: RaycastWheel, right: RaycastWheel) -> void:
	var left_grounded  := left.is_colliding() or (left.shapecast != null and left.shapecast.is_colliding())
	var right_grounded := right.is_colliding() or (right.shapecast != null and right.shapecast.is_colliding())

	var left_travel  := left.spring_compression  if left_grounded  else -1.0
	var right_travel := right.spring_compression if right_grounded else -1.0

	var diff := left_travel - right_travel
	var force := diff * anti_roll_strength

	if left_grounded:
		apply_force( left.global_basis.y *  force, left.global_position  - global_position)
	if right_grounded:
		apply_force(right.global_basis.y * -force, right.global_position - global_position)
