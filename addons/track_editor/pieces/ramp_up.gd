## Ramp: rises over one cell run (8 m). Pitch is configurable.
## Entry: south face (z=+4, y=0). Exit: north face (z=-4, y=+rise).
@tool
extends Node3D

const STEPS  := 6
const SLAB_T := 0.3
const RUN    := 8.0   # total horizontal length (fixed to cell depth)

@export_storage var road_width := 6.0
@export_storage var pitch_deg  := 30.0   # rise = RUN * tan(pitch)

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	pitch_deg  = params.get("pitch_deg",  pitch_deg)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, pitch_deg = pitch_deg}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width",  min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "pitch_deg",  label = "Pitch",  min = 6.0, max = 42.0, step = 6.0, default = 30.0},
	]

func _build() -> void:
	var pitch := deg_to_rad(pitch_deg)
	var rise  := RUN * tan(pitch)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.22, 0.22)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.8, 0.2, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var tmid    := (float(i) + 0.5) / STEPS
		var z_world := 4.0 - tmid * RUN          # +4 → -4
		var y_world := tmid * rise                # 0  → rise
		var seg_len := RUN / STEPS + 0.05

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(road_width, SLAB_T, seg_len)
		mi.mesh = bm
		mi.material_override = road_mat.duplicate()
		mi.position = Vector3(0, y_world, z_world)
		mi.rotation.x = pitch
		add_child(mi)

		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(road_width, SLAB_T, seg_len)
		cs.shape = bs
		cs.position = Vector3(0, y_world, z_world)
		cs.rotation.x = pitch
		sb.add_child(cs)

	# Guard rails
	for side in [-1, 1]:
		var r  := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.15, 0.5, sqrt(RUN * RUN + rise * rise) + 0.1)
		r.mesh = rm
		r.material_override = rail_mat.duplicate()
		r.position = Vector3(side * (road_width * 0.5 + 0.1), rise * 0.5, 0)
		r.rotation.x = pitch
		add_child(r)
