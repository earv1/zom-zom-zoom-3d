## Visual test bed for connector cases.
## Runs in the editor (@tool) and rebuilds automatically on _ready or when
## the "Rebuild" export toggle is flipped.  Each case mirrors a GUT test so
## you can cross-reference failures with what the mesh actually looks like.
@tool
extends Node3D

const CONNECTOR_SCENE := preload("res://addons/track_editor/pieces/connector.tscn")

const COLS    := 4
const SPACING := 30.0

@export var show_bezier: bool = false:
	set(value):
		show_bezier = value
		if is_node_ready():
			_build_all()

@export var rebuild: bool = false:
	set(_v):
		if is_node_ready():
			_build_all()

func _ready() -> void:
	_build_all()

# ---------------------------------------------------------------------------

func _build_all() -> void:
	for child in get_children():
		child.queue_free()

	var cases := _cases()
	for i in range(cases.size()):
		var c: Dictionary = cases[i]
		var col := i % COLS
		var row := i / COLS
		var offset := Vector3(col * SPACING, 0.0, row * SPACING)
		_spawn(c, offset)

func _spawn(c: Dictionary, offset: Vector3) -> void:
	var start: Vector3 = c.start + offset
	var end:   Vector3 = c.end   + offset

	var connector = CONNECTOR_SCENE.instantiate()
	connector.start_pos        = start
	connector.start_dir        = c.s_dir
	connector.end_pos          = end
	connector.end_dir          = c.e_dir
	connector.start_up         = c.get("s_up", Vector3.UP)
	connector.end_up           = c.get("e_up", Vector3.UP)
	connector.debug_show_bezier = show_bezier
	connector.position         = start
	add_child(connector)

	# Label floats above the midpoint
	var label := Label3D.new()
	label.text        = c.label
	label.position    = (start + end) * 0.5 + Vector3(0, 5, 0)
	label.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size   = 24
	label.modulate    = Color(1.0, 1.0, 0.4)
	add_child(label)

	# Green sphere = start, red sphere = end
	_add_marker(start, Color(0.2, 1.0, 0.2))
	_add_marker(end,   Color(1.0, 0.2, 0.2))

func _add_marker(pos: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color  = color
	mat.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh              = mesh
	mi.material_override = mat
	mi.position          = pos + Vector3(0, 0.4, 0)
	add_child(mi)

# ---------------------------------------------------------------------------
# Each entry mirrors one or more GUT tests in test_connector_path.gd.
# start/end positions are relative to the cell origin (offset applied above).

func _cases() -> Array:
	return [
		# ── straight cases ────────────────────────────────────────────────
		{
			label   = "straight forward\n(test: monotonic z)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 0, 10),  e_dir = Vector3(0, 0, 1),
		},
		{
			label   = "lateral straight\n(test: linear x, const y/z)",
			start   = Vector3.ZERO,       s_dir = Vector3(1, 0, 0),
			end     = Vector3(12, 0, 0),  e_dir = Vector3(1, 0, 0),
		},
		{
			label   = "height ramp\n(test: flush approach, const z)",
			start   = Vector3.ZERO,       s_dir = Vector3(1, 0, 0),
			end     = Vector3(10, 4, 0),  e_dir = Vector3(1, 0, 0),
		},

		# ── guided turn cases ─────────────────────────────────────────────
		{
			label   = "90° turn\n(test: leaves & arrives parallel)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(12, 0, -4), e_dir = Vector3(1, 0, 0),
		},
		{
			label   = "wide 90° turn\n(test: five guides, inner pull)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(20, 0, 0),  e_dir = Vector3(1, 0, 0),
		},
		{
			label   = "S-turn opposite dirs\n(test: no outward overshoot)",
			start   = Vector3.ZERO,       s_dir = Vector3(1, 0, 0),
			end     = Vector3(-8, 0, 8),  e_dir = Vector3(-1, 0, 0),
		},

		# ── anti-loop cases (these used to produce backward/looping paths) ─
		{
			label   = "end diagonal behind\n(test: exits along start_dir)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(2, 0, -8),  e_dir = Vector3(1, 0, 0),
		},
		{
			label   = "end reversed same axis\n(test: no straight backward)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 0, -8),  e_dir = Vector3(0, 0, -1),
		},
		{
			label   = "end far behind, large offset\n(stress: U-turn room)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(6, 0, -12), e_dir = Vector3(0, 0, -1),
		},

		# ── flush junction cases ──────────────────────────────────────────
		{
			label   = "flush: start & end width dir\n(test: perp to road dir)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(12, 0, -4), e_dir = Vector3(1, 0, 0),
		},
		{
			# Real editor case: straight at grid (0,0) → straight at grid (1,3)
			# Both face +z, 8-unit cells. Previously caused end slab to jut out.
			label   = "S-curve same dir\n(test: no width_dir flip at end)",
			start   = Vector3.ZERO,      s_dir = Vector3(0, 0, 1),
			end     = Vector3(8, 0, 16), e_dir = Vector3(0, 0, 1),
		},
		{
			label   = "height ramp flush\n(test: flush approach end dir)",
			start   = Vector3.ZERO,      s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 4, 8),  e_dir = Vector3(0, 0, 1),
		},

		# ── surface twist cases ──────────────────────────────────────────
		{
			label   = "floor → west wall\n(twist 90° forward)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 0, 16),  e_dir = Vector3(0, 0, 1),
			s_up    = Vector3.UP,          e_up  = Vector3(-1, 0, 0),
		},
		{
			label   = "floor → east wall\n(twist 90° forward)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 0, 16),  e_dir = Vector3(0, 0, 1),
			s_up    = Vector3.UP,          e_up  = Vector3(1, 0, 0),
		},
		{
			label   = "floor → ceiling\n(twist 180° forward)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(0, 0, 20),  e_dir = Vector3(0, 0, 1),
			s_up    = Vector3.UP,          e_up  = Vector3.DOWN,
		},
		{
			label   = "west wall → floor\n(twist + turn 90°)",
			start   = Vector3.ZERO,       s_dir = Vector3(0, 0, 1),
			end     = Vector3(12, 0, -4), e_dir = Vector3(1, 0, 0),
			s_up    = Vector3(-1, 0, 0),  e_up  = Vector3.UP,
		},
	]
