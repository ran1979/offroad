extends Node
## AI driver: added as a child of a car_base car, steers toward track waypoints.

var waypoints: Array
var target := 1  # waypoint index being steered at
var lane := 0.0  # lateral offset (m) so opponents don't share one line

var _slow_time := 0.0
var _reverse_time := 0.0

@onready var car: VehicleBody3D = get_parent()


func _physics_process(delta: float) -> void:
	var n := waypoints.size()
	# Aim at the next checkpoint the race still needs (so a miss gets corrected),
	# turning in toward the following one only when about to pass it; earlier clips inner walls.
	target = (car.passed + 1) % n
	var wp: Vector3 = waypoints[target]
	var rel := car.global_position - wp
	if rel.dot((wp - waypoints[target - 1]).normalized()) > -8.0 and rel.length() < 20.0:
		target = (target + 1) % n
		wp = waypoints[target]
	var dir: Vector3 = (waypoints[(target + 1) % n] - wp).normalized()
	var to := wp + Vector3(-dir.z, 0, dir.x) * lane - car.global_position
	to.y = 0.0

	var local := car.global_basis.inverse() * to
	var angle := atan2(local.x, local.z)  # +x is the car's left
	var speed := car.linear_velocity.length()
	car.steer_input = clampf(angle * 2.0, -1.0, 1.0)
	car.throttle_input = 0.4 if absf(angle) > 0.5 and speed > 15.0 else 1.0
	car.brake_input = 1.0 if absf(angle) > 0.9 and speed > 18.0 else 0.0
	car.nitro_input = absf(angle) < 0.15 and car.nitro > 40.0

	# Wedged against a wall: back out with opposite lock.
	_slow_time = _slow_time + delta if car.controls_enabled and speed < 1.5 else 0.0
	if _slow_time > 1.0:
		_slow_time = 0.0
		_reverse_time = 1.2
	if _reverse_time > 0.0:
		_reverse_time -= delta
		car.steer_input = -car.steer_input
		car.throttle_input = 0.0
		car.brake_input = 1.0
