extends Node3D
class_name ChunkManager

@export var tracked_node: Node3D
@export var chunk_size: float = 64.0
@export var tiles_per_chunk: int = 40         # 40x40 tiles per chunk → 1.6 unit tiles
@export var view_distance: int = 3

# Tile atlas: tiles_x2.png is 192x32 (6 tiles of 32x32 each, single row)
const TILE_COLS := 6
const TILE_ROWS := 1

# Weighted tile indices matching Rust: [0.70, 0.01, 0.01, 0.18, 0.05, 0.05]
const TILE_WEIGHTS: Array[float] = [0.70, 0.01, 0.01, 0.18, 0.05, 0.05]

var _texture: Texture2D
var _material: StandardMaterial3D
var _loaded_chunks: Dictionary = {}
var _last_chunk_coord: Vector2i = Vector2i(99999, 99999)
var _noise_seed: int = 0


func _ready() -> void:
	_noise_seed = randi()
	_texture = load("res://assets/textures/tiles_x2.png")

	_material = StandardMaterial3D.new()
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.albedo_texture = _texture

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


# Pick a weighted random tile index, seeded by tile world position for determinism.
func _pick_tile(tile_world_x: int, tile_world_z: int) -> int:
	# Deterministic hash from tile coordinates + seed
	var h := hash(Vector3i(tile_world_x, tile_world_z, _noise_seed))
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var r := rng.randf()
	var cumulative := 0.0
	for i in TILE_WEIGHTS.size():
		cumulative += TILE_WEIGHTS[i]
		if r < cumulative:
			return i
	return TILE_WEIGHTS.size() - 1


func _create_chunk(coord: Vector2i) -> StaticBody3D:
	var tile_size := chunk_size / tiles_per_chunk
	var origin_x := coord.x * chunk_size
	var origin_z := coord.y * chunk_size

	var u_step := 1.0 / TILE_COLS
	var v_step := 1.0 / TILE_ROWS

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tz in tiles_per_chunk:
		for tx in tiles_per_chunk:
			# Tile world indices (for deterministic seeding)
			var tile_wx := coord.x * tiles_per_chunk + tx
			var tile_wz := coord.y * tiles_per_chunk + tz

			var tile_idx := _pick_tile(tile_wx, tile_wz)
			var tile_col := tile_idx % TILE_COLS
			var tile_row := tile_idx / TILE_COLS

			var u0 := tile_col * u_step
			var u1 := u0 + u_step
			var v0 := tile_row * v_step
			var v1 := v0 + v_step

			var x0 := origin_x + tx * tile_size
			var x1 := x0 + tile_size
			var z0 := origin_z + tz * tile_size
			var z1 := z0 + tile_size

			# Two triangles per tile (flat, y=0)
			var v00 := Vector3(x0, 0.0, z0)
			var v10 := Vector3(x1, 0.0, z0)
			var v01 := Vector3(x0, 0.0, z1)
			var v11 := Vector3(x1, 0.0, z1)

			var normal := Vector3.UP

			st.set_normal(normal); st.set_uv(Vector2(u0, v0)); st.add_vertex(v00)
			st.set_normal(normal); st.set_uv(Vector2(u1, v0)); st.add_vertex(v10)
			st.set_normal(normal); st.set_uv(Vector2(u0, v1)); st.add_vertex(v01)

			st.set_normal(normal); st.set_uv(Vector2(u1, v0)); st.add_vertex(v10)
			st.set_normal(normal); st.set_uv(Vector2(u1, v1)); st.add_vertex(v11)
			st.set_normal(normal); st.set_uv(Vector2(u0, v1)); st.add_vertex(v01)

	st.set_material(_material)
	var mesh := st.commit()

	var body := StaticBody3D.new()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	# Flat collision: single BoxShape3D covering the whole chunk at ground level
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(chunk_size, 0.1, chunk_size)
	cs.shape = box
	cs.position = Vector3(origin_x + chunk_size * 0.5, -0.05, origin_z + chunk_size * 0.5)
	body.add_child(cs)

	add_child(body)
	return body
