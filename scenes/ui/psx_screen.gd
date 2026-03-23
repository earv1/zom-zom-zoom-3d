extends CanvasLayer

## Fullscreen PSX post-process overlay.
## Add as a child of your main scene, or as an autoload.

var _rect: ColorRect


func _ready() -> void:
	layer = 0  # render after 3D but before HUD (layer 1)
	var shader := preload("res://assets/shaders/psx_postprocess.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_depth", 15)
	mat.set_shader_parameter("dither_strength", 0.4)
	mat.set_shader_parameter("target_resolution", Vector2i(640, 480))

	_rect = ColorRect.new()
	_rect.material = mat
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
