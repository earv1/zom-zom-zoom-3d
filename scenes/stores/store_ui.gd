class_name StoreUI
extends CanvasLayer
## Store shelf shown while parked in a PitStore bay. The game keeps running.
## turn_left / turn_right pick a card, jump or ui_accept buys it (or click it),
## accelerate drives out.

signal closed

const COLUMNS := 4

var title := "STORE"
var items: Array[StringName] = []

var _selected := 0
var _cards: Array[Button] = []
var _scrap_label: Label


func _ready() -> void:
	layer = 5
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(980, 0)
	root.position = Vector2(-490, -260)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(_label(title, 34, Color(1.0, 0.85, 0.5)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_scrap_label = _label("", 28, Color(1.0, 0.92, 0.4))
	head.add_child(_scrap_label)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for i in items.size():
		var card := Button.new()
		card.custom_minimum_size = Vector2(236, 118)
		card.focus_mode = Control.FOCUS_NONE
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 15)
		card.pressed.connect(_buy.bind(i))
		card.mouse_entered.connect(func() -> void: _select(i))
		grid.add_child(card)
		_cards.append(card)
	if items.is_empty():
		root.add_child(_label("Sold out!", 22, Color.WHITE))

	root.add_child(_label("← →  choose     SPACE / ENTER  buy     ACCELERATE  drive out (momentum kept)", 16, Color(0.85, 0.85, 0.85)))
	GameManager.scrap_changed.connect(_refresh.unbind(1))
	_refresh()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("accelerate"):
		closed.emit()
		return
	if _cards.is_empty():
		return
	if Input.is_action_just_pressed("turn_left"):
		_select(posmod(_selected - 1, _cards.size()))
	elif Input.is_action_just_pressed("turn_right"):
		_select(posmod(_selected + 1, _cards.size()))
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		_buy(_selected)


func _select(i: int) -> void:
	_selected = i
	_refresh()


func _buy(i: int) -> void:
	_select(i)
	var card := _cards[i]
	if GameManager.buy(items[i]):
		card.scale = Vector2.ONE * 1.08
		card.pivot_offset = card.size * 0.5
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.18)
	else:
		var tw := create_tween()
		tw.tween_property(card, "position:x", card.position.x + 8.0, 0.04)
		tw.tween_property(card, "position:x", card.position.x - 8.0, 0.08)
		tw.tween_property(card, "position:x", card.position.x, 0.04)
	_refresh()


func _refresh() -> void:
	_scrap_label.text = "SCRAP " + Num.short(GameManager.scrap)
	for i in _cards.size():
		var id := items[i]
		var u := Economy.upgrade(id)
		var level := GameManager.level_of(id)
		var why := GameManager.blocker(id)
		var price := "MAXED" if why == "maxed" else ("OWNED" if why == "owned" else Num.short(GameManager.price_of(id)) + " scrap")
		if why == "needs weapon":
			price = "NEEDS WEAPON"
		var lv := "" if u.max_level <= 1 else "  Lv %d/%d" % [level, u.max_level]
		_cards[i].text = "%s%s\n%s\n%s" % [u.name, lv, u.description, price]
		var c := Color.WHITE
		if why == "can't afford":
			c = Color(1.0, 0.55, 0.5)
		elif why != "":
			c = Color(0.6, 0.6, 0.6)
		_cards[i].add_theme_color_override("font_color", c)
		_cards[i].add_theme_color_override("font_hover_color", c)
		_cards[i].modulate = Color(1.25, 1.15, 0.85) if i == _selected else Color.WHITE


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
