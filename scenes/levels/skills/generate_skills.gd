extends SceneTree
## Builds the four skill tracks out of Track Editor pieces (editable in the
## track editor, like the park). Each is three sections that get harder, with a
## checkpoint after each (the third is the finish); Track Sense is the final
## exam that uses every skill.
##
##   godot --headless --path . --script res://scenes/levels/skills/generate_skills.gd
##
## Pound-pad arcs are worked out from the pad's bounce/push (no air drag):
## rising v = sqrt(2 g h), time to a landing dy higher = (v + sqrt(v^2 - 2 g dy)) / g,
## distance = push * time. test_skills flies the real car along each one.

const DIR := "res://scenes/levels/skills/"
const ROAD := 24.0

var scene: Node3D
var t: TrackTurtle


func _init() -> void:
	var failed := 0
	for build in [_ground_pound, _tricks, _upside_down, _track_sense]:
		failed += build.call()
	quit(1 if failed else 0)


func _begin(name: String) -> void:
	scene = Node3D.new()
	scene.name = name
	var track := Node3D.new()
	track.name = "TrackRoot"
	scene.add_child(track)
	track.owner = scene
	t = TrackTurtle.new(scene, track, ROAD, "red")


func _save(file: String) -> int:
	if not t.trail.is_empty():
		scene.set_meta("route", t.trail)                  # the driving line (autopilot tests, future AI)
	var packed := PackedScene.new()
	var err := packed.pack(scene)
	if err == OK:
		err = ResourceSaver.save(packed, DIR + file)
	print("%s: %d pieces, %d alignment errors, save %s" % [file, scene.get_node("TrackRoot").get_child_count(), t.errors, error_string(err)])
	scene.free()
	return 1 if t.errors or err != OK else 0


func _gate(kind: int, order: int, at: Vector3, yaw: float, width := 28.0, drop := 0.0, spins := 0, depth := 4.0) -> void:
	t.place("skill_gate", at, yaw, {kind = kind, order = order, width = width, respawn_drop = drop, spins = spins, depth = depth})


func _hint(text: String, at: Vector3, height := 7.0, reach := 45.0) -> void:
	t.place("hint_sign", at, 0.0, {text = text, height = height, reach = reach})


## Gate across the road the turtle just laid (middle of the last cell).
func _gate_here(kind: int, order: int) -> void:
	_gate(kind, order, t.pos - t.heading * 4.0, TrackTurtle.yaw_of(t.heading), 40.0)   # wider than the road: catches a drifting landing


# ── GROUND POUND: pound pads in the sky, a platformer of hops ─────────────────
# Each section starts on a solid deck at the same height (top y 30) with a short
# run-up, crosses its pads, and ends on the next deck: that's the checkpoint, so
# a respawn always puts you back on solid ground ready to go.
# Pad arcs (no drag): h 24 push 12 -> level ~53 m, up 10 ~47 m; h 30 push 14 -> up 8 ~64 m, up 12 ~61 m.

const DECK_TOP := 30.0


func _ground_pound() -> int:
	_begin("GroundPoundSkill")
	# start deck, along -Z: z +24 .. -24
	t.place("deck", Vector3(0, 0, 0), 0.0, {width_cells = 3, depth_cells = 6, height = DECK_TOP})
	_gate(0, 0, Vector3(0, DECK_TOP, -6), 0.0, 20.0)                # short run-up: ~25 m/s at the edge
	# 1: one big pad right under the edge, throwing you onto deck A
	_hint("Drive off the edge and hold CTRL / LB to dive.\nHit the pad hard to GROUND POUND it.", Vector3(0, DECK_TOP, -14))
	# a long pad (z -24 .. -72) running right up to deck A: wherever you pound it, its throw (~47 m) lands on the deck
	t.place("pound_pad", Vector3(0, 20, -48), 0.0, {size = 48.0, bounce = 24.0, push = 12.0})
	t.place("deck", Vector3(0, 0, -96), 0.0, {width_cells = 3, depth_cells = 6, height = DECK_TOP})    # z -72 .. -120
	_gate(1, 1, Vector3(0, DECK_TOP, -102), 0.0, 26.0, 0.0, 0, 44.0)  # catches the landing; respawn 18 m from the edge
	# 2: three pads and a turn, onto deck B
	_hint("Three pads this time. A pounded pad throws you along its arrow:\nsteer in the air, CTRL / LB to pound the next.", Vector3(0, DECK_TOP, -110))
	t.place("pound_pad", Vector3(0, 20, -142), 0.0, {size = 28.0, bounce = 24.0, push = 12.0})
	t.place("pound_pad", Vector3(0, 20, -195), 90.0, {size = 22.0, bounce = 24.0, push = 12.0})
	_hint("Turn! This one throws you left.", Vector3(0, 20, -195), 10.0, 26.0)
	t.place("pound_pad", Vector3(-53, 20, -195), 90.0, {size = 20.0, bounce = 24.0, push = 12.0})
	t.place("deck", Vector3(-116, 0, -195), 0.0, {width_cells = 6, depth_cells = 3, height = DECK_TOP})  # x -92 .. -140
	_gate(1, 2, Vector3(-122, DECK_TOP, -195), 90.0, 26.0, 0.0, 0, 44.0)
	# 3: small pads climbing to the finish
	_hint("Small pads, and they climb. Dive late to go further, early to stop short.", Vector3(-128, DECK_TOP, -195))
	t.place("pound_pad", Vector3(-158, 20, -195), 90.0, {size = 16.0, bounce = 30.0, push = 14.0})
	t.place("pound_pad", Vector3(-222, 28, -195), 90.0, {size = 12.0, bounce = 30.0, push = 14.0})
	t.place("deck", Vector3(-285, 0, -195), 0.0, {width_cells = 4, depth_cells = 4, height = 40.0})   # x -269 .. -301: the ~61 m throw lands mid-deck
	_gate(3, 9, Vector3(-285, 40, -195), 90.0, 32.0, 0.0, 0, 32.0)
	return _save("ground_pound_track.tscn")


# ── TRICKS: a long runway of kickers; each gate wants spins ───────────────────

func _tricks() -> int:
	_begin("TricksSkill")
	for i in 17:                                           # 48 m wide runway, z 0 .. -1360
		t.place("floor", Vector3(0, 0, -40.0 - 80.0 * i), 0.0, {width_cells = 6, depth_cells = 10})
	_gate(0, 0, Vector3(0, 0, -12), 0.0, 44.0)
	# gates sit past the furthest landing at full speed, so you always land before them
	# 1: a big kicker, one spin
	_hint("In the air, hold SHIFT / B and tap W  A  S  D (or roll the stick) to SPIN.\nLand it to open the pink TRICK gates.", Vector3(0, 0, -40), 7.0, 70.0)
	t.place("kicker", Vector3(0, 0, -150), 0.0, {length = 12.0, lip_angle = 25.0, width_cells = 4})
	_gate(2, 1, Vector3(0, 0, -440), 0.0, 44.0, 0.0, 1)
	# 2: a smaller kicker, less air: be quick
	_hint("Smaller kicker, less air: tap fast.\nKeep SHIFT / B held so you land level.", Vector3(0, 0, -470), 7.0, 60.0)
	t.place("kicker", Vector3(0, 0, -530), 0.0, {length = 12.0, lip_angle = 18.0, width_cells = 4})
	_gate(2, 2, Vector3(0, 0, -800), 0.0, 44.0, 0.0, 1)
	# 3: a huge kicker, two spins in one jump
	_hint("Big one: SPIN TWICE.\nKeep rolling W A S D / the stick while you spin to chain another.", Vector3(0, 0, -830), 7.0, 60.0)
	t.place("kicker", Vector3(0, 0, -890), 0.0, {length = 12.0, lip_angle = 30.0, width_cells = 4})
	_gate(3, 9, Vector3(0, 0, -1250), 0.0, 44.0, 0.0, 2)
	return _save("tricks_track.tscn")


# ── UPSIDE DOWN: three ceilings, each drop onto a smaller target ──────────────

## One ceiling section: a start deck (top `top`) at (sx, sz), a run-up heading
## -Z into a half loop, the ceiling back +Z, and a target pad past the deck that
## throws you +X onto the next deck at the same height (h 18 push 14: ~54 m).
## Returns the landing spot (centre of the next deck's top).
func _ceiling_section(sx: float, top: float, sz: float, pad_size: float, hint: String) -> Vector3:
	t.pos = Vector3(sx, top, sz - 16.0)
	t.heading = Vector3.FORWARD
	t.straight(8)                                          # 64 m run-up
	_hint(hint, Vector3(sx, top, sz - 30.0))
	var pad_z := sz + 16.0 + 30.0
	var ceiling_z := sz - 80.0
	t.ceiling({radius = 26.0, exit_offset = 0.0, ceiling_length = pad_z + 40.0 - ceiling_z})
	t.place("pound_pad", Vector3(sx, top, pad_z), -90.0, {size = pad_size, bounce = 18.0, push = 14.0})
	return Vector3(sx + 54.0, top, pad_z)                # same height: every section starts level


func _upside_down() -> int:
	_begin("UpsideDownSkill")
	t.place("deck", Vector3(0, 0, 40), 0.0, {width_cells = 3, depth_cells = 4, height = 30.0})   # start tower, top y 30
	_gate(0, 0, Vector3(0, 30, 48), 0.0, 20.0)
	var land := _ceiling_section(0, 30, 40, 28.0,
		"Hold the throttle into the curve: it takes you onto the CEILING.\nPress SPACE / A to drop off, CTRL / LB to pound the target.")
	for i in 2:
		# wide catch deck: you land moving +X, brake and turn left onto the next run-up
		t.place("deck", Vector3(land.x + 8.0, 0, land.z), 0.0, {width_cells = 6, depth_cells = 4, height = land.y})
		_gate(1, i + 1, land, 0.0, 48.0, 0.0, 0, 32.0)          # covers the whole catch deck
		_hint("Landed! Brake and turn left onto the next run-up.", land + Vector3(14, 0, 0), 6.0, 20.0)
		land = _ceiling_section(land.x, land.y, land.z, [20.0, 14.0][i],
			["Smaller target this time.", "Last one: the smallest target. Time the drop."][i])
	t.place("deck", Vector3(land.x, 0, land.z), 0.0, {width_cells = 4, depth_cells = 4, height = land.y})
	_gate(3, 9, land, -90.0, 32.0, 0.0, 0, 32.0)
	return _save("upside_down_track.tscn")


# ── TRACK SENSE: the final, every skill on one Trackmania-style run ───────────

func _track_sense() -> int:
	_begin("TrackSenseSkill")
	t.pos = Vector3.ZERO
	t.heading = Vector3.FORWARD
	t.straight(6)
	_gate(0, 0, Vector3(0, 0, -8), 0.0, 40.0)
	# 1: race, a jump, and big air to fly
	_hint("THE FINAL: every skill on one run.\nStuck or fell off? Press R / Y to go back to the last checkpoint.", Vector3(0, 0, -24), 7.0, 50.0)
	t.sweep(44, TrackTurtle.RIGHT)
	t.straight(3)
	_hint("Jump! Keep it straight and land on all four wheels.", t.pos)
	t.straight(2)
	t.jump(18.0)
	t.straight(24)                                         # flat out the 18-degree lip flies ~180 m
	t.sweep(44, TrackTurtle.LEFT)
	t.straight(3)
	_hint("BIG AIR: above 6 m you FLY (plane icon, top left).\nSteer to bank, W/S (stick up/down) to pitch. Hold S too long and you stall.", t.pos, 7.0, 50.0)
	t.jump(30.0)
	t.straight(40)                                         # ...and the 30-degree one ~270 m: land before the gate
	_gate_here(1, 1)
	# 2: a loop, then a kicker and a spin gate
	t.straight(2)
	_hint("Loop: hold the throttle and commit.", t.pos)
	t.loop()
	t.straight(6)
	_hint("Kicker: SHIFT / B + W A S D (roll the stick) to spin before the pink gate.", t.pos)
	t.jump(30.0)
	t.straight(40)
	_gate(2, 2, t.pos - t.heading * 4.0, TrackTurtle.yaw_of(t.heading), 40.0, 0.0, 1)
	# 3: onto the ceiling, drop onto the pad, bounce to the finish beside the road
	t.straight(2)
	var heading := t.heading
	var side := heading.cross(Vector3.UP)
	var origin := t.pos + heading * 4.0                    # the ceiling piece's origin (4 m past its entry)
	_hint("Last: ride the ceiling, SPACE / A to drop, CTRL / LB to pound the pad.", t.pos - heading * 12.0)
	t.ceiling({radius = 26.0, exit_offset = 0.0, ceiling_length = 170.0})
	var pad := origin - heading * 110.0                    # under the ceiling, back over the road
	t.place("pound_pad", pad + Vector3.UP * 0.05, TrackTurtle.yaw_of(side), {size = 28.0, bounce = 18.0, push = 14.0})
	var finish := pad + side * 45.0 + Vector3.UP * 10.0    # h 18 push 14, up 10: ~45 m
	t.place("deck", Vector3(finish.x, 0, finish.z), 0.0, {width_cells = 4, depth_cells = 4, height = 10.0})
	_gate(3, 9, finish, TrackTurtle.yaw_of(side), 32.0, 0.0, 0, 32.0)
	return _save("track_sense_track.tscn")
