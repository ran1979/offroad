class_name CarData
extends Resource
## Static description of a selectable car. Stats are 0..1 ratings, mapped to physics in car_base.gd.

@export var car_id := ""
@export var car_name := ""
@export var mesh_scene_path := ""
@export_range(0, 1) var acceleration := 0.8
@export_range(0, 1) var top_speed := 0.8
@export_range(0, 1) var handling := 0.8
@export var color := Color.WHITE


static func create(id: String, display_name: String, mesh_path: String, accel: float, speed: float, grip: float, tint: Color) -> CarData:
	var d := CarData.new()
	d.car_id = id
	d.car_name = display_name
	d.mesh_scene_path = mesh_path
	d.acceleration = accel
	d.top_speed = speed
	d.handling = grip
	d.color = tint
	return d
