extends Node
## Headless smoke test: godot --headless --fixed-fps 60 res://tests/smoke_test.tscn
## Player holds gas on the first straight; every AI must complete a lap within 60 s.

var frame := 0
var rm: Node


func _ready() -> void:
	Global.mode = Global.Mode.AI_RACE
	var track: Node = load(Global.TRACK_SCENE).instantiate()
	add_child(track)
	rm = track.get_node("RaceManager")
	Input.action_press("accelerate")


func _fail(msg: String) -> void:
	push_error("SMOKE FAIL: " + msg)
	get_tree().quit(1)


func _physics_process(_d: float) -> void:
	frame += 1
	var p: VehicleBody3D = rm.player
	if frame % 120 == 0:
		print("t=%ds player %.0f km/h y=%.2f" % [frame / 60, p.linear_velocity.length() * 3.6, p.global_position.y])
		for c in rm.cars.slice(1):
			var ai: Node = c.get_child(-1)
			print("   AI passed=%d tgt=%d pos=%v v=%.1f up=%.2f steer=%.2f" % [c.passed, ai.target, c.global_position.snapped(Vector3.ONE * 0.1), c.linear_velocity.length(), c.global_basis.y.y, c.steering])
	if frame == 60 * 9:
		if p.linear_velocity.length() * 3.6 < 60.0:
			_fail("player too slow")
		if not p.engine_sound.playing or p.engine_sound.pitch_scale < 1.2:
			_fail("engine sound not revving")
		Input.action_release("accelerate")
	if frame == 60 * 60:
		for c in rm.cars.slice(1):
			if c.passed < 12:
				_fail("AI stalled at checkpoint %d" % c.passed)
				return
		# Out-of-order checkpoint is ignored; the final valid one ends the race.
		var n: int = rm.track.WAYPOINTS.size()
		p.passed = n * rm.TOTAL_LAPS - 1
		rm.on_checkpoint(p, 5)
		if p.passed != n * rm.TOTAL_LAPS - 1:
			_fail("shortcut checkpoint accepted")
		rm.on_checkpoint(p, 0)
		if not (p.finished and rm.hud.results.visible):
			_fail("race did not finish")
		if not rm.hud.get_node("FinishSound").playing:
			_fail("no finish sound")
		print(rm.hud.get_node("Root/Results/VBox/Stats").text)
		print("AI passed: ", rm.cars.slice(1).map(func(c): return c.passed))
		print("SMOKE OK")
		get_tree().quit()
