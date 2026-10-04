class_name DamageNumber
extends Label3D
## Floating number that pops off whatever was hit, drifts up and fades.
## Crits are bigger, yellow and get a "!".


static func spawn(parent: Node, at: Vector3, amount: float, crit: bool = false) -> void:
	if parent == null:
		return
	var n := DamageNumber.new()
	n.text = Num.short(amount) + ("!" if crit else "")
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.fixed_size = true
	n.pixel_size = 0.0016 if crit else 0.0011
	n.font_size = 48
	n.outline_size = 14
	n.modulate = Color(1.0, 0.85, 0.15) if crit else Color(1, 1, 1)
	n.outline_modulate = Color(0.35, 0.05, 0.0) if crit else Color(0, 0, 0)
	parent.add_child(n)
	n.global_position = at + Vector3(randf_range(-0.6, 0.6), 1.5, randf_range(-0.6, 0.6))
	var tw := n.create_tween()
	tw.tween_property(n, "global_position:y", n.global_position.y + 3.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(n.queue_free)
