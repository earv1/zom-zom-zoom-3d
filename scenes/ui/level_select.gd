extends CanvasLayer

@onready var _progress_bar: ProgressBar = $LoadingBar
@onready var _loading_label: Label = $LoadingLabel
@onready var _center: CenterContainer = $Center

const MAIN_GAME := "res://scenes/levels/hadeda_park/hadeda_park.tscn"

var _loading_path: String = ""


func _ready() -> void:
	_progress_bar.visible = false
	_loading_label.visible = false
	# Pre-warm skid mark material so first drift has no hitch
	SkidMark.warmup()
	ResourceLoader.load_threaded_request(MAIN_GAME)   # start loading the park while the menu is up
	var garage := Button.new()
	garage.text = "GARAGE"
	garage.custom_minimum_size = ($Center/VBox/MainGame as Button).custom_minimum_size
	garage.pressed.connect(_on_garage_pressed)
	$Center/VBox.add_child(garage)
	$Center/VBox.move_child(garage, $Center/VBox/MainGame.get_index() + 1)
	var boss_test := Button.new()
	boss_test.text = "BOSS TEST"
	boss_test.custom_minimum_size = garage.custom_minimum_size
	boss_test.pressed.connect(_show_boss_test)
	$Center/VBox.add_child(boss_test)
	$Center/VBox.move_child(boss_test, $Center/VBox/MainGame.get_index() + 1)
	var skills := Button.new()
	skills.text = "SKILLS"
	skills.custom_minimum_size = garage.custom_minimum_size
	skills.pressed.connect(_show_skills)
	$Center/VBox.add_child(skills)
	$Center/VBox.move_child(skills, $Center/VBox/MainGame.get_index() + 1)
	var shake := Button.new()
	shake.custom_minimum_size = garage.custom_minimum_size
	var label_shake := func() -> void: shake.text = "SCREEN SHAKE: " + ("ON" if GameManager.screen_shake else "OFF")
	label_shake.call()
	shake.pressed.connect(func() -> void:
		GameManager.set_screen_shake(not GameManager.screen_shake)
		label_shake.call())
	$Center/VBox.add_child(shake)


func _on_main_game_pressed() -> void:
	_start_load(MAIN_GAME)


## Skill tracks: learn each move on its own course (three sections that get
## harder), then the final puts them all together.
func _show_skills() -> void:
	_center.visible = false
	var panel := CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "SKILLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	for id in SkillLevel.ORDER:
		var info: Dictionary = SkillLevel.SKILLS[id]
		var best: String = "   best %.2fs" % float(GameManager.skill_bests[id]) if GameManager.skill_bests.has(id) else ""
		var b := Button.new()
		b.text = "%s%s\n%s" % [info.title, best, info.blurb]
		b.custom_minimum_size = Vector2(560, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = load("res://assets/icons/skills/%s.svg" % id)
		b.add_theme_constant_override("icon_max_width", 44)
		b.pressed.connect(func() -> void:
			panel.queue_free()
			SkillLevel.selected = id
			_start_load(SkillLevel.SCENE))
		box.add_child(b)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true)
	box.add_child(back)
	panel.add_child(box)
	add_child(panel)
	(box.get_child(1) as Button).grab_focus()


## Boss test mode: load the park and fight any of the three bosses right away.
func _show_boss_test() -> void:
	_center.visible = false
	var panel := CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "BOSS TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	var blurbs := ["melee, leaps, shockwaves, lava", "+ pukes zombie rats", "+ rats and the eye laser"]
	for i in BossFight.NAMES.size():
		var b := Button.new()
		b.text = "%s\n%s" % [BossFight.NAMES[i], blurbs[i]]
		b.custom_minimum_size = Vector2(420, 64)
		b.pressed.connect(func() -> void:
			panel.queue_free()
			ParkLevel.test_stage = i
			_start_load(MAIN_GAME))
		box.add_child(b)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true)
	box.add_child(back)
	panel.add_child(box)
	add_child(panel)
	(box.get_child(1) as Button).grab_focus()


func _on_garage_pressed() -> void:
	_center.visible = false
	var screen := GarageScreen.new()
	screen.closed.connect(func() -> void: _center.visible = true)
	add_child(screen)


func _on_test_track_pressed() -> void:
	_start_load("res://scenes/test_track/test_track2.tscn")


func _start_load(path: String) -> void:
	_loading_path = path
	_center.visible = false
	_progress_bar.visible = true
	_loading_label.visible = true
	_loading_label.text = "LOADING..."
	_progress_bar.value = 0.0
	if path != MAIN_GAME:                              # the park is already loading in the background
		ResourceLoader.load_threaded_request(path)


func _process(_delta: float) -> void:
	if _loading_path.is_empty():
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_progress_bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_progress_bar.value = 100.0
			var scene := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
			get_tree().change_scene_to_packed(scene)
			_loading_path = ""
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_label.text = "LOAD FAILED"
			_loading_path = ""
