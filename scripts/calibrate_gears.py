#!/usr/bin/env python3
"""
Gear calibration tool for Zom Zom Zoom.

Mirrors the GDScript simulation in test_car_performance.gd.
Plots velocity over time and shows where time is spent in each gear.

Usage:
    python3 scripts/calibrate_gears.py
"""

import sys

# ── Constants (must match car_gears.gd and test_car_performance.gd) ──────────

GEARS = [
    {"speed_frac": 0.06, "accel_scale": 1.30},  # 1 — launch
    {"speed_frac": 0.15, "accel_scale": 1.15},  # 2 — building
    {"speed_frac": 0.42, "accel_scale": 1.05},  # 3 — 100 km/h lives here
    {"speed_frac": 0.72, "accel_scale": 0.92},  # 4 — long pull
    {"speed_frac": 1.00, "accel_scale": 0.82},  # 5 — top-end
]

UPSHIFT_THRESHOLD   = 0.92
DOWNSHIFT_THRESHOLD = 0.75

BASE_ACCELERATION = 2000.0
BASE_MAX_SPEED    = 195.0
MASS              = 50.0
SIM_DRAG          = 0.003
KMH_PER_UNIT      = 1.3

SIM_DT      = 0.005
SIM_TIMEOUT = 30.0

TARGET_100  = 100.0   # km/h
TARGET_250  = 250.0   # km/h

# ── Accel curve (piecewise linear, mirrors Curve_xmp6s) ──────────────────────

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


# ── Simulation ────────────────────────────────────────────────────────────────

def simulate(record_profile: bool = False):
    """
    Returns (t100, t250, profile).
    profile is list of (time, speed_kmh, gear) sampled every 0.1 s.
    """
    speed  = 0.0
    t      = 0.0
    gear   = 0
    t100   = None
    t250   = None
    profile = []
    next_sample = 0.0

    while t < SIM_TIMEOUT:
        gmax  = gear_max(gear)
        scale = GEARS[gear]["accel_scale"]

        # Upshift
        if gear < len(GEARS) - 1:
            if speed >= gmax * UPSHIFT_THRESHOLD:
                gear += 1
                gmax  = gear_max(gear)
                scale = GEARS[gear]["accel_scale"]

        ratio     = max(0.0, min(1.0, speed / max(gmax, 0.001)))
        cv        = accel_curve(ratio)
        f_motor   = BASE_ACCELERATION * scale * cv
        f_drag    = SIM_DRAG * speed * speed
        accel     = (f_motor - f_drag) / MASS

        speed = max(0.0, speed + accel * SIM_DT)
        t    += SIM_DT

        kmh = speed * KMH_PER_UNIT

        if t100 is None and kmh >= TARGET_100:
            t100 = t
        if t250 is None and kmh >= TARGET_250:
            t250 = t
            if not record_profile:
                break

        if record_profile and t >= next_sample:
            profile.append((t, kmh, gear + 1))  # gear is 1-indexed for display
            next_sample += 0.1

        if t250 is not None and not record_profile:
            break

    return t100, t250 or SIM_TIMEOUT, profile


# ── ASCII chart ───────────────────────────────────────────────────────────────

def ascii_chart(profile, width=70, height=20):
    """Print a terminal velocity/time chart with gear shading."""
    if not profile:
        return

    max_t   = profile[-1][0]
    max_kmh = max(p[1] for p in profile)
    max_kmh = max(max_kmh, 260.0)

    rows = [[" "] * width for _ in range(height)]

    # Reference lines
    for t100_ref in [3.0, 10.0]:
        x = int(t100_ref / max_t * (width - 1))
        if 0 <= x < width:
            for y in range(height):
                rows[y][x] = "│" if rows[y][x] == " " else rows[y][x]

    # 100 and 250 km/h horizontal markers
    for kmh_ref in [100.0, 250.0]:
        y_frac = 1.0 - kmh_ref / max_kmh
        y = int(y_frac * (height - 1))
        if 0 <= y < height:
            for x in range(width):
                if rows[y][x] == " ":
                    rows[y][x] = "─"

    # Velocity curve
    gear_chars = {1: "①", 2: "②", 3: "③", 4: "④", 5: "⑤"}
    prev_x = -1
    for (t, kmh, g) in profile:
        x = int(t / max_t * (width - 1))
        y = int((1.0 - kmh / max_kmh) * (height - 1))
        y = max(0, min(height - 1, y))
        if 0 <= x < width:
            rows[y][x] = str(g)
            prev_x = x

    print()
    print(f"  Velocity profile  (top={max_kmh:.0f} km/h, right={max_t:.1f} s)")
    print("  ┌" + "─" * width + "┐")
    for i, row in enumerate(rows):
        kmh_label = max_kmh * (1.0 - i / (height - 1))
        print(f"{kmh_label:5.0f} │{''.join(row)}│")
    print("  └" + "─" * width + "┘")
    # Time axis labels
    labels = " " * 7
    step = max_t / 5
    for i in range(6):
        t_label = f"{step * i:.1f}s"
        labels += t_label.ljust(width // 5)
    print(labels)
    print()
    print("  Legend: number = gear, ─ = 100/250 km/h, │ = 3 s / 10 s marks")


# ── Time-in-gear breakdown ────────────────────────────────────────────────────

def time_in_gear_breakdown(profile):
    gear_time = {}
    for i in range(len(profile) - 1):
        t0, _, g = profile[i]
        t1, _, _ = profile[i + 1]
        gear_time[g] = gear_time.get(g, 0.0) + (t1 - t0)
    print("  Time per gear:")
    for g in sorted(gear_time):
        print(f"    Gear {g}: {gear_time[g]:.2f} s")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    t100, t250, profile = simulate(record_profile=True)

    print("=" * 72)
    print("  ZOM ZOM ZOOM — Gear Calibration")
    print("=" * 72)
    print()
    print(f"  0→100 km/h : {t100:.2f} s  (target: 2.0–4.0 s)")
    print(f"  0→250 km/h : {t250:.2f} s  (target: 8.0–12.0 s)")
    print()

    ok100 = t100 is not None and 2.0 <= t100 <= 4.0
    ok250 = t250 < SIM_TIMEOUT and 8.0 <= t250 <= 12.0
    print(f"  0→100  {'✓ PASS' if ok100 else '✗ FAIL'}")
    print(f"  0→250  {'✓ PASS' if ok250 else '✗ FAIL'}")
    print()

    ascii_chart(profile)
    time_in_gear_breakdown(profile)

    print()
    print("  Current gear constants:")
    print(f"  {'Gear':<6} {'speed_frac':>12} {'accel_scale':>12}  {'max_speed (units/s)':>20}")
    for i, g in enumerate(GEARS):
        ms = BASE_MAX_SPEED * g["speed_frac"]
        print(f"  {i+1:<6} {g['speed_frac']:>12.2f} {g['accel_scale']:>12.2f}  {ms:>20.1f}")
    print()


def solve_accel_scales():
    """
    Binary-search accel_scale for gears 4 and 5 to hit 0→250 in ~10 s,
    keeping BASE_MAX_SPEED and gears 1-3 unchanged so 0→100 (~3 s) is unaffected.
    Gears 4 and 5 are scaled together by a single multiplier for simplicity.
    """
    global GEARS

    saved = [g.copy() for g in GEARS]
    lo, hi = 0.5, 5.0
    best_mult = None
    target_t250 = 10.0

    for _ in range(40):
        mid = (lo + hi) / 2.0
        for i in [3, 4]:                       # gear indices 3 = gear4, 4 = gear5
            GEARS[i]["accel_scale"] = saved[i]["accel_scale"] * mid
        t100, t250, _ = simulate()
        if t250 < target_t250:
            hi  = mid
            best_mult = mid
        else:
            lo  = mid

    # Apply best
    if best_mult is not None:
        for i in [3, 4]:
            GEARS[i]["accel_scale"] = saved[i]["accel_scale"] * best_mult
        t100, t250, _ = simulate()
        print("  Solved accel_scale multiplier for gears 4-5: ×{:.2f}".format(best_mult))
        for i, g in enumerate(GEARS):
            print(f"    Gear {i+1}: accel_scale = {g['accel_scale']:.3f}")
        print(f"  Result → 0→100: {t100:.2f} s, 0→250: {t250:.2f} s")
    else:
        print("  Solver failed to converge.")

    GEARS = saved  # restore
    print()


def sensitivity_analysis():
    """Show effect of varying BASE_MAX_SPEED on 0→250 time."""
    global BASE_MAX_SPEED
    print("  Sensitivity: BASE_MAX_SPEED vs 0→250 time")
    print(f"  {'max_speed':>10} {'250 km/h = X% of max':>22} {'0→100':>8} {'0→250':>8}")
    original = BASE_MAX_SPEED
    for ms in [195, 220, 250, 280, 320]:
        BASE_MAX_SPEED = float(ms)
        t100, t250, _ = simulate()
        ratio_at_250 = (TARGET_250 / KMH_PER_UNIT) / ms * 100
        t250_str = f"{t250:.2f}s" if t250 < SIM_TIMEOUT else "TIMEOUT"
        print(f"  {ms:>10}   {ratio_at_250:>18.1f}%   {t100:>6.2f}s   {t250_str:>8}")
    BASE_MAX_SPEED = original
    print()


if __name__ == "__main__":
    main()
    solve_accel_scales()
    sensitivity_analysis()
