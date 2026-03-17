## Full vertical loop. Spans 1 cell wide, ~3 cells tall.
## 12 segments of 30° each approximate a circle of radius ~5m.
@tool
extends Node3D

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.18, 0.28, 0.18)

	var radius := 5.0
	var centre_y := radius + 0.0  # loop centre sits at radius height
	var seg_count := 12

	for i in range(seg_count):
		var angle := (float(i) / seg_count) * TAU
		var next_angle := (float(i + 1) / seg_count) * TAU
		var mid_angle := (angle + next_angle) * 0.5

		var cy := centre_y + sin(mid_angle) * radius
		var cz := cos(mid_angle) * radius

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var seg_len := 2.0 * radius * sin(PI / seg_count) + 0.1
		bm.size = Vector3(6.0, 0.3, seg_len)
		mi.mesh = bm
		mi.material_override = road_mat.duplicate()
		mi.position = Vector3(0, cy, cz)
		# pitch: tangent of circle
		mi.rotation.x = -mid_angle
		add_child(mi)

	# Simple collision — two boxes for entry/exit, loop body approximated
	for side in [-1, 1]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(6.0, 0.3, 3.5)
		cs.shape = bs
		cs.position = Vector3(0, -0.15, side * (radius - 0.5))
		sb.add_child(cs)
		add_child(sb)
