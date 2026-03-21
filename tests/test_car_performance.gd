extends GutTest

## Simulated acceleration timing test — 0-100 km/h and 0-250 km/h.
##
## Uses Euler integration of the gear system with the car's actual accel curve.
## This is an APPROXIMATION — real Jolt physics includes wheel grip, suspension
## forces, and ground reaction that aren't captured here.
##
## Calibration tool: scripts/calibrate_gears.py — mirrors this simulation, plots
## a velocity-time chart, and runs a solver to find accel_scale values automatically.
## Run with: python3 scripts/calibrate_gears.py
##
## HOW TO CALIBRATE:
##   1. Run the game, time 0-100 and 0-250 with a stopwatch (or add a debug timer).
##   2. Run this test and read the reported times from the failure messages.
##   3. Adjust SIM_DRAG below until simulated times match in-game times.
##   4. The test then becomes a reliable regression — any gear change that
##      breaks your timing targets will show up as a test failure.

# ── Calibration constants ─────────────────────────────────────────────────────

## Quadratic drag coefficient. Higher = more drag = slower acceleration.
## Tune this until simulated times match real in-game times.
## Derived: 65 units/s felt like ~84 km/h → KMH_PER_UNIT ≈ 1.3.
## 250 km/h ≈ 192 units/s ≈ BASE_MAX_SPEED. SIM_DRAG tuned so terminal
## velocity is just above 250 km/h, letting the simulation reach that target.
const SIM_DRAG := 0.003

## Conversion from game units/s to km/h.
## From observation: 65 units/s was reported as ~84 km/h → 84/65 ≈ 1.29.
## Adjust if your speedometer says otherwise.
const KMH_PER_UNIT := 1.3

# ── Fixed car constants — match car.tscn ─────────────────────────────────────

const BASE_ACCELERATION := 2000.0
const BASE_MAX_SPEED    := 195.0
const MASS              := 50.0

# ── Simulation ────────────────────────────────────────────────────────────────

const SIM_DT      := 0.005   # 5 ms steps — small enough for accuracy
const SIM_TIMEOUT := 30.0    # give up after 30 s if target not reached

## Piecewise-linear approximation of the accel curve from car.tscn (Curve_xmp6s).
## Points: (0, 0.3) → (0.3, 0.9) → (0.6, 0.8) → (1.0, 0.1)
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


## Returns the time in seconds to reach target_kmh from a standstill, or
## SIM_TIMEOUT if the car never gets there.
func simulate_to(target_kmh: float) -> float:
	var speed    := 0.0
	var t        := 0.0
	var gear     := 0

	while t < SIM_TIMEOUT:
		var gmax    := _gear_max(gear)
		var scale   := _accel_scale(gear)

		# Upshift
		if gear < CarGears.GEARS.size() - 1:
			if speed >= gmax * CarGears.UPSHIFT_THRESHOLD:
				gear += 1
				gmax  = _gear_max(gear)
				scale = _accel_scale(gear)

		var ratio     := clampf(speed / maxf(gmax, 0.001), 0.0, 1.0)
		var curve_val := _accel_curve(ratio)
		var f_motor   := BASE_ACCELERATION * scale * curve_val
		var f_drag    := SIM_DRAG * speed * speed
		var accel     := (f_motor - f_drag) / MASS

		speed += accel * SIM_DT
		speed  = maxf(speed, 0.0)
		t     += SIM_DT

		if speed * KMH_PER_UNIT >= target_kmh:
			return t

	return SIM_TIMEOUT


# ── Tests ─────────────────────────────────────────────────────────────────────

func test_zero_to_100_in_3_seconds() -> void:
	var t := simulate_to(100.0)
	var msg := "0-100 km/h simulation: %.2f s (target 3.0 ± 1.0 s) — adjust SIM_DRAG to calibrate" % t
	assert_gt(t, 2.0, msg)
	assert_lt(t, 4.0, msg)


func test_zero_to_250_in_10_seconds() -> void:
	var t := simulate_to(250.0)
	var msg := "0-250 km/h simulation: %.2f s (target 10.0 ± 2.0 s) — adjust SIM_DRAG to calibrate" % t
	assert_gt(t, 8.0, msg)
	assert_lt(t, 12.0, msg)


func test_top_speed_reaches_250_kmh() -> void:
	# Verify the car can physically reach 250 km/h within 30 s
	var t := simulate_to(250.0)
	assert_lt(t, SIM_TIMEOUT, "car should reach 250 km/h — check gear max_speed and BASE_MAX_SPEED")


func test_100_reached_before_250() -> void:
	var t100 := simulate_to(100.0)
	var t250 := simulate_to(250.0)
	assert_lt(t100, t250, "0-100 should be faster than 0-250")
