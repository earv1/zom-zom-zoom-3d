class_name ShaderWarmup
extends Node3D
## Load-time warm-up. The GL Compatibility renderer compiles a shader the first
## time a material is drawn, which is the hitch when a new enemy, weapon, boss or
## effect first appears mid-run. Behind a LOADING cover, this draws one of
## everything that can show up later for a few frames, so every shader compiles
## now:
##   - real instances of enemies, gore, orbs, weapons and all three boss stages
##   - one-shot effects (lava, vomit, fog, shockwave, damage numbers)
##   - every material found in the level, hidden ones included, on small cards
## Skipped headless (nothing renders there, and tests need the car free).

signal done

const FRAMES := 8                ## rendered frames to hold everything on screen
const DISTANCE := 14.0           ## metres in front of the camera
const MAX_CARDS := 1500
const RACK_SCENES: Array[String] = [
	"res://scenes/enemy/xp_orb.tscn",
	"res://scenes/weapons/projectile.tscn",
]

## Scenes that are load()ed mid-run stay referenced here, so the load is instant.
static var keep: Array[Resource] = []

var level: Node3D
var car: RigidBody3D
var pool: Array = []             ## EnemyEntry list from the spawner
var force := false               ## run even headless (tests exercise the code path)


func _ready() -> void:
	if DisplayServer.get_name() == "headless" and not force:
		done.emit.call_deferred()
		queue_free.call_deferred()
		return
	_run()


func _run() -> void:
	var cover := _cover()
	var was_frozen := car.freeze
	car.freeze = true
	await get_tree().process_frame             # let the camera settle on the car
	var cam := get_viewport().get_camera_3d()
	global_transform = Transform3D(cam.global_basis, cam.global_position - cam.global_basis.z * DISTANCE)

	var slot := [0]
	var put := func(node: Node3D, size: float = 2.0) -> Node3D:
		var i: int = slot[0]
		slot[0] += 1
		add_child(node)
		node.position = Vector3((i % 8 - 3.5) * size, (floori(i / 8.0) - 1.5) * size, 0.0)
		return node

	for entry in pool:
		var scene: PackedScene = entry.get("scene")
		if scene:
			var enemy := _still(scene.instantiate())
			put.call(enemy)
			var frag: PackedScene = enemy.get("fragment_scene")
			if frag:
				put.call(_still(frag.instantiate()))
	for path in RACK_SCENES:
		put.call(_still(load(path).instantiate()))
	for path in Economy.WEAPON_SCENES.values():
		var weapon: PackedScene = load(path)
		keep.append(weapon)
		put.call(_still(weapon.instantiate()))
	for model in HadedaBoss.STAGE_MODELS:     # skinned meshes compile their own variants
		var boss: Node3D = model.instantiate()
		boss.scale = Vector3.ONE * 0.25
		put.call(boss, 2.0)

	# a cyborg fight drives the boss-only effects; it drops from high up, out of the way
	var fight := BossFight.new()
	fight.stage = HadedaBoss.Stage.CYDEDA
	fight.car = car
	fight.arena_radius = 140.0
	add_child(fight)
	fight.position = Vector3(0, -40, -60)
	var fx_at := global_position + global_basis.y * -4.0
	fight._lava_burst(fx_at)
	fight._vomit_burst(fx_at)
	(car.get_node("CarAirControl") as CarAirControl)._shockwave(fx_at, 4.0)
	DamageNumber.spawn(self, fx_at, 12.0, true)
	DamageNumber.spawn(self, fx_at, 3.0, false)
	for child in get_children():
		if child is BaseEnemy:
			child.call("_fog_in")
			break

	# every material in the level (and in everything above), hidden ones included,
	# plus the attack-time ones that don't exist yet (lava lake, leap / laser circles)
	var mats := _materials(level)
	for shader in [BossFight.LAVA_SHADER, BossFight.TARGET_SHADER]:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		mats.append(sm)
	var cards := 0
	for mat in mats:
		if cards >= MAX_CARDS:
			break
		var card := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.3
		card.mesh = quad
		card.material_override = mat
		add_child(card)
		card.position = Vector3((cards % 40 - 20) * 0.32, (floori(cards / 40.0) - 18) * 0.32, 2.0)
		cards += 1

	for i in FRAMES:
		await get_tree().process_frame

	car.freeze = was_frozen
	var fade := cover.create_tween()
	fade.tween_property(cover.get_child(0), "modulate:a", 0.0, 0.35)
	fade.tween_callback(cover.queue_free)
	done.emit()
	queue_free()


## Frozen in place: no AI, no physics, still drawn.
func _still(node: Node) -> Node3D:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	return node


func _materials(root: Node) -> Array[Material]:
	var seen := {}
	var out: Array[Material] = []
	var add := func(m: Material) -> void:
		if m and not seen.has(m):
			seen[m] = true
			out.append(m)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		add.call(gi.material_override)
		add.call(gi.material_overlay)
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
			for s in (gi as MeshInstance3D).get_surface_override_material_count():
				add.call((gi as MeshInstance3D).get_surface_override_material(s))
		elif gi is CPUParticles3D:
			mesh = (gi as CPUParticles3D).mesh
		if mesh:
			for s in mesh.get_surface_count():
				add.call(mesh.surface_get_material(s))
	return out


func _cover() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var rect := ColorRect.new()
	rect.color = Color(0.05, 0.03, 0.02)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "LOADING..."
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.add_child(label)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return layer
