@tool
extends RefCounted

class_name TrackTheme

const ROAD_COLOR := Color(0.22, 0.22, 0.22)
const STUNT_ROAD_COLOR := Color(0.28, 0.22, 0.22)
const KERB_COLOR := Color(0.9, 0.9, 0.2)

static func road_material(stunt: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STUNT_ROAD_COLOR if stunt else ROAD_COLOR
	return mat

static func kerb_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = KERB_COLOR
	return mat
