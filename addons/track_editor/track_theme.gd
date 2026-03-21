@tool
extends RefCounted

class_name TrackTheme

const MODE_LINES := 0
const MODE_BLANK := 1
const MODE_COLORFUL := 2

const ROAD_COLOR := Color(0.22, 0.22, 0.22)
const LINE_COLOR := Color(0.96, 0.96, 0.96)
const SIDE_COLORS := {
	"yellow": Color(0.9, 0.9, 0.2),
	"red": Color(0.88, 0.2, 0.2),
	"blue": Color(0.2, 0.45, 0.9),
}

static func road_material(mode: int, side_color_name: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = side_color(side_color_name) if mode == MODE_COLORFUL else ROAD_COLOR
	return mat

static func side_material(side_color_name: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = side_color(side_color_name)
	return mat

static func line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LINE_COLOR
	return mat

static func side_color(side_color_name: String) -> Color:
	return SIDE_COLORS.get(side_color_name, SIDE_COLORS["yellow"])

static func show_sides(mode: int) -> bool:
	return mode != MODE_BLANK

static func show_lines(mode: int) -> bool:
	return mode == MODE_LINES
