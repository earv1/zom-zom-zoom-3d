class_name WinScreen
extends CanvasLayer

@onready var _time_label: Label = $Panel/VBox/TimeLabel
@onready var _kills_label: Label = $Panel/VBox/KillsLabel
@onready var _level_label: Label = $Panel/VBox/LevelLabel
@onready var _retry_button: Button = $Panel/VBox/RetryButton
@onready var _quit_button: Button = $Panel/VBox/QuitButton
@onready var _panel: Panel = $Panel


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry)
	_quit_button.pressed.connect(get_tree().quit)
	call_deferred("_init_pivot")


func _init_pivot() -> void:
	_panel.pivot_offset = _panel.size / 2.0


func show_screen() -> void:
	var secs := int(GameManager.elapsed_time)
	_time_label.text = "Time: %02d:%02d" % [secs / 60, secs % 60]
	_kills_label.text = "Enemies killed: %d" % GameManager.enemies_killed
	_level_label.text = "Level: %d" % GameManager.current_level
	visible = true
	get_tree().paused = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.88, 0.88)
	var t := create_tween().set_parallel()
	t.tween_property(_panel, "modulate:a", 1.0, 0.3)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_retry() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().reload_current_scene()
