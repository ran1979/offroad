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
const SPEED_POWER_TIME := 2.5
const POWER_SOUNDS := {
	"pickup": preload("res://audio/pickup.wav"),
	"fire": preload("res://audio/fire.wav"),
	"speed": preload("res://audio/speed.wav"),
}

var is_player := true
var controls_enabled := false
var steer_input := 0.0
var throttle_input := 0.0
var brake_input := 0.0
var nitro_input := false
var nitro := 100.0
var power_input := false  # use held power this frame
var power := ""  # "", or one of Powers.KINDS
var powers_used := 0
var _boost_time := 0.0  # "speed" power remaining
var _stun_time := 0.0  # spinning out after a hit
var respawn_transform: Transform3D

# Race state, owned by race_manager.gd
var passed := 0
var finished := false

var _stuck_time := 0.0

@onready var wheels := find_children("*", "VehicleWheel3D")
@onready var dust := [$DustL, $DustR]
@onready var flame: CPUParticles3D = $NitroFlame
@onready var engine_sound: AudioStreamPlayer3D = $EngineSound
@onready var nitro_sound: AudioStreamPlayer3D = $NitroSound
@onready var skid_sound: AudioStreamPlayer3D = $SkidSound
@onready var power_sound: AudioStreamPlayer3D = $PowerSound


func _ready() -> void:
	for w in wheels:
		w.suspension_stiffness = suspension_stiffness
		w.damping_compression = suspension_damping
		w.damping_relaxation = suspension_damping * 1.3
		w.wheel_friction_slip = friction_slip * (1.0 if w.use_as_steering else 0.9)
	if not freeze:  # showroom cars stay silent and out of play
		engine_sound.play()
		add_to_group("cars")


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
		power_input = Input.is_action_just_pressed("use_power")
		if controls_enabled and Input.is_action_just_pressed("reset_car"):
			respawn()  # manual unstick: back to the last checkpoint
	if controls_enabled and power_input and power != "":
		_use_power()
	_boost_time = maxf(_boost_time - delta, 0.0)
	if _boost_time > 0.0:
		throttle_input = 1.0
	if _stun_time > 0.0:  # spinning out: no control
		_stun_time -= delta
		steer_input = 0.0
		throttle_input = 0.0
		brake_input = 0.0
		nitro_input = false
	if not controls_enabled:
		steer_input = 0.0
		throttle_input = 0.0
		brake_input = 1.0
		nitro_input = false

	var speed := linear_velocity.length()
	var fwd_speed := linear_velocity.dot(global_basis.z)
	var drift := absf(linear_velocity.dot(global_basis.x))
	var grounded := is_grounded()
	var nitro_on := nitro_input and nitro > 0.0 and throttle_input > 0.0
	var boosting := nitro_on or _boost_time > 0.0
	var mult := NITRO_MULT if nitro_on else 1.0
	if _boost_time > 0.0:
		mult = 1.7

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
	if nitro_on:
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

	# Audio: engine pitch follows speed and revs up on gas; loops toggle with nitro / braking / drifting.
	engine_sound.pitch_scale = 0.6 + clampf(absf(fwd_speed) / top_speed, 0.0, 1.5) * 1.2 + throttle_input * 0.2
	engine_sound.volume_db = -14.0 + throttle_input * 8.0
	_set_loop(nitro_sound, boosting)
	_set_loop(skid_sound, grounded and ((brake_input > 0.0 and fwd_speed > 5.0) or drift > 6.0))

	# Auto-respawn when flipped, fallen off, or wedged against something.
	var stuck := global_basis.y.y < 0.3 or global_position.y < -10.0 or (speed < 0.5 and (throttle_input > 0.0 or brake_input > 0.0))
	_stuck_time = _stuck_time + delta if controls_enabled and stuck else 0.0
	if _stuck_time > 3.0:
		respawn()


## Called by pickups. Returns false if already holding a power.
func give_power() -> bool:
	if power != "":
		return false
	power = Powers.KINDS.pick_random()
	_play_power_sound("pickup")
	return true


## Knocked by a fireball or boom: `push` is a velocity change (m/s).
func hit(push: Vector3) -> void:
	apply_central_impulse(push * mass)
	apply_torque_impulse(Vector3.UP * (8.0 if randf() < 0.5 else -8.0) * mass)
	_stun_time = 1.2


func _use_power() -> void:
	match power:
		"speed":
			_boost_time = SPEED_POWER_TIME
			apply_central_impulse(global_basis.z * 5.0 * mass)
			_play_power_sound("speed")
		"fire":
			var fb := Powers.Fireball.new()
			fb.shooter = self
			fb.velocity = global_basis.z * (maxf(linear_velocity.dot(global_basis.z), 0.0) + 40.0)
			fb.position = global_position + global_basis.z * 3.0 + Vector3.UP
			get_parent().add_child(fb)
			_play_power_sound("fire")
		"boom":
			const RADIUS := 14.0
			for c in get_tree().get_nodes_in_group("cars"):
				var away: Vector3 = c.global_position - global_position
				if c != self and away.length() < RADIUS:
					var falloff := 1.0 - away.length() / RADIUS * 0.5
					c.hit((Vector3(away.x, 0, away.z).normalized() * 10.0 + Vector3.UP * 7.0) * falloff)
			Powers.flash(get_parent(), global_position + Vector3.UP, Powers.COLORS.boom, RADIUS)
	power = ""
	powers_used += 1


func _play_power_sound(key: String) -> void:
	power_sound.stream = POWER_SOUNDS[key]
	power_sound.play()


func _set_loop(player: AudioStreamPlayer3D, on: bool) -> void:
	if player.playing != on:
		player.playing = on


func respawn() -> void:
	global_transform = respawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_stuck_time = 0.0
	_stun_time = 0.0
