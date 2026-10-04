extends Node3D
## Boss sandbox: drive around and dodge the hadeda boss.
## 7/8/9 stage (hadeda, zadeda, cydeda) · L eye laser · P peck · O wing slam
## B drill burrow · N toggle the auto demo. The circle can't keep up with the car
## at speed, so keep moving.
##
## BOSS_SHOTS=<dir> renders a scripted laser shot sequence to <dir> and quits.

@export var boss: HadedaBoss
@export var car: Node3D

var _auto := true
var _next_action := 2.0
var _label: Label
var _shots_dir := OS.get_environment("BOSS_SHOTS")
var _shot_times: Array[float] = [0.9, 1.3, 2.2, 3.0, 4.2]
var _clock := 0.0


func _ready() -> void:
	GameManager.reset()
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	if _shots_dir != "":
		_auto = false
		boss.fire_laser(3.0)


func _process(delta: float) -> void:
	_clock += delta
	if _shots_dir != "":
		_capture_shots()
	elif _auto:
		_next_action -= delta
		if _next_action <= 0.0 and boss.current_clip() == &"idle" and not boss.laser.is_active():
			_run_demo_action()
	_label.text = "%s   clip: %s%s   health: %d\n7/8/9 stage · L laser · P peck · O wing slam · B burrow · N auto demo (%s)" % [
		HadedaBoss.Stage.keys()[boss.stage], boss.current_clip(),
		"  [HIT LIVE]" if boss.is_hit_live() else "", GameManager.current_health,
		"on" if _auto else "off"]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_7: boss.stage = HadedaBoss.Stage.HADEDA
		KEY_8: boss.stage = HadedaBoss.Stage.ZADEDA
		KEY_9: boss.stage = HadedaBoss.Stage.CYDEDA
		KEY_L: boss.fire_laser()
		KEY_P: boss.play(&"peck_combo")
		KEY_O: boss.play(&"wing_slam")
		KEY_B: boss.play(&"drill_burrow")
		KEY_N: _auto = not _auto


func _run_demo_action() -> void:
	if boss.has_laser() and randf() < 0.5:
		boss.fire_laser()
	else:
		boss.play([&"peck_combo", &"wing_slam", &"drill_burrow", &"scream"].pick_random())
	_next_action = randf_range(1.5, 3.0)


func _capture_shots() -> void:
	if _shot_times.is_empty():
		get_tree().quit()
		return
	if _clock >= _shot_times[0]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%.1fs.png" % [_shots_dir, _shot_times[0]])
		_shot_times.pop_front()
