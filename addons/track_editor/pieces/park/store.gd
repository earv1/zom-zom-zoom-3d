@tool
extends ParkPiece
## Drive-through store building. The bay lane runs along Z through the middle:
## drive in from +Z. kind: 0 roadside diner, 1 petrol station, 2 sky workshop
## (place it on a sky_pillar). The store logic (PitStore) attaches at runtime.

const KINDS: Array[StringName] = [&"diner", &"petrol", &"sky"]

@export_storage var kind := 0


func get_param_defs() -> Array:
	return [{name = "kind", label = "Store (0 diner, 1 petrol, 2 sky)", min = 0.0, max = 2.0, step = 1.0, default = 0.0}]


func get_connection_anchors() -> Array:
	return [
		{"position": Vector3(0, 0, 8), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(0, 0, -8), "out_dir": Vector3(0, 0, -1)},
	]


func _build() -> void:
	match KINDS[clampi(kind, 0, 2)]:
		&"diner": _diner()
		&"petrol": _petrol()
		&"sky": _workshop()
	ParkGeometry.box(self, Vector3(12, 0.3, 16), Vector3(0, -0.15, 0), ParkGeometry.concrete())
	if not Engine.is_editor_hint():
		# loaded lazily: the store logic needs the game's autoloads, the building doesn't
		var store: Node3D = load("res://scenes/stores/pit_store.gd").new()
		store.set("kind", KINDS[clampi(kind, 0, 2)])
		add_child(store)


func _diner() -> void:
	var teal := _mat(Color(0.25, 0.68, 0.66))
	var cream := _mat(Color(0.93, 0.88, 0.76))
	var red := _mat(Color(0.82, 0.16, 0.14))
	ParkGeometry.box(self, Vector3(12, 5, 16), Vector3(13, 2.5, 0), cream)          # diner car body
	ParkGeometry.box(self, Vector3(12.2, 0.9, 16.2), Vector3(13, 3.2, 0), red)      # stripe
	ParkGeometry.box(self, Vector3(13, 0.6, 17), Vector3(13, 5.3, 0), teal)         # roof
	ParkGeometry.box(self, Vector3(14, 0.5, 12), Vector3(0, 6.2, 0), teal)          # drive-through awning
	for x in [-6.5, 6.5]:
		for z in [-5.5, 5.5]:
			ParkGeometry.box(self, Vector3(0.5, 6.0, 0.5), Vector3(x, 3.0, z), cream)
	_pole_sign("DINER", Vector3(-10, 0, 6), Color(1.0, 0.3, 0.45), 12.0)


func _petrol() -> void:
	var white := _mat(Color(0.92, 0.92, 0.9))
	var green := _mat(Color(0.12, 0.55, 0.28))
	var yellow := _mat(Color(0.98, 0.78, 0.12))
	ParkGeometry.box(self, Vector3(18, 1.0, 16), Vector3(0, 7.0, 0), white)         # canopy
	ParkGeometry.box(self, Vector3(18.2, 0.5, 16.2), Vector3(0, 6.4, 0), green)
	for x in [-7.5, 7.5]:
		for z in [-6.0, 6.0]:
			ParkGeometry.box(self, Vector3(0.7, 6.5, 0.7), Vector3(x, 3.25, z), white)
		ParkGeometry.box(self, Vector3(1.6, 0.4, 7.0), Vector3(x, 0.2, 0), white)    # pump island
		for z in [-2.0, 2.0]:
			ParkGeometry.box(self, Vector3(0.9, 2.0, 0.9), Vector3(x, 1.4, z), yellow)
	ParkGeometry.box(self, Vector3(9, 4, 8), Vector3(15, 2, -4), white)             # kiosk
	_pole_sign("PETROL", Vector3(11, 0, 9), Color(0.3, 1.0, 0.45), 14.0)


func _workshop() -> void:
	var steel := _mat(Color(0.45, 0.48, 0.52))
	var orange := _mat(Color(0.95, 0.45, 0.12))
	for x in [-7.0, 7.0]:
		ParkGeometry.box(self, Vector3(1.0, 7.0, 14), Vector3(x, 3.5, 0), steel)     # hangar walls
	ParkGeometry.box(self, Vector3(15, 0.6, 15), Vector3(0, 7.3, 0), orange)        # roof
	var beacon := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.8
	bulb.height = 1.6
	beacon.mesh = bulb
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.8, 1.0)
	glow.emission_energy_multiplier = 4.0
	glow.albedo_color = Color(0.5, 0.9, 1.0)
	beacon.material_override = glow
	beacon.position = Vector3(0, 8.4, 0)
	add_child(beacon)
	_sign("SKY WORKSHOP", Vector3(0, 9.6, 7.6), Color(0.4, 0.85, 1.0))


func _pole_sign(text: String, at: Vector3, color: Color, height: float) -> void:
	ParkGeometry.box(self, Vector3(0.5, height, 0.5), at + Vector3(0, height * 0.5, 0), _mat(Color(0.3, 0.3, 0.32)))
	_sign(text, at + Vector3(0, height + 1.2, 0), color)


func _sign(text: String, at: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 160
	l.pixel_size = 0.02
	l.outline_size = 24
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.05, 0.05)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = at
	add_child(l)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
