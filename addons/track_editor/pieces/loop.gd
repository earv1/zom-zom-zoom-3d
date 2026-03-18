## Full vertical loop — helical so exit is offset by one cell (8 m in Z).
## Entry: east face  (x=+4, y=0, z=0)
## Exit:  west face  (x=-4, y=0, z=+8)  →  place next piece one cell over in Z.
@tool
extends Node3D

const Z_SHIFT := 8.0    # one cell offset between entry and exit
const STEPS   := 28     # arc segments (more = smoother)
const SLAB_T  := 0.3

var radius     := 18.0
var road_width := 6.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	radius     = params.get("radius",     radius)
	road_width = params.get("road_width", road_width)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, radius = radius}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width",  min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "radius",     label = "Radius", min = 6.0, max = 42.0, step = 6.0, default = 18.0},
	]

func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.35, 0.18)

	var sb := StaticBody3D.new()
	add_child(sb)

	# ── flat approach  x = +4 → 0,  z = 0 ───────────────────────────────────
	_add_slab(sb, Vector3(4.0, SLAB_T, road_width),
		Vector3(2.0, -SLAB_T * 0.5, 0.0), _flat_basis(), mat)

	# ── helix loop ────────────────────────────────────────────────────────────
	for i in range(STEPS):
		var t0   := float(i)       / STEPS
		var t1   := float(i + 1)   / STEPS
		var tmid := (t0 + t1) * 0.5

		var a0   := TAU * t0
		var a1   := TAU * t1
		var amid := TAU * tmid

		var p0   := _arc(a0)
		var p1   := _arc(a1)
		var pmid := _arc(amid)
		var seg_len := (p1 - p0).length() + 0.02

		# inward normal — same as a pure circle (helix curvature points to axis)
		var inward := Vector3(sin(amid), cos(amid), 0.0)
		# slab centre sits just outward of the road surface by half thickness
		var centre := pmid - inward * (SLAB_T * 0.5)

		_add_slab(sb, Vector3(seg_len, SLAB_T, road_width),
			centre, _helix_basis(amid), mat)

	# ── flat exit  x = 0 → -4,  z = +8 ──────────────────────────────────────
	_add_slab(sb, Vector3(4.0, SLAB_T, road_width),
		Vector3(-2.0, -SLAB_T * 0.5, Z_SHIFT), _flat_basis(), mat)

# ── arc helpers ───────────────────────────────────────────────────────────────

## Helix arc position.  At a=0: (0,0,0) heading west. At a=TAU: (0,0,Z_SHIFT).
func _arc(a: float) -> Vector3:
	return Vector3(
		-radius * sin(a),
		 radius * (1.0 - cos(a)),
		 Z_SHIFT * a / TAU
	)

## Basis for a helix slab at arc angle `a`.
##   local X (seg_len) → helix tangent
##   local Y (SLAB_T)  → inward normal
##   local Z (road_width) → road-width direction (perpendicular to both)
func _helix_basis(a: float) -> Basis:
	var tangent := Vector3(-radius * cos(a), radius * sin(a), Z_SHIFT / TAU).normalized()
	var inward  := Vector3(sin(a), cos(a), 0.0)
	var width   := tangent.cross(inward).normalized()
	return Basis(tangent, inward, width)

## Flat-section basis: length along -X, thickness along +Y, width along +Z.
func _flat_basis() -> Basis:
	return Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))

# ── slab factory ──────────────────────────────────────────────────────────────

func _add_slab(sb: StaticBody3D, size: Vector3, pos: Vector3,
		basis: Basis, mat: StandardMaterial3D) -> void:
	var xform := Transform3D(basis, pos)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat.duplicate()
	mi.transform = xform
	add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xform
	sb.add_child(cs)
