extends CanvasLayer

@onready var _progress_bar: ProgressBar = $LoadingBar
@onready var _loading_label: Label = $LoadingLabel
@onready var _center: CenterContainer = $Center

var _loading_path: String = ""


func _ready() -> void:
	_progress_bar.visible = false
	_loading_label.visible = false
	# Pre-warm skid mark material so first drift has no hitch
	SkidMark.warmup()


func _on_main_game_pressed() -> void:
	_start_load("res://scenes/world/world.tscn")


func _on_test_track_pressed() -> void:
	_start_load("res://scenes/test_track/test_track.tscn")


func _start_load(path: String) -> void:
	_loading_path = path
	_center.visible = false
	_progress_bar.visible = true
	_loading_label.visible = true
	_loading_label.text = "LOADING..."
	_progress_bar.value = 0.0
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
