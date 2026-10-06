extends Node3D
## Builds the road, boundary walls, ramps and checkpoints from WAYPOINTS (a closed loop),
## then hands off to the RaceManager.

const WIDTH := 16.0
const WAYPOINTS: Array[Vector3] = [
	Vector3(-90, 0, -70), Vector3(0, 0, -75), Vector3(100, 0, -70), Vector3(140, 0, -40),
	Vector3(150, 0, 10), Vector3(130, 0, 50), Vector3(80, 0, 70), Vector3(-10, 0, 70),
	Vector3(-50, 0, 45), Vector3(-100, 0, 55), Vector3(-140, 0, 20), Vector3(-145, 0, -30),
	Vector3(-125, 0, -65),
]
## [segment, fraction along it, angle in degrees]; each sits on a long straight so jumps land clear of corners.
const RAMPS := [[0, 0.7, 8.0], [1, 0.3, 11.0], [6, 0.25, 11.0]]
const RAMP_SIZE := Vector3(9, 0.6, 9)

@onready var race_manager := $RaceManager


func _ready() -> void:
	_build_road()
	for r in RAMPS:
		_add_ramp(r[0], r[1], r[2])
	for i in WAYPOINTS.size():
		_add_checkpoint(i)
	race_manager.setup(self)


func dir_out(i: int) -> Vector3:
	return (WAYPOINTS[(i + 1) % WAYPOINTS.size()] - WAYPOINTS[i]).normalized()


## Mitered half-width vector at waypoint i, so the road keeps WIDTH through corners.
func edge(i: int) -> Vector3:
	var d_in := dir_out(i - 1)
	var t := (d_in + dir_out(i)).normalized()
	var side := Vector3(-t.z, 0, t.x)
	return side * (WIDTH / 2.0) / side.dot(Vector3(-d_in.z, 0, d_in.x))


## Respawn pose at waypoint i; random lane so several respawning cars rarely stack.
func distance_to_track(p: Vector3) -> float:
	var best := INF
	for i in WAYPOINTS.size():
		var q := Geometry3D.get_closest_point_to_segment(p, WAYPOINTS[i], WAYPOINTS[(i + 1) % WAYPOINTS.size()])
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


func checkpoint_transform(i: int) -> Transform3D:
	var d := dir_out(i)
	var lane := Vector3(-d.z, 0, d.x) * randf_range(-WIDTH / 2.0 + 3.0, WIDTH / 2.0 - 3.0)
	return Transform3D(Basis.looking_at(-d), WAYPOINTS[i] + d * 6.0 + lane + Vector3.UP)


func _mat(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.roughness = 1.0
	m.metallic_specular = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_road() -> void:
	var n := WAYPOINTS.size()
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = FastNoiseLite.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var lift := Vector3.UP * 0.03
	var v := 0.0
	var wall_k := (WIDTH / 2.0 + 1.0) / (WIDTH / 2.0)
	var wall_mats := [_mat(Color(0.85, 0.15, 0.1)), _mat(Color(0.95, 0.95, 0.95))]
	for i in n:
		var a := WAYPOINTS[i]
		var b := WAYPOINTS[(i + 1) % n]
		var ea := edge(i)
		var eb := edge((i + 1) % n)
		var v2 := v + a.distance_to(b) / WIDTH
		for tri in [[a + ea, 0, v], [a - ea, 1, v], [b + eb, 0, v2], [a - ea, 1, v], [b - eb, 1, v2], [b + eb, 0, v2]]:
			st.set_uv(Vector2(tri[1], tri[2]))
			st.add_vertex(tri[0] + lift)
		v = v2
		_add_block(a + ea * wall_k, b + eb * wall_k, 1.0, wall_mats[i % 2])
		_add_block(a - ea * wall_k, b - eb * wall_k, 1.0, wall_mats[(i + 1) % 2])
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = _mat(Color(0.45, 0.32, 0.22), noise_tex)
	add_child(road)
	# Start/finish line
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, 0.02, 1.5)
	line.mesh = box
	line.material_override = _mat(Color.WHITE)
	line.transform = Transform3D(Basis.looking_at(-dir_out(0)), WAYPOINTS[0] + Vector3.UP * 0.04)
	add_child(line)


## Static box wall from p to q (centre line), `height` tall.
func _add_block(p: Vector3, q: Vector3, height: float, mat: Material) -> void:
	var size := Vector3(0.8, height, p.distance_to(q))
	_add_static(Transform3D(Basis.looking_at(q - p), (p + q) / 2.0 + Vector3.UP * height / 2.0), size, mat)


func _add_static(xf: Transform3D, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(mesh)
	body.add_child(shape)
	body.transform = xf
	add_child(body)


## Tilted box whose low edge sits on the ground mid-segment; the high edge is a jump lip.
func _add_ramp(seg: int, along: float, degrees: float) -> void:
	var a := WAYPOINTS[seg]
	var b := WAYPOINTS[(seg + 1) % WAYPOINTS.size()]
	var angle := deg_to_rad(degrees)
	var basis := Basis.looking_at(-dir_out(seg)) * Basis(Vector3.RIGHT, -angle)
	var y := RAMP_SIZE.z / 2.0 * sin(angle) - RAMP_SIZE.y / 2.0 * cos(angle)
	_add_static(Transform3D(basis, a.lerp(b, along) + Vector3.UP * y), RAMP_SIZE, _mat(Color(0.8, 0.55, 0.25)))


func _add_checkpoint(i: int) -> void:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(edge(i).length() * 2.0 + 6.0, 8.0, 6.0)
	area.add_child(shape)
	var t := (dir_out(i - 1) + dir_out(i)).normalized()
	area.transform = Transform3D(Basis.looking_at(-t), WAYPOINTS[i] + Vector3.UP * 2.0)
	area.body_entered.connect(race_manager.on_checkpoint.bind(i))
	add_child(area)
