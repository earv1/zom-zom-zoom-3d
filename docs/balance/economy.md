# Economy & upgrade balance

All balance numbers live in four CSV tables under `data/`. The game reads them at
runtime through `data/economy.gd`, and a simulation can read the same files directly.
Change a number in a CSV and both the game and any simulation pick it up.

| Table | What it holds |
|---|---|
| `data/upgrades.csv` | Every purchasable upgrade: stores (`diner`, `sky`, `petrol`) and the permanent `garage` |
| `data/scrap_sources.csv` | Base scrap paid per scoring event |
| `data/stat_defaults.csv` | Every player stat's starting value and clamps |
| `data/difficulty.csv` | How enemy health and kill rewards grow over a run |

## Formulas

These are implemented in `Economy` / `GameManager`; keep this list in sync with `data/economy.gd`.

| Quantity | Formula |
|---|---|
| Price of the next level | `round(base_cost * cost_growth ^ level * (1 - store_discount))` (garage prices are never discounted) |
| `add` upgrade at level L | `stat + value * L` |
| `mul` upgrade at level L | `stat * (1 + value) ^ L` |
| Combo multiplier | `min(1 + combo_step * combo_count, combo_cap)` |
| Scrap paid out | `max(round(base * combo_multiplier * scrap_mult), 1)` |
| Kill reward base | `enemy xp_value * kill base * kill_reward_growth ^ minutes` |
| Enemy health | `ceil(max_health * enemy_health_growth ^ minutes)` |
| Damage taken | `max(round(damage * (1 - armor)), 1)` |
| Outgoing hit | crit with chance `crit_chance` for `crit_mult` x damage |
| Parts banked at run end | `floor(run_scrap * bank_rate)` |

The combo grows by one per scoring event, drops if nothing scores within
`combo_window` seconds, and resets when you take damage.

Stats are rebuilt from scratch on every purchase: defaults, then garage levels,
then this run's levels, then clamped to `stat_defaults.csv` min/max.

## `upgrades.csv` columns

| Column | Meaning |
|---|---|
| `id` | Unique key (saved in the garage file for garage rows) |
| `store` | `diner` (common), `sky` (Sky Workshop), `petrol` (rare), `garage` (permanent, paid in parts) |
| `stat` / `op` / `value` | Stat changed per level; `op` is `add`, `mul`, `unlock` (weapon) or `weapon` (weapon level) |
| `max_level` | Highest level |
| `base_cost` / `cost_growth` | Price curve (see formulas) |
| `weapon` | Weapon id for `unlock` / `weapon` rows |

### Store rules

- **Roadside Diner**: common upgrades, small steps, long level caps. Shows its whole catalogue.
- **Sky Workshop**: only reachable by landing the launch-ramp jump onto the sky pillar.
  Each item with a diner twin is **3x the effect at 2x the base price**
  (`test_sky_items_are_3x_effect_at_2x_price_of_their_diner_twin` enforces this).
  Its exclusive items (crit, combo cap/step, boost, armor) don't follow the rule.
- **Petrol Station**: rare, strong items with low level caps and steep growth.
  Each visit shows 3 random items you don't already own or have maxed.
- **Garage**: between runs, paid in parts.

Stores never pause the game. Parking in a bay saves the car's velocity and spin.
The car is shielded while parked, and driving out restores exactly that momentum.

## Simulating

A simulation needs four things:

1. Load the four CSVs and apply the formulas above.
2. **Income model**: scoring events per minute by source, e.g. kills by enemy type
   and spawn rate, near misses, tricks, loops and laps. Boss payouts arrive at 5, 10
   and 15 minutes of racing.
3. **Spending policy**: e.g. buy the cheapest affordable item at each store visit,
   visiting stores every N seconds and the Sky Workshop with probability p.
4. **Damage model**: DPS = weapon base damage x `damage_mult` x fire rate x
   `fire_rate_mult` x (1 + `crit_chance` x (`crit_mult` - 1)). Compare it with enemy
   health growth to find when the player falls behind or snowballs. Boss health is in
   `scenes/boss/boss_fight.gd` (`MAX_HEALTH`: 120 / 180 / 260).

The things to watch:
- time-to-afford for each tier
- player DPS vs `enemy_health_growth` over 15 minutes
- garage parts per run vs garage prices, i.e. how many runs each permanent upgrade takes
