extends Camera3D
## Smooth third-person follow camera with a speed FOV kick.

var target: VehicleBody3D


func _physics_process(delta: float) -> void:
	if not target:
		return
	var back := target.global_basis.z
	back.y = 0.0
	var want := target.global_position - back.normalized() * 7.5 + Vector3.UP * 3.2
	global_position = global_position.lerp(want, 1.0 - exp(-5.0 * delta))
	look_at(target.global_position + Vector3.UP * 1.2)
	fov = lerpf(fov, 70.0 + target.linear_velocity.length() * 0.5, 3.0 * delta)
