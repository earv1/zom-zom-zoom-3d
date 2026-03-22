class_name EnemySpawner
extends Node3D

@export var car: Node3D
@export var spawn_radius: float = 40.0

const MAX_ENEMIES := 100

var _timer: float = 0.0
var _pool: Array = []
var _inactive: Dictionary = {}  # pool_key (scene path) -> Array[BaseEnemy]
var _active_count: int = 0


func _ready() -> void:
	add_to_group("enemy_spawner")
	_pool = [
		{scene = preload("res://scenes/enemy/zombie.tscn"), weight = 1.0, unlock_time = 0.0},
		{scene = preload("res://scenes/enemy/runner.tscn"), weight = 0.6, unlock_time = 60.0},
		{scene = preload("res://scenes/enemy/tank.tscn"), weight = 0.3, unlock_time = 120.0},
		{scene = preload("res://scenes/enemy/exploder.tscn"), weight = 0.5, unlock_time = 180.0},
	]


const RAMP_DURATION := 10.0  # seconds before full spawn rate
const BATCH_MAX := 3

func _process(delta: float) -> void:
	_timer += delta
	var interval := maxf(0.3, 2.0 - GameManager.elapsed_time * 0.008)
	if _timer >= interval:
		_timer = 0.0
		var batch := clampi(int(lerpf(1.0, BATCH_MAX, GameManager.elapsed_time / RAMP_DURATION)), 1, BATCH_MAX)
		for i in batch:
			_spawn()


func _spawn() -> void:
	if _active_count >= MAX_ENEMIES:
		return

	var available: Array = _pool.filter(
		func(e: Variant) -> bool: return GameManager.elapsed_time >= (e as Dictionary).get("unlock_time", 0.0)
	)
	if available.is_empty():
		return

	var total_weight := 0.0
	for e in available:
		total_weight += e.weight

	var roll := randf() * total_weight
	var chosen: Dictionary = available[-1]
	for e in available:
		roll -= e.weight
		if roll <= 0.0:
			chosen = e
			break

	var spawn_dist := spawn_radius * 3.0
	var key: String = (chosen.get("scene") as PackedScene).resource_path
	var enemy: BaseEnemy

	if _inactive.has(key) and not (_inactive[key] as Array).is_empty():
		enemy = (_inactive[key] as Array).pop_back() as BaseEnemy
		enemy.drop_near(car.global_position, spawn_dist)
		enemy.reset_for_spawn(car)
	else:
		var enemy_scene := chosen.get("scene") as PackedScene
		enemy = enemy_scene.instantiate() as BaseEnemy
		enemy._spawner = self
		enemy.pool_key = key
		add_child(enemy)
		enemy.drop_near(car.global_position, spawn_dist)
		enemy.reset_for_spawn(car)

	_active_count += 1


func recycle(enemy: BaseEnemy) -> void:
	_active_count = maxi(0, _active_count - 1)
	enemy.visible = false
	enemy.process_mode = PROCESS_MODE_DISABLED
	enemy.freeze = true
	var key := enemy.pool_key
	if not _inactive.has(key):
		_inactive[key] = []
	(_inactive[key] as Array).append(enemy)
