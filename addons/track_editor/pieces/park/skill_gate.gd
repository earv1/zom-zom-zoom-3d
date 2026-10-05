@tool
extends ParkPiece
## Skill-track gate: two posts and a banner across the way (drive through along
## -Z). `kind`: 0 start, 1 checkpoint, 2 trick checkpoint, 3 finish.
## Checkpoints count in `order`. Any gate with `spins` > 0 only counts once you
## have landed that many spins since the last gate (kind 2 needs at least one). A gate is also where
## you respawn: `respawn_drop` > 0 respawns you that high above it, falling (for
## pound pads). The skill level (SkillLevel) finds gates by group "skill_gates".

enum Kind { START, CHECKPOINT, TRICK, FINISH }

@export_storage var kind := 1
@export_storage var order := 1
@export_storage var width := 28.0
@export_storage var respawn_drop := 0.0
@export_storage var spins := 0
@export_storage var depth := 4.0           ## trigger depth along the way: deep gates catch a landing anywhere on a deck

const COLOURS := [Color(0.3, 0.9, 0.4), Color(0.25, 0.7, 1.0), Color(1.0, 0.45, 0.9), Color(1.0, 0.85, 0.2)]


func get_param_defs() -> Array:
	return [
		{name = "kind", label = "Kind (0 start, 1 cp, 2 trick, 3 finish)", min = 0.0, max = 3.0, step = 1.0, default = 1.0},
		{name = "order", label = "Order", min = 0.0, max = 30.0, step = 1.0, default = 1.0},
		{name = "width", label = "Width", min = 8.0, max = 96.0, step = 4.0, default = 28.0},
		{name = "respawn_drop", label = "Respawn drop", min = 0.0, max = 40.0, step = 2.0, default = 0.0},
		{name = "spins", label = "Spins needed", min = 0.0, max = 5.0, step = 1.0, default = 0.0},
		{name = "depth", label = "Trigger depth", min = 2.0, max = 64.0, step = 2.0, default = 4.0},
	]


func get_connection_anchors() -> Array:
	return []


## Spins you must land since the last gate for this one to count.
func spins_needed() -> int:
	return maxi(spins, 1) if kind == Kind.TRICK else spins


func label() -> String:
	var need := spins_needed()
	var trick := ("  -  SPIN x%d" % need) if need > 0 else ""
	match kind:
		Kind.START: return "START"
		Kind.FINISH: return "FINISH" + trick
		Kind.TRICK: return "TRICK" + trick
	return "CHECKPOINT"


func _build() -> void:
	if not Engine.is_editor_hint():
		add_to_group("skill_gates")
	var colour: Color = COLOURS[2] if spins_needed() > 0 and kind != Kind.FINISH else COLOURS[clampi(kind, 0, 3)]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour * 0.6
	var h := 9.0
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = 0.6
		cyl.height = h
		post.mesh = cyl
		post.material_override = mat
		post.position = Vector3(side * width * 0.5, h * 0.5, 0)
		add_child(post)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width + 1.2, 1.6, 0.6)
	bar.mesh = box
	bar.material_override = mat
	bar.position = Vector3(0, h, 0)
	add_child(bar)
	var text := Label3D.new()
	text.text = label()
	text.font_size = 96
	text.pixel_size = 0.02
	text.outline_size = 16
	text.modulate = Color.WHITE
	text.outline_modulate = colour.darkened(0.6)
	text.position = Vector3(0, h, 0.35)
	text.double_sided = true
	add_child(text)
