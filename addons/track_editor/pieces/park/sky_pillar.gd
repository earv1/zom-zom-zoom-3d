@tool
extends ParkPiece
## Tall rock pillar with a landing deck on top: home of the Sky Workshop.
## Reach it by launching off a kicker aimed at the open +Z side; curbs on the
## other sides catch an overshoot.

@export_storage var height := 30.0
@export_storage var top := 28.0


func get_param_defs() -> Array:
	return [
		{name = "height", label = "Height", min = 8.0, max = 80.0, step = 2.0, default = 30.0},
		{name = "top", label = "Deck size", min = 12.0, max = 48.0, step = 2.0, default = 28.0},
	]


func _build() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.58, 0.34, 0.22)
	rock.roughness = 0.95
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top * 0.55
	cyl.bottom_radius = top * 0.8
	cyl.height = height - 0.7                  # stop just under the landing deck
	cyl.radial_segments = 9
	cyl.rings = 3
	pillar.mesh = cyl
	pillar.material_override = rock
	pillar.position.y = (height - 0.7) * 0.5
	add_child(pillar)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = top * 0.55
	shape.height = height
	cs.shape = shape
	cs.position.y = height * 0.5
	sb.add_child(cs)
	add_child(sb)
	ParkGeometry.box(self, Vector3(top, 0.6, top), Vector3(0, height - 0.3, 0), ParkGeometry.concrete())
	var curb := ParkGeometry.paint(side_color_name)
	var h := top * 0.5
	ParkGeometry.box(self, Vector3(top, 1.2, 0.8), Vector3(0, height + 0.6, -h), curb)
	ParkGeometry.box(self, Vector3(0.8, 1.2, top), Vector3(-h, height + 0.6, 0), curb)
	ParkGeometry.box(self, Vector3(0.8, 1.2, top), Vector3(h, height + 0.6, 0), curb)
