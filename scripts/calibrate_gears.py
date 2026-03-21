#!/usr/bin/env python3
"""
Gear calibration tool for Zom Zom Zoom.

Mirrors the physics of the gear system and wheel drag to show:
  - Velocity-over-time profile (with gear labels)
  - Time spent per gear
  - Terminal velocity per gear (where motor force = drag)
  - 0→100 and 0→250 km/h timings

Usage:
    python3 scripts/calibrate_gears.py

# ── Physics model ─────────────────────────────────────────────────────────────
# Drag comes from raycast_wheel.gd z_force (NOT quadratic aero drag):
#   z_force = speed * z_traction * (mass * gravity / total_wheels)  per wheel
#   z_traction = 0.15, gravity = 9.8, mass = 50, total_wheels = 4
#   total drag decel = 4 * speed * 0.15 * (50*9.8/4) / 50 = 1.47 * speed m/s²
# This is LINEAR in speed, creating a natural terminal velocity per gear.
#
# HUD: linear_velocity.length() * 3.6  (standard m/s → km/h)
# Motor wheels: WheelRL + WheelRR (is_motor=true in car.tscn) = 2 wheels.
# Each motor wheel applies car.acceleration * accel_curve force to the car.
"""

# ── Constants (must match car_gears.gd and test_car_performance.gd) ──────────

GEARS = [
    {"speed_frac": 0.06, "accel_scale": 1.300},  # 1 — launch
    {"speed_frac": 0.15, "accel_scale": 1.150},  # 2 — building
    {"speed_frac": 0.42, "accel_scale": 1.050},  # 3 — mid-range
    {"speed_frac": 0.72, "accel_scale": 1.313},  # 4 — long pull
    {"speed_frac": 1.00, "accel_scale": 1.450},  # 5 — top-end
]

UPSHIFT_THRESHOLD   = 0.40   # upshift at 40% of gear's max_speed
DOWNSHIFT_THRESHOLD = 0.30   # downshift at 30% of previous gear's max_speed

BASE_ACCELERATION = 2000.0   # car.tscn acceleration property
BASE_MAX_SPEED    = 195.0    # car.tscn max_speed property
MASS              = 50.0     # car.tscn mass
N_MOTOR_WHEELS    = 2        # WheelRL + WheelRR

# Linear drag: z_traction * gravity * (mass / total_wheels) * n_wheels / mass
# = z_traction * gravity = 0.15 * 9.8 = 1.47  (units: m/s² per m/s)
Z_TRACTION    = 0.15
GRAVITY       = 9.8
TOTAL_WHEELS  = 4
LINEAR_DRAG   = Z_TRACTION * GRAVITY  # = 1.47 s⁻¹
KMH_PER_UNIT  = 3.6   # HUD: m/s * 3.6 = km/h

SIM_DT      = 0.005   # 5 ms steps
SIM_TIMEOUT = 30.0

TARGET_100 = 100.0    # km/h
TARGET_250 = 250.0    # km/h

# ── Accel curve (piecewise linear — matches Curve_xmp6s in car.tscn) ─────────
# Points: (0, 0.3) → (0.3, 0.9) → (0.6, 0.8) → (1.0, 0.1)

def accel_curve(t: float) -> float:
    t = max(0.0, min(1.0, t))
    if t <= 0.3:
        return 0.3 + (0.9 - 0.3) * (t / 0.3)
    elif t <= 0.6:
        return 0.9 + (0.8 - 0.9) * ((t - 0.3) / 0.3)
    else:
        return 0.8 + (0.1 - 0.8) * ((t - 0.6) / 0.4)


def gear_max(gear: int) -> float:
    return BASE_MAX_SPEED * GEARS[gear]["speed_frac"]


# ── Terminal velocity analysis ────────────────────────────────────────────────

def terminal_velocity(gear: int, tol: float = 0.01) -> float:
    """
    Binary-search for the speed where motor accel = drag accel in this gear.
    Returns the terminal velocity in m/s, or gear_max if never reached.
    """
    m   = gear_max(gear)
    a   = GEARS[gear]["accel_scale"]

    def net(v: float) -> float:
        ratio  = max(0.0, min(1.0, v / max(m, 0.001)))
        motor  = N_MOTOR_WHEELS * BASE_ACCELERATION * a * accel_curve(ratio) / MASS
        drag   = LINEAR_DRAG * v
        return motor - drag

    if net(m) >= 0:          # motor exceeds drag even at gear max
        return m

    lo, hi = 0.0, m
    for _ in range(60):
        mid = (lo + hi) / 2
        if net(mid) > 0:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


# ── Simulation ────────────────────────────────────────────────────────────────

def simulate(record_profile: bool = False):
    """
    Returns (t100, t250, profile).
    profile: list of (time_s, speed_kmh, gear_1indexed) sampled every 0.1 s.
    """
    speed = 0.0
    t     = 0.0
    gear  = 0
    t100  = None
    t250  = None
    profile   = []
    next_sample = 0.0

    while t < SIM_TIMEOUT:
        gmax  = gear_max(gear)
        scale = GEARS[gear]["accel_scale"]

        # Upshift
        if gear < len(GEARS) - 1:
            if speed >= gmax * UPSHIFT_THRESHOLD:
                gear  += 1
                gmax   = gear_max(gear)
                scale  = GEARS[gear]["accel_scale"]

        ratio     = max(0.0, min(1.0, speed / max(gmax, 0.001)))
        cv        = accel_curve(ratio)
        motor_acc = N_MOTOR_WHEELS * BASE_ACCELERATION * scale * cv / MASS
        drag_acc  = LINEAR_DRAG * speed
        speed     = max(0.0, speed + (motor_acc - drag_acc) * SIM_DT)
        t        += SIM_DT

        kmh = speed * KMH_PER_UNIT
        if t100 is None and kmh >= TARGET_100:
            t100 = t
        if t250 is None and kmh >= TARGET_250:
            t250 = t
            if not record_profile:
                break

        if record_profile and t >= next_sample:
            profile.append((t, kmh, gear + 1))
            next_sample += 0.1

        if t250 is not None and not record_profile:
            break

    return t100, t250 or SIM_TIMEOUT, profile


# ── ASCII chart ───────────────────────────────────────────────────────────────

def ascii_chart(profile, width=70, height=20):
    if not profile:
        return

    max_t   = profile[-1][0]
    max_kmh = max(p[1] for p in profile)
    max_kmh = max(max_kmh, 260.0)

    rows = [[" "] * width for _ in range(height)]

    for t_ref in [3.0, 10.0]:
        x = int(t_ref / max_t * (width - 1))
        if 0 <= x < width:
            for y in range(height):
                if rows[y][x] == " ":
                    rows[y][x] = "│"

    for kmh_ref in [100.0, 250.0]:
        y_frac = 1.0 - kmh_ref / max_kmh
        y = int(y_frac * (height - 1))
        if 0 <= y < height:
            for x in range(width):
                if rows[y][x] == " ":
                    rows[y][x] = "─"

    for (t, kmh, g) in profile:
        x = int(t / max_t * (width - 1))
        y = int((1.0 - kmh / max_kmh) * (height - 1))
        y = max(0, min(height - 1, y))
        if 0 <= x < width:
            rows[y][x] = str(g)

    print()
    print(f"  Velocity profile  (top={max_kmh:.0f} km/h, right={max_t:.1f} s)")
    print("  ┌" + "─" * width + "┐")
    for i, row in enumerate(rows):
        kmh_label = max_kmh * (1.0 - i / (height - 1))
        print(f"{kmh_label:5.0f} │{''.join(row)}│")
    print("  └" + "─" * width + "┘")
    labels = " " * 7
    step = max_t / 5
    for i in range(6):
        labels += f"{step*i:.1f}s".ljust(width // 5)
    print(labels)
    print()
    print("  Legend: number = gear, ─ = 100/250 km/h, │ = 3 s / 10 s marks")


def time_in_gear(profile):
    gt = {}
    for i in range(len(profile) - 1):
        t0, _, g = profile[i]
        t1, _, _ = profile[i + 1]
        gt[g] = gt.get(g, 0.0) + (t1 - t0)
    print("  Time per gear:")
    for g in sorted(gt):
        print(f"    Gear {g}: {gt[g]:.2f} s")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    t100, t250, profile = simulate(record_profile=True)

    print("=" * 72)
    print("  ZOM ZOM ZOOM — Gear Calibration  (linear drag, KMH = m/s × 3.6)")
    print("=" * 72)
    print()
    print(f"  0→100 km/h : {t100:.2f} s  (target: 2.0–5.0 s)")
    print(f"  0→250 km/h : {t250:.2f} s  (target: 8.0–14.0 s)")
    print()

    ok100 = t100 is not None and 2.0 <= t100 <= 5.0
    ok250 = t250 < SIM_TIMEOUT and 8.0 <= t250 <= 14.0
    print(f"  0→100  {'✓ PASS' if ok100 else '✗ FAIL'}")
    print(f"  0→250  {'✓ PASS' if ok250 else '✗ FAIL'}")
    print()

    print("  Terminal velocity per gear:")
    for i, g in enumerate(GEARS):
        vt  = terminal_velocity(i)
        kmh = vt * KMH_PER_UNIT
        up  = gear_max(i) * UPSHIFT_THRESHOLD
        flag = " ✓" if vt > up else " ✗ UPSHIFT UNREACHABLE"
        print(f"    Gear {i+1}: terminal={kmh:.0f} km/h, upshift at {up*KMH_PER_UNIT:.0f} km/h{flag}")
    print()

    ascii_chart(profile)
    time_in_gear(profile)

    print()
    print("  Gear constants:")
    print(f"  {'Gear':<6} {'speed_frac':>12} {'accel_scale':>12}  {'max (m/s)':>10}  {'max (km/h)':>10}")
    for i, g in enumerate(GEARS):
        ms = BASE_MAX_SPEED * g["speed_frac"]
        print(f"  {i+1:<6} {g['speed_frac']:>12.3f} {g['accel_scale']:>12.3f}  {ms:>10.1f}  {ms*KMH_PER_UNIT:>10.0f}")
    print()


if __name__ == "__main__":
    main()
