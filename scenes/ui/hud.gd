class_name HUD
extends CanvasLayer

@onready var _health_bar: ProgressBar = $TopBar/HealthBar
@onready var _timer_label: Label = $TopBar/TimerLabel
@onready var _level_label: Label = $TopBar/LevelLabel
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _level_up_screen: LevelUpScreen = $LevelUpScreen
@onready var _game_over_screen: GameOverScreen = $GameOverScreen


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


func _process(_delta: float) -> void:
	var secs := int(GameManager.elapsed_time)
	_timer_label.text = "  %02d:%02d" % [secs / 60, secs % 60]


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
