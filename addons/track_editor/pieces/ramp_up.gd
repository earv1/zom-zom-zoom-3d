## Ramp piece: flat entry, rises one full cell height (4m) over 8m length.
## Exit connects to an elevated straight.
@tool
extends Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.22, 0.22)

	# 4 stepped sections approximating the slope
	var steps := 5
	for i in range(steps):
		var t := (i + 0.5) / steps
		var z_pos := -4.0 + (float(i) / steps) * 8.0 + (8.0 / steps) * 0.5
		var y_pos := t * 4.0  # rises to 4m
		var pitch := atan2(4.0, 8.0)  # ~26.6 degrees

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.0, 0.3, 8.0 / steps + 0.05)
		mi.mesh = bm
		mi.material_override = road_mat.duplicate()
		mi.position = Vector3(0, y_pos - 0.15, z_pos)
		mi.rotation.x = -pitch
		add_child(mi)

	# Collision ramp box — rotated
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 0.3, 8.6)
	cs.shape = bs
	var pitch := atan2(4.0, 8.0)
	cs.rotation.x = -pitch
	cs.position = Vector3(0, 2.0 - 0.15, 0)
	sb.add_child(cs)
	add_child(sb)

	# Guard rails
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.8, 0.2, 0.2)
	for side in [-1, 1]:
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.15, 4.0, 0.15)
		r.mesh = rm
		r.material_override = rail_mat.duplicate()
		r.position = Vector3(side * 3.1, 2.0, 0)
		r.rotation.x = -atan2(4.0, 8.0)
		add_child(r)
