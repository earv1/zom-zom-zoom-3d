extends Node3D

@export var car: Node3D


func _ready() -> void:
	for mesh in car.find_children("*", "MeshInstance3D", true):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameManager.game_over.connect(_on_game_over)

	var music := $MusicPlayer as AudioStreamPlayer
	(music.stream as AudioStreamMP3).loop = true
	music.play()


func _on_game_over() -> void:
	pass  # GameOverScreen handles display; retry reloads via GameOverScreen
