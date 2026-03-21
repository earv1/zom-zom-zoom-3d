extends Node3D

@export var car: Node3D


func _ready() -> void:
	if not car:
		car = get_node_or_null("Car")
	for mesh in car.find_children("*", "MeshInstance3D", true):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameManager.game_over.connect(_on_game_over)

	var music := $MusicPlayer as AudioStreamPlayer
	(music.stream as AudioStreamMP3).loop = true
	music.volume_db = -80.0
	music.play()
	var tween := create_tween()
	tween.tween_property(music, "volume_db", -3.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_game_over() -> void:
	pass  # GameOverScreen handles display; retry reloads via GameOverScreen
