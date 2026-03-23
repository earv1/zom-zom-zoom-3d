extends Node3D

const EXIT_DISTANCE := 20000.0
const PICKUP_MEAN_INTERVAL := 60.0
const PICKUP_SPAWN_DIST := 80.0
const PICKUP_SPREAD := 30.0
const MAX_PICKUPS := 5

const LevelExitScript := preload("res://scenes/world/level_exit.gd")
const ObjectiveMarkerScript := preload("res://scenes/ui/objective_marker.gd")
const HealthPickupScript := preload("res://scenes/world/health_pickup.gd")
const PsxScreenScript := preload("res://scenes/ui/psx_screen.gd")

@export var car: Node3D

var _level_exit: Node3D
var _objective_marker: Control
var _pickup_timer := 0.0
var _next_pickup_time := 0.0
var _pickups: Array = []


func _ready() -> void:
	if not car:
		car = get_node_or_null("Car")
	GameManager.game_over.connect(_on_game_over)

	var music := $MusicPlayer as AudioStreamPlayer
	(music.stream as AudioStreamMP3).loop = true
	music.volume_db = -1.0
	music.play()

	_spawn_level_exit()
	_setup_objective_marker()
	_setup_psx_screen()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SEMICOLON:
		var debug_on: bool = not car.get("show_debug")
		car.set("show_debug", debug_on)
		for wheel in car.get("wheels"):
			(wheel as Node).set("show_debug", debug_on)


func _spawn_level_exit() -> void:
	var angle := randf() * TAU
	var pos := Vector3(cos(angle) * EXIT_DISTANCE, 0.5, sin(angle) * EXIT_DISTANCE)

	_level_exit = Node3D.new()
	_level_exit.set_script(LevelExitScript)
	_level_exit.position = pos
	_level_exit.set_car(car)
	add_child(_level_exit)


func _setup_objective_marker() -> void:
	var hud := $HUD as CanvasLayer
	_objective_marker = Control.new()
	_objective_marker.set_script(ObjectiveMarkerScript)
	_objective_marker.name = "ObjectiveMarker"
	hud.add_child(_objective_marker)
	_objective_marker.add_objective(_level_exit, Color(0.2, 1.0, 0.4), "EXIT")


func _setup_psx_screen() -> void:
	var psx := CanvasLayer.new()
	psx.set_script(PsxScreenScript)
	psx.name = "PsxScreen"
	add_child(psx)


func _process(delta: float) -> void:
	_pickup_timer += delta
	if _pickup_timer >= _next_pickup_time:
		_pickup_timer = 0.0
		_next_pickup_time = _rand_pickup_interval()
		_try_spawn_pickup()


func _rand_pickup_interval() -> float:
	# Exponential distribution with mean = PICKUP_MEAN_INTERVAL
	return -PICKUP_MEAN_INTERVAL * log(randf_range(0.01, 1.0))


func _try_spawn_pickup() -> void:
	# Clean up freed pickups
	_pickups = _pickups.filter(func(p: Node3D) -> bool: return is_instance_valid(p))
	if _pickups.size() >= MAX_PICKUPS:
		return

	# Direction from car toward exit
	var to_exit := (_level_exit.global_position - car.global_position).normalized()
	to_exit.y = 0.0

	# Spawn ahead of car, biased toward exit
	var spread_angle := randf_range(-0.5, 0.5)
	var dir := to_exit.rotated(Vector3.UP, spread_angle)
	var pos := car.global_position + dir * PICKUP_SPAWN_DIST
	pos += Vector3(randf_range(-PICKUP_SPREAD, PICKUP_SPREAD), 0, randf_range(-PICKUP_SPREAD, PICKUP_SPREAD))
	pos.y = 0.5

	var pickup := Node3D.new()
	pickup.set_script(HealthPickupScript)
	pickup.position = pos
	pickup.set_car(car)
	add_child(pickup)
	_pickups.append(pickup)
	_objective_marker.add_objective(pickup, Color(1.0, 0.3, 0.3), "HEALTH")


func _on_game_over() -> void:
	pass  # GameOverScreen handles display; retry reloads via GameOverScreen
