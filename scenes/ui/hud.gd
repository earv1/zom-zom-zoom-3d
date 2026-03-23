class_name HUD
extends CanvasLayer

const NEAR_MISS_RADIUS := 5.0
const NEAR_MISS_XP := 10
const SHAKE_DURATION := 0.3
const SHAKE_INTENSITY := 8.0

const PopupTextScript := preload("res://scenes/ui/popup_text.gd")
const TrickInputDisplayScript := preload("res://scenes/ui/trick_input_display.gd")

@onready var _health_bar: ProgressBar = $HealthBar
@onready var _timer_label: Label = $XPLabels/TimerLabel
@onready var _level_label: Label = $XPLabels/LevelLabel
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _boost_container: VBoxContainer = $BoostContainer
@onready var _boost_bar: ProgressBar = $BoostContainer/BoostBar
@onready var _boost_label: Label = $BoostContainer/BoostLabel
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _game_over_screen: GameOverScreen = $GameOverScreen
@onready var _win_screen: CanvasLayer = $WinScreen
@onready var _speed_label: Label = $SpeedLabel

var _car_boost: CarBoost
var _car: RigidBody3D
var _health_tween: Tween
var _popup_text: Control
var _shake_timer := 0.0
var _near_miss_cooldowns: Dictionary = {}  # enemy instance_id -> float
var _trick_display: Control


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_up_triggered.connect(_on_level_up_triggered)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)

	_health_bar.max_value = GameManager.max_health
	_health_bar.value = GameManager.current_health
	_xp_bar.max_value = 100
	_xp_bar.value = 0

	var boosts := get_tree().get_nodes_in_group("car_boost")
	if boosts.size() > 0:
		_car_boost = boosts[0] as CarBoost
		_car = _car_boost.get_parent() as RigidBody3D
	_boost_container.visible = false

	_setup_popup_text()

	# Connect trick signals
	_setup_trick_display()
	if _car:
		var air_ctrl := _car.get_node_or_null("CarAirControl") as CarAirControl
		if air_ctrl:
			air_ctrl.trick_landed.connect(_on_trick_landed)
			air_ctrl.trick_input.connect(_trick_display.on_trick_input)
			air_ctrl.trick_sequence_reset.connect(_trick_display.on_sequence_reset)
			air_ctrl.trick_spin_started.connect(_trick_display.on_spin_started)
			air_ctrl.trick_spin_ended.connect(_trick_display.on_spin_ended)
		else:
			push_warning("HUD: CarAirControl not found on car")
	else:
		push_warning("HUD: _car is null, trick display signals not connected")


func _process(delta: float) -> void:
	var secs := int(GameManager.elapsed_time)
	_timer_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	_update_boost_bar()
	if _car:
		_speed_label.text = "%d km/h" % int(_car.linear_velocity.length() * 3.6)
		_check_near_misses(delta)
	_update_shake(delta)


# ── Popup Text ────────────────────────────────────────────────────────────────

func _setup_trick_display() -> void:
	_trick_display = Control.new()
	_trick_display.set_script(TrickInputDisplayScript)
	_trick_display.name = "TrickInputDisplay"
	_trick_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trick_display.size = get_viewport().get_visible_rect().size
	add_child(_trick_display)


func _setup_popup_text() -> void:
	_popup_text = Control.new()
	_popup_text.set_script(PopupTextScript)
	_popup_text.name = "PopupText"
	add_child(_popup_text)


func show_popup(text: String, color: Color = Color.WHITE) -> void:
	if _popup_text:
		_popup_text.show_text(text, color)


# ── Screen Shake ──────────────────────────────────────────────────────────────

func trigger_shake() -> void:
	_shake_timer = SHAKE_DURATION


func _update_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var intensity := (_shake_timer / SHAKE_DURATION) * SHAKE_INTENSITY
		offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
	else:
		offset = Vector2.ZERO


# ── Near-Miss XP ─────────────────────────────────────────────────────────────

func _check_near_misses(delta: float) -> void:
	# Expire cooldowns
	var expired: Array = []
	for id in _near_miss_cooldowns:
		_near_miss_cooldowns[id] -= delta
		if _near_miss_cooldowns[id] <= 0.0:
			expired.append(id)
	for id in expired:
		_near_miss_cooldowns.erase(id)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is RigidBody3D:
			continue
		if not (enemy as Node3D).visible:
			continue
		var eid := enemy.get_instance_id()
		if _near_miss_cooldowns.has(eid):
			continue
		var dist: float = (enemy as Node3D).global_position.distance_to(_car.global_position)
		if dist > NEAR_MISS_RADIUS and dist < NEAR_MISS_RADIUS + 3.0:
			GameManager.add_xp(NEAR_MISS_XP)
			show_popup("NEAR MISS +%d" % (NEAR_MISS_XP * 3), Color(1.0, 0.9, 0.2))
			_near_miss_cooldowns[eid] = 2.0  # cooldown per enemy


# ── Tricks ────────────────────────────────────────────────────────────────────

func _on_trick_landed(trick_name: String, spin_count: int) -> void:
	var xp := 50 * spin_count
	GameManager.add_xp(xp)
	show_popup("%s x%d  +%d" % [trick_name, spin_count, xp * 3], Color(0.3, 1.0, 0.8))


# ── Boost Bar ─────────────────────────────────────────────────────────────────

func _update_boost_bar() -> void:
	if not _car_boost:
		return

	if _car_boost.is_boosting:
		_boost_container.visible = true
		_boost_label.text = "BOOST!"
		_boost_bar.value = _car_boost.boost_timer / CarBoost.BOOST_DURATION
		_boost_bar.modulate = Color(0.2, 0.9, 1.0)
	elif _car_boost.hold_time > 0.0:
		_boost_container.visible = true
		var charge := _car_boost.hold_time / CarBoost.HOLD_REQUIRED
		_boost_bar.value = charge
		if charge >= 1.0:
			_boost_label.text = "RELEASE!"
			_boost_bar.modulate = Color(1.0, 0.85, 0.0)
		else:
			_boost_label.text = "BOOST"
			_boost_bar.modulate = Color(1.0, 0.5, 0.1)
	else:
		_boost_container.visible = false


# ── Health ────────────────────────────────────────────────────────────────────

func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	var took_damage := current < _health_bar.value
	var healed := current > _health_bar.value
	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(_health_bar, "value", float(current), 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if took_damage:
		_health_bar.modulate = Color(2.0, 0.4, 0.4)
		create_tween().tween_property(_health_bar, "modulate", Color.WHITE, 0.4)
		trigger_shake()
	elif healed:
		_health_bar.modulate = Color(0.4, 2.0, 0.4)
		create_tween().tween_property(_health_bar, "modulate", Color.WHITE, 0.5)
		show_popup("+%d HP" % HEAL_DISPLAY, Color(0.3, 1.0, 0.4))

# Used for heal popup display
const HEAL_DISPLAY := 25


func _on_xp_changed(current: int, to_next: int) -> void:
	_xp_bar.max_value = to_next
	create_tween().tween_property(_xp_bar, "value", float(current), 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_level_changed(new_level: int) -> void:
	_level_label.text = "Lv %d" % new_level


func _on_level_up_triggered(choices: Array) -> void:
	_level_up_screen.show_choices(choices)


func _on_game_over() -> void:
	_game_over_screen.show_screen()


func _on_game_won() -> void:
	_win_screen.show_screen()
