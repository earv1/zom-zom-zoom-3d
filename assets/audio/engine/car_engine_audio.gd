## Engine audio component — attach as child of Car.
## Uses two engine samples (low/high) crossfaded and pitch-shifted
## across 5 virtual gear bands to simulate a full engine range.
extends Node

const CAR1_PATH  := "res://assets/audio/engine/car1/freesound_community-engine-47745.mp3"
const CAR2_PATH  := "res://assets/audio/engine/car2/tanweraman-car-throttle-static-337873.mp3"

# Speed thresholds where each virtual gear begins (units/s)
const GEAR_SPEEDS := [0.0, 20.0, 40.0, 65.0, 90.0]

# Pitch range within each gear band — rises from min to max then resets on shift
const PITCH_MIN  := 0.7
const PITCH_MAX  := 1.5
const FADE_SPEED := 5.0

# car2 fades in from this speed onward
const CROSSFADE_START := 40.0
const CROSSFADE_END   := 85.0

var _low:  AudioStreamPlayer
var _high: AudioStreamPlayer
var _car:  RigidBody3D
var _current_gear := 0


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	_low  = _make_looping_player(CAR1_PATH)
	_high = _make_looping_player(CAR2_PATH)
	_low.volume_db = 0.0


func _process(delta: float) -> void:
	if not _car:
		return

	var speed := _car.linear_velocity.length()
	_current_gear = _gear_for_speed(speed)

	# Pitch rises within the current gear band, resets at each shift
	var low_speed: float  = GEAR_SPEEDS[_current_gear]
	var high_speed: float = GEAR_SPEEDS[_current_gear + 1] \
		if _current_gear + 1 < GEAR_SPEEDS.size() \
		else GEAR_SPEEDS[-1] * 1.4
	var t     := clampf((speed - low_speed) / maxf(high_speed - low_speed, 0.001), 0.0, 1.0)
	var pitch := lerpf(PITCH_MIN, PITCH_MAX, t)
	_low.pitch_scale  = pitch
	_high.pitch_scale = pitch

	# Crossfade car1 → car2 with speed
	var blend: float       = clampf((speed - CROSSFADE_START) / (CROSSFADE_END - CROSSFADE_START), 0.0, 1.0)
	var target_low: float  = lerpf(0.0, -24.0, blend)
	var target_high: float = lerpf(-24.0, 0.0, blend)
	_low.volume_db  = lerpf(_low.volume_db,  target_low,  FADE_SPEED * delta)
	_high.volume_db = lerpf(_high.volume_db, target_high, FADE_SPEED * delta)


func _gear_for_speed(speed: float) -> int:
	var gear := 0
	for i in range(GEAR_SPEEDS.size() - 1, -1, -1):
		if speed >= GEAR_SPEEDS[i]:
			gear = i
			break
	return gear


func _make_looping_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		p.stream = stream
	p.volume_db = -80.0
	p.autoplay  = true
	add_child(p)
	return p
