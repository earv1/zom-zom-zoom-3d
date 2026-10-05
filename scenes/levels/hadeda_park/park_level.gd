class_name ParkLevel
extends Node3D
## Hadeda Park: roam the desert skatepark, race its ring road (laps and loops
## pay scrap) and spend at its stores. Drive through the summon panel when you're
## ready (difficulty keeps climbing meanwhile): an earthquake sinks the park, the
## dome shrinks round a boss arena and the next boss drops in:
## hadeda, then zadeda (pukes zombie rats), then cydeda (rats + eye laser).
## Beat a boss and the park rises again; beat cydeda to win.
## Debug builds: press 0 to summon the next boss from anywhere. Boss test mode
## (main menu): set `test_stage` and the level summons that boss straight away.

enum Phase { RACE, QUAKE_OUT, FIGHT, QUAKE_IN, WON }

const STAGES: Array[HadedaBoss.Stage] = [HadedaBoss.Stage.HADEDA, HadedaBoss.Stage.ZADEDA, HadedaBoss.Stage.CYDEDA]
const RACE_MUSIC := preload("res://assets/music/Desert Planet - Quincas Moreira.mp3")
const BOSS_MUSIC := preload("res://assets/music/Dark Start Hope.mp3")
const MUSIC_FADE := 2.0                     ## seconds to crossfade between songs
const PsxScreenScript := preload("res://scenes/ui/psx_screen.gd")
const ObjectiveMarkerScript := preload("res://scenes/ui/objective_marker.gd")
const ARENA_DOME_HEIGHT := 0.55            ## boss dome height / radius: rounder than the park dome
const DOME_FIT_TIME := 2.4

@export var car: RigidBody3D
@export var track: Node3D                 ## the instanced track scene (holds TrackRoot)
@export var landscape: DesertLandscape
@export var spawner: EnemySpawner
@export var start_grid: Marker3D
@export var checkpoints: Node3D            ## Marker3D children in lap order; the first is start/finish
@export var race_seconds := 0.0           ## > 0 brings the boss automatically after this long (tests)

var phase := Phase.RACE
var stage_index := 0
## Boss test mode: 0..2 (hadeda, zadeda, cydeda) summons that boss as soon as the
## level is up; -1 plays normally. Used once, then reset.
static var test_stage := -1
var race_clock := 0.0
var arena: BossArena
var dome: Node3D                           ## the park's glass dome: stays up, shrinks round boss arenas
var fight: BossFight

var _track_root: Node3D
var _dome_home := Transform3D.IDENTITY
var _dome_exits := 4
var _track_sink_depth := 40.0
var _shake := 0.0
var _shake_target := 0.0
var _kick := 0.0                 ## screen-only jolt from boss landings; decays fast, never rattles the car
var _rattle_timer := 0.0
var _dust: CPUParticles3D
var _music: AudioStreamPlayer               ## the song playing now (or fading in)
var _music_players: Array[AudioStreamPlayer] = []
var _music_fade: Tween
var _status: Label
var _banner: Label
var _flash: ColorRect
var _next_cp := -1                         # -1 = lap not started
var _lap_time := 0.0
var _best_lap := INF
var _laps := 0


func _ready() -> void:
	GameManager.reset()
	_track_root = track.get_node("TrackRoot")
	for piece in _track_root.get_children():   # the dome stays up when the park sinks
		if String(piece.name).begins_with("dome"):
			dome = piece
			dome.reparent(self)
			_dome_home = dome.global_transform
			_dome_exits = dome.get("exits")
			break
	_track_sink_depth = _track_height() + 6.0
	arena = BossArena.new()
	add_child(arena)
	_build_checkpoints()
	_build_loop_triggers()
	_setup_summon_panels()
	_build_dust()
	_build_ui()
	var psx := CanvasLayer.new()
	psx.set_script(PsxScreenScript)
	add_child(psx)
	for i in 2:                                 # two players so songs crossfade
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_linear = 0.0
		add_child(player)
		_music_players.append(player)
	_play_music(RACE_MUSIC)
	_reset_car()
	add_child(PauseMenu.new())               # P / Esc: pause, see your upgrades
	if test_stage >= 0:                       # boss test mode: straight to the fight
		stage_index = clampi(test_stage, 0, STAGES.size() - 1)
		test_stage = -1
		_arm_panels(true)
		get_tree().create_timer(1.0, false).timeout.connect(_start_boss)
	var warmup := ShaderWarmup.new()          # compile every shader now, not mid-race
	warmup.level = self
	warmup.car = car
	warmup.pool = spawner.pool
	add_child(warmup)


func _process(delta: float) -> void:
	_update_shake(delta)
	match phase:
		Phase.RACE:
			race_clock += delta
			if _next_cp >= 0:
				_lap_time += delta
			if race_seconds > 0.0 and race_clock >= race_seconds:
				_start_boss()
	_update_status()


func _physics_process(delta: float) -> void:
	if car.global_position.y < -25.0:        # safety net: fell out of the world
		_rescue_car()
	if _shake < 0.05:
		return
	_rattle_timer -= delta
	var air := car.get_node_or_null("CarAirControl") as CarAirControl
	if air and air.state != CarAirControl.State.GROUNDED:
		return                               # the ground shakes, not the air: no pumping a car upward
	if _rattle_timer <= 0.0:                 # earthquake rattles the car
		_rattle_timer = randf_range(0.06, 0.16)
		var kick := Vector3(randf_range(-0.15, 0.15), randf_range(0.3, 1.0), randf_range(-0.15, 0.15))
		car.apply_central_impulse(kick * car.mass * 1.6 * _shake)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.is_debug_build() and key and key.pressed and not key.echo and key.keycode == KEY_0 and phase == Phase.RACE:
		_start_boss()


# ── boss cycle ────────────────────────────────────────────────────────────────

func _setup_summon_panels() -> void:
	var marker := Control.new()
	marker.set_script(ObjectiveMarkerScript)
	get_node("HUD").add_child(marker)
	for panel in get_tree().get_nodes_in_group("summon_panels"):
		panel.summoned.connect(func() -> void:
			if phase == Phase.RACE:
				_start_boss())
		marker.call("add_objective", panel, Color(1.0, 0.3, 0.2), "SUMMON")
	_arm_panels(true)


func _arm_panels(armed: bool) -> void:
	for panel in get_tree().get_nodes_in_group("summon_panels"):
		panel.call("set_next", BossFight.NAMES[mini(stage_index, BossFight.NAMES.size() - 1)], armed)


func _start_boss() -> void:
	if phase != Phase.RACE:
		return
	_arm_panels(false)
	phase = Phase.QUAKE_OUT
	var stage_name: String = BossFight.NAMES[stage_index]
	_announce("THE GROUND TREMBLES...")
	_shake_target = 0.75
	_dust.emitting = true
	for store in get_tree().get_nodes_in_group("pit_stores"):
		store.call("leave")                  # nobody gets left parked in a sinking building
	car.linear_damp = 2.5                    # the quake bogs the car down
	spawner.process_mode = Node.PROCESS_MODE_DISABLED
	_swallow_enemies()
	_prepare_fight()                         # build the boss now, in the buried arena, while the quake plays
	await _wait(0.8)

	var sink := create_tween()
	sink.tween_property(_track_root, "position:y", -_track_sink_depth, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sink.finished
	_track_root.visible = false

	var center := _arena_center()
	var from_center := Vector2(car.global_position.x - center.x, car.global_position.z - center.z)
	if from_center.length() > arena.radius - 25.0:
		# the arena had to be pulled inward: bring the car inside it behind a flash
		var flash := create_tween()
		flash.tween_property(_flash, "color:a", 1.0, 0.25)
		await flash.finished
		var spot := from_center.normalized() * (arena.radius - 45.0)
		car.global_position = Vector3(center.x + spot.x, 1.5, center.z + spot.y)
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	arena.global_position = Vector3(center.x, arena.global_position.y, center.z)
	arena.ground_y = DesertLandscape.COLLISION_FLOOR_Y
	arena.rise(2.2)
	_fit_dome(Vector3(center.x, 0.0, center.z), arena.radius + BossArena.WALL_INNER, 0, ARENA_DOME_HEIGHT)   # glass meets the wall's inner face
	_announce(stage_name + " APPROACHES")
	await arena.risen
	_shake_target = 0.0
	_dust.emitting = false
	car.linear_damp = 0.0
	_play_music(BOSS_MUSIC)

	fight.global_position = Vector3(center.x, DesertLandscape.COLLISION_FLOOR_Y, center.z)
	fight.landed.connect(func() -> void: _burst(1.0))
	fight.defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
	fight.start()
	_set_camera_focus(fight.boss)
	phase = Phase.FIGHT


## Builds the next boss fight up front (model, hitbox, health bar, materials)
## and parks it inside the still-buried arena. It's drawn there behind the
## ground, so its shaders compile during the quake instead of freezing the
## frame the boss arrives (the web build hitches badly on first draws).
func _prepare_fight() -> void:
	var center := _arena_center()
	fight = BossFight.new()
	fight.stage = STAGES[stage_index]
	fight.car = car
	fight.arena_radius = arena.radius
	fight.auto_start = false
	add_child(fight)
	fight.global_position = Vector3(center.x, DesertLandscape.COLLISION_FLOOR_Y - BossArena.BURY - 18.0, center.z)   # deep enough that its head stays under the sand


func _on_boss_defeated() -> void:
	phase = Phase.QUAKE_IN
	_announce(BossFight.NAMES[stage_index] + " DEFEATED")
	_set_camera_focus(null)
	fight.queue_free()
	fight = null
	stage_index += 1
	if stage_index >= STAGES.size():
		phase = Phase.WON
		_play_music(RACE_MUSIC)
		GameManager.game_won.emit()
		return

	_shake_target = 0.6
	_dust.emitting = true
	arena.sink(2.0)
	_fit_dome(_dome_home.origin, -1.0, _dome_exits)
	await arena.sunk
	await _flash_white()                      # back to the start grid while the screen is white
	_track_root.visible = true
	var rise := create_tween()
	rise.tween_property(_track_root, "position:y", 0.0, 2.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await rise.finished
	_shake_target = 0.0
	_dust.emitting = false
	spawner.process_mode = Node.PROCESS_MODE_INHERIT
	_play_music(RACE_MUSIC)
	race_clock = 0.0
	phase = Phase.RACE
	_arm_panels(true)
	_announce("SUMMON PANEL READY: " + BossFight.NAMES[stage_index])


## Moves and scales the dome so it encloses a circle of `radius` round
## `centre` (radius < 0 = back to full size). Centre and radius change together,
## so anything inside the start and end domes stays inside the whole way.
## Moves/scales the dome to `radius` (or home with radius < 0). height_ratio,
## if given, sets its height as a fraction of that radius (stretching it taller).
func _fit_dome(centre: Vector3, radius: float, exits: int, height_ratio := -1.0) -> void:
	if not dome:
		return
	var full: float = dome.get("radius")
	var s := 1.0 if radius < 0.0 else radius / full
	var target_scale := Vector3.ONE * s
	if radius >= 0.0 and height_ratio > 0.0:
		target_scale.y = height_ratio * radius / float(dome.get("height"))
	if exits == 0:
		dome.call("set_exits", 0)              # a small arena gets no way out
	var tw := create_tween().set_parallel()
	tw.tween_property(dome, "global_position", Vector3(centre.x, _dome_home.origin.y, centre.z), DOME_FIT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(dome, "scale", target_scale, DOME_FIT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if exits > 0:
		tw.chain().tween_callback(dome.call.bind("set_exits", exits))


func _arena_center() -> Vector3:
	var fwd := -car.global_basis.z
	fwd.y = 0.0
	var c := car.global_position + fwd.normalized() * 30.0
	var lim := landscape.play_half + Vector2.ONE * landscape.flat_margin - Vector2.ONE * (arena.radius + 12.0)
	c.x = clampf(c.x, landscape.play_center.x - lim.x, landscape.play_center.x + lim.x)
	c.z = clampf(c.z, landscape.play_center.y - lim.y, landscape.play_center.y + lim.y)
	if dome:                                  # keep the whole arena inside the park's dome
		var home := Vector2(_dome_home.origin.x, _dome_home.origin.z)
		var room: float = float(dome.get("radius")) - float(dome.get("transition")) - arena.radius - BossArena.WALL_INNER
		var off := Vector2(c.x, c.z) - home
		if off.length() > room:
			off = off.normalized() * maxf(room, 0.0)
			c.x = home.x + off.x
			c.z = home.y + off.y
	return Vector3(c.x, DesertLandscape.COLLISION_FLOOR_Y, c.z)


func _swallow_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEnemy and (e as BaseEnemy).visible:
			(e as BaseEnemy).die()


func _rescue_car() -> void:
	if phase == Phase.FIGHT and is_instance_valid(fight):
		car.global_position = fight.global_position + Vector3(0.0, 2.0, arena.radius * 0.5)
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
	else:
		_reset_car()


func _reset_car() -> void:
	car.global_transform = start_grid.global_transform
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	_next_cp = -1
	_lap_time = 0.0


# ── laps ──────────────────────────────────────────────────────────────────────

func _build_checkpoints() -> void:
	var markers := checkpoints.get_children()
	for i in markers.size():
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(34.0, 10.0, 3.0)          # spans a 24 m road plus margin
		cs.shape = box
		cs.position.y = 4.0
		area.add_child(cs)
		(markers[i] as Node3D).add_child(area)
		area.body_entered.connect(_on_checkpoint.bind(i))


## A trigger at the top of every loop in the park pays out for going all the way round.
func _build_loop_triggers() -> void:
	for piece in _track_root.get_children():
		if not String(piece.name).begins_with("loop"):
			continue
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(10.0, 6.0, 14.0)
		cs.shape = box
		area.add_child(cs)
		piece.add_child(area)
		var radius: float = piece.get("radius") if piece.get("radius") != null else 18.0
		area.position = Vector3(0.0, radius * 2.0, 4.0)
		area.body_entered.connect(func(body: Node) -> void:
			if body == car and phase == Phase.RACE:
				GameManager.earn(&"loop")
				_announce("LOOP!"))


func _on_checkpoint(body: Node, index: int) -> void:
	if body != car or phase != Phase.RACE:
		return
	var count := checkpoints.get_child_count()
	if index == 0 and (_next_cp == -1 or _next_cp == 0):
		if _next_cp == 0:
			_laps += 1
			var best := _lap_time < _best_lap
			_best_lap = minf(_best_lap, _lap_time)
			GameManager.earn(&"lap")
			_announce("LAP %.1fs" % _lap_time + ("  BEST!" if best else ""))
		_lap_time = 0.0
		_next_cp = 1 % count
	elif index == _next_cp:
		_next_cp = (index + 1) % count


# ── juice ─────────────────────────────────────────────────────────────────────

func _update_shake(delta: float) -> void:
	_shake = move_toward(_shake, _shake_target, delta * 1.2)
	_kick = move_toward(_kick, 0.0, delta * 2.5)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var amount := maxf(_shake, _kick) if GameManager.screen_shake else 0.0   # the setting gates every screen shake
		var t := Time.get_ticks_msec() * 0.001
		cam.h_offset = (sin(t * 37.0) + 0.5 * sin(t * 23.0 + 2.0)) * 0.45 * amount
		cam.v_offset = (sin(t * 41.0 + 1.3) + 0.5 * sin(t * 29.0)) * 0.45 * amount


func _set_camera_focus(node: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and "focus" in cam:
		cam.focus = node


## A short screen jolt (boss landings, stomps). Screen only: it never moves the car.
func _burst(strength: float) -> void:
	_kick = maxf(_kick, strength)


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 180
	_dust.lifetime = 2.6
	_dust.emitting = false
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(70, 0.5, 70)
	_dust.direction = Vector3.UP
	_dust.spread = 35.0
	_dust.gravity = Vector3(0, -0.5, 0)
	_dust.initial_velocity_min = 1.5
	_dust.initial_velocity_max = 5.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 6.0
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.82, 0.66, 0.46, 0.28)
	quad.material = mat
	_dust.mesh = quad
	car.add_child.call_deferred(_dust)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.position = Vector2(-300, 12)
	_status.custom_minimum_size = Vector2(600, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	ui.add_child(_status)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-500, -140)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	ui.add_child(_banner)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash)


func _update_status() -> void:
	match phase:
		Phase.RACE:

			var lap := "LAP %d  %.1fs" % [_laps + 1, _lap_time] if _next_cp >= 0 else "CROSS THE START LINE"
			var best := "   BEST %.1fs" % _best_lap if _best_lap < INF else ""
			_status.text = "DRIVE THROUGH THE SUMMON PANEL TO FACE %s\n%s%s" % [BossFight.NAMES[stage_index], lap, best]
		Phase.FIGHT, Phase.QUAKE_OUT, Phase.QUAKE_IN:
			_status.text = ""
		Phase.WON:
			_status.text = "ALL THREE HADEDAS DEFEATED"


func _announce(text: String) -> void:
	_banner.text = text
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _flash_white() -> void:
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 1.0, 0.35)
	await tw.finished
	_reset_car()
	var back := create_tween()
	back.tween_property(_flash, "color:a", 0.0, 0.6)


## Crossfades to `stream`: the new song fades in on the free player while the
## old one fades out and stops. The first song fades in from silence.
func _play_music(stream: AudioStream) -> void:
	if _music and _music.stream == stream and _music.playing:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var old := _music
	_music = _music_players[1] if old == _music_players[0] else _music_players[0]
	if _music_fade:
		_music_fade.kill()
	_music.stream = stream
	_music.volume_linear = 0.0
	_music.play()
	_music_fade = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # fades finish on pause screens too
	_music_fade.tween_property(_music, "volume_linear", 1.0, MUSIC_FADE).set_trans(Tween.TRANS_SINE)
	if old and old.playing:
		_music_fade.tween_property(old, "volume_linear", 0.0, MUSIC_FADE).set_trans(Tween.TRANS_SINE)
		_music_fade.chain().tween_callback(old.stop)


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


func _track_height() -> float:
	var top := 0.0
	for mi in _track_root.find_children("*", "MeshInstance3D", true, false):
		var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)
	return top
