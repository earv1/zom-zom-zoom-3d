class_name DesertLandscape
extends Node3D
## Desert backdrop for the circuit: a flat sand pan under the track rising into
## dunes, sandstone mesas in the middle distance and a mountain ring on the
## horizon, plus saguaro cacti, boulders and scrub kept clear of the road.
## The near terrain has collision (drive off-road anywhere); the far ring is
## backdrop only. Built procedurally in _ready from a fixed seed.

@export var track_root: Node3D                    ## decor is kept off the road
@export var play_center := Vector2(145.0, -50.0)  ## middle of the track (xz)
@export var play_half := Vector2(160.0, 135.0)    ## half extents of the track bounds
@export var flat_margin := 70.0                   ## flat sand beyond the track bounds
@export var rng_seed := 7

const NEAR_SIZE := 1400.0
const NEAR_CELLS := 200
const FAR_SIZE := 7000.0
const FAR_CELLS := 120
const ROAD_CLEARANCE := 15.0
const FLOOR_Y := -0.08         ## sand sits a small lip below the road surface (y = 0)...
const COLLISION_FLOOR_Y := -0.01   ## ...but only visually: its collision is near-flush with the road so
                                   ## wheels roll on instead of hitting an 8 cm step and hopping (and the
                                   ## road stays 1 cm higher, so it, not sand, is what a wheel on it reports)
## Sandstone mesas: offset from play_center (x, z), radius, height.
const MESAS := [
	[-520.0, -380.0, 90.0, 70.0], [610.0, -260.0, 120.0, 95.0], [-320.0, 560.0, 70.0, 55.0],
	[470.0, 520.0, 150.0, 120.0], [-780.0, 130.0, 110.0, 85.0], [120.0, -720.0, 100.0, 80.0],
	[930.0, 260.0, 180.0, 140.0], [-1050.0, -720.0, 220.0, 160.0],
]
const TERRAIN_SHADER := preload("res://scenes/levels/hadeda_park/desert_terrain.gdshader")

var _dunes := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_fit_to_dome()
	_rng.seed = rng_seed
	_dunes.seed = rng_seed
	_dunes.frequency = 0.0035
	_dunes.fractal_octaves = 3
	_detail.seed = rng_seed + 1
	_detail.frequency = 0.02
	_ridges.seed = rng_seed + 2
	_ridges.frequency = 0.0012
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 4

	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	_build_near_terrain(terrain_mat)
	_build_far_terrain(terrain_mat)
	_scatter_decor()


## If the track has a glass dome, the flat pan covers exactly its footprint.
func _fit_to_dome() -> void:
	if not is_instance_valid(track_root):
		return
	for piece in track_root.get_children():
		if String(piece.name).begins_with("dome") and piece.get("radius") != null:
			var r: float = piece.get("radius")
			play_center = Vector2(piece.global_position.x, piece.global_position.z)
			play_half = Vector2(r, r)
			return


## Terrain height in world space. Exactly FLOOR_Y across the flat pan under the track.
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z) - play_center
	var q := p.abs() - play_half - Vector2.ONE * flat_margin
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	var h := 0.0
	if d > 0.0:
		var dune := _dunes.get_noise_2d(x, z) * 0.5 + 0.5
		h = smoothstep(0.0, 260.0, d) * (5.0 + dune * 36.0)
	for m in MESAS:
		var dist := p.distance_to(Vector2(m[0], m[1]))
		var edge: float = m[2] * (1.0 + _detail.get_noise_2d(x, z) * 0.25)
		if dist < edge + 30.0:
			h = maxf(h, m[3] * smoothstep(edge + 26.0, edge, dist) + _detail.get_noise_2d(z, x) * 3.0)
	var far := smoothstep(1400.0, 2700.0, p.length())
	if far > 0.0:
		h += far * (60.0 + (_ridges.get_noise_2d(x, z) * 0.5 + 0.5) * 300.0)
	return h + FLOOR_Y


func _build_near_terrain(mat: Material) -> void:
	var n := NEAR_CELLS + 1
	var cell := NEAR_SIZE / NEAR_CELLS
	var origin := play_center - Vector2.ONE * NEAR_SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = height_at(origin.x + ix * cell, origin.y + iz * cell)

	var mi := MeshInstance3D.new()
	mi.name = "NearTerrain"
	mi.mesh = _grid_mesh(heights, n, cell, origin)
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "NearTerrainBody"
	body.add_to_group("sand")                 # RaycastCar cruises SAND_SPEED slower on sand
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var solid := heights.duplicate()
	for i in solid.size():
		solid[i] += COLLISION_FLOOR_Y - FLOOR_Y
	shape.map_data = solid
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(play_center.x, 0.0, play_center.y)
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	add_child(body)


func _build_far_terrain(mat: Material) -> void:
	var n := FAR_CELLS + 1
	var cell := FAR_SIZE / FAR_CELLS
	var origin := play_center - Vector2.ONE * FAR_SIZE * 0.5
	var near_half := NEAR_SIZE * 0.5 - cell
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			var x := origin.x + ix * cell
			var z := origin.y + iz * cell
			var h := height_at(x, z)
			if absf(x - play_center.x) < near_half and absf(z - play_center.y) < near_half:
				h -= 6.0                         # tuck under the detailed near terrain
			heights[iz * n + ix] = h
	var mi := MeshInstance3D.new()
	mi.name = "FarTerrain"
	mi.mesh = _grid_mesh(heights, n, cell, origin)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _grid_mesh(heights: PackedFloat32Array, n: int, cell: float, origin: Vector2) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for iz in n:
		for ix in n:
			var i := iz * n + ix
			verts[i] = Vector3(origin.x + ix * cell, heights[i], origin.y + iz * cell)
			var hl := heights[iz * n + maxi(ix - 1, 0)]
			var hr := heights[iz * n + mini(ix + 1, n - 1)]
			var hd := heights[maxi(iz - 1, 0) * n + ix]
			var hu := heights[mini(iz + 1, n - 1) * n + ix]
			normals[i] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ── decor ─────────────────────────────────────────────────────────────────────

func _scatter_decor() -> void:
	var road := _road_samples()
	var solid := StaticBody3D.new()
	solid.name = "DecorCollision"
	add_child(solid)
	var area := play_half + Vector2.ONE * (flat_margin + 260.0)

	var cacti: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var scrub: Array[Transform3D] = []
	for i in 2200:
		var x := play_center.x + _rng.randf_range(-area.x, area.x)
		var z := play_center.y + _rng.randf_range(-area.y, area.y)
		if _near_road(x, z, road):
			continue
		var h := height_at(x, z)
		if h > 45.0:                                   # keep off the mesa tops
			continue
		var pos := Vector3(x, h, z)
		var spin := Basis(Vector3.UP, _rng.randf() * TAU)
		var roll := _rng.randf()
		if roll < 0.12 and cacti.size() < 170:
			var s := _rng.randf_range(0.8, 1.5)
			cacti.append(Transform3D(spin.scaled(Vector3.ONE * s), pos))
			_add_solid(solid, CylinderShape3D.new(), 0.5 * s, 7.0 * s, pos)
		elif roll < 0.28 and rocks.size() < 240:
			var s := _rng.randf_range(0.6, 2.2) * (1.0 if _rng.randf() < 0.85 else 3.0)
			var squash := Vector3(_rng.randf_range(0.8, 1.4), _rng.randf_range(0.45, 0.9), _rng.randf_range(0.8, 1.4))
			rocks.append(Transform3D(spin.scaled(squash * s), pos + Vector3.DOWN * 0.2 * s))
			_add_solid(solid, SphereShape3D.new(), 0.9 * s, 0.0, pos)
		elif scrub.size() < 420:
			var s := _rng.randf_range(0.5, 1.3)
			scrub.append(Transform3D(spin.scaled(Vector3(s, s * 0.6, s)), pos))
	_multimesh("Cacti", _cactus_mesh(), cacti, Color(0.30, 0.42, 0.22))
	_multimesh("Rocks", _rock_mesh(), rocks, Color(0.60, 0.36, 0.24))
	_multimesh("Scrub", _scrub_mesh(), scrub, Color(0.52, 0.48, 0.28))


func _road_samples() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not is_instance_valid(track_root):
		return pts
	for child in track_root.get_children():
		var node := child as Node3D
		if node.has_method("_sample_path"):              # connector: walk its centreline
			var path: Dictionary = node.call("_sample_path", 24)
			for p in path.get("points", []):
				var w: Vector3 = node.global_transform * (p as Vector3)
				pts.append(Vector2(w.x, w.z))
		else:
			# sample the piece's whole footprint every few metres
			var box := AABB()
			var first := true
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				box = b if first else box.merge(b)
				first = false
			if first:
				pts.append(Vector2(node.global_position.x, node.global_position.z))
				continue
			var step := ROAD_CLEARANCE
			var x := box.position.x
			while x <= box.end.x + 0.1:
				var z := box.position.z
				while z <= box.end.z + 0.1:
					pts.append(Vector2(x, z))
					z += step
				x += step
	return pts


func _near_road(x: float, z: float, road: PackedVector2Array) -> bool:
	var p := Vector2(x, z)
	var off := (p - play_center).abs() - play_half
	if off.x > ROAD_CLEARANCE + 30.0 or off.y > ROAD_CLEARANCE + 30.0:
		return false                                   # well outside the track bounds
	for r in road:
		if p.distance_squared_to(r) < ROAD_CLEARANCE * ROAD_CLEARANCE:
			return true
	return false


func _add_solid(body: StaticBody3D, shape: Shape3D, radius: float, height: float, pos: Vector3) -> void:
	if shape is CylinderShape3D:
		(shape as CylinderShape3D).radius = radius
		(shape as CylinderShape3D).height = height
		pos += Vector3.UP * height * 0.5
	else:
		(shape as SphereShape3D).radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


func _multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mmi.material_override = mat
	add_child(mmi)


## Saguaro: a trunk with two upturned arms.
func _cactus_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.42
	trunk.bottom_radius = 0.5
	trunk.height = 7.0
	trunk.radial_segments = 8
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 3.5, 0)))
	for side in [-1.0, 1.0]:
		var stub := CylinderMesh.new()
		stub.top_radius = 0.3
		stub.bottom_radius = 0.3
		stub.height = 1.3
		stub.radial_segments = 6
		var up := 2.6 if side < 0 else 3.6
		st.append_from(stub, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(side * 0.9, up, 0)))
		var arm := CylinderMesh.new()
		arm.top_radius = 0.28
		arm.bottom_radius = 0.3
		arm.height = 2.4
		arm.radial_segments = 6
		st.append_from(arm, 0, Transform3D(Basis(), Vector3(side * 1.5, up + 1.1, 0)))
	st.generate_normals()
	return st.commit()


func _rock_mesh() -> Mesh:
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	return rock


func _scrub_mesh() -> Mesh:
	var bush := SphereMesh.new()
	bush.radial_segments = 6
	bush.rings = 3
	bush.radius = 0.9
	bush.height = 1.4
	return bush
