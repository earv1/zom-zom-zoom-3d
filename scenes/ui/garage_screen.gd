class_name GarageScreen
extends CanvasLayer
## Between-run garage: spend parts (banked from each run's scrap) on permanent
## upgrades from the "garage" rows of data/upgrades.csv.

signal closed

var _cards: Array[Button] = []
var _ids: Array[StringName] = []
var _parts_label: Label


func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(760, 0)
	root.position = Vector2(-380, -280)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_label("GARAGE", 40, Color(1.0, 0.85, 0.5)))
	_parts_label = _label("", 26, Color(0.6, 0.9, 1.0))
	root.add_child(_parts_label)
	root.add_child(_label("Each run banks part of the scrap you earn as parts. Upgrades here are permanent.", 15, Color(0.8, 0.8, 0.8)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for u in Economy.store_upgrades(&"garage"):
		var card := Button.new()
		card.custom_minimum_size = Vector2(370, 92)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 16)
		card.pressed.connect(_buy.bind(u.id))
		grid.add_child(card)
		_cards.append(card)
		_ids.append(u.id)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void: closed.emit(); queue_free())
	root.add_child(back)
	if not _cards.is_empty():
		_cards[0].grab_focus()
	_refresh()


func _buy(id: StringName) -> void:
	GameManager.buy(id)
	_refresh()


func _refresh() -> void:
	_parts_label.text = "PARTS  " + Num.short(GameManager.parts)
	for i in _cards.size():
		var u := Economy.upgrade(_ids[i])
		var why := GameManager.blocker(_ids[i])
		var price := "MAXED" if why == "maxed" else Num.short(GameManager.price_of(_ids[i])) + " parts"
		_cards[i].text = "%s  Lv %d/%d\n%s\n%s" % [u.name, GameManager.level_of(_ids[i]), u.max_level, u.description, price]
		_cards[i].modulate = Color(1, 0.6, 0.55) if why == "can't afford" else Color.WHITE


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
