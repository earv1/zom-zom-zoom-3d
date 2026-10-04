extends SceneTree
## Builds park.tscn: the Hadeda Park, a giant car skatepark with a raceable
## ring, made entirely of Track Editor pieces and saved the way the editor
## saves (a TrackRoot of piece instances + connectors), so it stays editable
## in the track editor.
##
##   godot --headless --path . --script res://scenes/levels/hadeda_park/generate_park.gd
##
## Layout (metres, -Z = north, cells are 8 m centred on 8k+4):
##   One glass dome over everything (Rocket League style: drive up its walls),
##   sized to the park, with exits to the desert at the four compass points.
##   Plaza: a 240 m road-surface floor with a horseshoe bowl open to the east,
##   a north drop-in and the boss summon panel in the middle, a spine, two
##   funboxes, and a launch lane to a kicker that
##   fires you over the ring road onto the Sky Pillar (Sky Workshop).
##   North of the plaza: decks with a gap jump and a 10 m deck.
##   South of the plaza: a Roadside Diner.
##   Ring road (24 m wide, raceable laps, ~2 km): big sweepers, a loop on the
##   north and south straights, pit lanes through a Roadside Diner (east) and
##   the Petrol Station (south), and a spur into the plaza.
##
## The ring is laid with a turtle that walks cell-face anchors: each piece's
## entry anchor must land on the current anchor (checked), sweeping connectors
## join pieces through constant-radius arcs (radius 8k+4 keeps turns on grid).
## Alternate-route nodes (pit lanes, spurs) carry metadata "route".

const OUT := "res://scenes/levels/hadeda_park/park.tscn"
const PIECES := {
	"straight": preload("res://addons/track_editor/pieces/straight.tscn"),
	"loop": preload("res://addons/track_editor/pieces/loop.tscn"),
	"connector": preload("res://addons/track_editor/pieces/connector.tscn"),
	"floor": preload("res://addons/track_editor/pieces/park/floor.tscn"),
	"quarter_pipe": preload("res://addons/track_editor/pieces/park/quarter_pipe.tscn"),
	"bowl_corner": preload("res://addons/track_editor/pieces/park/bowl_corner.tscn"),
	"spine": preload("res://addons/track_editor/pieces/park/spine.tscn"),
	"kicker": preload("res://addons/track_editor/pieces/park/kicker.tscn"),
	"funbox": preload("res://addons/track_editor/pieces/park/funbox.tscn"),
	"deck": preload("res://addons/track_editor/pieces/park/deck.tscn"),
	"slope": preload("res://addons/track_editor/pieces/park/slope.tscn"),
	"sky_pillar": preload("res://addons/track_editor/pieces/park/sky_pillar.tscn"),
	"dome": preload("res://addons/track_editor/pieces/park/dome.tscn"),
	"summon_panel": preload("res://addons/track_editor/pieces/park/summon_panel.tscn"),
	"diner": preload("res://addons/track_editor/pieces/park/store_diner.tscn"),
	"petrol": preload("res://addons/track_editor/pieces/park/store_petrol.tscn"),
	"sky_workshop": preload("res://addons/track_editor/pieces/park/store_sky_workshop.tscn"),
}
const WIDTH := 24.0
const SIDE_COLOR := "red"
const RIGHT := 1
const LEFT := -1
const ALT_LIFT := 0.03
const DOME_TRANSITION := 24.0             ## the dome wall's quarter-pipe curve
const DOME_MARGIN := 24.0                  ## clearance between the outermost road and that curve
const DESERT_FLOOR_Y := -0.08                ## the desert sand sits a small lip below road level
const LAUNCH_LIP_X := -108.0               ## kicker lip on the plaza's west edge
## Sky pillar centre and height. Calibrated with the real car by
## test_hadeda_park_jump: a controlled launch off the 35-degree kicker lands on
## the deck; flat-out overshoots into the desert. Hitting it means managing speed.
const PILLAR := Vector3(-282, 0, 0)
const PILLAR_HEIGHT := 28.0

var scene_root: Node3D
var track: Node3D
var pos := Vector3.ZERO                    # turtle anchor: centre of a cell face
var heading := Vector3.FORWARD             # turtle travel direction (-Z = north)
var first_piece: Node3D
var pending := {}                          # connector waiting for the next piece
var route := ""                            # "" = ring road, else the alternate route
var errors := 0
var _split := {}
var _merge_for := {}
var _lift_next_start := false


func _init() -> void:
	scene_root = Node3D.new()
	scene_root.name = "HadedaPark"
	track = Node3D.new()
	track.name = "TrackRoot"
	scene_root.add_child(track)
	track.owner = scene_root

	_build_ring()
	_build_plaza()
	_build_decks()
	_build_sky_pillar()
	place("diner", Vector3(0, 0, 152), 0.0)            # south of the plaza
	_build_dome()                                      # last: sized to cover everything above

	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("park: %d nodes, %d alignment errors, save %s -> %s" % [
		track.get_child_count(), errors, error_string(err), OUT])
	scene_root.free()
	quit(1 if errors or err != OK else 0)


# ── layout ────────────────────────────────────────────────────────────────────

func _build_ring() -> void:
	pos = Vector3(-204, 0, 184)
	heading = Vector3.FORWARD
	straight(38)                         # west straight (start / finish)
	sweep(124, RIGHT)                    # NW sweeper
	straight(4)
	loop()                               # north loop
	straight(16)
	sweep(124, RIGHT)                    # NE sweeper
	straight(6)
	var diner_split := fork()            # east pit lane through the diner
	straight(7)
	var east_spur := fork()              # road into the dome's east exit
	straight(11)
	merge_next(diner_split)
	straight(6)
	sweep(124, RIGHT)                    # SE sweeper
	straight(4)
	loop()                               # south loop
	straight(4)
	var petrol_split := fork()           # south pit lane through the petrol station
	straight(18)
	merge_next(petrol_split)
	straight(2)
	close()                              # SW corner back onto the start straight

	for split in [[diner_split, "diner_pit_lane", "diner"], [petrol_split, "petrol_pit_lane", "petrol"]]:
		branch(split[0], split[1], func() -> void:
			sweep(28, LEFT)
			straight(2)
			sweep(28, RIGHT)
			store(split[2])
			straight(2)
			sweep(28, RIGHT)
			straight(2)
			join(28, LEFT))
	branch(east_spur, "east_spur", func() -> void:     # dead-ends inside the dome
		sweep(28, RIGHT)
		straight(10))


func _build_plaza() -> void:
	for x in [-80.0, 0.0, 80.0]:                        # 240 m road-style floor
		for z in [-80.0, 0.0, 80.0]:
			place("floor", Vector3(x, 0, z), 0.0, {width_cells = 10, depth_cells = 10})
	var qp := {radius = 8.0, height = 10.0, width_cells = 8, deck = 4.0}
	place("quarter_pipe", Vector3(0, 0, -36), 0.0, qp)         # bowl: north wall
	place("quarter_pipe", Vector3(0, 0, 36), 180.0, qp)        # south wall
	place("quarter_pipe", Vector3(-36, 0, 0), 90.0, qp)        # west wall (east side open)
	var corner := {radius = 8.0, height = 10.0, deck = 6.0}
	place("bowl_corner", Vector3(-36, 0, -36), 0.0, corner)
	place("bowl_corner", Vector3(-36, 0, 36), 90.0, corner)
	place("slope", Vector3(0, 0, -56), 180.0, {length = 24.0, height = 10.0, width_cells = 3})  # drop-in
	place("summon_panel", Vector3(0, 0, 0), 0.0, {size = 16.0})  # boss summon, in the bowl
	place("spine", Vector3(72, 0, 0), 90.0, {radius = 4.0, width_cells = 6})
	place("funbox", Vector3(64, 0, -64), 0.0, {top = 16.0, height = 3.0, slope = 10.0})
	place("funbox", Vector3(64, 0, 64), 0.0, {top = 16.0, height = 3.0, slope = 10.0})
	# launch lane along z = 0 off the plaza's west edge, over the ring road to the sky pillar
	place("kicker", Vector3(LAUNCH_LIP_X + 6.0, 0, 0), 90.0, {length = 12.0, lip_angle = 35.0, width_cells = 2})


func _build_decks() -> void:                            # outside the dome's north exit
	place("slope", Vector3(0, 0, -140), 0.0, {length = 24.0, height = 4.0, width_cells = 4})
	place("deck", Vector3(0, 0, -168), 0.0, {width_cells = 6, depth_cells = 4, height = 4.0})
	place("kicker", Vector3(18, 4, -168), -90.0, {length = 12.0, lip_angle = 25.0, width_cells = 3})  # gap jump east
	place("deck", Vector3(80, 0, -168), 0.0, {width_cells = 4, depth_cells = 4, height = 4.0})
	place("slope", Vector3(80, 0, -140), 0.0, {length = 24.0, height = 4.0, width_cells = 4})
	place("slope", Vector3(0, 4, -188), 0.0, {length = 8.0, height = 6.0, width_cells = 6})
	place("deck", Vector3(0, 0, -208), 0.0, {width_cells = 6, depth_cells = 4, height = 10.0})


## One glass dome over the whole park, sized from every piece's footprint (plus
## the road half-width and the dome's wall transition) so it always clears it.
func _build_dome() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var points: Array[Vector2] = []
	for node in track.get_children():
		var ps: Array[Vector3] = [node.position]
		if node.get("end_pos") != null:
			ps.append(node.get("end_pos"))
		for p in ps:
			var flat := Vector2(p.x, p.z)
			points.append(flat)
			lo = lo.min(flat)
			hi = hi.max(flat)
	var centre := (lo + hi) * 0.5
	var reach := 0.0
	for p in points:
		reach = maxf(reach, p.distance_to(centre))
	var radius := snappedf(reach + WIDTH + DOME_MARGIN + DOME_TRANSITION, 8.0)
	place("dome", Vector3(centre.x, DESERT_FLOOR_Y, centre.y), 0.0, {radius = radius, height = radius * 0.35,
		transition = DOME_TRANSITION, exits = 4, exit_width = 32.0, exit_height = 16.0})
	print("dome: centre %s radius %.0f" % [centre, radius])


func _build_sky_pillar() -> void:
	place("sky_pillar", PILLAR, 0.0, {height = PILLAR_HEIGHT, top = 28.0})
	place("sky_workshop", PILLAR + Vector3.UP * PILLAR_HEIGHT, 90.0)


# ── free placement ────────────────────────────────────────────────────────────

func place(type: String, at: Vector3, yaw_deg: float, params: Dictionary = {}) -> Node3D:
	var piece: Node3D = PIECES[type].instantiate()
	piece.position = at
	piece.basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	piece.name = "%s_%d_%d_%d" % [type, roundi(at.x), roundi(at.y), roundi(at.z)]
	piece.set("side_color_name", SIDE_COLOR)
	for key in params:
		piece.set(key, params[key])
	track.add_child(piece)
	piece.owner = scene_root
	return piece


# ── turtle moves ──────────────────────────────────────────────────────────────

func straight(count: int) -> void:
	for i in count:
		_advance_to_exit(_place("straight", Vector3.FORWARD))


## Loops are sized for the 24 m road: the exit shifts sideways further than the
## road is wide, so the ribbon never runs over itself.
func loop() -> void:
	_advance_to_exit(_place("loop", Vector3.LEFT, {radius = 26.0, exit_offset = 32.0}))


## Inline drive-through store (16 m long) on the current route.
func store(kind: String) -> void:
	_advance_to_exit(_place(kind, Vector3.FORWARD))


## 90-degree sweeping arc to the given side, optionally changing height.
func sweep(radius: float, side: int, rise: float = 0.0) -> void:
	assert(posmod(int(radius), 8) == 4, "sweep radius must be 8k+4 to stay on the grid")
	var side_dir := heading.cross(Vector3.UP) * side
	_open_connector()
	pos += heading * radius + side_dir * radius + Vector3.UP * rise
	heading = side_dir


## Final sweeper back onto the first piece's entry anchor.
func close() -> void:
	var target := _entry_anchor(first_piece, first_piece.position - first_piece.basis.z * -4.0)
	var to_target: Vector3 = target.position - pos
	var side_dir := heading.cross(Vector3.UP)
	var radius := to_target.dot(heading)
	if not is_equal_approx(absf(to_target.dot(side_dir)), radius):
		push_error("closing turn is not a clean arc: %s" % to_target)
		errors += 1
	_open_connector()
	_add_connector(target)


# ── alternate routes ──────────────────────────────────────────────────────────

func fork() -> Dictionary:
	return {"pos": pos, "heading": heading}


## The next piece's entry becomes where `split`'s alternate route rejoins.
func merge_next(split: Dictionary) -> void:
	_merge_for = split


## Builds an alternate route from `split`; it must start with a sweep and
## either end with join() (pit lane) or simply stop (spur onto the plaza).
func branch(split: Dictionary, route_name: String, build: Callable) -> void:
	var saved := {"pos": pos, "heading": heading}
	pos = split.pos
	heading = split.heading
	route = route_name
	_split = split
	_lift_next_start = true
	build.call()
	route = ""
	pos = saved.pos
	heading = saved.heading


## Final arc of an alternate route into its merge point (checked to be clean).
func join(radius: float, side: int) -> void:
	var merge: Dictionary = _split.merge
	var side_dir := heading.cross(Vector3.UP) * side
	var expected := pos + heading * radius + side_dir * radius
	if expected.distance_to(merge.position) > 0.01:
		push_error("%s does not rejoin cleanly: arc ends at %s, merge is at %s" % [route, expected, merge.position])
		errors += 1
	_open_connector()
	_add_connector(merge, ALT_LIFT)
	pos = expected
	heading = side_dir


# ── turtle placement ──────────────────────────────────────────────────────────

func _place(type: String, local_travel: Vector3, params: Dictionary = {}) -> Node3D:
	var piece: Node3D = PIECES[type].instantiate()
	piece.basis = _yaw_basis(local_travel, heading)
	var entry_local := _local_entry(piece)
	piece.position = pos - piece.basis * entry_local
	piece.name = "%s_%d_%d_%d" % [type, roundi(piece.position.x), roundi(piece.position.y), roundi(piece.position.z)]
	piece.set("road_width", WIDTH)
	piece.set("side_color_name", SIDE_COLOR)
	for key in params:
		piece.set(key, params[key])
	var entry := _entry_anchor(piece, pos)
	if entry.position.distance_to(pos) > 0.01:
		push_error("%s entry %s does not meet anchor %s" % [piece.name, entry.position, pos])
		errors += 1
	if not pending.is_empty():
		_add_connector(entry)
	if not _merge_for.is_empty():
		_merge_for["merge"] = entry
		_merge_for = {}
	if route != "":
		piece.set_meta("route", route)
	track.add_child(piece)
	piece.owner = scene_root
	if first_piece == null:
		first_piece = piece
	return piece


## Local position of the anchor a piece is entered through (the one whose
## out_dir points back against the travel direction).
func _local_entry(piece: Node3D) -> Vector3:
	var travel_local := piece.basis.inverse() * heading
	for a in piece.get_connection_anchors():
		if (a.out_dir as Vector3).dot(travel_local) < -0.9:
			return a.position
	return Vector3(0, 0, 4)


func _advance_to_exit(piece: Node3D) -> void:
	var anchors := _anchors(piece)
	var exit: Dictionary = anchors[0] if anchors[0].position.distance_to(pos) > anchors[1].position.distance_to(pos) else anchors[1]
	pos = exit.position
	var dir: Vector3 = exit.out_dir
	heading = Vector3(dir.x, 0.0, dir.z).normalized()


func _open_connector() -> void:
	var lift := ALT_LIFT if _lift_next_start else 0.0
	_lift_next_start = false
	pending = {"start_pos": pos + Vector3.UP * lift, "start_dir": heading}


## Mirrors plugin.gd _create_connector, with sweep on.
func _add_connector(end_anchor: Dictionary, end_lift: float = 0.0) -> void:
	var conn: Node3D = PIECES["connector"].instantiate()
	var start: Vector3 = pending.start_pos
	conn.position = start
	conn.name = "connector_%d_%d_%d" % [roundi(start.x), roundi(start.y), roundi(start.z)]
	conn.set("start_pos", start)
	conn.set("start_dir", pending.start_dir)
	conn.set("end_pos", end_anchor.position + Vector3.UP * end_lift)
	conn.set("end_dir", -(end_anchor.out_dir as Vector3))
	conn.set("start_up", Vector3.UP)
	conn.set("end_up", Vector3.UP)
	conn.set("road_width", WIDTH)
	conn.set("start_width", WIDTH)
	conn.set("end_width", WIDTH)
	conn.set("side_color_name", SIDE_COLOR)
	conn.set("sweep", 1.0)
	if route != "":
		conn.set_meta("route", route)
	track.add_child(conn)
	conn.owner = scene_root
	pending = {}


func _anchors(piece: Node3D) -> Array:
	var out := []
	for a in piece.get_connection_anchors():
		out.append({
			"position": piece.transform * (a.position as Vector3),
			"out_dir": (piece.transform.basis * (a.out_dir as Vector3)).normalized(),
		})
	return out


func _entry_anchor(piece: Node3D, near: Vector3) -> Dictionary:
	var anchors := _anchors(piece)
	anchors.sort_custom(func(a, b): return a.position.distance_to(near) < b.position.distance_to(near))
	return anchors[0]


## Yaw (in 90-degree steps) that turns the piece's local travel direction into `world_dir`.
func _yaw_basis(local_travel: Vector3, world_dir: Vector3) -> Basis:
	for step in 4:
		var b := Basis(Vector3.UP, step * PI * 0.5)
		if (b * local_travel).distance_to(world_dir) < 0.01:
			return b
	push_error("no yaw maps %s to %s" % [local_travel, world_dir])
	errors += 1
	return Basis.IDENTITY
