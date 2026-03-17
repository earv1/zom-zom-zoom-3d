## Banked turn: flat entry/exit, road surface tilted 30° inward.
@tool
extends Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.32)

	# Road slab tilted 30° around Z axis
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.5, 0.3, 8.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.rotation.z = deg_to_rad(-30)
	mi.position = Vector3(0, 0.3, 0)
	add_child(mi)

	# Outer wall
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.4, 0.55)
	var wm := MeshInstance3D.new()
	var wbm := BoxMesh.new()
	wbm.size = Vector3(0.3, 2.5, 8.0)
	wm.mesh = wbm
	wm.material_override = wall_mat
	wm.position = Vector3(3.5, 1.2, 0)
	add_child(wm)

	# Collision
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.5, 0.3, 8.0)
	cs.shape = bs
	cs.rotation.z = deg_to_rad(-30)
	cs.position = Vector3(0, 0.3, 0)
	sb.add_child(cs)
	add_child(sb)
