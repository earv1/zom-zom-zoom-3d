extends GutTest

## Tests for the hadeda boss eye laser: the tracking circle, damage rules and
## state timing, plus the boss's stage/clip wiring. Ground snapping is turned
## off so the laser runs without terrain; _physics_process is stepped by hand.

const DT := 0.1

var _laser: EyeLaser
var _target: Node3D


func before_each() -> void:
	GameManager.reset()
	_target = add_child_autofree(Node3D.new())
	_laser = EyeLaser.new()
	_laser.snap_to_ground = false
	_laser.target = _target
	add_child_autofree(_laser)
	_laser.set_physics_process(false)


func after_each() -> void:
	GameManager.reset()


func _step(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_laser._physics_process(DT)


# ── Tracking ──────────────────────────────────────────────────────────────────

func test_circle_locks_onto_target_at_start() -> void:
	_target.global_position = Vector3(10, 0, -4)
	_laser.start()
	assert_almost_eq(_laser.circle_center, Vector3(10, 0, -4), Vector3.ONE * 0.001)


func test_circle_chases_no_faster_than_track_speed() -> void:
	_laser.start()
	_target.global_position = Vector3(100, 0, 0)
	_step(DT)
	assert_almost_eq(_laser.circle_center.x, _laser.track_speed * DT, 0.001,
		"circle should move exactly track_speed * dt toward a distant target")


func test_circle_slows_down_while_firing() -> void:
	_laser.start()
	_step(_laser.charge_time)
	assert_eq(_laser.state, EyeLaser.State.FIRE)
	var before := _laser.circle_center.x
	_target.global_position = Vector3(100, 0, 0)
	_step(DT)
	assert_almost_eq(_laser.circle_center.x - before, _laser.fire_track_speed * DT, 0.001)


func test_car_at_full_speed_outruns_the_circle() -> void:
	assert_lt(_laser.track_speed, 60.0, "the car's max_speed is 60; the circle must be dodgeable")


# ── Damage ────────────────────────────────────────────────────────────────────

func test_no_damage_while_charging() -> void:
	_laser.start()
	_step(_laser.charge_time - DT)
	assert_eq(GameManager.current_health, GameManager.max_health)


func test_damage_inside_circle_while_firing() -> void:
	_laser.start(1.0)
	_step(_laser.charge_time + 1.0)
	var expected := int(_laser.damage_per_second * 1.0) / _laser.damage_tick * _laser.damage_tick
	assert_almost_eq(GameManager.max_health - GameManager.current_health, expected, _laser.damage_tick)


func test_no_damage_outside_circle() -> void:
	_laser.start(1.0)
	_laser.track_speed = 0.0
	_laser.fire_track_speed = 0.0
	_target.global_position = Vector3(_laser.radius + 1.0, 0, 0)
	_step(_laser.charge_time + 1.0)
	assert_eq(GameManager.current_health, GameManager.max_health)


# ── Sequence ──────────────────────────────────────────────────────────────────

func test_runs_charge_fire_end_idle() -> void:
	watch_signals(_laser)
	_laser.start(0.5)
	assert_eq(_laser.state, EyeLaser.State.CHARGE)
	_step(_laser.charge_time)
	assert_eq(_laser.state, EyeLaser.State.FIRE)
	_step(0.5)
	assert_eq(_laser.state, EyeLaser.State.END)
	_step(_laser.end_time)
	assert_eq(_laser.state, EyeLaser.State.IDLE)
	assert_signal_emit_count(_laser, "state_changed", 4)


func test_stop_ends_early() -> void:
	_laser.start()
	_laser.stop()
	assert_eq(_laser.state, EyeLaser.State.END)


# ── Boss wiring ───────────────────────────────────────────────────────────────

func test_every_stage_loads_with_shared_clips_and_eye_socket() -> void:
	var boss: HadedaBoss = add_child_autofree(HadedaBoss.new())
	for s in HadedaBoss.Stage.values():
		boss.stage = s
		for clip in [&"idle", &"walk", &"peck_combo", &"wing_slam", &"drill_burrow"]:
			assert_true(boss._anim.has_animation(clip), "%s missing on %s" % [clip, s])
		assert_gt(boss._eye_bone, -1, "laser_eye bone missing on %s" % s)
		assert_eq(boss._anim.has_animation(&"laser_fire"), s == HadedaBoss.Stage.CYDEDA)


func test_only_cydeda_fires_the_laser() -> void:
	var boss: HadedaBoss = add_child_autofree(HadedaBoss.new())
	boss.stage = HadedaBoss.Stage.ZADEDA
	boss.fire_laser()
	assert_false(boss.laser.is_active())
	boss.stage = HadedaBoss.Stage.CYDEDA
	boss.fire_laser()
	assert_true(boss.laser.is_active())
	assert_eq(boss.current_clip(), &"laser_charge")


func test_hit_window_reports_live_frames() -> void:
	var boss: HadedaBoss = add_child_autofree(HadedaBoss.new())
	boss.play(&"peck_combo", 0.0)
	boss._anim.seek((11 - 1) / 24.0, true)
	assert_true(boss.is_hit_live(), "frame 11 is inside the first peck")
	boss._anim.seek((15 - 1) / 24.0, true)
	assert_false(boss.is_hit_live(), "frame 15 is between pecks")


func test_each_stage_has_its_own_voice_and_a_call_never_cuts_a_scream() -> void:
	var boss: HadedaBoss = add_child_autofree(HadedaBoss.new())
	for s in HadedaBoss.Stage.values():
		boss.stage = s
		boss._voice.stop()
		boss._voice_ready_at = 0.0
		boss.play(&"peck_combo")
		assert_eq(boss._voice.stream, HadedaBoss.VOICES[s][0], "attack call on stage %s" % s)
		boss.play(&"scream")
		assert_eq(boss._voice.stream, HadedaBoss.VOICES[s][1], "scream on stage %s" % s)
		boss._voice_ready_at = 0.0
		boss.play(&"wing_slam")
		assert_eq(boss._voice.stream, HadedaBoss.VOICES[s][1], "scream kept playing on stage %s" % s)
