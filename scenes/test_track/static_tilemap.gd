extends StaticBody3D

## Static tiled ground — same visual as ChunkManager but no chunk loading.
## Generates a single large tiled mesh on _ready().

@export var ground_size: float = 512.0
@export var tile_size: float = 1.6

const TILE_COLS := 6
const TILE_ROWS := 1
const TILE_WEIGHTS: Array[float] = [0.70, 0.01, 0.01, 0.18, 0.05, 0.05]

var _noise_seed: int = 0


func _ready() -> void:
	_noise_seed = 42  # fixed seed for determinism
	var texture: Texture2D = load("res://assets/textures/tiles_x2.png")

	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = texture

	# Generate tiles in chunks to avoid huge single mesh
	var chunk_size := 64.0
	var half := ground_size * 0.5
	var cx_start := floori(-half / chunk_size)
	var cx_end := ceili(half / chunk_size)
	var tiles_per_chunk := int(chunk_size / tile_size)

	for cx in range(cx_start, cx_end):
		for cz in range(cx_start, cx_end):
			var mi := _build_chunk_mesh(cx, cz, chunk_size, tiles_per_chunk, mat)
			add_child(mi)

	# Single large collision box
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size, 0.2, ground_size)
	cs.shape = box
	cs.position = Vector3(0, -0.1, 0)
	add_child(cs)


func _build_chunk_mesh(cx: int, cz: int, chunk_size: float, tiles_per_chunk: int, mat: StandardMaterial3D) -> MeshInstance3D:
	var origin_x := cx * chunk_size
	var origin_z := cz * chunk_size
	var u_step := 1.0 / TILE_COLS

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tz in tiles_per_chunk:
		for tx in tiles_per_chunk:
			var tile_wx := cx * tiles_per_chunk + tx
			var tile_wz := cz * tiles_per_chunk + tz

			var tile_idx := _pick_tile(tile_wx, tile_wz)
			var u0 := (tile_idx % TILE_COLS) * u_step
			var u1 := u0 + u_step

			var x0 := origin_x + tx * tile_size
			var x1 := x0 + tile_size
			var z0 := origin_z + tz * tile_size
			var z1 := z0 + tile_size

			var v00 := Vector3(x0, 0.0, z0)
			var v10 := Vector3(x1, 0.0, z0)
			var v01 := Vector3(x0, 0.0, z1)
			var v11 := Vector3(x1, 0.0, z1)

			var normal := Vector3.UP
			st.set_normal(normal); st.set_uv(Vector2(u0, 0)); st.add_vertex(v00)
			st.set_normal(normal); st.set_uv(Vector2(u1, 0)); st.add_vertex(v10)
			st.set_normal(normal); st.set_uv(Vector2(u0, 1)); st.add_vertex(v01)
			st.set_normal(normal); st.set_uv(Vector2(u1, 0)); st.add_vertex(v10)
			st.set_normal(normal); st.set_uv(Vector2(u1, 1)); st.add_vertex(v11)
			st.set_normal(normal); st.set_uv(Vector2(u0, 1)); st.add_vertex(v01)

	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


func _pick_tile(tile_world_x: int, tile_world_z: int) -> int:
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
