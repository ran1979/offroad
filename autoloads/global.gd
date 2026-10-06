extends Node
## Global state: car roster, current selection and race mode.

enum Mode { TIME_TRIAL, AI_RACE }

const MENU_SCENE := "res://scenes/ui/car_select.tscn"
const TRACK_SCENE := "res://scenes/tracks/offroad_track.tscn"

var cars: Array[CarData] = [
	CarData.create("buggy", "Dune Buggy", "res://scenes/cars/buggy_mesh.tscn", 0.95, 0.75, 0.95, Color(1.0, 0.45, 0.1)),
	CarData.create("truck", "Trophy Truck", "res://scenes/cars/truck_mesh.tscn", 0.7, 1.0, 0.65, Color(0.15, 0.45, 0.95)),
]
var selected_car := 0
var mode := Mode.AI_RACE


func get_car() -> CarData:
	return cars[selected_car]


## Tints every MeshInstance3D whose name starts with "Paint".
func paint(root: Node, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.4
	mat.roughness = 0.35
	for m in root.find_children("Paint*", "MeshInstance3D"):
		m.material_override = mat


# Android back button / Esc: race -> menu, menu -> quit.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()


func go_back() -> void:
	if get_tree().current_scene.scene_file_path == MENU_SCENE:
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)
