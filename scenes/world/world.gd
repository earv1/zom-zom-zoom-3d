extends Node3D

const EXIT_DISTANCE := 20000.0
const LevelExitScript := preload("res://scenes/world/level_exit.gd")
const ObjectiveMarkerScript := preload("res://scenes/ui/objective_marker.gd")

@export var car: Node3D

var _level_exit: Node3D
var _objective_marker: Control


func _ready() -> void:
	if not car:
		car = get_node_or_null("Car")
	for mesh in car.find_children("*", "MeshInstance3D", true):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameManager.game_over.connect(_on_game_over)

	var music := $MusicPlayer as AudioStreamPlayer
	(music.stream as AudioStreamMP3).loop = true
	music.volume_db = -1.0
	music.play()

	_spawn_level_exit()
	_setup_objective_marker()


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


func _on_game_over() -> void:
	pass  # GameOverScreen handles display; retry reloads via GameOverScreen
