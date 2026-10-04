class_name EnemySpawner
extends Node3D

@export var car: Node3D
@export var spawn_radius: float = 40.0
@export var pool: Array[EnemyEntry] = []
## Scales the horde: the active cap, batch size and every per-type cap
## (each kept at least 1). 0.1 = a tenth of the base horde.
@export var spawn_multiplier := 0.1

const MAX_ENEMIES := 100          # before spawn_multiplier

var _timer: float = 0.0
var _inactive: Dictionary = {}  # pool_key (scene path) -> Array[BaseEnemy]
var _active_count: int = 0
var _active_per_type: Dictionary = {}  # pool_key -> int


func _ready() -> void:
	add_to_group("enemy_spawner")


const RAMP_DURATION := 10.0  # seconds before full spawn rate
const BATCH_MAX := 3

func _process(delta: float) -> void:
	_timer += delta
	var interval := maxf(0.3, 2.0 - GameManager.elapsed_time * 0.008)
	if _timer >= interval:
		_timer = 0.0
		var batch_max := maxi(1, roundi(BATCH_MAX * spawn_multiplier))
		var batch := clampi(int(lerpf(1.0, batch_max, GameManager.elapsed_time / RAMP_DURATION)), 1, batch_max)
		for i in batch:
			_spawn()


func _spawn() -> void:
	if _active_count >= maxi(1, roundi(MAX_ENEMIES * spawn_multiplier * GameManager.enemy_scale("enemy_count_exp"))):
		return

	var available: Array = pool.filter(
		func(e: EnemyEntry) -> bool: return GameManager.elapsed_time >= e.unlock_time
	)
	if available.is_empty():
		return

	var total_weight := 0.0
	for e in available:
		total_weight += (e as EnemyEntry).weight

	var roll := randf() * total_weight
	var chosen: EnemyEntry = available[-1]
	for e in available:
		roll -= (e as EnemyEntry).weight
		if roll <= 0.0:
			chosen = e
			break

	var spawn_dist := spawn_radius * 3.0
	var key: String = chosen.scene.resource_path

	if chosen.max_active >= 0 and _active_per_type.get(key, 0) >= maxi(1, ceili(chosen.max_active * spawn_multiplier)):
		return

	var enemy: BaseEnemy

	if _inactive.has(key) and not (_inactive[key] as Array).is_empty():
		enemy = (_inactive[key] as Array).pop_back() as BaseEnemy
		enemy.drop_near(car.global_position, spawn_dist)
		enemy.reset_for_spawn(car)
	else:
		enemy = chosen.scene.instantiate() as BaseEnemy
		enemy._spawner = self
		enemy.pool_key = key
		add_child(enemy)
		enemy.drop_near(car.global_position, spawn_dist)
		enemy.reset_for_spawn(car)

	_active_count += 1
	_active_per_type[key] = _active_per_type.get(key, 0) + 1


func recycle(enemy: BaseEnemy) -> void:
	_active_count = maxi(0, _active_count - 1)
	enemy.visible = false
	enemy.process_mode = PROCESS_MODE_DISABLED
	enemy.freeze = true
	enemy.collision_layer = 0                 # a hidden, frozen enemy must not be an invisible wall
	enemy.collision_mask = 0
	var key := enemy.pool_key
	_active_per_type[key] = maxi(0, _active_per_type.get(key, 0) - 1)
	if not _inactive.has(key):
		_inactive[key] = []
	(_inactive[key] as Array).append(enemy)
