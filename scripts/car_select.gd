extends Node3D
## Showroom: rotating pedestal, car browsing, mode pick, start race.

const CAR_SCENE := preload("res://scenes/cars/car_base.tscn")

var car: VehicleBody3D

@onready var turntable: Node3D = $Turntable
@onready var ui := $UI


func _ready() -> void:
	$Camera3D.look_at_from_position(Vector3(0, 2.4, 7.0), Vector3(0, 0.8, 0))
	ui.get_node("Prev").pressed.connect(_cycle.bind(-1))
	ui.get_node("Next").pressed.connect(_cycle.bind(1))
	var tt: Button = ui.get_node("Modes/TimeTrial")
	var ai: Button = ui.get_node("Modes/AIRace")
	tt.button_pressed = Global.mode == Global.Mode.TIME_TRIAL
	ai.button_pressed = Global.mode == Global.Mode.AI_RACE
	tt.pressed.connect(func(): Global.mode = Global.Mode.TIME_TRIAL)
	ai.pressed.connect(func(): Global.mode = Global.Mode.AI_RACE)
	ui.get_node("Race").pressed.connect(get_tree().change_scene_to_file.bind(Global.TRACK_SCENE))
	_show_car()


func _process(delta: float) -> void:
	turntable.rotate_y(delta * 0.5)


func _cycle(step: int) -> void:
	Global.selected_car = wrapi(Global.selected_car + step, 0, Global.cars.size())
	_show_car()


func _show_car() -> void:
	if car:
		car.queue_free()
	var data := Global.get_car()
	car = CAR_SCENE.instantiate()
	car.freeze = true  # display only
	car.apply_data(data)
	turntable.add_child(car)
	ui.get_node("CarName").text = data.car_name
	ui.get_node("Stats/Accel").value = data.acceleration * 100.0
	ui.get_node("Stats/Speed").value = data.top_speed * 100.0
	ui.get_node("Stats/Handling").value = data.handling * 100.0
