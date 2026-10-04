class_name Economy
extends RefCounted
## Read-only access to the balance tables in data/*.csv (the single source of
## truth for the game and for balance simulations):
##   upgrades.csv       every purchasable upgrade (stores + garage)
##   scrap_sources.csv  base scrap per scoring event
##   stat_defaults.csv  starting value and clamps for every stat
##   difficulty.csv     the Risk-of-Rain-style difficulty coefficient
##   difficulty_tiers.csv  tracker tier names
##
## Formulas (keep docs/balance/economy.md in sync):
##   price of the next level  = round(base_cost * cost_growth ^ level * (1 - store_discount))
##   "add" upgrade at level L = stat + value * L
##   "mul" upgrade at level L = stat * (1 + value) ^ L
##   payout                   = round(base * combo_multiplier * scrap_mult)
##   combo_multiplier         = min(1 + combo_step * combo_count, combo_cap)

const UPGRADES_CSV := "res://data/upgrades.csv"
const SOURCES_CSV := "res://data/scrap_sources.csv"
const STATS_CSV := "res://data/stat_defaults.csv"
const DIFFICULTY_CSV := "res://data/difficulty.csv"
const TIERS_CSV := "res://data/difficulty_tiers.csv"
const STORES: Array[StringName] = [&"diner", &"sky", &"petrol", &"garage"]
const WEAPON_SCENES := {
	&"garlic": "res://scenes/weapons/garlic.tscn",
	&"side_rockets": "res://scenes/weapons/side_rockets.tscn",
	&"ring_fire": "res://scenes/weapons/ring_fire.tscn",
}

static var _upgrades: Array[Dictionary] = []
static var _by_id := {}
static var _sources := {}
static var _stats := {}
static var _difficulty := {}
static var _tiers: PackedStringArray = []


static func upgrades() -> Array[Dictionary]:
	_load()
	return _upgrades


static func upgrade(id: StringName) -> Dictionary:
	_load()
	return _by_id.get(id, {})


static func store_upgrades(store: StringName) -> Array[Dictionary]:
	_load()
	return _upgrades.filter(func(u: Dictionary) -> bool: return u.store == store)


static func source_base(source: StringName) -> float:
	_load()
	return _sources.get(source, 0.0)


## A value from difficulty.csv.
static func difficulty(key: String) -> float:
	_load()
	return _difficulty.get(key, 0.0)


## Tracker tier names, easiest first.
static func tier_names() -> PackedStringArray:
	_load()
	return _tiers


## {stat: {default, min, max}}
static func stat_table() -> Dictionary:
	_load()
	return _stats


static func price(u: Dictionary, level: int, discount: float = 0.0) -> int:
	return roundi(u.base_cost * pow(u.cost_growth, level) * (1.0 - discount))


## Applies `levels` of upgrade `u` to a stats dictionary in place.
static func apply(stats: Dictionary, u: Dictionary, levels: int) -> void:
	if levels <= 0 or u.stat == "":
		return
	match u.op:
		&"add":
			stats[u.stat] += u.value * levels
		&"mul":
			stats[u.stat] *= pow(1.0 + u.value, levels)


static func clamp_stats(stats: Dictionary) -> void:
	for stat in _stats:
		var row: Dictionary = _stats[stat]
		if row.has("min"):
			stats[stat] = maxf(stats[stat], row.min)
		if row.has("max"):
			stats[stat] = minf(stats[stat], row.max)


static func _load() -> void:
	if not _upgrades.is_empty():
		return
	for row in _read_csv(UPGRADES_CSV):
		var u := {
			"id": StringName(row.id), "name": row.name, "store": StringName(row.store),
			"rarity": StringName(row.rarity), "stat": String(row.stat), "op": StringName(row.op),
			"value": float(row.value), "max_level": int(row.max_level), "base_cost": float(row.base_cost),
			"cost_growth": float(row.cost_growth), "weapon": StringName(row.weapon),
			"description": row.description,
		}
		_upgrades.append(u)
		_by_id[u.id] = u
	for row in _read_csv(SOURCES_CSV):
		_sources[StringName(row.source)] = float(row.base)
	for row in _read_csv(STATS_CSV):
		var s := {"default": float(row.default)}
		if row.min != "":
			s["min"] = float(row.min)
		if row.max != "":
			s["max"] = float(row.max)
		_stats[String(row.stat)] = s     # stat names are plain String keys everywhere
	for row in _read_csv(DIFFICULTY_CSV):
		_difficulty[String(row.key)] = float(row.value)
	for row in _read_csv(TIERS_CSV):
		_tiers.append(String(row.name))


static func _read_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Economy: cannot read %s" % path)
		return rows
	var header := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i]
		rows.append(row)
	return rows
