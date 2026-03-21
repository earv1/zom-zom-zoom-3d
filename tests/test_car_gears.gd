extends GutTest

## Tests for CarGears shift logic and curve generation.
## _try_shift and _shift only touch current_gear + emit a signal,
## so they can be tested without a real RaycastCar in the tree.
## base_max_speed is set to 100.0 so threshold maths are easy to reason about.

const BASE_MAX_SPEED := 100.0

var _gears: CarGears


func before_each() -> void:
	_gears = CarGears.new()
	add_child(_gears)
	_gears._base_max_speed = BASE_MAX_SPEED


func after_each() -> void:
	_gears.queue_free()
	_gears = null


# helpers
func _gear_max(gear: int) -> float:
	return BASE_MAX_SPEED * float(CarGears.GEARS[gear][&"speed_frac"])


# ── Upshift ───────────────────────────────────────────────────────────────────

func test_upshift_fires_at_threshold() -> void:
	_gears.current_gear = 0
	var threshold: float = _gear_max(0) * CarGears.UPSHIFT_THRESHOLD
	_gears._try_shift(threshold)
	assert_eq(_gears.current_gear, 1, "should upshift at exactly the threshold speed")


func test_no_upshift_below_threshold() -> void:
	_gears.current_gear = 0
	var just_under: float = _gear_max(0) * CarGears.UPSHIFT_THRESHOLD - 0.1
	_gears._try_shift(just_under)
	assert_eq(_gears.current_gear, 0, "should not upshift below threshold")


func test_upshift_increments_by_one() -> void:
	for gear in range(CarGears.GEARS.size() - 1):
		_gears.current_gear = gear
		_gears._try_shift(_gear_max(gear))
		assert_eq(_gears.current_gear, gear + 1, "should shift from %d to %d" % [gear, gear + 1])


func test_no_upshift_from_top_gear() -> void:
	var top: int = CarGears.GEARS.size() - 1
	_gears.current_gear = top
	_gears._try_shift(9999.0)
	assert_eq(_gears.current_gear, top, "top gear should not upshift")


# ── Downshift ─────────────────────────────────────────────────────────────────

func test_downshift_fires_below_threshold() -> void:
	_gears.current_gear = 1
	var threshold: float = _gear_max(0) * CarGears.DOWNSHIFT_THRESHOLD
	_gears._try_shift(threshold - 0.1)
	assert_eq(_gears.current_gear, 0, "should downshift below threshold")


func test_no_downshift_above_threshold() -> void:
	_gears.current_gear = 1
	var threshold: float = _gear_max(0) * CarGears.DOWNSHIFT_THRESHOLD
	_gears._try_shift(threshold + 0.1)
	assert_eq(_gears.current_gear, 1, "should not downshift above threshold")


func test_no_downshift_from_gear_zero() -> void:
	_gears.current_gear = 0
	_gears._try_shift(0.0)
	assert_eq(_gears.current_gear, 0, "gear 0 should not downshift")


func test_downshift_decrements_by_one() -> void:
	for gear in range(1, CarGears.GEARS.size()):
		_gears.current_gear = gear
		_gears._try_shift(0.0)
		assert_eq(_gears.current_gear, gear - 1, "should shift from %d to %d" % [gear, gear - 1])


# ── Hysteresis gap ────────────────────────────────────────────────────────────

func test_no_immediate_downshift_after_upshift() -> void:
	_gears.current_gear = 0
	var upshift_speed: float = _gear_max(0) * CarGears.UPSHIFT_THRESHOLD
	_gears._try_shift(upshift_speed)
	assert_eq(_gears.current_gear, 1, "should have upshifted")
	_gears._try_shift(upshift_speed)
	assert_eq(_gears.current_gear, 1, "should not immediately downshift at the upshift speed")


# ── Signal ────────────────────────────────────────────────────────────────────

func test_gear_changed_signal_emitted_on_upshift() -> void:
	watch_signals(_gears)
	_gears.current_gear = 0
	_gears._shift(1)
	assert_signal_emitted_with_parameters(_gears, "gear_changed", [0, 1])


func test_gear_changed_signal_emitted_on_downshift() -> void:
	watch_signals(_gears)
	_gears.current_gear = 2
	_gears._shift(1)
	assert_signal_emitted_with_parameters(_gears, "gear_changed", [2, 1])


# ── Preview curve ─────────────────────────────────────────────────────────────

func test_curve_has_correct_point_count() -> void:
	# Each gear gets 2 points (start + step-down) except the last which gets 1
	var expected: int = (CarGears.GEARS.size() - 1) * 2 + 1
	assert_eq(_gears.acceleration_preview.point_count, expected,
		"curve should have two points per gear except the last")


func test_curve_starts_at_one() -> void:
	assert_almost_eq(_gears.acceleration_preview.sample(0.0), 1.0, 0.01,
		"gear 1 should normalise to 1.0 at speed 0")


# ── Speed fractions ───────────────────────────────────────────────────────────

func test_speed_fracs_are_ascending() -> void:
	for i in range(1, CarGears.GEARS.size()):
		var frac: float      = float(CarGears.GEARS[i][&"speed_frac"])
		var prev_frac: float = float(CarGears.GEARS[i - 1][&"speed_frac"])
		assert_gt(frac, prev_frac, "speed_frac should increase each gear")


func test_top_gear_reaches_full_speed() -> void:
	var top_frac: float = float(CarGears.GEARS[-1][&"speed_frac"])
	assert_almost_eq(top_frac, 1.0, 0.001, "top gear should reach 100% of base max_speed")
