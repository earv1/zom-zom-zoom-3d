class_name HadedaBoss
extends Node3D
## Three-stage hadeda boss: hadeda (healthy) -> zadeda (zombie) -> cydeda (cyborg zombie).
##
## All stages share one rig and the same clip names, so any attack plays on any
## stage; only cydeda has the eye laser. Models face +Z. Clips, timings and hit
## windows come from the Blender build (test/model_test/hadeda_boss/attacks.py).

signal stage_changed(new_stage: Stage)
signal attack_finished(clip: StringName)

enum Stage { HADEDA, ZADEDA, CYDEDA }

const STAGE_MODELS: Array[PackedScene] = [
	preload("res://models/bosses/hadeda/hadeda.glb"),
	preload("res://models/bosses/hadeda/zadeda.glb"),
	preload("res://models/bosses/hadeda/cydeda.glb"),
]
const LOOPING_CLIPS: Array[StringName] = [&"idle", &"walk", &"laser_fire", &"fly"]
const ATTACKS: Array[StringName] = [&"peck_combo", &"wing_slam", &"drill_burrow", &"puke", &"stomp", &"beak_stab", &"scream"]
## Blender frames (24 fps, frame 1 = t 0) when each attack's hitbox should be live.
const HIT_FRAMES := {
	&"peck_combo": [Vector2i(10, 12), Vector2i(19, 21), Vector2i(30, 33)],
	&"wing_slam": [Vector2i(21, 26)],
	&"drill_burrow": [Vector2i(25, 50)],
}
## The walk is in place: move the boss at this many model units per second
## (times its scale) while "walk" plays, or the feet slide.
const WALK_SPEED := 0.677
## Per-stage voice (clean / raspy zombie / robot), rebuilt by tools/make_hadeda_sfx.sh.
## [short call for attacks, long scream for intro / leaps / death].
const VOICES: Array = [
	[preload("res://assets/audio/boss/hadeda_call.wav"), preload("res://assets/audio/boss/hadeda_scream.wav")],
	[preload("res://assets/audio/boss/zadeda_call.wav"), preload("res://assets/audio/boss/zadeda_scream.wav")],
	[preload("res://assets/audio/boss/cydeda_call.wav"), preload("res://assets/audio/boss/cydeda_scream.wav")],
]
const VOICE_GAP := 1.2                   ## min seconds between attack calls, so combos don't spam

@export var stage := Stage.HADEDA:
	set = set_stage
@export var target: Node3D:
	set = set_target
@export var turn_speed := 2.0            ## rad/s while turning to face the laser circle
@export var laser_duration := 3.0

var laser: EyeLaser

var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _eye_bone := -1
var _voice: AudioStreamPlayer3D
var _voice_ready_at := 0.0


func _ready() -> void:
	laser = EyeLaser.new()
	laser.target = target
	laser.origin = eye_position
	laser.state_changed.connect(_on_laser_state)
	add_child(laser)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 40.0              # it's a giant bird: audible across the arena
	_voice.max_db = 6.0
	_voice.max_distance = 600.0
	_voice.position.y = 6.0
	add_child(_voice)
	_spawn_model()


func _process(delta: float) -> void:
	if laser.is_active():
		_face(laser.circle_center, delta)


func set_stage(value: Stage) -> void:
	stage = value
	if not is_inside_tree():
		return
	laser.stop()
	_spawn_model()
	stage_changed.emit(stage)


func set_target(value: Node3D) -> void:
	target = value
	if laser:
		laser.target = value


func has_laser() -> bool:
	return stage == Stage.CYDEDA


## Plays an attack (or any clip) and returns to idle when it ends.
func play(clip: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if not _anim.has_animation(clip):
		push_warning("HadedaBoss: no clip '%s' on stage %s" % [clip, Stage.keys()[stage]])
		return
	_anim.play(clip, blend, speed)
	if clip == &"scream":
		_say(1, true)
	elif clip in ATTACKS or clip == &"laser_charge":
		_say(0, false)


## Plays the stage's call (0) or scream (1). A scream cuts off a call; nothing
## cuts off a scream; calls wait VOICE_GAP between each other.
func _say(kind: int, force: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var stream: AudioStream = VOICES[stage][kind]
	var screaming: bool = _voice.playing and _voice.stream == VOICES[stage][1]
	if screaming or (not force and now < _voice_ready_at):
		return
	_voice.stream = stream
	_voice.pitch_scale = randf_range(0.92, 1.08)
	_voice.play()
	_voice_ready_at = now + VOICE_GAP


func fire_laser(duration: float = -1.0) -> void:
	if not has_laser():
		push_warning("HadedaBoss: only cydeda has the eye laser")
		return
	if laser.is_active():
		return
	laser.charge_time = _anim.get_animation(&"laser_charge").length
	play(&"laser_charge")
	laser.start(duration if duration > 0.0 else laser_duration)


func current_clip() -> StringName:
	return _anim.current_animation


## Current position in the clip as a Blender frame (24 fps, frame 1 = t 0).
func clip_frame() -> float:
	return _anim.current_animation_position * 24.0 + 1.0


## Index of the current attack's live hit window, or -1 when none is live.
func hit_window() -> int:
	var clip := current_clip()
	if not HIT_FRAMES.has(clip):
		return -1
	var frame := clip_frame()
	var windows: Array = HIT_FRAMES[clip]
	for i in windows.size():
		var window: Vector2i = windows[i]
		if frame >= window.x and frame <= window.y:
			return i
	return -1


## True while the current attack's hitbox should be live.
func is_hit_live() -> bool:
	return hit_window() >= 0


## Global position of a rig bone (e.g. "drill" for the beak tip, "jaw", "hand.R").
func bone_position(bone: String) -> Vector3:
	var idx := _skeleton.find_bone(bone)
	if idx < 0:
		return global_position
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(idx).origin


## Global position of the eye laser socket (the cyborg optic).
func eye_position() -> Vector3:
	if _eye_bone < 0:
		return global_position
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_eye_bone).origin


func _spawn_model() -> void:
	if _model:
		_model.queue_free()
	_model = STAGE_MODELS[stage].instantiate()
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_eye_bone = _skeleton.find_bone("laser_eye")
	for clip in LOOPING_CLIPS:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_on_clip_finished)
	_anim.play(&"idle")


func _on_clip_finished(clip: StringName) -> void:
	if clip in LOOPING_CLIPS or clip == &"laser_charge":
		return
	_anim.play(&"idle", 0.25)
	attack_finished.emit(clip)


func _on_laser_state(new_state: EyeLaser.State) -> void:
	match new_state:
		EyeLaser.State.FIRE:
			play(&"laser_fire", 0.05)
		EyeLaser.State.END:
			play(&"laser_end", 0.1)


func _face(point: Vector3, delta: float) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(d.x, d.z), turn_speed * delta)
