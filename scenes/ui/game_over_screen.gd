class_name GameOverScreen
extends CanvasLayer

@onready var _time_label: Label = $Panel/VBox/TimeLabel
@onready var _kills_label: Label = $Panel/VBox/KillsLabel
@onready var _retry_button: Button = $Panel/VBox/RetryButton
@onready var _quit_button: Button = $Panel/VBox/QuitButton


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry)
	_quit_button.pressed.connect(get_tree().quit)


func show_screen() -> void:
	var secs := int(GameManager.elapsed_time)
	_time_label.text = "Time: %02d:%02d" % [secs / 60, secs % 60]
	_kills_label.text = "Enemies killed: %d" % GameManager.enemies_killed
	visible = true
	get_tree().paused = true


func _on_retry() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().reload_current_scene()
