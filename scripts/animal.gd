extends RigidBody3D
class_name Animal

signal merge_requested(animal_a: Animal, animal_b: Animal)

var tier: int = 0
var is_merging: bool = false
var above_death_line_time: float = 0.0
const MAX_SPEED := 12.0
const CONTAINER_TOP := 9.5  # Just above container height to catch escapees

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	_build_visual()
	_apply_physics()

func _physics_process(delta: float) -> void:
	# Cap speed so small animals don't ping around wildly
	var speed := linear_velocity.length()
	if speed > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	# Keep animals inside container — clamp if launched above top
	if global_position.y > CONTAINER_TOP:
		global_position.y = CONTAINER_TOP
		if linear_velocity.y > 0:
			linear_velocity.y = 0
	# Dampen horizontal sliding/wandering without slowing falling
	var h_damp := AnimalData.get_linear_damp(tier)
	var factor := clampf(1.0 - h_damp * delta, 0.0, 1.0)
	linear_velocity.x *= factor
	linear_velocity.z *= factor

func setup(p_tier: int) -> void:
	tier = p_tier
	if is_inside_tree():
		_build_visual()
		_apply_physics()

func _apply_physics() -> void:
	mass = AnimalData.get_mass(tier)
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = AnimalData.get_bounce(tier)
	phys_mat.friction = AnimalData.get_friction(tier)
	physics_material_override = phys_mat
	angular_damp = AnimalData.get_angular_damp(tier)

func _build_visual() -> void:
	# Remove old visuals
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D or child is Label3D:
			child.queue_free()

	var radius: float = AnimalData.get_radius(tier)
	var color: Color = AnimalData.get_color(tier)

	# Collision shape
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col_shape.shape = sphere
	add_child(col_shape)

	# Main body sphere
	var body_mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	sphere_mesh.radial_segments = 24
	sphere_mesh.rings = 12
	body_mesh.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.metallic = 0.1
	body_mesh.material_override = mat
	add_child(body_mesh)

	# Eyes
	_add_eye(radius, Vector3(-0.25, 0.3, 0.85))
	_add_eye(radius, Vector3(0.25, 0.3, 0.85))

	# Distinctive features per animal
	_add_features(radius, tier)

func _add_eye(body_radius: float, normalized_pos: Vector3) -> void:
	var eye_radius := body_radius * 0.22
	var pupil_radius := eye_radius * 0.55
	var eye_pos := normalized_pos * body_radius

	# White of eye
	var eye_mesh := MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = eye_radius
	eye_sphere.height = eye_radius * 2.0
	eye_sphere.radial_segments = 12
	eye_sphere.rings = 6
	eye_mesh.mesh = eye_sphere
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.WHITE
	eye_mat.roughness = 0.3
	eye_mesh.material_override = eye_mat
	eye_mesh.position = eye_pos
	add_child(eye_mesh)

	# Pupil
	var pupil_mesh := MeshInstance3D.new()
	var pupil_sphere := SphereMesh.new()
	pupil_sphere.radius = pupil_radius
	pupil_sphere.height = pupil_radius * 2.0
	pupil_sphere.radial_segments = 8
	pupil_sphere.rings = 4
	pupil_mesh.mesh = pupil_sphere
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color.BLACK
	pupil_mat.roughness = 0.2
	pupil_mesh.material_override = pupil_mat
	pupil_mesh.position = eye_pos + normalized_pos.normalized() * eye_radius * 0.5
	add_child(pupil_mesh)

func _add_features(radius: float, p_tier: int) -> void:
	match p_tier:
		0:  # Mouse — two round pink ear spheres on top + thin tail
			_add_sphere_feature(radius, Vector3(-0.4, 0.9, 0.0), radius * 0.35, Color("FF8FA0"))
			_add_sphere_feature(radius, Vector3(0.4, 0.9, 0.0), radius * 0.35, Color("FF8FA0"))
			_add_cylinder_feature(radius, Vector3(0.0, 0.0, -1.2), radius * 0.05, radius * 0.8, Color("FF8FA0"))
		1:  # Frog — big bulging eyes on top (bright green body already distinctive)
			_add_sphere_feature(radius, Vector3(-0.35, 0.85, 0.3), radius * 0.25, Color("1B8A2E"))
			_add_sphere_feature(radius, Vector3(0.35, 0.85, 0.3), radius * 0.25, Color("1B8A2E"))
		2:  # Rabbit — two tall upright ear cylinders + cotton tail
			_add_cylinder_feature(radius, Vector3(-0.2, 1.2, 0.0), radius * 0.12, radius * 0.9, Color("C8A882"))
			_add_cylinder_feature(radius, Vector3(0.2, 1.2, 0.0), radius * 0.12, radius * 0.9, Color("C8A882"))
			_add_sphere_feature(radius, Vector3(0.0, 0.0, -1.05), radius * 0.2, Color("F5F5F5"))
		3:  # Cat — grey body with pointed ear cones + whisker dots
			_add_cone_feature(radius, Vector3(-0.4, 0.9, 0.0), radius * 0.2, radius * 0.4, Color("5A5A5A"))
			_add_cone_feature(radius, Vector3(0.4, 0.9, 0.0), radius * 0.2, radius * 0.4, Color("5A5A5A"))
			# Nose
			_add_sphere_feature(radius, Vector3(0.0, 0.1, 0.95), radius * 0.08, Color("FF9999"))
		4:  # Fox — orange with big pointed ear cones + white-tipped bushy tail
			_add_cone_feature(radius, Vector3(-0.4, 0.95, 0.0), radius * 0.22, radius * 0.5, Color("D4652F"))
			_add_cone_feature(radius, Vector3(0.4, 0.95, 0.0), radius * 0.22, radius * 0.5, Color("D4652F"))
			_add_sphere_feature(radius, Vector3(0.0, 0.1, -1.15), radius * 0.3, Color("D4652F"))
			_add_sphere_feature(radius, Vector3(0.0, 0.1, -1.35), radius * 0.18, Color("F5F5F5"))
		5:  # Penguin — near-black with big white belly + orange feet
			_add_sphere_feature(radius, Vector3(0.0, -0.15, 0.75), radius * 0.6, Color("F5F5F5"))
			_add_sphere_feature(radius, Vector3(-0.3, -0.85, 0.3), radius * 0.15, Color("FF8C00"))
			_add_sphere_feature(radius, Vector3(0.3, -0.85, 0.3), radius * 0.15, Color("FF8C00"))
		6:  # Zebra — white with bold black stripes + small ears
			_add_stripe_ring(radius, 0.35, Color.BLACK)
			_add_stripe_ring(radius, 0.0, Color.BLACK)
			_add_stripe_ring(radius, -0.35, Color.BLACK)
			_add_cone_feature(radius, Vector3(-0.35, 0.9, 0.0), radius * 0.1, radius * 0.25, Color.BLACK)
			_add_cone_feature(radius, Vector3(0.35, 0.9, 0.0), radius * 0.1, radius * 0.25, Color.BLACK)
		7:  # Panda — white body with black eye patches, ears, and limbs
			var panda_black := Color("1A1A1A")
			# Black eye patches — big dark ovals behind the eyes so white eyes pop
			_add_sphere_feature(radius, Vector3(-0.25, 0.28, 0.72), radius * 0.32, panda_black)
			_add_sphere_feature(radius, Vector3(0.25, 0.28, 0.72), radius * 0.32, panda_black)
			# Round black ears on top
			_add_sphere_feature(radius, Vector3(-0.55, 0.85, 0.0), radius * 0.22, panda_black)
			_add_sphere_feature(radius, Vector3(0.55, 0.85, 0.0), radius * 0.22, panda_black)
			# Black arm/shoulder patches on the sides
			_add_sphere_feature(radius, Vector3(-0.85, -0.1, 0.2), radius * 0.3, panda_black)
			_add_sphere_feature(radius, Vector3(0.85, -0.1, 0.2), radius * 0.3, panda_black)
			# Black leg patches at the bottom
			_add_sphere_feature(radius, Vector3(-0.35, -0.85, 0.2), radius * 0.25, panda_black)
			_add_sphere_feature(radius, Vector3(0.35, -0.85, 0.2), radius * 0.25, panda_black)
			# Small dark nose
			_add_sphere_feature(radius, Vector3(0.0, 0.08, 0.95), radius * 0.08, panda_black)
		8:  # Bear — chocolate brown with round ears + snout
			_add_sphere_feature(radius, Vector3(-0.5, 0.85, 0.1), radius * 0.28, Color("4A2E14"))
			_add_sphere_feature(radius, Vector3(0.5, 0.85, 0.1), radius * 0.28, Color("4A2E14"))
			_add_sphere_feature(radius, Vector3(0.0, -0.05, 0.9), radius * 0.2, Color("8B6B4A"))
		9:  # Elephant — slate grey with big flat ear discs + trunk
			_add_disc_feature(radius, Vector3(-1.05, 0.15, 0.0), radius * 0.55, Color("6E7E88"))
			_add_disc_feature(radius, Vector3(1.05, 0.15, 0.0), radius * 0.55, Color("6E7E88"))
			_add_cylinder_feature(radius, Vector3(0.0, -0.3, 1.0), radius * 0.1, radius * 0.6, Color("8E99A4"))
		10: # Whale — deep blue with tail fin + white underside
			_add_box_feature(radius, Vector3(0.0, 0.3, -1.1), Vector3(radius * 0.9, radius * 0.45, radius * 0.12), Color("0A3670"))
			_add_sphere_feature(radius, Vector3(0.0, -0.3, 0.3), radius * 0.6, Color("4A7FBA"))

func _add_sphere_feature(body_radius: float, normalized_pos: Vector3, feat_radius: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = feat_radius
	sphere.height = feat_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	mesh_inst.position = normalized_pos * body_radius
	add_child(mesh_inst)

func _add_cylinder_feature(body_radius: float, normalized_pos: Vector3, cyl_radius: float, cyl_height: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = cyl_radius
	cyl.bottom_radius = cyl_radius
	cyl.height = cyl_height
	cyl.radial_segments = 8
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	mesh_inst.position = normalized_pos * body_radius
	add_child(mesh_inst)

func _add_cone_feature(body_radius: float, normalized_pos: Vector3, cone_radius: float, cone_height: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = cone_radius
	cyl.height = cone_height
	cyl.radial_segments = 8
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	mesh_inst.position = normalized_pos * body_radius
	add_child(mesh_inst)

func _add_stripe_ring(body_radius: float, y_offset: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = body_radius * 1.01
	torus.bottom_radius = body_radius * 1.01
	torus.height = body_radius * 0.1
	torus.radial_segments = 16
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, y_offset * body_radius, 0.0)
	add_child(mesh_inst)

func _add_disc_feature(body_radius: float, normalized_pos: Vector3, disc_radius: float, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = disc_radius
	cyl.bottom_radius = disc_radius
	cyl.height = body_radius * 0.05
	cyl.radial_segments = 12
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	# Rotate disc to face sideways (rotate 90 degrees on Z axis)
	mesh_inst.position = normalized_pos * body_radius
	mesh_inst.rotation_degrees = Vector3(0, 0, 90)
	add_child(mesh_inst)

func _add_box_feature(body_radius: float, normalized_pos: Vector3, box_size: Vector3, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh_inst.material_override = mat
	mesh_inst.position = normalized_pos * body_radius
	add_child(mesh_inst)

func _on_body_entered(body: Node) -> void:
	if is_merging:
		return
	if body is Animal:
		var other: Animal = body as Animal
		if other.is_merging:
			return
		if other.tier == tier:
			# Only the one with lower instance id fires the signal
			if get_instance_id() < other.get_instance_id():
				merge_requested.emit(self, other)

static func create(p_tier: int) -> Animal:
	var animal := Animal.new()
	animal.tier = p_tier
	return animal
