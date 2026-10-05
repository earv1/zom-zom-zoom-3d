class_name TrackTurtle
extends RefCounted
## Lays Track Editor pieces from a script the way the editor would: a turtle
## walks cell-face anchors (each piece's entry must land on the current anchor,
## checked), sweeping connectors join pieces through constant-radius arcs, and
## free pieces can be placed anywhere. Shared by the park and skill generators.

const PIECES := {
	"jump": preload("res://addons/track_editor/pieces/jump.tscn"),
	"ramp_up": preload("res://addons/track_editor/pieces/ramp_up.tscn"),
	"bank": preload("res://addons/track_editor/pieces/bank.tscn"),
	"ceiling": preload("res://addons/track_editor/pieces/ceiling.tscn"),
	"pound_pad": preload("res://addons/track_editor/pieces/park/pound_pad.tscn"),
	"skill_gate": preload("res://addons/track_editor/pieces/park/skill_gate.tscn"),
	"hint_sign": preload("res://addons/track_editor/pieces/park/hint_sign.tscn"),
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

const RIGHT := 1
const LEFT := -1
const ALT_LIFT := 0.03

var width := 24.0
var side_color := "red"
var scene_root: Node3D
var track: Node3D
var pos := Vector3.ZERO                    # turtle anchor: centre of a cell face
var heading := Vector3.FORWARD             # turtle travel direction (-Z = north)
var first_piece: Node3D
var pending := {}                          # connector waiting for the next piece
var route := ""                            # "" = main road, else the alternate route
var errors := 0
var _split := {}
var _merge_for := {}
var _lift_next_start := false
## The driving line the turtle has laid (cell anchors, plus points round each
## sweep), in order. Generators save it as the track's "route" metadata.
var trail := PackedVector3Array()


func _init(root: Node3D, track_root: Node3D, road_width := 24.0, color := "red") -> void:
	scene_root = root
	track = track_root
	width = road_width
	side_color = color


# ── free placement ────────────────────────────────────────────────────────────

func place(type: String, at: Vector3, yaw_deg: float, params: Dictionary = {}) -> Node3D:
	var piece: Node3D = PIECES[type].instantiate()
	piece.position = at
	piece.basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	piece.name = "%s_%d_%d_%d" % [type, roundi(at.x), roundi(at.y), roundi(at.z)]
	piece.set("side_color_name", side_color)
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


## Jump lip (one cell): the road carries on at ground level right after the lip,
## so the car flies over the road ahead and lands on it.
func jump(lip_angle: float) -> Node3D:
	var piece := _place("jump", Vector3.FORWARD, {lip_angle = lip_angle})
	_advance_to_exit(piece)
	pos.y = piece.position.y
	return piece


## Half loop into an upside-down ceiling road. The turtle stops here: the
## ceiling's far end is upside down, so nothing connects after it.
func ceiling(params: Dictionary = {}) -> Node3D:
	var piece := _place("ceiling", Vector3.LEFT, params)
	trail.append(pos + heading * 30.0)                    # the driving line carries on into the half loop
	return piece


## Yaw (degrees) that points a piece's -Z travel direction along `dir`.
static func yaw_of(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


## Inline drive-through store (16 m long) on the current route.
func store(kind: String) -> void:
	_advance_to_exit(_place(kind, Vector3.FORWARD))


## 90-degree sweeping arc to the given side, optionally changing height.
func sweep(radius: float, side: int, rise: float = 0.0) -> void:
	assert(posmod(int(radius), 8) == 4, "sweep radius must be 8k+4 to stay on the grid")
	var side_dir := heading.cross(Vector3.UP) * side
	_open_connector()
	var centre := pos + side_dir * radius
	for i in range(1, 8):                                # the arc, for the driving line
		var a := PI * 0.5 * i / 8.0
		trail.append(centre - side_dir * radius * cos(a) + heading * radius * sin(a) + Vector3.UP * rise * i / 8.0)
	pos += heading * radius + side_dir * radius + Vector3.UP * rise
	heading = side_dir
	trail.append(pos)


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
	piece.set("road_width", width)
	piece.set("side_color_name", side_color)
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
	trail.append(pos)


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
	conn.set("road_width", width)
	conn.set("start_width", width)
	conn.set("end_width", width)
	conn.set("side_color_name", side_color)
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
