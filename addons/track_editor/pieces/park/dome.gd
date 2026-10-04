@tool
extends ParkPiece
## Glass arena dome (Rocket League style): a quarter-pipe transition from the
## floor into a curved glass shell you can drive up and over. Its surface is
## sticky track (RaycastCar adhesion), so cars hold on to walls and ceiling.
## `exits` openings sit at the bottom, evenly spaced from +Z (south). The dome
## is centred on the placed cell and has no floor: put floor pieces under it.

@export_storage var radius := 120.0
@export_storage var height := 55.0
@export_storage var transition := 14.0
@export_storage var exits := 4
@export_storage var exit_width := 24.0
@export_storage var exit_height := 16.0

const GLASS := preload("res://addons/track_editor/park_glass.gdshader")
const SEGMENTS := 64
const RINGS := 22


func get_param_defs() -> Array:
	return [
		{name = "radius", label = "Radius", min = 24.0, max = 800.0, step = 8.0, default = 120.0},
		{name = "height", label = "Height", min = 16.0, max = 300.0, step = 4.0, default = 55.0},
		{name = "transition", label = "Wall transition", min = 4.0, max = 30.0, step = 2.0, default = 14.0},
		{name = "exits", label = "Exits", min = 0.0, max = 8.0, step = 1.0, default = 4.0},
		{name = "exit_width", label = "Exit width", min = 8.0, max = 48.0, step = 4.0, default = 24.0},
		{name = "exit_height", label = "Exit height", min = 6.0, max = 40.0, step = 2.0, default = 16.0},
	]


func get_connection_anchors() -> Array:
	return []


## (r, y) points from the floor, up the transition, over the shell to the crown.
func _profile() -> PackedVector2Array:
	var t := minf(transition, height * 0.5)
	var pts := PackedVector2Array()
	for i in 7:
		var phi := PI * 0.5 * i / 6.0
		pts.append(Vector2(radius - t + t * sin(phi), t - t * cos(phi)))
	for i in range(1, RINGS + 1):
		var theta := PI * 0.5 * i / RINGS
		pts.append(Vector2(radius * cos(theta), t + (height - t) * sin(theta)))
	return pts


## Opens or closes the exits (boss arenas close them) by rebuilding the shell.
func set_exits(count: int) -> void:
	if count == exits:
		return
	exits = count
	_rebuild()


func _in_exit(angle: float, y: float) -> bool:
	if exits <= 0 or y > exit_height:
		return false
	var half := exit_width * 0.5 / radius
	for k in exits:
		var centre := TAU * k / exits
		if absf(angle_difference(angle, centre)) < half:
			return true
	return false


func _build() -> void:
	var prof := _profile()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in SEGMENTS:
		var a0 := TAU * s / SEGMENTS
		var a1 := TAU * (s + 1) / SEGMENTS
		for i in prof.size() - 1:
			var p := prof[i]
			var q := prof[i + 1]
			if _in_exit((a0 + a1) * 0.5, (p.y + q.y) * 0.5):
				continue
			var v := [_rev(p, a0), _rev(p, a1), _rev(q, a1), _rev(q, a0)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.add_vertex(v[k])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = GLASS
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var sb := StaticBody3D.new()
	sb.add_to_group("sticky_track")
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)


func _rev(p: Vector2, a: float) -> Vector3:
	return Vector3(sin(a) * p.x, p.y, cos(a) * p.x)
