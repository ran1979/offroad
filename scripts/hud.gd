extends CanvasLayer
## Race HUD: speed, nitro, lap, timer, position, minimap, countdown and results overlay.

var track_points: Array = []
var cars: Array = []
var player: Node3D
var _map_scale := 1.0
var _map_offset := Vector2.ZERO

@onready var lap_label: Label = $Root/Info/Lap
@onready var time_label: Label = $Root/Info/Time
@onready var info_label: Label = $Root/Info/Extra
@onready var speed_label: Label = $Root/Speed
@onready var nitro_bar: ProgressBar = $Root/Nitro
@onready var power_label: Label = $Root/Power
@onready var center_label: Label = $Root/Center
@onready var minimap: Control = $Root/Minimap
@onready var results: Control = $Root/Results


func _ready() -> void:
	results.hide()
	minimap.draw.connect(_draw_minimap)
	$Root/Results/VBox/Buttons/Replay.pressed.connect(get_tree().reload_current_scene)
	$Root/Results/VBox/Buttons/Menu.pressed.connect(get_tree().change_scene_to_file.bind(Global.MENU_SCENE))


func setup(points: Array, all_cars: Array, player_car: Node3D) -> void:
	track_points = points
	cars = all_cars
	player = player_car
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var avail := minimap.size - Vector2(24, 24)
	_map_scale = minf(avail.x / (hi.x - lo.x), avail.y / (hi.y - lo.y))
	_map_offset = minimap.size / 2.0 - (lo + hi) / 2.0 * _map_scale


func update_hud(speed_kmh: float, nitro: float, lap: String, time: String, info: String, power := "") -> void:
	power_label.text = "" if power == "" else "%s  [SHIFT]" % power.to_upper()
	power_label.modulate = Powers.COLORS.get(power, Color.WHITE)
	speed_label.text = "%d km/h" % speed_kmh
	nitro_bar.value = nitro
	lap_label.text = lap
	time_label.text = time
	info_label.text = info
	minimap.queue_redraw()


func center_text(text: String) -> void:
	center_label.text = text


func show_results(title: String, lines: String, success := true) -> void:
	$FinishSound.pitch_scale = 1.0 if success else 0.7  # lower, sadder jingle for TIME UP
	$FinishSound.play()
	$Root/Results/VBox/Title.text = title
	$Root/Results/VBox/Stats.text = lines
	results.show()


func _to_map(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * _map_scale + _map_offset


func _draw_minimap() -> void:
	if track_points.is_empty():
		return
	var pts := PackedVector2Array(track_points.map(_to_map))
	pts.append(pts[0])
	minimap.draw_polyline(pts, Color(1, 1, 1, 0.7), 5.0)
	for c in cars:
		var me: bool = c == player
		minimap.draw_circle(_to_map(c.global_position), 6.0 if me else 4.5, Color.CYAN if me else Color.ORANGE_RED)
