## Headless validator — forces full script compilation across all scenes.
## Run via: just check
## Errors (including type errors) print to stdout and exit with code 1.
extends SceneTree

const SCENES := [
	"res://scenes/world/world.tscn",
	"res://scenes/world/car.tscn",
	"res://scenes/world/car_ram.tscn",
	"res://scenes/enemy/zombie.tscn",
	"res://scenes/enemy/runner.tscn",
	"res://scenes/enemy/tank.tscn",
	"res://scenes/enemy/exploder.tscn",
	"res://scenes/weapons/front_gun.tscn",
	"res://scenes/weapons/ring_fire.tscn",
	"res://scenes/weapons/side_rockets.tscn",
	"res://scenes/weapons/projectile.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/level_up_screen.tscn",
	"res://scenes/ui/game_over_screen.tscn",
	"res://scenes/ui/level_select.tscn",
]

func _init() -> void:
	for path in SCENES:
		if ResourceLoader.exists(path):
			load(path)
	quit()
