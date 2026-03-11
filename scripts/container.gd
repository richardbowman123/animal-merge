extends Node3D
class_name GameContainer

const WIDTH := 5.0
const DEPTH := 5.0
const HEIGHT := 9.0
const WALL_THICKNESS := 0.2
const EDGE_COLOR := Color(0.3, 0.6, 1.0, 1.0)
const WALL_COLOR := Color(0.7, 0.85, 1.0, 0.12)
const DEATH_LINE_HEIGHT := 8.5  # 0.5 units below top

var death_line_y: float:
	get: return global_position.y + DEATH_LINE_HEIGHT

func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_edges()
	_build_death_line()

func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, WALL_THICKNESS, DEPTH)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0.0, -WALL_THICKNESS / 2.0, 0.0)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(WIDTH, WALL_THICKNESS, DEPTH)
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.4
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	add_child(body)

func _build_walls() -> void:
	var hw := WIDTH / 2.0
	var hd := DEPTH / 2.0
	var hh := HEIGHT / 2.0
	var walls := [
		[Vector3(-hw - WALL_THICKNESS / 2.0, hh, 0.0), Vector3(WALL_THICKNESS, HEIGHT, DEPTH)],
		[Vector3(hw + WALL_THICKNESS / 2.0, hh, 0.0), Vector3(WALL_THICKNESS, HEIGHT, DEPTH)],
		[Vector3(0.0, hh, -hd - WALL_THICKNESS / 2.0), Vector3(WIDTH, HEIGHT, WALL_THICKNESS)],
		[Vector3(0.0, hh, hd + WALL_THICKNESS / 2.0), Vector3(WIDTH, HEIGHT, WALL_THICKNESS)],
	]
	for wall_def in walls:
		var pos: Vector3 = wall_def[0]
		var sz: Vector3 = wall_def[1]
		_create_wall(pos, sz)

func _create_wall(pos: Vector3, sz: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	col.shape = box
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = sz
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WALL_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.2
	mat.metallic = 0.1
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	add_child(body)

func _build_edges() -> void:
	var hw := WIDTH / 2.0
	var hd := DEPTH / 2.0
	var edge_radius := 0.03

	# Vertical edges (4 corners)
	var corners := [
		Vector3(-hw, 0.0, -hd),
		Vector3(hw, 0.0, -hd),
		Vector3(-hw, 0.0, hd),
		Vector3(hw, 0.0, hd),
	]
	for c in corners:
		_add_edge_line(c, c + Vector3(0, HEIGHT, 0), edge_radius)

	# Bottom horizontal edges
	_add_edge_line(Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), edge_radius)
	_add_edge_line(Vector3(-hw, 0, hd), Vector3(hw, 0, hd), edge_radius)
	_add_edge_line(Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), edge_radius)
	_add_edge_line(Vector3(hw, 0, -hd), Vector3(hw, 0, hd), edge_radius)

	# Top horizontal edges
	_add_edge_line(Vector3(-hw, HEIGHT, -hd), Vector3(hw, HEIGHT, -hd), edge_radius)
	_add_edge_line(Vector3(-hw, HEIGHT, hd), Vector3(hw, HEIGHT, hd), edge_radius)
	_add_edge_line(Vector3(-hw, HEIGHT, -hd), Vector3(-hw, HEIGHT, hd), edge_radius)
	_add_edge_line(Vector3(hw, HEIGHT, -hd), Vector3(hw, HEIGHT, hd), edge_radius)

func _add_edge_line(from: Vector3, to: Vector3, radius: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var length := from.distance_to(to)
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 8
	mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = EDGE_COLOR
	mat.emission_enabled = true
	mat.emission = EDGE_COLOR
	mat.emission_energy_multiplier = 2.0
	mat.roughness = 0.1
	mesh_inst.material_override = mat

	# Must add to tree BEFORE positioning — look_at crashes if node is not in tree
	add_child(mesh_inst)

	var midpoint := (from + to) / 2.0
	mesh_inst.position = midpoint

	var direction := (to - from).normalized()
	if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
		# Rotate cylinder from default Y-axis to align with direction
		var axis := Vector3.UP.cross(direction).normalized()
		var angle := Vector3.UP.angle_to(direction)
		mesh_inst.basis = Basis(axis, angle)

func _build_death_line() -> void:
	var hw := WIDTH / 2.0 + 0.1
	var hd := DEPTH / 2.0 + 0.1
	var y := DEATH_LINE_HEIGHT
	var radius := 0.02

	var lines := [
		[Vector3(-hw, y, -hd), Vector3(hw, y, -hd)],
		[Vector3(-hw, y, hd), Vector3(hw, y, hd)],
		[Vector3(-hw, y, -hd), Vector3(-hw, y, hd)],
		[Vector3(hw, y, -hd), Vector3(hw, y, hd)],
	]

	for line_def in lines:
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var from: Vector3 = line_def[0]
		var to: Vector3 = line_def[1]
		var length := from.distance_to(to)
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = length
		cyl.radial_segments = 8
		mesh_inst.mesh = cyl

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.RED
		mat.emission_enabled = true
		mat.emission = Color.RED
		mat.emission_energy_multiplier = 3.0
		mat.roughness = 0.1
		mesh_inst.material_override = mat

		# Must add to tree BEFORE positioning
		add_child(mesh_inst)

		var midpoint := (from + to) / 2.0
		mesh_inst.position = midpoint

		var direction := (to - from).normalized()
		if not direction.is_equal_approx(Vector3.UP) and not direction.is_equal_approx(Vector3.DOWN):
			var axis := Vector3.UP.cross(direction).normalized()
			var angle := Vector3.UP.angle_to(direction)
			mesh_inst.basis = Basis(axis, angle)

func get_drop_bounds() -> Rect2:
	var hw := WIDTH / 2.0 - 0.2
	var hd := DEPTH / 2.0 - 0.2
	return Rect2(-hw, -hd, WIDTH - 0.4, DEPTH - 0.4)
