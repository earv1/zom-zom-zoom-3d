class_name CarShadowLight
extends Node

## SpotLight3D that always sits at the 11 o'clock direction from the car,
## elevated above it, and points straight at the car. Casts a local real shadow
## without affecting global scene lighting.

@export var elevation_deg: float = 70.0   # higher = shorter/smaller shadow
@export var light_height: float = 25.0    # world-space height above car
@export var light_energy: float = 1.5
@export var spot_angle: float = 15.0      # cone half-angle in degrees
@export var spot_range: float = 60.0

var _car: RigidBody3D
var _light: SpotLight3D


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarShadowLight: parent must be RigidBody3D")
		return

	_light = SpotLight3D.new()
	_light.shadow_enabled = true
	_light.shadow_bias = 0.3
	_light.shadow_normal_bias = 2.0
	_light.light_energy = light_energy
	_light.spot_range = spot_range
	_light.spot_angle = spot_angle
	# Top-level so it moves in world space independently of the car's pitch/roll
	_light.top_level = true
	_car.add_child.call_deferred(_light)


func _process(_delta: float) -> void:
	if not _car or not _light:
		return

	# Flatten car forward — only yaw matters for 11 o'clock
	var forward := -_car.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()

	# 11 o'clock = 30° to the left of car's forward
	var from_dir := forward.rotated(Vector3.UP, deg_to_rad(-30.0))

	# Horizontal offset from car based on elevation angle
	var h_dist := light_height / tan(deg_to_rad(elevation_deg))
	var source_pos := _car.global_position + from_dir * h_dist + Vector3.UP * light_height

	_light.global_position = source_pos
	_light.look_at(_car.global_position, Vector3.UP)
