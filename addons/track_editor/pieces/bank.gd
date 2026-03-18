## Banked turn: flat entry/exit, road surface tilted inward.
@tool
extends Node3D

@export_storage var road_width := 6.0
@export_storage var bank_angle := 30.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	bank_angle = params.get("bank_angle", bank_angle)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, bank_angle = bank_angle}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width",  min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "bank_angle", label = "Bank Angle", min = 6.0, max = 60.0, step = 6.0, default = 30.0},
	]

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.32)

	# Road slab tilted around Z axis
	var slab_w := road_width + 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(slab_w, 0.3, 8.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.rotation.z = deg_to_rad(-bank_angle)
	mi.position = Vector3(0, 0.3, 0)
	add_child(mi)

	# Outer wall
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.4, 0.55)
	var wm  := MeshInstance3D.new()
	var wbm := BoxMesh.new()
	wbm.size = Vector3(0.3, 2.5, 8.0)
	wm.mesh = wbm
	wm.material_override = wall_mat
	wm.position = Vector3(road_width * 0.5 + 0.5, 1.2, 0)
	add_child(wm)

	# Collision
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(slab_w, 0.3, 8.0)
	cs.shape = bs
	cs.rotation.z = deg_to_rad(-bank_angle)
	cs.position = Vector3(0, 0.3, 0)
	sb.add_child(cs)
	add_child(sb)
