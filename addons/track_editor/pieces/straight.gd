@tool
extends Node3D

var _has_left  := false
var _has_right := false

func _ready() -> void:
	_build()

func set_neighbors(has_left: bool, has_right: bool) -> void:
	if _has_left == has_left and _has_right == has_right:
		return
	_has_left  = has_left
	_has_right = has_right
	for child in get_children():
		child.queue_free()
	_build()

func _build() -> void:
	# Road extends to full cell edge on any side that has a neighbour,
	# giving a seamless 2x-wide surface when two straights are placed side-by-side.
	var left_w  := 4.0 if _has_left  else 3.0  # half-widths from centre
	var right_w := 4.0 if _has_right else 3.0
	var road_w  := left_w + right_w
	var road_ox := (right_w - left_w) * 0.5    # x offset to keep road centred in its actual span

	# Road slab
	_add_mesh(Vector3(road_w, 0.3, 8.0), Vector3(road_ox, -0.15, 0), Color(0.22, 0.22, 0.22))

	# Kerbs — only on open sides
	if not _has_left:
		_add_mesh(Vector3(0.4, 0.4, 8.0), Vector3(road_ox - road_w * 0.5 - 0.2, -0.1, 0), Color(0.9, 0.9, 0.2))
	if not _has_right:
		_add_mesh(Vector3(0.4, 0.4, 8.0), Vector3(road_ox + road_w * 0.5 + 0.2, -0.1, 0), Color(0.9, 0.9, 0.2))

	# Collision
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(road_w + 0.4, 0.3, 8.0)
	cs.shape = bs
	cs.position = Vector3(road_ox, -0.15, 0)
	sb.add_child(cs)
	add_child(sb)

func _add_mesh(size: Vector3, offset: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = offset
	add_child(mi)
