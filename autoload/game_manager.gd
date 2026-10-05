extends Node

## Run state + the scrap economy. Everything that scores calls earn(); upgrades
## are bought at stores (diner / sky workshop / petrol station) with scrap, or in
## the garage with parts that persist between runs. Balance numbers live in the
## data/*.csv tables (see Economy); nothing levels up automatically any more.

const SAVE_PATH := "user://garage.cfg"

## Player setting: every screen shake (quakes, boss landings, ground pounds)
## checks this. Anything new that shakes the screen must too.
var screen_shake := true
## Best completion time (seconds) per skill track id, saved with the garage.
var skill_bests: Dictionary = {}

var elapsed_time: float = 0.0
var current_health: int = 100
var max_health: int = 100
var enemies_killed: int = 0

# legacy stat fields still read by weapons; kept in sync with `stats`
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
# legacy XP fields (the old level-up loop is gone; the HUD still reads these)
var current_level: int = 1
var current_xp: int = 0

var unlocked_weapons: Array[StringName] = [&"front_gun"]
var weapon_levels: Dictionary = {}

var scrap: int = 0
var run_scrap: int = 0                     ## total earned this run (drives banking)
var parts: int = 0                         ## persistent garage currency
var combo_count: int = 0
var combo_time_left: float = 0.0
var bosses_defeated: int = 0
var invulnerable := false                  ## e.g. while parked in a store bay
var stats: Dictionary = {}
var run_levels: Dictionary = {}            ## upgrade id -> level bought this run
var meta_levels: Dictionary = {}           ## garage upgrade id -> level (saved)

var _is_game_over: bool = false
var _regen_carry := 0.0
var _banked := false

signal xp_changed(current: int, to_next: int)
signal level_changed(new_level: int)
signal health_changed(current: int, maximum: int)
signal level_up_triggered(choices: Array)
signal game_over()
signal game_won()
signal weapon_unlocked(id: StringName, scene: PackedScene)
signal weapon_leveled_up(id: StringName)
signal scrap_changed(scrap: int)
signal scrap_earned(amount: int, source: StringName, multiplier: float)
signal combo_changed(count: int, multiplier: float)
signal upgrade_bought(id: StringName, level: int)
signal parts_changed(parts: int)
signal run_banked(parts_earned: int)


## Gamepad (and the code-only keyboard keys) for every action. Stick up/down
## double as throttle/brake past STICK_PRESS, so a spin is the same stick roll
## as W A S D, and steering on the diagonal doesn't brake.
const STICK_PRESS := 0.6
const BINDINGS := {
	"accelerate": [["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	"decelerate": [["axis", JOY_AXIS_TRIGGER_LEFT, 1.0], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	"turn_left": [["axis", JOY_AXIS_LEFT_X, -1.0]],
	"turn_right": [["axis", JOY_AXIS_LEFT_X, 1.0]],
	"jump": [["button", JOY_BUTTON_A]],
	"handbreak": [["button", JOY_BUTTON_B], ["button", JOY_BUTTON_RIGHT_SHOULDER]],
	"dive": [["key", KEY_CTRL], ["button", JOY_BUTTON_LEFT_SHOULDER]],
	"respawn": [["key", KEY_R], ["button", JOY_BUTTON_Y]],
	"restart_skill": [["key", KEY_BACKSPACE], ["button", JOY_BUTTON_BACK]],
	"pause": [["key", KEY_P], ["key", KEY_ESCAPE], ["button", JOY_BUTTON_START]],
}


func _ready() -> void:
	_bind_controls()
	_load_meta()
	_recompute_stats()
	game_over.connect(bank_run)
	game_won.connect(bank_run)


func _process(delta: float) -> void:
	if _is_game_over:
		return
	elapsed_time += delta
	if combo_count > 0:
		combo_time_left -= delta
		if combo_time_left <= 0.0:
			_set_combo(0)
	var regen: float = stats.get("regen", 0.0)
	if regen > 0.0 and current_health < max_health:
		_regen_carry += regen * delta
		if _regen_carry >= 1.0:
			var heal := int(_regen_carry)
			_regen_carry -= heal
			current_health = mini(current_health + heal, max_health)
			health_changed.emit(current_health, max_health)


# ── difficulty (Risk of Rain style) ───────────────────────────────────────────

## Climbs with time and with every boss beaten; scales the enemies.
func difficulty_coefficient() -> float:
	var minutes := elapsed_time / 60.0
	return (1.0 + Economy.difficulty("rate_per_minute") * minutes) * pow(Economy.difficulty("boss_factor"), bosses_defeated)


## coefficient ^ <key> from difficulty.csv, e.g. enemy_scale("enemy_health_exp").
func enemy_scale(exp_key: String) -> float:
	return pow(difficulty_coefficient(), Economy.difficulty(exp_key))


## {index, name, progress (0..1 through the current tier)}.
func difficulty_tier() -> Dictionary:
	var names := Economy.tier_names()
	var steps := (difficulty_coefficient() - 1.0) / Economy.difficulty("tier_step")
	var index := mini(floori(steps), names.size() - 1)
	var progress := 1.0 if index == names.size() - 1 and steps >= names.size() - 1 else steps - floorf(steps)
	return {"index": index, "name": names[index], "progress": progress}


# ── scrap & combo ─────────────────────────────────────────────────────────────

func combo_multiplier() -> float:
	return minf(1.0 + stats.combo_step * combo_count, stats.combo_cap)


## Scores an event. `base` defaults to the source's value in scrap_sources.csv.
## Returns the scrap actually paid out.
func earn(source: StringName, base: float = -1.0) -> int:
	if _is_game_over:
		return 0
	if base < 0.0:
		base = Economy.source_base(source)
	var mult := combo_multiplier()
	var amount := maxi(roundi(base * mult * stats.scrap_mult), 1)
	scrap += amount
	run_scrap += amount
	scrap_changed.emit(scrap)
	scrap_earned.emit(amount, source, mult)
	_set_combo(combo_count + 1)
	return amount


## Legacy entry point (XP orbs, near misses, tricks): now pays scrap.
func add_xp(amount: int) -> void:
	earn(&"pickup", float(amount))


func _set_combo(count: int) -> void:
	combo_count = count
	combo_time_left = stats.combo_window if count > 0 else 0.0
	combo_changed.emit(combo_count, combo_multiplier())


# ── damage ────────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _is_game_over or invulnerable:
		return
	var dealt := maxi(roundi(amount * (1.0 - stats.armor)), 1)
	current_health = max(0, current_health - dealt)
	health_changed.emit(current_health, max_health)
	if combo_count > 0:
		_set_combo(0)                          # getting hit drops the combo
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is RigidBody3D:
			(enemy as RigidBody3D).linear_velocity = Vector3.ZERO
	if current_health <= 0:
		_is_game_over = true
		game_over.emit()


## Rolls a crit on an outgoing hit. Returns [damage, is_crit].
func roll_hit(amount: float) -> Array:
	if randf() < stats.crit_chance:
		return [amount * stats.crit_mult, true]
	return [amount, false]


# ── upgrades ──────────────────────────────────────────────────────────────────

func level_of(id: StringName) -> int:
	var u := Economy.upgrade(id)
	return meta_levels.get(id, 0) if u.get("store") == &"garage" else run_levels.get(id, 0)


func price_of(id: StringName) -> int:
	var u := Economy.upgrade(id)
	var discount: float = 0.0 if u.store == &"garage" else stats.store_discount
	return Economy.price(u, level_of(id), discount)


## Why an upgrade can't be bought right now ("" when it can).
func blocker(id: StringName) -> String:
	var u := Economy.upgrade(id)
	if u.is_empty():
		return "unknown"
	if u.op == &"unlock" and u.weapon in unlocked_weapons:
		return "owned"
	if level_of(id) >= u.max_level:
		return "maxed"
	if u.op == &"weapon" and u.weapon not in unlocked_weapons:
		return "needs weapon"
	var wallet := parts if u.store == &"garage" else scrap
	if wallet < price_of(id):
		return "can't afford"
	return ""


func buy(id: StringName) -> bool:
	if blocker(id) != "":
		return false
	var u := Economy.upgrade(id)
	var cost := price_of(id)
	var level := level_of(id) + 1
	if u.store == &"garage":
		parts -= cost
		meta_levels[id] = level
		parts_changed.emit(parts)
		_save_meta()
	else:
		scrap -= cost
		run_levels[id] = level
		scrap_changed.emit(scrap)
	match u.op:
		&"unlock":
			unlocked_weapons.append(u.weapon)
			weapon_unlocked.emit(u.weapon, load(Economy.WEAPON_SCENES[u.weapon]))
		&"weapon":
			weapon_levels[u.weapon] = weapon_levels.get(u.weapon, 1) + 1
			weapon_leveled_up.emit(u.weapon)
	_recompute_stats()
	upgrade_bought.emit(id, level)
	return true


func _recompute_stats() -> void:
	var table := Economy.stat_table()
	var s := {}
	for stat in table:
		s[stat] = table[stat].default
	for u in Economy.upgrades():
		Economy.apply(s, u, meta_levels.get(u.id, 0) if u.store == &"garage" else run_levels.get(u.id, 0))
	Economy.clamp_stats(s)
	stats = s
	damage_multiplier = s.damage_mult
	fire_rate_multiplier = s.fire_rate_mult
	speed_multiplier = s.top_speed_mult
	var new_max := int(s.max_health)
	if new_max != max_health:
		current_health = clampi(current_health + new_max - max_health, 1, new_max)
		max_health = new_max
		health_changed.emit(current_health, max_health)


# ── persistence (garage) ──────────────────────────────────────────────────────

## Banks part of this run's scrap as garage parts. Called once per run end.
func bank_run() -> int:
	if _banked:
		return 0
	_banked = true
	var earned := floori(run_scrap * stats.bank_rate)
	parts += earned
	_save_meta()
	parts_changed.emit(parts)
	run_banked.emit(earned)
	return earned


func _load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	parts = cfg.get_value("garage", "parts", 0)
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	skill_bests = cfg.get_value("skills", "bests", {})
	var saved: Dictionary = cfg.get_value("garage", "levels", {})
	meta_levels = {}
	for id in saved:
		meta_levels[StringName(id)] = int(saved[id])


## Records a skill completion; returns true if it's a new best.
func record_skill_time(id: String, seconds: float) -> bool:
	if skill_bests.has(id) and float(skill_bests[id]) <= seconds:
		return false
	skill_bests[id] = seconds
	_save_meta()
	return true


func _bind_controls() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		if action in ["accelerate", "decelerate"]:
			InputMap.action_set_deadzone(action, STICK_PRESS)
		for b in BINDINGS[action]:
			var ev: InputEvent
			match b[0]:
				"key":
					ev = InputEventKey.new()
					(ev as InputEventKey).physical_keycode = b[1]
				"button":
					ev = InputEventJoypadButton.new()
					(ev as InputEventJoypadButton).button_index = b[1]
				"axis":
					ev = InputEventJoypadMotion.new()
					(ev as InputEventJoypadMotion).axis = b[1]
					(ev as InputEventJoypadMotion).axis_value = b[2]
			ev.device = -1                                   # any controller
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save_meta()


func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("garage", "parts", parts)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("skills", "bests", skill_bests)
	var plain := {}
	for id in meta_levels:
		plain[String(id)] = meta_levels[id]
	cfg.set_value("garage", "levels", plain)
	cfg.save(SAVE_PATH)


# ── legacy level-up API (kept so old scenes still load) ──────────────────────

func apply_upgrade(upgrade: Resource) -> void:
	push_warning("GameManager.apply_upgrade: level-up upgrades are gone; buy from a store instead (%s)" % upgrade)


func reset() -> void:
	elapsed_time = 0.0
	enemies_killed = 0
	current_level = 1
	current_xp = 0
	unlocked_weapons = [&"front_gun"]
	weapon_levels = {}
	run_levels = {}
	run_scrap = 0
	bosses_defeated = 0
	combo_count = 0
	combo_time_left = 0.0
	invulnerable = false
	_regen_carry = 0.0
	_is_game_over = false
	_banked = false
	_load_meta()
	_recompute_stats()
	max_health = int(stats.max_health)
	current_health = max_health
	scrap = int(stats.start_scrap)
	scrap_changed.emit(scrap)
	combo_changed.emit(0, 1.0)
	health_changed.emit(current_health, max_health)
