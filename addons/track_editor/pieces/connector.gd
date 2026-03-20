## Bezier connector between two track pieces.
## start_pos / end_pos are world-space (TrackRoot assumed at origin).
## The node's own position is set to start_pos; all geometry is local to that.
@tool
extends Node3D

const STEPS  := 24
const SLAB_T := 0.3

@export_storage var start_pos  := Vector3.ZERO
@export_storage var start_dir  := Vector3(0, 0, 1)
@export_storage var end_pos    := Vector3(8, 0, 0)
@export_storage var end_dir    := Vector3(1, 0, 0)
@export_storage var road_width := 6.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
	]

func _build() -> void:
	var chord := (end_pos - start_pos).length()
	if chord < 0.01:
		return

	var tension := chord / 3.0
	var p0 := start_pos
	var p1 := start_pos + start_dir * tension
	var p2 := end_pos   - end_dir   * tension
	var p3 := end_pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.22)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var ta   := float(i)       / STEPS
		var tb   := float(i + 1)   / STEPS
		var tmid := (ta + tb) * 0.5

		# World-space bezier points → subtract start_pos for local space
		var wa := _bezier(p0, p1, p2, p3, ta)   - start_pos
		var wb := _bezier(p0, p1, p2, p3, tb)   - start_pos
		var wm := _bezier(p0, p1, p2, p3, tmid) - start_pos

		var seg     := wb - wa
		var seg_len := seg.length() + 0.02
		var fwd     := seg.normalized()

		# Perpendicular to fwd in the horizontal plane
		var right := fwd.cross(Vector3.UP)
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()

		# Basis: X=along curve, Y=up (flat road), Z=road width
		var basis := Basis(fwd, Vector3.UP, right)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(seg_len, SLAB_T, road_width)
		mi.mesh = bm
		mi.material_override = mat.duplicate()
		mi.transform = Transform3D(basis, wm)
		add_child(mi)

		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(seg_len, SLAB_T, road_width)
		cs.shape = bs
		cs.transform = Transform3D(basis, wm)
		sb.add_child(cs)

func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var mt := 1.0 - t
	return mt*mt*mt*p0 + 3.0*mt*mt*t*p1 + 3.0*mt*t*t*p2 + t*t*t*p3
