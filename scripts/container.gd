extends Node3D
class_name GameContainer

const WIDTH := 5.0
const DEPTH := 5.0
const HEIGHT := 9.0
const WALL_THICKNESS := 0.2
const EDGE_COLOR := Color(0.3, 0.6, 1.0, 1.0)
const WALL_COLOR := Color(0.7, 0.85, 1.0, 0.04)

const YELLOW_LINE_HEIGHT := 7.0
const ORANGE_LINE_HEIGHT := 7.75
const RED_LINE_HEIGHT := 8.5

const YELLOW_COLOR := Color(1.0, 0.9, 0.0)
const ORANGE_COLOR := Color(1.0, 0.5, 0.0)
const RED_COLOR := Color(1.0, 0.0, 0.0)

const YELLOW_PULSE_HZ := 4.0
const ORANGE_PULSE_HZ := 6.0
const RED_PULSE_HZ := 10.0

const DIM_ALPHA := 0.3
const DIM_EMISSION := 0.5

var death_line_y: float:
	get: return global_position.y + RED_LINE_HEIGHT

var yellow_line_y: float:
	get: return global_position.y + YELLOW_LINE_HEIGHT

var orange_line_y: float:
	get: return global_position.y + ORANGE_LINE_HEIGHT

var _yellow_lines: Array[MeshInstance3D] = []
var _orange_lines: Array[MeshInstance3D] = []
var _red_lines: Array[MeshInstance3D] = []

var _warning_level: int = 0
var _pulse_time: float = 0.0

func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_edges()
	_build_warning_lines()

func _process(delta: float) -> void:
	if _warning_level == 0:
		return
	_pulse_time += delta
	_animate_warning_lines()

func set_warning_level(level: int) -> void:
	if level == _warning_level:
		return
	_warning_level = clampi(level, 0, 3)
	_pulse_time = 0.0
	# Reset all lines to dim when level changes
	_set_line_set_dim(_yellow_lines, YELLOW_COLOR)
	_set_line_set_dim(_orange_lines, ORANGE_COLOR)
	_set_line_set_dim(_red_lines, RED_COLOR)

func _animate_warning_lines() -> void:
	if _warning_level >= 1:
		var pulse := _calc_pulse(YELLOW_PULSE_HZ)
		_set_line_alpha(_yellow_lines, lerpf(DIM_ALPHA, 1.0, pulse))
		_set_line_emission(_yellow_lines, lerpf(DIM_EMISSION, 3.0, pulse))
	if _warning_level >= 2:
		var pulse := _calc_pulse(ORANGE_PULSE_HZ)
		_set_line_alpha(_orange_lines, lerpf(DIM_ALPHA, 1.0, pulse))
		_set_line_emission(_orange_lines, lerpf(DIM_EMISSION, 4.0, pulse))
	if _warning_level >= 3:
		var pulse := _calc_pulse(RED_PULSE_HZ)
		_set_line_alpha(_red_lines, lerpf(DIM_ALPHA, 1.0, pulse))
		_set_line_emission(_red_lines, lerpf(DIM_EMISSION, 5.0, pulse))

func _calc_pulse(hz: float) -> float:
	return (sin(_pulse_time * hz * TAU) + 1.0) * 0.5

func _set_line_set_dim(lines: Array[MeshInstance3D], color: Color) -> void:
	for mesh_inst in lines:
		if is_instance_valid(mesh_inst):
			var mat: StandardMaterial3D = mesh_inst.material_override
			mat.albedo_color = Color(color.r, color.g, color.b, DIM_ALPHA)
			mat.emission_energy_multiplier = DIM_EMISSION

func _set_line_alpha(lines: Array[MeshInstance3D], alpha: float) -> void:
	for mesh_inst in lines:
		if is_instance_valid(mesh_inst):
			var mat: StandardMaterial3D = mesh_inst.material_override
			mat.albedo_color.a = alpha

func _set_line_emission(lines: Array[MeshInstance3D], energy: float) -> void:
	for mesh_inst in lines:
		if is_instance_valid(mesh_inst):
			var mat: StandardMaterial3D = mesh_inst.material_override
			mat.emission_energy_multiplier = energy

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
	mat.cull_mode = BaseMaterial3D.CULL_BACK
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

func _build_warning_lines() -> void:
	_build_line_set(YELLOW_LINE_HEIGHT, YELLOW_COLOR, DIM_EMISSION, _yellow_lines)
	_build_line_set(ORANGE_LINE_HEIGHT, ORANGE_COLOR, DIM_EMISSION, _orange_lines)
	_build_line_set(RED_LINE_HEIGHT, RED_COLOR, DIM_EMISSION, _red_lines)

func _build_line_set(height: float, color: Color, emission_energy: float, line_array: Array[MeshInstance3D]) -> void:
	var hw := WIDTH / 2.0 + 0.1
	var hd := DEPTH / 2.0 + 0.1
	var y := height
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
		mat.albedo_color = Color(color.r, color.g, color.b, DIM_ALPHA)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

		line_array.append(mesh_inst)

func get_drop_bounds() -> Rect2:
	var hw := WIDTH / 2.0 - 0.2
	var hd := DEPTH / 2.0 - 0.2
	return Rect2(-hw, -hd, WIDTH - 0.4, DEPTH - 0.4)
