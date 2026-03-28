class_name Runner
extends BaseEnemy

const RAT_COLOR := Color(0.55, 0.45, 0.38)
const TAIL_ANIM := "tail_wag"

@onready var _rat_model: Node3D = $RatModel
var _anim_player: AnimationPlayer


func _ready() -> void:
	super._ready()
	_apply_color()
	_anim_player = _rat_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_tail()


func _process(delta: float) -> void:
	super._process(delta)
	if car:
		var to_car := car.global_position - global_position
		to_car.y = 0.0
		if to_car.length_squared() > 0.01:
			_rat_model.look_at(global_position + to_car, Vector3.UP)


func reset_for_spawn(car_ref: Node3D) -> void:
	super.reset_for_spawn(car_ref)
	_play_tail()


func _apply_color() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = RAT_COLOR
	for mesh in _rat_model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = mat


func _play_tail() -> void:
	if _anim_player and _anim_player.has_animation(TAIL_ANIM):
		_anim_player.play(TAIL_ANIM)
