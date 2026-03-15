extends Node3D


func _ready() -> void:
	var air_control := $Car/CarAirControl as CarAirControl
	var trick_display := $TrickDisplay
	if air_control and trick_display:
		air_control.trick_landed.connect(trick_display.show_trick)
