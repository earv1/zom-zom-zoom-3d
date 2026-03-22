class_name Projectile
extends Area3D

var speed: float = 40.0
var damage: float = 1.0
var direction: Vector3 = Vector3.FORWARD
var target: Node3D = null
var homing_strength: float = 5.0

const SLOW_RADIUS := 8.0   # start slowing when this close to target
const MIN_SPEED_MULT := 0.35  # slowest speed multiplier near target


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _process(delta: float) -> void:
	var speed_mult := 1.0
	if is_instance_valid(target):
		var to_target := (target.global_position - global_position)
		var dist := to_target.length()
		direction = direction.lerp(to_target.normalized(), homing_strength * delta).normalized()
		# Slow down when close to target for tighter tracking
		if dist < SLOW_RADIUS:
			speed_mult = lerpf(MIN_SPEED_MULT, 1.0, dist / SLOW_RADIUS)
	global_position += direction * speed * speed_mult * delta


func _on_body_entered(body: Node) -> void:
	if body is BaseEnemy:
		body.take_damage(int(damage))
		queue_free()
