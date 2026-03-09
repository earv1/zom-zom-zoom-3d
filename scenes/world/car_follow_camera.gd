extends Camera3D

@export var min_distance := 4.0
@export var max_distance := 8.0
@export var height := 3.0
@export var camera_sensibility := 0.001
@export var follow_strength := 1.5  # how quickly camera swings behind the car

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
	from_target.y = 0.0
	from_target = from_target.lerp(ideal_flat, follow_strength * delta)

	# Clamp horizontal distance
	var flat_len := from_target.length()
	if flat_len < min_distance:
		from_target = from_target.normalized() * min_distance
	elif flat_len > max_distance:
		from_target = from_target.normalized() * max_distance

	from_target.y = height
	global_position = target.global_position + from_target

	var look_dir := global_position.direction_to(target.global_position).abs() - Vector3.UP
	if not look_dir.is_zero_approx():
		look_at_from_position(global_position, target.global_position, Vector3.UP)
