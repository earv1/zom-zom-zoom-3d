class_name SkillLevel
extends Node3D
## Runs one skill track: a generated track scene (TrackRoot of Track Editor
## pieces) with skill gates (start, checkpoints, trick checkpoints, finish) and
## hint signs. Drive the gates in order against the clock; respawn at the last
## gate you passed with R (or by falling off); Backspace restarts; Esc goes back
## to the menu. Best times are saved per skill.

const SKILLS := {
	"ground_pound": {
		title = "GROUND POUND",
		track = "res://scenes/levels/skills/ground_pound_track.tscn",
		blurb = "Dive, pound, bounce: hop the pads to a high finish.",
		kill_y = 3.0,
	},
	"tricks": {
		title = "TRICKS",
		track = "res://scenes/levels/skills/tricks_track.tscn",
		blurb = "Spin in the air and land it to pass the trick gates.",
		kill_y = -20.0,
	},
	"upside_down": {
		title = "UPSIDE DOWN",
		track = "res://scenes/levels/skills/upside_down_track.tscn",
		blurb = "Ride the ceiling, jump off, pound the target. Three times.",
		kill_y = 3.0,
	},
	"track_sense": {
		title = "TRACK SENSE",
		track = "res://scenes/levels/skills/track_sense_track.tscn",
		blurb = "The final: race, fly, loop, spin, ride the ceiling and pound.",
		kill_y = -20.0,
	},
}
const ORDER: Array[String] = ["ground_pound", "tricks", "upside_down", "track_sense"]   ## the final last
const MENU := "res://scenes/ui/level_select.tscn"
const SCENE := "res://scenes/levels/skills/skill_level.tscn"

## Which skill the next skill_level.tscn load runs (set by the menu).
static var selected := "ground_pound"

@export var skill_id := ""                 ## empty: use `selected`
@export var car: RigidBody3D
@export var record_times := true           ## tests turn this off so they don't touch the save

var gates: Array = []                       ## checkpoints in order, then the finish
var track: Node3D
var elapsed := 0.0
var running := false
var done := false

var _start_gate: Node3D
var _next := 0
var _respawn: Node3D
var _spins := 0                             ## spins landed since the last gate
var _kill_y := -20.0
var _hints: Array = []
var _status: Label
var _hint: Label
var _banner: Label
var _panel: Control
var _air: CarAirControl


func _ready() -> void:
	if skill_id == "":
		skill_id = selected
	var info: Dictionary = SKILLS[skill_id]
	_kill_y = info.kill_y
	GameManager.reset()
	_ensure_actions()
	track = (load(info.track) as PackedScene).instantiate()
	track.name = "Track"
	add_child(track)
	_add_landscape()
	_collect_gates()
	_hints = get_tree().get_nodes_in_group("skill_hints")
	_air = car.get_node("CarAirControl") as CarAirControl
	_air.trick_landed.connect(func(_name: String, count: int) -> void:
		_spins += count
		_announce("SPIN x%d LANDED!" % count if count > 1 else "SPIN LANDED!"))
	_build_ui()
	for tracker in find_children("*", "DifficultyTracker", true, false):
		tracker.visible = false                    # no enemies or difficulty in a skill track
	_respawn = _start_gate
	_place_car(_start_gate)
	_announce(info.title)
	var warmup := ShaderWarmup.new()            # compile every shader behind a loading cover (web hitches)
	warmup.level = self
	warmup.car = car
	add_child(warmup)


func _physics_process(delta: float) -> void:
	if done:
		return
	if not running and Vector2(car.linear_velocity.x, car.linear_velocity.z).length() > 2.0:
		running = true                          # the clock starts when you drive off (not the spawn settle)
	if running:
		elapsed += delta
	if car.global_position.y < _kill_y:
		respawn()


func _process(_delta: float) -> void:
	var count := gates.size()
	var at := mini(_next, count)
	var title: String = SKILLS[skill_id].title
	_status.text = "%s   %d / %d   %.2fs\n[R] back to checkpoint   [Backspace] restart   [Esc] menu" % [title, at, count, elapsed]
	var text := ""
	var nearest := INF
	for h in _hints:
		var d: float = (h as Node3D).global_position.distance_to(car.global_position)
		if d < float(h.get("reach")) and d < nearest:
			nearest = d
			text = String(h.get("text"))
	_hint.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		respawn()
	elif event.is_action_pressed("restart_skill"):
		restart()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU)


## Back to the last gate passed (falling from above it if the gate says so).
func respawn() -> void:
	_place_car(_respawn)


func restart() -> void:
	_next = 0
	elapsed = 0.0
	running = false
	done = false
	_spins = 0
	_respawn = _start_gate
	if _panel:
		_panel.queue_free()
		_panel = null
	_place_car(_start_gate)


func _place_car(gate: Node3D) -> void:
	var drop: float = gate.get("respawn_drop") if gate.get("respawn_drop") != null else 0.0
	var xf := Transform3D(gate.global_basis.orthonormalized(), gate.global_position + Vector3.UP * (1.2 + drop))
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	if _air:
		_air._set_flying(false)
		_air.state = CarAirControl.State.GROUNDED


# ── gates ─────────────────────────────────────────────────────────────────────

func _collect_gates() -> void:
	var checkpoints: Array = []
	var finish: Node3D = null
	for gate in get_tree().get_nodes_in_group("skill_gates"):
		match int(gate.get("kind")):
			0: _start_gate = gate
			3: finish = gate
			_: checkpoints.append(gate)
	checkpoints.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("order")) < int(b.get("order")))
	gates = checkpoints
	if finish:
		gates.append(finish)
	for gate in gates:
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(gate.get("width")), 12.0, float(gate.get("depth")))
		cs.shape = box
		cs.position.y = 5.0
		area.add_child(cs)
		gate.add_child(area)
		area.body_entered.connect(_on_gate.bind(gate))


func _on_gate(body: Node, gate: Node3D) -> void:
	if body != car or done:
		return
	var index := gates.find(gate)
	if index < _next:
		return                                     # already passed
	if index > _next:
		_announce("MISSED A CHECKPOINT")
		return
	var need: int = gate.call("spins_needed")
	if _spins < need:
		_announce("LAND %d SPIN%s TO PASS THIS GATE" % [need, "S" if need > 1 else ""])
		return
	_next += 1
	_spins = 0
	_respawn = gate
	if int(gate.get("kind")) == 3:
		_finish()
	else:
		_announce("CHECKPOINT %d / %d   %.2fs" % [_next, gates.size(), elapsed])


func _finish() -> void:
	done = true
	var best := record_times and GameManager.record_skill_time(skill_id, elapsed)
	var best_time: float = GameManager.skill_bests.get(skill_id, elapsed)
	_show_panel("SKILL COMPLETE\n%.2fs%s" % [elapsed, "   NEW BEST!" if best else "   (best %.2fs)" % best_time])


# ── scene setup ───────────────────────────────────────────────────────────────

func _ensure_actions() -> void:
	for pair in [["respawn", KEY_R], ["restart_skill", KEY_BACKSPACE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var key := InputEventKey.new()
			key.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], key)


## Desert floor sized to the track's footprint.
func _add_landscape() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for piece in track.get_node("TrackRoot").get_children():
		var p := Vector2((piece as Node3D).global_position.x, (piece as Node3D).global_position.z)
		lo = lo.min(p)
		hi = hi.max(p)
	var land := DesertLandscape.new()
	land.name = "DesertLandscape"
	land.track_root = track.get_node("TrackRoot")
	land.play_center = (lo + hi) * 0.5
	land.play_half = (hi - lo) * 0.5 + Vector2.ONE * 60.0
	add_child(land)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	_status = _label(ui, 20, Control.PRESET_CENTER_TOP, Vector2(-400, 12))
	_hint = _label(ui, 26, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -190))
	_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_banner = _label(ui, 44, Control.PRESET_CENTER, Vector2(-400, -160))
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_banner.modulate.a = 0.0


func _label(ui: CanvasLayer, size: int, preset: int, at: Vector2) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(preset)
	l.position += at
	l.custom_minimum_size = Vector2(800, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	ui.add_child(l)
	return l


func _announce(text: String) -> void:
	_banner.text = text
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _show_panel(text: String) -> void:
	var ui := _banner.get_parent()
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position += Vector2(-200, -40)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var again := Button.new()
	again.text = "AGAIN"
	again.pressed.connect(restart)
	box.add_child(again)
	var i := ORDER.find(skill_id)
	if i >= 0 and i < ORDER.size() - 1:
		var next := Button.new()
		next.text = "NEXT: " + String(SKILLS[ORDER[i + 1]].title)
		next.pressed.connect(func() -> void:
			selected = ORDER[i + 1]
			get_tree().change_scene_to_file(SCENE))
		box.add_child(next)
	var menu := Button.new()
	menu.text = "MENU"
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU))
	box.add_child(menu)
	_panel.add_child(box)
	ui.add_child(_panel)
	again.grab_focus()
