extends Camera3D

@export var min_distance := 4.0
@export var max_distance := 8.0
@export var height := 3.0
@export var camera_sensibility := 0.001
@export var follow_strength := 1.5  # how quickly camera swings behind the car
## Boss lock-on: while set, the camera sits behind the car facing this node and
## aims along the floor toward it (its ground spot, not up at a flying boss).
var focus: Node3D
const FOCUS_REACH := 40.0     ## aim this far from the car toward the focus, so the car stays in frame
const FOCUS_FOLLOW := 3.0     ## swing-behind speed while locked on
const AIM_SMOOTH := 4.0

var _aim_offset := Vector3.ZERO   ## smoothed shift of the look point toward the focus (zero outside boss fights)

@onready var target : Node3D = get_parent().get_parent()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		top_level = false
		get_parent().rotate_y(-event.relative.x * camera_sensibility)
		top_level = true


func _physics_process(delta: float) -> void:
	var from_target := global_position - target.global_position

	# Softly pull camera toward behind the car (car's +Z is its rear)
	var ideal_flat := target.global_basis.z * max_distance
	var aim_offset := Vector3.ZERO
	var strength := follow_strength
	if is_instance_valid(focus):
		var to_focus := focus.global_position - target.global_position
		to_focus.y = 0.0
		if to_focus.length() > 1.0:
			ideal_flat = -to_focus.normalized() * max_distance
			aim_offset = to_focus.limit_length(FOCUS_REACH)   # stays at the car's height: on the floor
			strength = FOCUS_FOLLOW
	from_target.y = 0.0
	from_target = from_target.lerp(ideal_flat, strength * delta)

	# Clamp horizontal distance
	var flat_len := from_target.length()
	if flat_len < min_distance:
		from_target = from_target.normalized() * min_distance
	elif flat_len > max_distance:
		from_target = from_target.normalized() * max_distance

	from_target.y = height
	global_position = target.global_position + from_target

	_aim_offset = _aim_offset.lerp(aim_offset, minf(AIM_SMOOTH * delta, 1.0))
	var aim := target.global_position + _aim_offset
	var look_dir := global_position.direction_to(aim).abs() - Vector3.UP
	if not look_dir.is_zero_approx():
		look_at_from_position(global_position, aim, Vector3.UP)
