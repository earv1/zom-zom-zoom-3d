@tool
extends ParkPiece
## Skill-track hint: a floating sign with instructions. Driving within `reach`
## also shows the text on the HUD (SkillLevel finds signs by group "skill_hints").

@export_storage var text := "HINT"
@export_storage var height := 7.0
@export_storage var reach := 40.0


func get_param_defs() -> Array:
	return [
		{name = "height", label = "Height", min = 2.0, max = 30.0, step = 1.0, default = 7.0},
		{name = "reach", label = "HUD reach", min = 10.0, max = 120.0, step = 5.0, default = 40.0},
	]


func get_connection_anchors() -> Array:
	return []


func _build() -> void:
	if not Engine.is_editor_hint():
		add_to_group("skill_hints")
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = 72
	sign.pixel_size = 0.02
	sign.outline_size = 14
	sign.width = 900.0
	sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.modulate = Color(1.0, 0.95, 0.8)
	sign.outline_modulate = Color(0.15, 0.08, 0.02)
	sign.position.y = height
	add_child(sign)
