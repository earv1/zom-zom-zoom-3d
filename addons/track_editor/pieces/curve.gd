## 90-degree curved piece. Approximated with 4 straight segments rotated
## around the inner corner of the cell.
@tool
extends Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.22)
	var kerb_mat := StandardMaterial3D.new()
	kerb_mat.albedo_color = Color(0.9, 0.9, 0.2)

	# 4 arc segments each 22.5°, pivot at (-4, 0, -4) corner
	# Radius to centre of road = 4m + 3m = 7m (outer) / 4m - 3m = 1m (inner)
	# We approximate the road surface with 4 box slabs
	var pivot := Vector3(-4.0, 0.0, -4.0)
	var steps := 4
	var seg_angle := 90.0 / steps

	for i in range(steps):
		var angle := deg_to_rad(i * seg_angle + seg_angle * 0.5)
		# Centre of road arc at radius 4m from pivot
		var r := 4.0
		var cx := pivot.x + sin(angle) * r
		var cz := pivot.z + cos(angle) * r

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.0, 0.3, 2.2)  # slightly wider chord per segment
		mi.mesh = bm
		mi.material_override = road_mat.duplicate()
		mi.position = Vector3(cx, -0.15, cz)
		mi.rotation.y = -angle
		add_child(mi)

	# Collision — approximate with one large box covering the quarter
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7.0, 0.3, 7.0)
	cs.shape = bs
	cs.position = Vector3(pivot.x * 0.5 + 4.0 * 0.5 - 0.5, -0.15, pivot.z * 0.5 + 4.0 * 0.5 - 0.5)
	sb.add_child(cs)
	add_child(sb)
