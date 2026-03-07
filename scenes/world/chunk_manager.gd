extends Node3D
class_name ChunkManager

@export var tracked_node: Node3D
@export var chunk_size: float = 64.0
@export var subdivisions: int = 32
@export var view_distance: int = 3
@export var height_scale: float = 0.5
@export var noise_frequency: float = 0.015

var _noise: FastNoiseLite
var _loaded_chunks: Dictionary = {}
var _last_chunk_coord: Vector2i = Vector2i(99999, 99999)
var _material: StandardMaterial3D


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 4
	_noise.seed = randi()

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.35, 0.55, 0.25)

	_update_chunks()


func _get_chunk_coord(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.z / chunk_size)
	)


func _physics_process(_delta: float) -> void:
	if not tracked_node:
		return
	var current_coord := _get_chunk_coord(tracked_node.global_position)
	if current_coord != _last_chunk_coord:
		_last_chunk_coord = current_coord
		_update_chunks()


func _update_chunks() -> void:
	var needed: Dictionary = {}
	for x in range(_last_chunk_coord.x - view_distance, _last_chunk_coord.x + view_distance + 1):
		for z in range(_last_chunk_coord.y - view_distance, _last_chunk_coord.y + view_distance + 1):
			needed[Vector2i(x, z)] = true

	for coord: Vector2i in _loaded_chunks.keys():
		if not needed.has(coord):
			_loaded_chunks[coord].queue_free()
			_loaded_chunks.erase(coord)

	for coord: Vector2i in needed.keys():
		if not _loaded_chunks.has(coord):
			_loaded_chunks[coord] = _create_chunk(coord)


func _get_height(world_x: float, world_z: float) -> float:
	return _noise.get_noise_2d(world_x, world_z) * height_scale


func _create_chunk(coord: Vector2i) -> StaticBody3D:
	var verts_per_side := subdivisions + 1
	var step := chunk_size / subdivisions
	var origin_x := coord.x * chunk_size
	var origin_z := coord.y * chunk_size

	# Sample heights
	var heights: Array[float] = []
	heights.resize(verts_per_side * verts_per_side)
	for z in verts_per_side:
		for x in verts_per_side:
			heights[z * verts_per_side + x] = _get_height(origin_x + x * step, origin_z + z * step)

	# Build visual mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in subdivisions:
		for x in subdivisions:
			var i00 := z * verts_per_side + x
			var i10 := i00 + 1
			var i01 := i00 + verts_per_side
			var i11 := i01 + 1

			var v00 := Vector3(origin_x + x * step,       heights[i00], origin_z + z * step)
			var v10 := Vector3(origin_x + (x + 1) * step, heights[i10], origin_z + z * step)
			var v01 := Vector3(origin_x + x * step,       heights[i01], origin_z + (z + 1) * step)
			var v11 := Vector3(origin_x + (x + 1) * step, heights[i11], origin_z + (z + 1) * step)

			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v01)
			st.add_vertex(v10); st.add_vertex(v11); st.add_vertex(v01)

	st.generate_normals()
	st.set_material(_material)
	var mesh := st.commit()

	# Build collision (HeightMapShape3D is centered; scale x/z per step, position at chunk center)
	var hm := HeightMapShape3D.new()
	hm.map_width = verts_per_side
	hm.map_depth = verts_per_side
	hm.map_data = PackedFloat32Array(heights)

	var body := StaticBody3D.new()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.position = Vector3(origin_x + chunk_size * 0.5, 0.0, origin_z + chunk_size * 0.5)
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)

	add_child(body)
	return body
