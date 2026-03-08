class_name Exploder
extends BaseEnemy


func _on_die() -> void:
	var death_pos := global_position
	var saved_car := car

	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 5.0
	collision.shape = sphere
	area.add_child(collision)
	get_tree().current_scene.add_child(area)
	area.global_position = death_pos

	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		for body in area.get_overlapping_bodies():
			if body == saved_car:
				GameManager.take_damage(25)
		area.queue_free()
	)
