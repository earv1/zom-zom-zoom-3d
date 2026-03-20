class_name LevelUpScreen
extends CanvasLayer

@onready var _cards_container: HBoxContainer = $Center/VBox/CardsContainer
@onready var _vbox: VBoxContainer = $Center/VBox
@onready var _overlay: ColorRect = $Overlay

var _card_scene: PackedScene = preload("res://scenes/ui/upgrade_card.tscn")


func show_choices(choices: Array) -> void:
	if choices.is_empty():
		return

	for child in _cards_container.get_children():
		child.queue_free()

	for upgrade in choices:
		var card: UpgradeCard = _card_scene.instantiate()
		_cards_container.add_child(card)
		card.setup(upgrade)
		card.card_selected.connect(_on_card_selected)

	visible = true
	get_tree().paused = true
	_play_entrance()


func _play_entrance() -> void:
	_overlay.modulate.a = 0.0
	_vbox.modulate.a = 0.0
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.2)

	# Wait one frame so CenterContainer computes its layout before we read position
	await get_tree().process_frame
	var natural_y := _vbox.position.y

	_vbox.position.y = natural_y + 30.0
	var vt := create_tween().set_parallel()
	vt.tween_property(_vbox, "modulate:a", 1.0, 0.25).set_delay(0.1)
	vt.tween_property(_vbox, "position:y", natural_y, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.1)

	var cards := _cards_container.get_children()
	for i in cards.size():
		var card := cards[i] as Control
		card.modulate.a = 0.0
		card.scale = Vector2(0.85, 0.85)
		card.pivot_offset = card.custom_minimum_size / 2.0
		var delay := 0.2 + i * 0.07
		var ct := create_tween().set_parallel()
		ct.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		ct.tween_property(card, "scale", Vector2.ONE, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)


func _on_card_selected(upgrade: Resource) -> void:
	GameManager.apply_upgrade(upgrade)
	_play_exit()


func _play_exit() -> void:
	var natural_y := _vbox.position.y
	var t := create_tween().set_parallel()
	t.tween_property(_vbox, "modulate:a", 0.0, 0.15)
	t.tween_property(_vbox, "position:y", natural_y - 20.0, 0.15).set_ease(Tween.EASE_IN)
	t.tween_property(_overlay, "modulate:a", 0.0, 0.2)
	await t.finished
	visible = false
	get_tree().paused = false
