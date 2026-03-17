## Jump pad: flat road with a raised lip at the end to launch the car.
@tool
extends Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.22)

	# Main flat slab
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, 0.3, 6.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.position = Vector3(0, -0.15, 1.0)
	add_child(mi)

	# Launch ramp lip (small angled wedge at front)
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.8, 0.5, 0.1)
	var lip := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(6.0, 0.8, 2.0)
	lip.mesh = lbm
	lip.material_override = lip_mat
	lip.position = Vector3(0, 0.2, -3.0)
	lip.rotation.x = deg_to_rad(-20)
	add_child(lip)

	# Collision — main + lip
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 0.3, 6.0)
	cs.shape = bs
	cs.position = Vector3(0, -0.15, 1.0)
	sb.add_child(cs)

	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(6.0, 0.8, 2.0)
	cs2.shape = bs2
	cs2.position = Vector3(0, 0.2, -3.0)
	cs2.rotation.x = deg_to_rad(-20)
	sb.add_child(cs2)

	add_child(sb)
