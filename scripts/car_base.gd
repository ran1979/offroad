extends VehicleBody3D
## Shared car physics for player and AI. Inputs are read from the keyboard/touch
## actions when is_player, otherwise set externally (see ai_car.gd).
## Note: `engine_force` / `brake` are built-in VehicleBody3D properties, hence the max_ prefix.

@export var max_engine_force := 260.0  # per wheel (4WD)
@export var max_brake_force := 4.0
@export var max_steer_angle := 0.45
@export var top_speed := 30.0  # m/s
@export var suspension_stiffness := 40.0
@export var suspension_damping := 2.0
@export var friction_slip := 3.0
@export var air_control_torque := 0.8

const NITRO_MULT := 1.5
const NITRO_DRAIN := 30.0  # % per second
const NITRO_REGEN := 8.0   # % per second while fast or drifting

var is_player := true
var controls_enabled := false
var steer_input := 0.0
var throttle_input := 0.0
var brake_input := 0.0
var nitro_input := false
var nitro := 100.0
var respawn_transform: Transform3D

# Race state, owned by race_manager.gd
var passed := 0
var finished := false

var _stuck_time := 0.0

@onready var wheels := find_children("*", "VehicleWheel3D")
@onready var dust := [$DustL, $DustR]
@onready var flame: CPUParticles3D = $NitroFlame


func _ready() -> void:
	for w in wheels:
		w.suspension_stiffness = suspension_stiffness
		w.damping_compression = suspension_damping
		w.damping_relaxation = suspension_damping * 1.3
		w.wheel_friction_slip = friction_slip * (1.0 if w.use_as_steering else 0.9)


func apply_data(d: CarData, tint := d.color) -> void:
	max_engine_force = lerpf(200.0, 320.0, d.acceleration)
	top_speed = lerpf(26.0, 36.0, d.top_speed)
	friction_slip = lerpf(2.2, 4.0, d.handling)
	max_steer_angle = lerpf(0.35, 0.55, d.handling)
	var mesh: Node3D = load(d.mesh_scene_path).instantiate()
	$Body.add_child(mesh)
	Global.paint(mesh, tint)


func is_grounded() -> bool:
	return wheels.any(func(w): return w.is_in_contact())


func _physics_process(delta: float) -> void:
	if is_player:
		steer_input = Input.get_axis("steer_right", "steer_left")
		throttle_input = Input.get_action_strength("accelerate")
		brake_input = Input.get_action_strength("brake")
		nitro_input = Input.is_action_pressed("nitro")
	if not controls_enabled:
		steer_input = 0.0
		throttle_input = 0.0
		brake_input = 1.0
		nitro_input = false

	var speed := linear_velocity.length()
	var fwd_speed := linear_velocity.dot(global_basis.z)
	var drift := absf(linear_velocity.dot(global_basis.x))
	var grounded := is_grounded()
	var boosting := nitro_input and nitro > 0.0 and throttle_input > 0.0
	var mult := NITRO_MULT if boosting else 1.0

	# Steering: less lock at speed.
	var steer_target := steer_input * max_steer_angle * lerpf(1.0, 0.5, clampf(speed / top_speed, 0.0, 1.0))
	steering = move_toward(steering, steer_target, 2.5 * delta)

	engine_force = 0.0
	brake = 0.0
	if throttle_input > 0.0 and fwd_speed < top_speed * mult:
		engine_force = throttle_input * max_engine_force * mult
	if brake_input > 0.0:
		if fwd_speed > 1.0 or not controls_enabled:
			brake = brake_input * max_brake_force
		elif fwd_speed > -8.0:
			engine_force = -brake_input * max_engine_force * 0.6  # reverse

	# Nitro gauge
	if boosting:
		nitro = maxf(nitro - NITRO_DRAIN * delta, 0.0)
	elif grounded and (speed > top_speed * 0.7 or drift > 4.0):
		nitro = minf(nitro + NITRO_REGEN * delta, 100.0)

	# Mid-air stabilization: gas/brake pitch, steer rolls.
	if not grounded:
		var t := global_basis.x * (throttle_input - brake_input) - global_basis.z * steer_input * 0.5
		apply_torque(t * air_control_torque * mass)

	flame.emitting = boosting
	var dusty := grounded and speed > 3.0 and (throttle_input > 0.0 or drift > 3.0)
	for d in dust:
		d.emitting = dusty

	# Auto-respawn when flipped, fallen off, or wedged against something.
	var stuck := global_basis.y.y < 0.3 or global_position.y < -10.0 or (speed < 0.5 and (throttle_input > 0.0 or brake_input > 0.0))
	_stuck_time = _stuck_time + delta if controls_enabled and stuck else 0.0
	if _stuck_time > 3.0:
		respawn()


func respawn() -> void:
	global_transform = respawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_stuck_time = 0.0
