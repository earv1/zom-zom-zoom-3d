class_name LevelUpScreen
extends CanvasLayer

@onready var _cards_container: HBoxContainer = $VBox/CardsContainer

var _card_scene: PackedScene = preload("res://scenes/ui/upgrade_card.tscn")


func show_choices(choices: Array) -> void:
	if choices.is_empty():
		return
	visible = true
	get_tree().paused = true

	for child in _cards_container.get_children():
		child.queue_free()

	for upgrade in choices:
		var card: UpgradeCard = _card_scene.instantiate()
		_cards_container.add_child(card)
		card.setup(upgrade)
		card.card_selected.connect(_on_card_selected)


func _on_card_selected(upgrade: Resource) -> void:
	GameManager.apply_upgrade(upgrade)
	visible = false
	get_tree().paused = false
