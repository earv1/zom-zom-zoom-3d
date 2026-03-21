extends GutTest

## Structural tests for the gear system's physical behaviour.
##
## Calibration tool: scripts/calibrate_gears.py — mirrors this simulation,
## plots a velocity-time chart, and runs a solver to find accel_scale values.
## Run with: python3 scripts/calibrate_gears.py
##
## WHY STRUCTURAL TESTS INSTEAD OF TIMING TESTS:
##   The Jolt physics engine adds real-world effects (wheel slip, suspension,
##   static friction) that this Euler simulation cannot capture, so absolute
##   timing numbers are not reliable regressions.  Instead we test STRUCTURE:
##     1. In each gear, the terminal velocity must be above the upshift
##        threshold so the car can actually reach it and shift.
##     2. Gear 5 terminal velocity must sit in a sensible top-speed range.
##   These hold regardless of Jolt-specific tuning.
##
## PHYSICS MODEL:
##   Drag comes from the wheel z_force in raycast_wheel.gd (linear, NOT aero):
##     z_force = speed × z_traction × (mass × gravity / total_wheels)  per wheel
##     z_traction = 0.15 (raycast_wheel.gd default)
##     gravity = 9.8 m/s², mass = 50 kg, total_wheels = 4
##     → drag_decel = 4 × speed × 0.15 × (50×9.8/4) / 50 = 1.47 × speed  m/s²
##   This is LINEAR in speed, creating a natural terminal velocity in each gear.
##
##   HUD formula: linear_velocity.length() × 3.6  (standard m/s → km/h).
##   Motor wheels: WheelRL + WheelRR (is_motor=true in car.tscn) = 2 wheels.
##   Each motor wheel applies car.acceleration × accel_curve force to the car.

# ── Constants (must match car.tscn and car_gears.gd) ─────────────────────────

const BASE_ACCELERATION := 2000.0
const BASE_MAX_SPEED    := 195.0
const MASS              := 50.0
const N_MOTOR_WHEELS    := 2      # WheelRL + WheelRR

const Z_TRACTION   := 0.15       # raycast_wheel.gd default
const GRAVITY      := 9.8        # m/s²
const TOTAL_WHEELS := 4
## Linear drag deceleration coefficient (m/s² per m/s of speed).
## Derived: Z_TRACTION × GRAVITY = 0.15 × 9.8 = 1.47
const LINEAR_DRAG := Z_TRACTION * GRAVITY

## HUD conversion: velocity.length() × 3.6 = km/h  (standard SI, m/s → km/h)
const KMH_PER_UNIT := 3.6

# ── Accel curve (piecewise linear — matches Curve_xmp6s in car.tscn) ─────────

func _accel_curve(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t <= 0.3:
		return lerpf(0.3, 0.9, t / 0.3)
	elif t <= 0.6:
		return lerpf(0.9, 0.8, (t - 0.3) / 0.3)
	else:
		return lerpf(0.8, 0.1, (t - 0.6) / 0.4)


func _gear_max(gear: int) -> float:
	return BASE_MAX_SPEED * float(CarGears.GEARS[gear][&"speed_frac"])


func _accel_scale(gear: int) -> float:
	return float(CarGears.GEARS[gear][&"accel_scale"])


# ── Terminal velocity solver ──────────────────────────────────────────────────

## Returns the terminal velocity (m/s) in a given gear: the speed where
## motor acceleration equals drag deceleration.
## Uses binary search over [0, gear_max].
func _terminal_velocity(gear: int) -> float:
	var m: float = _gear_max(gear)
	var a: float = _accel_scale(gear)

	var lo := 0.0
	var hi := m

	for _i in 60:
		var mid := (lo + hi) * 0.5
		var ratio := clampf(mid / maxf(m, 0.001), 0.0, 1.0)
		var motor  := float(N_MOTOR_WHEELS) * BASE_ACCELERATION * a * _accel_curve(ratio) / MASS
		var drag   := LINEAR_DRAG * mid
		if motor > drag:
			lo = mid
		else:
			hi = mid

	return (lo + hi) * 0.5


# ── Tests ─────────────────────────────────────────────────────────────────────

## Each gear (except the last) must have a terminal velocity above its upshift
## threshold.  If the terminal sits below the threshold the car stalls in that
## gear and never progresses — which is exactly the bug this test guards.
func test_each_gear_upshift_threshold_is_reachable() -> void:
	for gear in range(CarGears.GEARS.size() - 1):  # skip last gear (no upshift)
		var terminal := _terminal_velocity(gear)
		var threshold := _gear_max(gear) * CarGears.UPSHIFT_THRESHOLD
		var msg := (
			"Gear %d: terminal %.1f m/s (%.0f km/h) must exceed upshift threshold %.1f m/s (%.0f km/h). "
			+ "If this fails, lower UPSHIFT_THRESHOLD or increase accel_scale for this gear."
		) % [
			gear + 1,
			terminal, terminal * KMH_PER_UNIT,
			threshold, threshold * KMH_PER_UNIT,
		]
		assert_gt(terminal, threshold, msg)


## Gear 5 terminal velocity should be in a reasonable top-speed range.
## Too low → car feels slow at the top end; too high → physics is broken.
func test_gear5_terminal_velocity_is_in_range() -> void:
	var top_gear := CarGears.GEARS.size() - 1
	var terminal := _terminal_velocity(top_gear)
	var kmh      := terminal * KMH_PER_UNIT
	var msg_lo   := "Gear 5 terminal %.0f km/h is below 150 km/h — needs higher accel_scale" % kmh
	var msg_hi   := "Gear 5 terminal %.0f km/h exceeds 350 km/h — physics may be unbalanced" % kmh
	assert_gt(kmh, 150.0, msg_lo)
	assert_lt(kmh, 350.0, msg_hi)


## Each successive gear must reach a higher terminal velocity than the previous.
func test_terminal_velocity_increases_each_gear() -> void:
	var prev_terminal := 0.0
	for gear in CarGears.GEARS.size():
		var terminal := _terminal_velocity(gear)
		assert_gt(terminal, prev_terminal,
			"Gear %d terminal (%.1f m/s) should exceed gear %d terminal (%.1f m/s)" % [
				gear + 1, terminal, gear, prev_terminal])
		prev_terminal = terminal
