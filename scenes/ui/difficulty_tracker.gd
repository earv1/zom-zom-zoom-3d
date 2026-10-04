class_name DifficultyTracker
extends Control
## Risk-of-Rain-style difficulty tracker: one segment per tier (past tiers full,
## the current one filling), the tier's name and the run time. Colours run from
## calm teal to NITROUS violet.

const COLORS: Array[Color] = [
	Color(0.35, 0.85, 0.75), Color(0.45, 0.85, 0.45), Color(0.75, 0.85, 0.3), Color(0.95, 0.8, 0.25),
	Color(1.0, 0.6, 0.2), Color(1.0, 0.4, 0.2), Color(0.95, 0.2, 0.2), Color(0.85, 0.15, 0.35),
	Color(0.65, 0.15, 0.55), Color(0.6, 0.3, 1.0),
]
const SEG_W := 22.0
const SEG_H := 10.0
const GAP := 3.0

var _segments: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _name: Label
var _time: Label
var _last_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := Economy.tier_names().size()
	for i in count:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.45)
		bg.position = Vector2(i * (SEG_W + GAP), 0)
		bg.size = Vector2(SEG_W, SEG_H)
		add_child(bg)
		var fill := ColorRect.new()
		fill.color = COLORS[i % COLORS.size()]
		fill.size = Vector2(0, SEG_H)
		bg.add_child(fill)
		_segments.append(bg)
		_fills.append(fill)
	_name = _label(20)
	_name.position = Vector2(0, SEG_H + 4)
	_time = _label(16)
	_time.position = Vector2(0, SEG_H + 30)
	custom_minimum_size = Vector2(count * (SEG_W + GAP), SEG_H + 50)


func _process(_delta: float) -> void:
	var tier := GameManager.difficulty_tier()
	var index: int = tier.index
	for i in _fills.size():
		var amount := 1.0 if i < index else (float(tier.progress) if i == index else 0.0)
		_fills[i].size.x = SEG_W * amount
	_name.text = tier.name
	_name.add_theme_color_override("font_color", COLORS[index % COLORS.size()])
	if index != _last_index:
		if _last_index >= 0:
			_name.scale = Vector2.ONE * 1.35                # tier up!
			_name.pivot_offset = Vector2(0, 12)
			create_tween().tween_property(_name, "scale", Vector2.ONE, 0.4)
		_last_index = index
	var secs := int(GameManager.elapsed_time)
	_time.text = "%02d:%02d   x%.2f" % [secs / 60, secs % 60, GameManager.difficulty_coefficient()]


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l
