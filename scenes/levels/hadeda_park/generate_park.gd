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
const WIDTH := 24.0
const SIDE_COLOR := "red"
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
var t: TrackTurtle


func _init() -> void:
	scene_root = Node3D.new()
	scene_root.name = "HadedaPark"
	track = Node3D.new()
	track.name = "TrackRoot"
	scene_root.add_child(track)
	track.owner = scene_root
	t = TrackTurtle.new(scene_root, track, WIDTH, SIDE_COLOR)

	_build_ring()
	_build_plaza()
	_build_decks()
	_build_sky_pillar()
	t.place("diner", Vector3(0, 0, 152), 0.0)            # south of the plaza
	_build_dome()                                      # last: sized to cover everything above

	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("park: %d nodes, %d alignment errors, save %s -> %s" % [
		track.get_child_count(), t.errors, error_string(err), OUT])
	scene_root.free()
	quit(1 if t.errors or err != OK else 0)


# ── layout ────────────────────────────────────────────────────────────────────

func _build_ring() -> void:
	t.pos = Vector3(-204, 0, 184)
	t.heading = Vector3.FORWARD
	t.straight(38)                         # west straight (start / finish)
	t.sweep(124, TrackTurtle.RIGHT)                    # NW sweeper
	t.straight(4)
	t.loop()                               # north loop
	t.straight(16)
	t.sweep(124, TrackTurtle.RIGHT)                    # NE sweeper
	t.straight(6)
	var diner_split := t.fork()            # east pit lane through the diner
	t.straight(7)
	var east_spur := t.fork()              # road into the dome's east exit
	t.straight(11)
	t.merge_next(diner_split)
	t.straight(6)
	t.sweep(124, TrackTurtle.RIGHT)                    # SE sweeper
	t.straight(4)
	t.loop()                               # south loop
	t.straight(4)
	var petrol_split := t.fork()           # south pit lane through the petrol station
	t.straight(18)
	t.merge_next(petrol_split)
	t.straight(2)
	t.close()                              # SW corner back onto the start straight

	for split in [[diner_split, "diner_pit_lane", "diner"], [petrol_split, "petrol_pit_lane", "petrol"]]:
		t.branch(split[0], split[1], func() -> void:
			t.sweep(28, TrackTurtle.LEFT)
			t.straight(2)
			t.sweep(28, TrackTurtle.RIGHT)
			t.store(split[2])
			t.straight(2)
			t.sweep(28, TrackTurtle.RIGHT)
			t.straight(2)
			t.join(28, TrackTurtle.LEFT))
	t.branch(east_spur, "east_spur", func() -> void:     # dead-ends inside the dome
		t.sweep(28, TrackTurtle.RIGHT)
		t.straight(10))


func _build_plaza() -> void:
	for x in [-80.0, 0.0, 80.0]:                        # 240 m road-style floor
		for z in [-80.0, 0.0, 80.0]:
			t.place("floor", Vector3(x, 0, z), 0.0, {width_cells = 10, depth_cells = 10})
	var qp := {radius = 8.0, height = 10.0, width_cells = 8, deck = 4.0}
	t.place("quarter_pipe", Vector3(0, 0, -36), 0.0, qp)         # bowl: north wall
	t.place("quarter_pipe", Vector3(0, 0, 36), 180.0, qp)        # south wall
	t.place("quarter_pipe", Vector3(-36, 0, 0), 90.0, qp)        # west wall (east side open)
	var corner := {radius = 8.0, height = 10.0, deck = 6.0}
	t.place("bowl_corner", Vector3(-36, 0, -36), 0.0, corner)
	t.place("bowl_corner", Vector3(-36, 0, 36), 90.0, corner)
	t.place("slope", Vector3(0, 0, -56), 180.0, {length = 24.0, height = 10.0, width_cells = 3})  # drop-in
	t.place("summon_panel", Vector3(0, 0, 0), 0.0, {size = 16.0})  # boss summon, in the bowl
	t.place("spine", Vector3(72, 0, 0), 90.0, {radius = 4.0, width_cells = 6})
	t.place("funbox", Vector3(64, 0, -64), 0.0, {top = 16.0, height = 3.0, slope = 10.0})
	t.place("funbox", Vector3(64, 0, 64), 0.0, {top = 16.0, height = 3.0, slope = 10.0})
	# launch lane along z = 0 off the plaza's west edge, over the ring road to the sky pillar
	t.place("kicker", Vector3(LAUNCH_LIP_X + 6.0, 0, 0), 90.0, {length = 12.0, lip_angle = 35.0, width_cells = 2})


func _build_decks() -> void:                            # outside the dome's north exit
	t.place("slope", Vector3(0, 0, -140), 0.0, {length = 24.0, height = 4.0, width_cells = 4})
	t.place("deck", Vector3(0, 0, -168), 0.0, {width_cells = 6, depth_cells = 4, height = 4.0})
	t.place("kicker", Vector3(18, 4, -168), -90.0, {length = 12.0, lip_angle = 25.0, width_cells = 3})  # gap jump east
	t.place("deck", Vector3(80, 0, -168), 0.0, {width_cells = 4, depth_cells = 4, height = 4.0})
	t.place("slope", Vector3(80, 0, -140), 0.0, {length = 24.0, height = 4.0, width_cells = 4})
	t.place("slope", Vector3(0, 4, -188), 0.0, {length = 8.0, height = 6.0, width_cells = 6})
	t.place("deck", Vector3(0, 0, -208), 0.0, {width_cells = 6, depth_cells = 4, height = 10.0})


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
	t.place("dome", Vector3(centre.x, DESERT_FLOOR_Y, centre.y), 0.0, {radius = radius, height = radius * 0.35,
		transition = DOME_TRANSITION, exits = 4, exit_width = 32.0, exit_height = 16.0})
	print("dome: centre %s radius %.0f" % [centre, radius])


func _build_sky_pillar() -> void:
	t.place("sky_pillar", PILLAR, 0.0, {height = PILLAR_HEIGHT, top = 28.0})
	t.place("sky_workshop", PILLAR + Vector3.UP * PILLAR_HEIGHT, 90.0)
