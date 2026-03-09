extends CanvasLayer

signal game_started


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed

	if pressed:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		game_started.emit()
		queue_free()
