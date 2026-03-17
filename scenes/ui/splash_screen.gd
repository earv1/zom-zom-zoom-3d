extends CanvasLayer

signal game_started


func _ready() -> void:
	game_started.emit()
	queue_free()
