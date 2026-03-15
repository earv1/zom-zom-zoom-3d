extends CanvasLayer


func _on_main_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")


func _on_test_track_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test_track/test_track.tscn")
