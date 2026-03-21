class_name SkidMark
extends MeshInstance3D

## Builds a flat ribbon mesh from sampled positions.
## Call add_point() while drifting, finish() when done.
## Use SkidMark.warmup() at load time to pre-create the shared material.

const MAX_POINTS := 300
const HALF_WIDTH := 0.16  # meters — tire mark width
const FADE_TIME  := 8.0   # seconds after finish before free

var _points: PackedVector3Array = PackedVector3Array()
var _dirs: PackedVector3Array = PackedVector3Array()
var _finished := false
var _fade_timer := 0.0

static var _shared_mat: StandardMaterial3D


static func warmup() -> void:
	if _shared_mat:
		return
	_shared_mat = StandardMaterial3D.new()
	_shared_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shared_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_mat.albedo_color = Color(0.05, 0.05, 0.05, 0.7)
	_shared_mat.no_depth_test = false
	_shared_mat.render_priority = -1


func _ready() -> void:
	warmup()
	material_override = _shared_mat


func reset_strip() -> void:
	_points.clear()
	_dirs.clear()
	_finished = false
	_fade_timer = 0.0
	mesh = null


func _process(delta: float) -> void:
	if not _finished:
		return
	_fade_timer += delta
	if _fade_timer >= FADE_TIME:
		queue_free()


func add_point(pos: Vector3, forward: Vector3) -> void:
	if _finished:
		return

	# Snap to ground + tiny offset to avoid z-fighting
	pos.y = 0.02

	# Skip if too close to last point
	if _points.size() > 0 and pos.distance_squared_to(_points[_points.size() - 1]) < 0.04:
		return

	# Width direction: perpendicular to forward on the XZ plane
	var width_dir := Vector3(-forward.z, 0.0, forward.x).normalized()

	_points.append(pos)
	_dirs.append(width_dir)

	# Rebuild mesh
	if _points.size() >= 2:
		_rebuild()

	# Cap length
	if _points.size() >= MAX_POINTS:
		finish()


func finish() -> void:
	_finished = true


func _rebuild() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	for i in range(_points.size() - 1):
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[i + 1]
		var da: Vector3 = _dirs[i]
		var db: Vector3 = _dirs[i + 1]

		var al := a - da * HALF_WIDTH
		var ar := a + da * HALF_WIDTH
		var bl := b - db * HALF_WIDTH
		var br := b + db * HALF_WIDTH

		# Two triangles for the quad
		verts.append_array([al, bl, br, al, br, ar])
		for _j in 6:
			norms.append(Vector3.UP)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms

	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
