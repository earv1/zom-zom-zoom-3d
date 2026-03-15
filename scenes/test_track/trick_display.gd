class_name TrickDisplay
extends CanvasLayer

@onready var _label: Label = $Label

var _timer := 0.0
const DISPLAY_TIME := 2.0


func show_trick(trick_name: String) -> void:
	_label.text = trick_name + "!"
	_label.visible = true
	_timer = DISPLAY_TIME


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		_label.modulate.a = clampf(_timer / 0.5, 0.0, 1.0)
		if _timer <= 0.0:
			_label.visible = false
