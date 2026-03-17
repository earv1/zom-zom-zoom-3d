class_name HUD
extends CanvasLayer

@onready var _health_bar: ProgressBar = $HealthBar
@onready var _timer_label: Label = $XPLabels/TimerLabel
@onready var _level_label: Label = $XPLabels/LevelLabel
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _boost_container: VBoxContainer = $BoostContainer
@onready var _boost_bar: ProgressBar = $BoostContainer/BoostBar
@onready var _boost_label: Label = $BoostContainer/BoostLabel
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _game_over_screen: GameOverScreen = $GameOverScreen
@onready var _speed_label: Label = $SpeedLabel

var _car_boost: CarBoost
var _car: RigidBody3D


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_up_triggered.connect(_on_level_up_triggered)
	GameManager.game_over.connect(_on_game_over)

	_health_bar.max_value = GameManager.max_health
	_health_bar.value = GameManager.current_health
	_xp_bar.max_value = 100
	_xp_bar.value = 0

	var boosts := get_tree().get_nodes_in_group("car_boost")
	if boosts.size() > 0:
		_car_boost = boosts[0] as CarBoost
		_car = _car_boost.get_parent() as RigidBody3D
	_boost_container.visible = false


func _process(_delta: float) -> void:
	var secs := int(GameManager.elapsed_time)
	_timer_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	_update_boost_bar()
	if _car:
		_speed_label.text = "%d km/h" % int(_car.linear_velocity.length() * 3.6)


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


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_xp_changed(current: int, to_next: int) -> void:
	_xp_bar.max_value = to_next
	_xp_bar.value = current


func _on_level_changed(new_level: int) -> void:
	_level_label.text = "Lv %d" % new_level


func _on_level_up_triggered(choices: Array) -> void:
	_level_up_screen.show_choices(choices)


func _on_game_over() -> void:
	_game_over_screen.show_screen()
