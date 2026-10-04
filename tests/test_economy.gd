extends GutTest

## The scrap economy and stores: payouts, combo, buying from the upgrade table,
## stat effects, garage banking, and the store's park-and-resume momentum.


func before_each() -> void:
	GameManager.meta_levels = {}
	GameManager.parts = 0
	GameManager.reset()
	GameManager.meta_levels = {}
	GameManager._recompute_stats()


func after_all() -> void:
	GameManager.reset()


func test_upgrade_table_loads_every_store() -> void:
	for store in Economy.STORES:
		assert_gt(Economy.store_upgrades(store).size(), 0, "%s has upgrades" % store)
	for u in Economy.upgrades():
		assert_true(u.stat == "" or Economy.stat_table().has(u.stat), "%s targets a known stat" % u.id)


func test_sky_items_are_3x_effect_at_2x_price_of_their_diner_twin() -> void:
	for pair in [[&"diner_damage", &"sky_damage"], [&"diner_fire_rate", &"sky_fire_rate"],
			[&"diner_health", &"sky_health"], [&"diner_scrap", &"sky_scrap"]]:
		var d := Economy.upgrade(pair[0])
		var s := Economy.upgrade(pair[1])
		assert_almost_eq(s.value, d.value * 3.0, 0.0001, "%s effect" % s.id)
		assert_almost_eq(s.base_cost, d.base_cost * 2.0, 0.0001, "%s price" % s.id)


func test_earn_applies_combo_and_scrap_mult() -> void:
	assert_eq(GameManager.earn(&"near_miss"), 10, "first event is x1.0")
	assert_eq(GameManager.earn(&"near_miss"), 11, "second event rides a x1.1 combo")
	assert_eq(GameManager.scrap, 21)
	GameManager.take_damage(1)
	assert_eq(GameManager.combo_count, 0, "getting hit drops the combo")


func test_combo_caps() -> void:
	for i in 100:
		GameManager.earn(&"pickup", 1.0)
	assert_almost_eq(GameManager.combo_multiplier(), GameManager.stats.combo_cap, 0.0001)


func test_buying_spends_scrap_and_compounds_the_stat() -> void:
	GameManager.scrap = 10000
	var before := GameManager.damage_multiplier
	var price := GameManager.price_of(&"diner_damage")
	assert_true(GameManager.buy(&"diner_damage"))
	assert_eq(GameManager.scrap, 10000 - price)
	assert_almost_eq(GameManager.damage_multiplier, before * 1.08, 0.0001)
	assert_true(GameManager.buy(&"diner_damage"))
	assert_almost_eq(GameManager.damage_multiplier, before * 1.08 * 1.08, 0.0001)
	assert_gt(GameManager.price_of(&"diner_damage"), price, "prices climb with level")


func test_cannot_buy_without_scrap_or_prerequisites() -> void:
	GameManager.scrap = 0
	assert_eq(GameManager.blocker(&"diner_damage"), "can't afford")
	GameManager.scrap = 100000
	assert_eq(GameManager.blocker(&"diner_garlic"), "needs weapon")
	assert_true(GameManager.buy(&"petrol_garlic"))
	assert_eq(GameManager.blocker(&"petrol_garlic"), "owned")
	assert_eq(GameManager.blocker(&"diner_garlic"), "")


func test_armor_reduces_damage() -> void:
	GameManager.scrap = 100000
	GameManager.buy(&"petrol_roll_cage")
	var hp := GameManager.current_health
	GameManager.take_damage(100)
	assert_eq(hp - GameManager.current_health, 88)


func test_run_end_banks_parts() -> void:
	GameManager.earn(&"boss_cydeda")
	var expected := floori(GameManager.run_scrap * GameManager.stats.bank_rate)
	assert_eq(GameManager.bank_run(), expected)
	assert_eq(GameManager.bank_run(), 0, "banks once per run")


func test_store_parks_car_and_restores_momentum() -> void:
	var car := RigidBody3D.new()                 # park() only needs a rigid body
	add_child_autofree(car)
	var store := PitStore.new()
	add_child_autofree(store)
	car.linear_velocity = Vector3(0, 0, -42)
	car.angular_velocity = Vector3(0, 0.5, 0)
	store.park(car)
	assert_true(car.freeze, "car is held while shopping")
	assert_true(GameManager.invulnerable, "and shielded")
	assert_true(store.is_open())
	store.leave()
	assert_false(car.freeze)
	assert_false(GameManager.invulnerable)
	assert_eq(car.linear_velocity, Vector3(0, 0, -42), "drives out with the speed it came in with")
	assert_eq(car.angular_velocity, Vector3(0, 0.5, 0))


func test_every_store_shelves_three_offers_and_signs_them() -> void:
	for kind in [&"diner", &"sky", &"petrol"]:
		var store := PitStore.new()
		store.kind = kind
		add_child_autofree(store)
		var stock := store.stock()
		assert_eq(stock.size(), 3, "%s offers 3" % kind)
		for id in stock:
			assert_eq(Economy.upgrade(id).store, kind)
			assert_true(store._sign.text.contains(Economy.upgrade(id).name), "%s is on the sign" % id)


func test_difficulty_climbs_through_racing_tiers() -> void:
	GameManager.elapsed_time = 0.0
	GameManager.bosses_defeated = 0
	assert_almost_eq(GameManager.difficulty_coefficient(), 1.0, 0.0001)
	assert_eq(GameManager.difficulty_tier().name, "SUNDAY DRIVE")
	GameManager.elapsed_time = 600.0                        # 10 minutes at 0.1/min
	assert_almost_eq(GameManager.difficulty_coefficient(), 2.0, 0.0001)
	assert_eq(GameManager.difficulty_tier().index, 3, "a tier every 0.3 of coefficient")
	assert_almost_eq(GameManager.enemy_scale("enemy_health_exp"), 2.0, 0.0001, "enemy health doubles")
	GameManager.bosses_defeated = 1
	assert_almost_eq(GameManager.difficulty_coefficient(), 2.3, 0.0001, "a boss bumps it like a new stage")
	GameManager.elapsed_time = 60.0 * 600.0
	assert_eq(GameManager.difficulty_tier().name, "NITROUS", "tops out at NITROUS")
	GameManager.elapsed_time = 0.0
	GameManager.bosses_defeated = 0
