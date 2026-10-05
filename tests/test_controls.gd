extends GutTest

## Controller support: gamepad events drive the same actions as the keyboard.

const CAR := preload("res://scenes/world/car.tscn")


func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()                         # deliver now, not on some later frame


func _button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func after_each() -> void:
	for axis in [JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		_axis(axis, 0.0)
	await wait_physics_frames(2)


func test_triggers_drive_and_the_stick_steers_analogue() -> void:
	var root := Node3D.new()
	get_tree().root.add_child(root)
	get_tree().current_scene = root                      # the car hangs its skid marks off the scene
	var car: RigidBody3D = CAR.instantiate()
	root.add_child(car)
	await wait_physics_frames(2)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait_physics_frames(2)
	assert_eq(car.get("motor_input"), 1, "RT accelerates")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await wait_physics_frames(2)
	assert_eq(car.get("motor_input"), 0, "letting go of RT stops")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await wait_physics_frames(2)
	assert_eq(car.get("motor_input"), -1, "LT brakes / reverses")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_axis(JOY_AXIS_LEFT_X, -0.6)
	await wait_physics_frames(2)
	var steer := Input.get_axis("turn_right", "turn_left")
	assert_between(steer, 0.3, 0.9, "the stick steers part-way, not just full lock")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.35)                           # a diagonal-ish push: no accidental brake
	await wait_physics_frames(2)
	assert_false(Input.is_action_pressed("decelerate"), "small stick down doesn't brake")
	root.queue_free()


func test_buttons_map_to_every_action() -> void:
	for pair in [[JOY_BUTTON_A, "jump"], [JOY_BUTTON_B, "handbreak"], [JOY_BUTTON_RIGHT_SHOULDER, "handbreak"],
			[JOY_BUTTON_LEFT_SHOULDER, "dive"], [JOY_BUTTON_Y, "respawn"], [JOY_BUTTON_BACK, "restart_skill"],
			[JOY_BUTTON_START, "pause"]]:
		_button(pair[0], true)
		await wait_physics_frames(1)
		assert_true(Input.is_action_pressed(pair[1]), "%s -> %s" % [pair[0], pair[1]])
		_button(pair[0], false)
		await wait_physics_frames(1)
	assert_true(InputMap.action_has_event("dive", (func() -> InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = KEY_CTRL
		return k).call()), "keyboard keys kept for code-registered actions")
