extends RayCast3D
class_name End5RaycastWheel

@export var shapecast : ShapeCast3D

@export_group("Wheel properties")
@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5
@export var over_extend := 0.0
@export var wheel_radius := 0.4
@export var z_traction := 0.05
@export var z_brake_traction := 0.25

@export_category("Motor")
@export var is_motor := false
@export var is_steer := false
@export var grip_curve : Curve

@export_category("Debug")
@export var show_debug := false

@onready var wheel: Node3D = get_child(0)

var engine_force := 0.0
var grip_factor  := 0.0
var is_braking   := false


func _ready() -> void:
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	if shapecast:
		shapecast.target_position.x = -(rest_dist + over_extend)
		shapecast.add_exception(get_parent())

		shapecast.position.y = offset_shapecast

var offset_shapecast := 0.5
func apply_wheel_physics(car: End5RaycastCar) -> void:
	force_raycast_update()
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	if shapecast:
		#shapecast.force_shapecast_update()
		shapecast.target_position.x = -(rest_dist + over_extend) - offset_shapecast
		#print("target: ", shapecast.target_position)
		#var dist_corrected := shapecast.global_basis * shapecast.target_position
		#var position_shape := global_position - Vector3(0, wheel_radius,0) + dist_corrected * shapecast.get_closest_collision_safe_fraction()
		#if shapecast.is_colliding(): DebugDraw.draw_sphere(position_shape, 0.1, Color.RED)
		#if shapecast.is_colliding():
			#DebugDraw.draw_sphere(shapecast.get_collision_point(0), 0.1, Color.YELLOW)
			#print("shape_col: ", shapecast.get_collision_point(0))
			#print("dist corrected: ", dist_corrected)
			#print(shapecast.get_collision_point(0))
			#var hit_dist = dist_corrected.dot(to_local(shapecast.get_collision_point(0)))
			#print("local: ", to_local(shapecast.get_collision_point(0)))
			#print("hit_dist: ", hit_dist)
			#var pos_fix = global_position + Vector3(0, -hit_dist-wheel_radius, 0)
			#DebugDraw.draw_sphere(pos_fix, 0.1, Color.WEB_PURPLE)
		#if is_colliding(): ## Raycast
			#DebugDraw.draw_sphere(get_collision_point(), 0.1, Color.GREEN)
			#print("raycast: ", get_collision_point())
		## New tests
		#var result = shape_cast(global_position, dist_corrected)
		#if result["hit_distance"]: print(result["hit_distance"])

		#print("----\n")

	## Rotates wheel visuals
	var forward_dir   := -global_basis.z
	var vel           := forward_dir.dot(car.linear_velocity)
	wheel.rotate_x( (-vel * get_physics_process_delta_time()) / wheel_radius )


	## Collision on top of shapecast
	if not shapecast.is_colliding():
		var result = rest_info()
		if result:
			#print(result)
			DebugDraw.draw_sphere(result["point"], 0.15, Color.BLUE)
	else:
		var result = rest_info()
		if result:
			#print(result)
			DebugDraw.draw_sphere(result["point"], 0.15, Color.YELLOW)

	if shapecast and not shapecast.is_colliding(): return
	if not shapecast and not is_colliding(): return


	# From here on, the wheel raycast is now colliding

	var contact       := get_collision_point()
	if shapecast:
		contact = shapecast.get_collision_point(0)
		DebugDraw.draw_sphere(contact, 0.1, Color.GREEN)

		var unsafe := shapecast.get_closest_collision_unsafe_fraction()
		var pos_bottom := shapecast.global_position + (global_basis.y*unsafe*(shapecast.target_position.x-offset_shapecast))
		DebugDraw.draw_sphere(pos_bottom, 0.1, Color.RED)

	var spring_len    := maxf(0.0, global_position.distance_to(contact) - wheel_radius)
	var offset        := rest_dist - spring_len

	wheel.position.y = -spring_len#move_toward(wheel.position.y, -spring_len, 5 * get_physics_process_delta_time()) # Local y position of the wheel
	contact = wheel.global_position # Contact is now the wheel origin point
	var force_pos     := contact - car.global_position

	## Spring forces
	var spring_force  := spring_strength * offset
	var tire_vel      := car._get_point_velocity(contact) # Center of the wheel
	var spring_damp_f := spring_damping * global_basis.y.dot(tire_vel)

	var y_force       := (spring_force - spring_damp_f) * get_collision_normal()
	if shapecast:
		y_force       = (spring_force - spring_damp_f) * shapecast.get_collision_normal(0)#clampf(spring_force - spring_damp_f, -150000, 150000) * shapecast.get_collision_normal(0)

	#if shapecast.get_collision_count() > 1:
		#spring_len    = maxf(0.0, global_position.distance_to(shapecast.get_collision_point(1)) - wheel_radius)
		#offset        = rest_dist - spring_len
		#spring_force  = spring_strength * offset
		#tire_vel      = car._get_point_velocity(shapecast.get_collision_point(1))
		#spring_damp_f = spring_damping * global_basis.y.dot(tire_vel)
		#y_force  += (spring_force - spring_damp_f) * shapecast.get_collision_normal(1)
		#print(shapecast.get_collision_count())


	## Acceleration
	if is_motor and car.motor_input:
		var speed_ratio := vel / car.max_speed
		var ac := car.accel_curve.sample_baked(speed_ratio)
		var accel_force := forward_dir * car.acceleration * car.motor_input * ac
		car.apply_force(accel_force, force_pos)
		if show_debug: DebugDraw.draw_arrow_ray(contact, accel_force/car.mass, 2.5, 0.5, Color.RED)

	## Tire X traction (Steering)
	var steering_x_vel := global_basis.x.dot(tire_vel)
	grip_factor        = absf(steering_x_vel/tire_vel.length())
	#grip_factor        = absf(steering_x_vel/car.max_speed)
	var x_traction     := grip_curve.sample_baked(grip_factor)

	#print(grip_factor)
	if not car.hand_break and grip_factor < 0.2:
		car.is_slipping = false
	if car.hand_break:
		x_traction = 0.01
	elif car.is_slipping:
		x_traction = 0.1


	var gravity        := -car.get_gravity().y
	var x_force        := -global_basis.x * steering_x_vel * x_traction * ((car.mass * gravity)/car.total_wheels)

	## Tire Z traction (Longidutinasl)
	var f_vel          := forward_dir.dot(tire_vel)
	var z_friction     := z_traction
	if is_braking:
		z_friction = z_brake_traction

	var z_force        := global_basis.z * f_vel * z_friction * ((car.mass * gravity)/car.total_wheels)

	## Counter sliding
	if absf(f_vel) < 0.05:
		#print(f_vel)
		var susp := global_basis.y * (spring_force - spring_damp_f)
		z_force.z -= susp.z * car.global_basis.y.dot(Vector3.UP)
		x_force.x -= susp.x * car.global_basis.y.dot(Vector3.UP)


	car.apply_force(y_force, force_pos)
	car.apply_force(x_force, force_pos)
	car.apply_force(z_force, force_pos)

	if show_debug: DebugDraw.draw_arrow_ray(contact, z_force/car.mass, 2.5, 0.2, Color.PURPLE,0, true)
	if show_debug: DebugDraw.draw_arrow_ray(contact, y_force/car.mass, 2.5, 0.3)
	if show_debug: DebugDraw.draw_arrow_ray(contact, x_force/car.mass, 1.5, 0.2, Color.YELLOW)

	if shapecast:
		for idx in shapecast.get_collision_count():
			if shapecast.get_collider(idx) is RigidBody3D:
				#print("OK")
				shapecast.get_collider(idx).apply_force(-(x_force+y_force+z_force), force_pos)


func shape_cast(origin: Vector3, cast_to: Vector3) -> Dictionary:
	var space:= get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.33
	params.shape = sphere
	params.transform = transform
	params.transform.origin = origin
	params.exclude = [get_parent()]
	params.motion = cast_to
	var cast_result = space.cast_motion(params)
	var result : Dictionary
	result["hit_distance"] = cast_result[0] * cast_to.length()
	DebugDraw.draw_sphere(origin, 0.1, Color(Color.ALICE_BLUE, 0.2))
	DebugDraw.draw_sphere(origin+cast_to, 0.1, Color.ANTIQUE_WHITE)
	return result

func collide_shape() -> Array[Vector3]:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shapecast.shape
	params.transform = shapecast.transform
	params.transform.origin = shapecast.global_position
	params.exclude = [get_parent()]
	var result = space.collide_shape(params, 3)
	return result

func intersect_shape() -> Array[Dictionary]:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shapecast.shape
	params.transform = shapecast.transform
	params.transform.origin = shapecast.global_position
	params.exclude = [get_parent()]
	var result = space.intersect_shape(params, 3)
	return result


func rest_info() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shapecast.shape
	params.transform = shapecast.transform
	params.transform.origin = shapecast.global_position
	params.exclude = [get_parent()]
	var result = space.get_rest_info(params)
	return result
