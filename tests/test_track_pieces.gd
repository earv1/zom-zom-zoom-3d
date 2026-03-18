## GUT tests for track editor piece API.
## Verifies configure / get_config / get_param_defs on all six pieces.
extends GutTest

const PIECES := {
	"straight": "res://addons/track_editor/pieces/straight.tscn",
	"curve":    "res://addons/track_editor/pieces/curve.tscn",
	"ramp_up":  "res://addons/track_editor/pieces/ramp_up.tscn",
	"loop":     "res://addons/track_editor/pieces/loop.tscn",
	"bank":     "res://addons/track_editor/pieces/bank.tscn",
	"jump":     "res://addons/track_editor/pieces/jump.tscn",
}

var _piece: Node3D

func after_each() -> void:
	if is_instance_valid(_piece):
		_piece.queue_free()
		_piece = null

# ── helpers ───────────────────────────────────────────────────────────────────

func _load_piece(name: String) -> Node3D:
	var packed: PackedScene = load(PIECES[name])
	var p: Node3D = packed.instantiate()
	add_child(p)          # triggers _ready() → _build()
	_piece = p
	return p

# ── API surface ───────────────────────────────────────────────────────────────

func test_all_pieces_have_configure() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		assert_true(p.has_method("configure"), "%s has configure()" % name)

func test_all_pieces_have_get_config() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		assert_true(p.has_method("get_config"), "%s has get_config()" % name)

func test_all_pieces_have_get_param_defs() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		assert_true(p.has_method("get_param_defs"), "%s has get_param_defs()" % name)

# ── param_defs shape ──────────────────────────────────────────────────────────

func test_param_defs_not_empty() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		var defs: Array = p.get_param_defs()
		assert_gt(defs.size(), 0, "%s: param_defs not empty" % name)

func test_param_defs_have_required_keys() -> void:
	var required := ["name", "label", "min", "max", "step", "default"]
	for name in PIECES:
		var p := _load_piece(name)
		for d in p.get_param_defs():
			for key in required:
				assert_has(d, key, "%s param '%s' has key '%s'" % [name, d.get("name", "?"), key])

func test_param_defs_min_less_than_max() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		for d in p.get_param_defs():
			assert_lt(d.min, d.max,
				"%s param '%s': min < max" % [name, d.get("name", "?")])

func test_param_defs_default_in_range() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		for d in p.get_param_defs():
			assert_gte(d.default, d.min,
				"%s param '%s': default >= min" % [name, d.get("name", "?")])
			assert_lte(d.default, d.max,
				"%s param '%s': default <= max" % [name, d.get("name", "?")])

# ── get_config ────────────────────────────────────────────────────────────────

func test_get_config_keys_match_param_defs() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		var cfg: Dictionary = p.get_config()
		for d in p.get_param_defs():
			assert_has(cfg, d.name,
				"%s get_config() has key '%s'" % [name, d.name])

func test_get_config_values_match_defaults() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		var cfg: Dictionary = p.get_config()
		for d in p.get_param_defs():
			assert_almost_eq(cfg[d.name], d.default, 0.01,
				"%s '%s' default value matches" % [name, d.name])

# ── configure ─────────────────────────────────────────────────────────────────

func test_configure_updates_values() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		var defs: Array = p.get_param_defs()
		# Build a params dict with each slider bumped by one step (clamped to max)
		var params := {}
		for d in defs:
			params[d.name] = min(d.default + d.step, d.max)
		p.configure(params)
		var cfg: Dictionary = p.get_config()
		for d in defs:
			assert_almost_eq(cfg[d.name], min(d.default + d.step, d.max), 0.01,
				"%s '%s' updated after configure()" % [name, d.name])

func test_configure_creates_children() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		p.configure(p.get_config())
		assert_gt(p.get_child_count(), 0,
			"%s has children after configure()" % name)

func test_configure_roundtrip() -> void:
	for name in PIECES:
		var p := _load_piece(name)
		var original: Dictionary = p.get_config()
		p.configure(original)
		var after: Dictionary = p.get_config()
		for key in original:
			assert_almost_eq(after[key], original[key], 0.01,
				"%s '%s' roundtrip unchanged" % [name, key])
