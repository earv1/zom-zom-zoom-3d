@tool
class_name ParkGeometry
extends RefCounted
## Geometry helpers for the skatepark pieces: extrude or revolve a 2D
## cross-section into a solid with matching trimesh collision, plus the shared
## park materials. Cross-sections are (z, y) points running along the riding
## surface; the solid is closed down to y = `base` underneath.

const CONCRETE_SHADER := preload("res://addons/track_editor/park_concrete.gdshader")

static var _concrete: ShaderMaterial
static var _coping: StandardMaterial3D


static func concrete() -> ShaderMaterial:
	if _concrete == null:
		_concrete = ShaderMaterial.new()
		_concrete.shader = CONCRETE_SHADER
	return _concrete


## Kerb-coloured edge for copings and lips, matching the road pieces' kerbs.
static func coping() -> StandardMaterial3D:
	if _coping == null:
		_coping = StandardMaterial3D.new()
		_coping.albedo_color = TrackTheme.side_color("red")
		_coping.roughness = 0.6
		_coping.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _coping


static func paint(color_name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = TrackTheme.side_color(color_name)
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Extrudes `surface` (z, y points, in riding order) across x in [-width/2, width/2]
## and closes it down to y = base. Adds the mesh and a trimesh collider to `parent`.
static func extrude(parent: Node3D, surface: PackedVector2Array, width: float, mat: Material,
		base: float = -0.3, xform := Transform3D.IDENTITY) -> MeshInstance3D:
	var outline := _ccw(_close_down(surface, base))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var n := outline.size()
	for i in n:                                # skin, one quad per outline edge
		var a := outline[i]
		var b := outline[(i + 1) % n]
		_quad(st, Vector3(-hw, a.y, a.x), Vector3(hw, a.y, a.x), Vector3(hw, b.y, b.x), Vector3(-hw, b.y, b.x))
	var tris := Geometry2D.triangulate_polygon(outline)
	for i in range(0, tris.size(), 3):         # end caps, facing -x and +x
		for side in [-1.0, 1.0]:
			var idx := [tris[i], tris[i + 1], tris[i + 2]]
			if side < 0.0:
				idx.reverse()
			for k in idx:
				var p := outline[k]
				st.add_vertex(Vector3(side * hw, p.y, p.x))
	return _finish(parent, st, mat, xform)


## Revolves `profile` (r, y points: distance from the Y axis, height) around the
## Y axis from angle 0 to `angle` (radians), closed down to y = base.
static func revolve(parent: Node3D, profile: PackedVector2Array, angle: float, steps: int, mat: Material,
		base: float = -0.3, xform := Transform3D.IDENTITY) -> MeshInstance3D:
	var outline := _ccw(_close_down(profile, base))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for s in steps:
		var a0 := angle * s / steps
		var a1 := angle * (s + 1) / steps
		for i in n:
			var p := outline[i]
			var q := outline[(i + 1) % n]
			_quad(st, _rev(p, a0), _rev(p, a1), _rev(q, a1), _rev(q, a0))
	var tris := Geometry2D.triangulate_polygon(outline)
	for i in range(0, tris.size(), 3):
		for end in [0.0, angle]:
			var idx := [tris[i], tris[i + 1], tris[i + 2]]
			if end == 0.0:
				idx.reverse()
			for k in idx:
				st.add_vertex(_rev(outline[k], end))
	return _finish(parent, st, mat, xform)


## Box with collision.
static func box(parent: Node3D, size: Vector3, center: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.position = center
	sb.add_child(cs)
	parent.add_child(sb)
	return mi


## Quarter-circle transition from the floor up to vertical: (z, y) points from
## (z_start, 0) curving up to (z_start - radius, radius), then straight up to `height`.
static func transition(z_start: float, radius: float, height: float, steps: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cz := z_start
	var cy := radius
	for i in steps + 1:
		var t := PI * 0.5 * i / steps            # 0 -> 90 degrees
		pts.append(Vector2(cz - sin(t) * radius, cy - cos(t) * radius))
	if height > radius + 0.01:
		pts.append(Vector2(z_start - radius, height))
	return pts


## Surface points plus the drop back down to `base`, without duplicating
## endpoints that already sit on the base.
static func _close_down(surface: PackedVector2Array, base: float) -> PackedVector2Array:
	var outline := PackedVector2Array(surface)
	var last := surface[surface.size() - 1]
	var first := surface[0]
	if not is_equal_approx(last.y, base):
		outline.append(Vector2(last.x, base))
	if not is_equal_approx(first.y, base):
		outline.append(Vector2(first.x, base))
	return outline


static func _rev(p: Vector2, a: float) -> Vector3:
	return Vector3(sin(a) * p.x, p.y, cos(a) * p.x)


## a -> b runs along +x on one outline point, d -> c on the next one. With the
## outline counter-clockwise in (z, y), this winding gives outward normals.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)


## Same outline, counter-clockwise in (z, y) (or (r, y) for revolves).
static func _ccw(outline: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		area += a.x * b.y - b.x * a.y
	return outline if area > 0.0 else _reversed(outline)


static func _reversed(p: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array()
	for i in range(p.size() - 1, -1, -1):
		r.append(p[i])
	return r


static func _finish(parent: Node3D, st: SurfaceTool, mat: Material, xform: Transform3D) -> MeshInstance3D:
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true            # winding isn't guaranteed; collide from both sides
	cs.shape = shape
	sb.transform = xform
	sb.add_child(cs)
	parent.add_child(sb)
	return mi
