class_name Powers
## Road power-ups: pickup boxes, the fireball projectile and explosion flashes.
## Cars hold one power at a time (see car_base.gd give_power / _use_power).

const KINDS := ["fire", "boom", "speed"]
const COLORS := {"fire": Color(1.0, 0.45, 0.1), "boom": Color(1.0, 0.2, 0.2), "speed": Color(0.2, 0.85, 1.0)}
const BOOM_SOUND := preload("res://audio/boom.wav")


static func glow(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Expanding fading sphere + boom sound at `pos`.
static func flash(parent: Node, pos: Vector3, color: Color, radius: float) -> void:
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = glow(color, 0.7)
	ball.position = pos
	ball.scale = Vector3.ONE * 0.5
	parent.add_child(ball)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = BOOM_SOUND
	snd.unit_size = 15.0
	ball.add_child(snd)
	snd.play()
	var tw := ball.create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * radius, 0.4)
	tw.tween_property(ball.material_override, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_interval(1.0)  # let the sound finish
	tw.chain().tween_callback(ball.queue_free)


## Spinning box on the road; gives a random power, respawns after a few seconds.
class Pickup extends Area3D:
	var _mesh := MeshInstance3D.new()
	var _t := randf() * TAU

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(2.5, 3.0, 2.5)
		shape.position.y = 1.5
		add_child(shape)
		_mesh.mesh = BoxMesh.new()
		_mesh.mesh.size = Vector3.ONE * 1.1
		_mesh.material_override = Powers.glow(Color(1.0, 0.85, 0.2), 0.85)
		add_child(_mesh)
		body_entered.connect(_on_body)

	func _process(delta: float) -> void:
		_t += delta
		_mesh.rotation = Vector3(0.6, _t * 2.0, 0.3)
		_mesh.position.y = 1.3 + sin(_t * 3.0) * 0.25

	func _on_body(body: Node3D) -> void:
		if not _mesh.visible or not body.has_method("give_power") or not body.give_power():
			return
		_mesh.visible = false
		await get_tree().create_timer(5.0).timeout
		_mesh.visible = true
		for b in get_overlapping_bodies():  # someone parked on it
			_on_body(b)
			break


## Fast projectile that homes gently on the nearest car ahead.
class Fireball extends Area3D:
	var shooter: Node3D
	var velocity: Vector3
	var _life := 3.0

	func _ready() -> void:
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = 0.8
		add_child(shape)
		var ball := MeshInstance3D.new()
		ball.mesh = SphereMesh.new()
		ball.mesh.radius = 0.45
		ball.mesh.height = 0.9
		ball.material_override = Powers.glow(Powers.COLORS.fire)
		add_child(ball)
		var light := OmniLight3D.new()
		light.light_color = Powers.COLORS.fire
		light.omni_range = 6.0
		add_child(light)
		body_entered.connect(_on_body)

	func _physics_process(delta: float) -> void:
		var dir := velocity.normalized()
		for c in get_tree().get_nodes_in_group("cars"):
			var to: Vector3 = c.global_position - global_position
			if c != shooter and to.length() < 60.0 and dir.dot(to.normalized()) > 0.85:
				velocity = velocity.slerp(to.normalized() * velocity.length(), 4.0 * delta)
				break
		global_position += velocity * delta
		_life -= delta
		if _life <= 0.0:
			queue_free()

	func _on_body(body: Node3D) -> void:
		if body == shooter:
			return
		if body.has_method("hit"):
			body.hit(velocity.normalized() * 6.0 + Vector3.UP * 6.0)
		Powers.flash(get_parent(), global_position, Powers.COLORS.fire, 5.0)
		queue_free()
