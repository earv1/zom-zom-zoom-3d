## Ramp: rises one full cell height (4m) over 8m.
## Entry: south face (z=+4, y=0). Exit: north face (z=-4, y=+4).
@tool
extends Node3D

const STEPS  := 6
const ROAD_W := 6.0
const SLAB_T := 0.3
const RISE   := 4.0   # total height gain
const RUN    := 8.0   # total horizontal length

func _ready() -> void:
	_build()

func _build() -> void:
	var pitch := atan2(RISE, RUN)   # ~26.6°

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.22, 0.22)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.8, 0.2, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var tmid := (float(i) + 0.5) / STEPS
		var z_world := 4.0 - tmid * RUN          # +4 → -4
		var y_world := tmid * RISE                # 0  →  4
		var seg_len := RUN / STEPS + 0.05

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ROAD_W, SLAB_T, seg_len)
		mi.mesh = bm
		mi.material_override = road_mat.duplicate()
		mi.position = Vector3(0, y_world, z_world)
		mi.rotation.x = pitch
		add_child(mi)

		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(ROAD_W, SLAB_T, seg_len)
		cs.shape = bs
		cs.position = Vector3(0, y_world, z_world)
		cs.rotation.x = pitch
		sb.add_child(cs)

	# Guard rails
	for side in [-1, 1]:
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.15, 0.5, sqrt(RUN * RUN + RISE * RISE) + 0.1)
		r.mesh = rm
		r.material_override = rail_mat.duplicate()
		r.position = Vector3(side * (ROAD_W * 0.5 + 0.1), RISE * 0.5, 0)
		r.rotation.x = pitch
		add_child(r)
