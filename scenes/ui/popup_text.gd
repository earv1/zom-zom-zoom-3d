extends Control

## Floating text popup that rises and fades out.

const RISE_SPEED := 60.0
const FADE_DURATION := 1.2

var _labels: Array = []  # Array of { label: Label, time: float, max_time: float }


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_text(text: String, color: Color = Color.WHITE, duration: float = FADE_DURATION) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position at center-ish, offset by existing popups
	var y_offset := _labels.size() * 40
	label.position = Vector2(size.x * 0.5 - 100, size.y * 0.35 - y_offset)
	label.size = Vector2(200, 40)
	add_child(label)
	_labels.append({"label": label, "time": 0.0, "max_time": duration})


func _process(delta: float) -> void:
	var to_remove: Array = []
	for i in range(_labels.size() - 1, -1, -1):
		var entry: Dictionary = _labels[i]
		entry["time"] += delta
		var t: float = entry["time"] / entry["max_time"]
		var label: Label = entry["label"]
		label.position.y -= RISE_SPEED * delta
		label.modulate.a = clampf(1.0 - t, 0.0, 1.0)
		if t >= 1.0:
			label.queue_free()
			to_remove.append(i)
	for i in to_remove:
		_labels.remove_at(i)
