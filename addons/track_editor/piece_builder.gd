## Static helpers for building track piece meshes procedurally.
## Each piece is 8x4x8m (CELL). Origin at cell centre, floor at y=0.
@tool
extends Node3D

const CELL_W := 8.0
const CELL_H := 4.0
const CELL_D := 8.0
const ROAD_W := 6.0   # driveable width inside the cell
const WALL_H := 0.4   # kerb/guard-rail height
const THICK  := 0.3   # slab thickness

## Build a flat road surface MeshInstance3D + StaticBody3D
static func make_flat_slab(parent: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO,
		color: Color = Color(0.25, 0.25, 0.25)) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = offset
	parent.add_child(sb)
