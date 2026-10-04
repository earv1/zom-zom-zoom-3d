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
