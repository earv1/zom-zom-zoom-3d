extends Node
@export var car: RigidBody3D
@export var update_ui_vars := true
@export var use_pause_time_inputs := false
@export var ball_impulse := 35.0
@export var direction_xz : Vector2 = Vector2(1.0, 0.0)

var mouse_pressed := false
var is_using_signals := false

func _ready() -> void:
	if update_ui_vars and car and car.has_signal("time_scale_changed"):
		is_using_signals = true
		car.time_scale_changed.connect(update_time_scale_label)
		car.all_force_changed.connect(update_checkbox.bind(%AllForcesCB))
		car.pull_force_changed.connect(update_checkbox.bind(%PullForcesCB))

		update_checkbox(not car.disable_pull_force, %PullForcesCB)
		update_checkbox(not car.disable_forces, %AllForcesCB)
	if not car:
		car = %Car
	if not update_ui_vars:
		$CanvasLayer.hide()


func _physics_process(_delta: float) -> void:
	if update_ui_vars and not is_using_signals and car:
		if "disable_pull_force" in car: update_checkbox(not car.disable_pull_force, %PullForcesCB)
		if "disable_forces" in car: update_checkbox(not car.disable_forces, %AllForcesCB)
		if "hand_break" in car: update_checkbox(car.hand_break, %HandBreakCB)
		if "is_braking" in car.wheels[0]: update_checkbox(car.wheels[0].is_braking, %BrakeCB)
		if "is_slipping" in car: update_checkbox(car.is_slipping, %SlippingCB)
		update_time_scale_label(Engine.time_scale)

		var speed := -car.global_basis.z.dot(car.linear_velocity)
		# Car velocity
		%SpeedLabel.text = "Speed: %4.1f m/s | %4.1f km/h | %4.1f mph" % \
			[speed, speed*3.6, speed*2.237]
		# Car motor
		if "accel_curve" in car:
			var ratio = speed / car.max_speed
			var ac = car.accel_curve.sample_baked(ratio)
			%MotorRatio.value = ac
			var real_accel = ac * car.acceleration
			if not car.motor_input:
				real_accel = 0
				%MotorRatio.value = 0
			%AccelLabel.text = "AccelForce: %.0f" % real_accel


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_scene"):
		get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.button_index == 3:
		if event.pressed:
			mouse_pressed = true
			if "disable_forces" in car:
				car.disable_forces = true
			car.freeze = false
			car.gravity_scale = 0.0
		else:
			mouse_pressed = false
			if "disable_forces" in car:
				car.disable_forces = false
			car.freeze = false
			car.gravity_scale = 1.0
	if event is InputEventMouseMotion:
		if event.button_mask == 4:
			car.linear_velocity.y = -event.relative.y / 20.0
			#car.global_position.y -= event.relative.y / 50.0

	# V key to toggle debug
	if event.is_action_pressed("toggle_pull_forces"):
		car.show_debug = not car.show_debug
	# C key to throw rock
	if event.is_action_pressed("toggle_all_forces"):
		var rock: RigidBody3D = $RockRB
		var new_pos := car.global_position + \
			(-car.global_basis.x * direction_xz.x) + \
			(-car.global_basis.z * direction_xz.y) + \
			(car.global_basis.y * 0.5)
		PhysicsServer3D.body_set_state(
			rock.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			Transform3D.IDENTITY.translated(new_pos)
		)
		rock.apply_central_impulse(car.global_basis.x * ball_impulse)


	if use_pause_time_inputs:
		if event.is_action_pressed("speed_1"):
			Engine.time_scale = 1.0
			car.freeze = false
		if event.is_action_pressed("speed_2"):
			Engine.time_scale = 0.25
			car.freeze = false
		if event.is_action_pressed("speed_3"):
			Engine.time_scale = 0.1
			car.freeze = false
		if event.is_action_pressed("speed_4"):
			Engine.time_scale = 0.01
			car.freeze = false

	if event.is_action_pressed("quit"):
		get_tree().quit()

func update_time_scale_label(value: float) :
	%TimeScaleLabel.text = "Time scale: %.2f" % value
	if value >= 0.9:
		%TimeScaleLabel.hide()
	else:
		%TimeScaleLabel.show()

func update_checkbox(value: bool, checkbox: CheckBox):
	checkbox.button_pressed = value
