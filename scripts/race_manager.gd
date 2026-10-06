extends Node
## Spawns cars, runs the countdown, validates checkpoints/laps, ranks cars and shows results.

const TOTAL_LAPS := 3
const TIME_LIMIT := 180.0  # time trial budget, seconds
const CAR_SCENE := preload("res://scenes/cars/car_base.tscn")
const AIDriver := preload("res://scripts/ai_car.gd")
const AI_COLORS := [Color(0.9, 0.15, 0.15), Color(0.2, 0.8, 0.3), Color(0.95, 0.85, 0.1)]

@onready var hud := $"../HUD"
@onready var camera := $"../ChaseCamera"

var track: Node3D
var cars: Array = []
var player: VehicleBody3D
var finish_order: Array = []
var time_trial := Global.mode == Global.Mode.TIME_TRIAL
var countdown := 3.0
var racing := false
var race_time := 0.0
var lap_start := 0.0
var best_lap := INF
var _off_track := {}  # car -> seconds spent outside the walls


func setup(t: Node3D) -> void:
	track = t
	var wps: Array = t.WAYPOINTS
	var dir: Vector3 = t.dir_out(0)
	var side := Vector3(-dir.z, 0, dir.x)
	var count := 1 if time_trial else 4
	for k in count:
		var car := CAR_SCENE.instantiate()
		var slot := count - 1 - k  # player (k=0) starts at the back
		var lateral := 0.0 if count == 1 else (slot % 2 * 2 - 1) * 3.5
		var pos: Vector3 = wps[0] + dir * (26.0 - slot / 2 * 8.0) + side * lateral + Vector3.UP * 0.5
		car.transform = Transform3D(Basis.looking_at(-dir), pos)
		car.respawn_transform = car.transform
		if k == 0:
			car.apply_data(Global.get_car())
			player = car
		else:
			car.apply_data(Global.cars[k % Global.cars.size()], AI_COLORS[k - 1])
			car.is_player = false
			car.top_speed *= randf_range(0.85, 0.95)
			var ai := AIDriver.new()
			ai.waypoints = wps
			ai.lane = randf_range(-2.0, 2.0)
			car.add_child(ai)
		track.add_child(car)
		cars.append(car)
	camera.target = player
	hud.setup(wps, cars, player)


func _physics_process(delta: float) -> void:
	if not player:
		return
	if countdown > 0.0:
		countdown -= delta
		hud.center_text(str(ceili(countdown)))
		if countdown <= 0.0:
			racing = true
			for c in cars:
				c.controls_enabled = true
			hud.center_text("GO!")
			get_tree().create_timer(1.0).timeout.connect(hud.center_text.bind(""))
	elif racing:
		race_time += delta
		if time_trial and race_time >= TIME_LIMIT:
			_end("TIME UP!")
	# Anyone outside the walls (e.g. jumped over them) gets reset after 2 s.
	for c in cars:
		var out: bool = track.distance_to_track(c.global_position) > track.WIDTH / 2.0 + 2.0
		_off_track[c] = _off_track.get(c, 0.0) + delta if out else 0.0
		if _off_track[c] > 2.0:
			c.respawn()
	_update_hud()


func _update_hud() -> void:
	var n: int = track.WAYPOINTS.size()
	var lap := mini(player.passed / n + 1, TOTAL_LAPS)
	var time_text := fmt_time(race_time)
	var info := ""
	if time_trial:
		time_text += "   LEFT " + fmt_time(maxf(TIME_LIMIT - race_time, 0.0))
		info = "BEST LAP " + (fmt_time(best_lap) if best_lap < INF else "--")
	else:
		info = "POS %d/%d" % [position_of(player), cars.size()]
	hud.update_hud(player.linear_velocity.length() * 3.6, player.nitro, "LAP %d/%d" % [lap, TOTAL_LAPS], time_text, info, player.power)


func on_checkpoint(body: Node3D, i: int) -> void:
	if not cars.has(body) or body.finished:
		return
	var n: int = track.WAYPOINTS.size()
	if i != (body.passed + 1) % n:
		return  # out of order: shortcut or going backwards
	body.passed += 1
	body.respawn_transform = track.checkpoint_transform(i)
	if i != 0:
		return
	if body == player and racing:
		best_lap = minf(best_lap, race_time - lap_start)
		lap_start = race_time
	if body.passed >= n * TOTAL_LAPS:
		body.finished = true
		finish_order.append(body)
		if body == player and racing:
			_end("FINISHED!")


func progress(c: VehicleBody3D) -> float:
	if c.finished:
		return 1000.0 - finish_order.find(c)
	var wps: Array = track.WAYPOINTS
	var prev: Vector3 = wps[c.passed % wps.size()]
	var nxt: Vector3 = wps[(c.passed + 1) % wps.size()]
	return c.passed + clampf(1.0 - c.global_position.distance_to(nxt) / prev.distance_to(nxt), 0.0, 1.0)


func position_of(car: VehicleBody3D) -> int:
	var p := progress(car)
	return 1 + cars.filter(func(c): return progress(c) > p).size()


func _end(title: String) -> void:
	racing = false
	player.controls_enabled = false
	var lines := "Total time: " + fmt_time(race_time)
	if not time_trial:
		lines += "\nFinal rank: " + ["1st", "2nd", "3rd", "4th"][position_of(player) - 1]
	if best_lap < INF:
		lines += "\nBest lap: " + fmt_time(best_lap)
	hud.show_results(title, lines, player.finished)


static func fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
