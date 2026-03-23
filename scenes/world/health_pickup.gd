extends Node3D

const PICKUP_RADIUS := 6.0
const HEAL_AMOUNT := 25
const BOB_SPEED := 2.5
const BOB_HEIGHT := 0.4
const LIFETIME := 20.0

var _car: Node3D
var _mesh: MeshInstance3D
var _time := 0.0
var _picked_up := false


func _ready() -> void:
	_build_visual()


func set_car(car: Node3D) -> void:
	_car = car


func _process(delta: float) -> void:
	_time += delta
	if _mesh:
		_mesh.position.y = 3.0 + sin(_time * BOB_SPEED) * BOB_HEIGHT

	if _picked_up:
		return
	if _time >= LIFETIME:
		queue_free()
		return
	if _car and global_position.distance_to(_car.global_position) <= PICKUP_RADIUS:
		_pick_up()


func _pick_up() -> void:
	_picked_up = true
	GameManager.current_health = mini(GameManager.current_health + HEAL_AMOUNT, GameManager.max_health)
	GameManager.health_changed.emit(GameManager.current_health, GameManager.max_health)
	queue_free()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 6.0, 1.5)
	_mesh.mesh = box
	_mesh.position.y = 3.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)
