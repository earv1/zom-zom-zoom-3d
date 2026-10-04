class_name PitStore
extends Node3D
## Drive-in store. It always has OFFERS upgrades on the shelf, rolled ahead of
## time and shown on a sign above the building so you can decide before going
## in. Rolling into the bay parks the car: its exact velocity and spin are saved
## and it is shielded, but the world keeps running (enemies, the boss clock).
## Buy with left/right + jump/enter or the mouse; press accelerate to leave and
## the car shoots out with the momentum it came in with. The shelf re-rolls once
## you've driven away.

signal opened
signal closed

const TITLES := {&"diner": "ROADSIDE DINER", &"petrol": "PETROL STATION", &"sky": "SKY WORKSHOP"}
const OFFERS := 3
const SIGN_HEIGHT := 20.0                 # above the stores' own pole signs

@export var kind := &"diner"
@export var bay_size := Vector3(10.0, 5.0, 12.0)

var car: RigidBody3D
var _saved_velocity := Vector3.ZERO
var _saved_spin := Vector3.ZERO
var _ui: StoreUI
var _armed := true
var offers: Array[StringName] = []
var _rerolling := false
var _sign: Label3D


func _ready() -> void:
	add_to_group("pit_stores")
	var bay := Area3D.new()
	bay.name = "Bay"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bay_size
	cs.shape = box
	cs.position.y = bay_size.y * 0.5
	bay.add_child(cs)
	add_child(bay)
	bay.body_entered.connect(_on_body_entered)
	bay.body_exited.connect(_on_body_exited)
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font_size = 72
	_sign.pixel_size = 0.03
	_sign.outline_size = 18
	_sign.modulate = Color(1.0, 0.95, 0.75)
	_sign.outline_modulate = Color(0.1, 0.05, 0.02)
	_sign.position.y = SIGN_HEIGHT
	add_child(_sign)
	GameManager.scrap_changed.connect(_refresh_sign.unbind(1))
	GameManager.upgrade_bought.connect(_refresh_sign.unbind(2))
	roll()


func is_open() -> bool:
	return is_instance_valid(_ui)


## Upgrade ids on the shelf this visit.
func stock() -> Array[StringName]:
	return offers


## Puts OFFERS random upgrades from this store's catalogue on the shelf,
## skipping anything maxed, owned or missing its weapon.
func roll() -> void:
	var ids: Array[StringName] = []
	for u in Economy.store_upgrades(kind):
		if GameManager.blocker(u.id) in ["", "can't afford"]:
			ids.append(u.id)
	ids.shuffle()
	offers = ids.slice(0, OFFERS)
	_refresh_sign()


func _refresh_sign() -> void:
	if not is_instance_valid(_sign):
		return
	var lines := PackedStringArray([TITLES.get(kind, "STORE")])
	for id in offers:
		var why := GameManager.blocker(id)
		var price := "SOLD" if why in ["maxed", "owned"] else Num.short(GameManager.price_of(id))
		lines.append("%s  %s%s" % [Economy.upgrade(id).name, price, "  (need scrap)" if why == "can't afford" else ""])
	if offers.is_empty():
		lines.append("sold out")
	_sign.text = "\n".join(lines)


func park(body: RigidBody3D) -> void:
	car = body
	_saved_velocity = car.linear_velocity
	_saved_spin = car.angular_velocity
	car.freeze = true
	GameManager.invulnerable = true
	_ui = StoreUI.new()
	_ui.title = TITLES.get(kind, "STORE")
	_ui.items = stock()
	_ui.closed.connect(leave)
	add_child(_ui)
	opened.emit()


func leave() -> void:
	if not is_open():
		return
	_ui.queue_free()
	_ui = null
	car.freeze = false
	car.linear_velocity = _saved_velocity      # pick up exactly where we left off
	car.angular_velocity = _saved_spin
	GameManager.invulnerable = false
	_armed = false                             # re-arms once the car has left the bay
	_rerolling = true
	closed.emit()


func _on_body_entered(body: Node) -> void:
	if _armed and body is RaycastCar and not is_open():
		park(body as RigidBody3D)


func _on_body_exited(body: Node) -> void:
	if body is RaycastCar and not is_open():
		_armed = true
		if _rerolling:                         # fresh stock once you've driven away
			_rerolling = false
			roll()
