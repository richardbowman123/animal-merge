extends Node3D
class_name DropSystem

signal animal_dropped(tier: int, position: Vector3)

var current_tier: int = 0
var next_tier: int = 0
var can_drop: bool = false
var _ghost: MeshInstance3D = null
var _drop_line: MeshInstance3D = null
var _cursor_pos := Vector3.ZERO
var _drop_height := 10.0
var _container_bounds: Rect2

# Target indicator
var _target_indicator: Node3D = null
var _target_hit_y: float = 0.0

# Touch aiming state
var _touch_aiming := false
var _touch_index := -1
var _is_touch_device := false  # Set true on first touch event, ignores fake mouse after

const DROP_ZONE_FRACTION := 0.33  # Top third of screen
const TARGET_COLOR := Color(0.3, 0.5, 1.0)

func _ready() -> void:
	current_tier = AnimalData.get_random_droppable_tier()
	next_tier = AnimalData.get_random_droppable_tier()
	_create_ghost()
	_create_drop_line()
	_create_target_indicator()

func force_tier(tier: int) -> void:
	current_tier = tier
	next_tier = tier
	_update_ghost_appearance()
	_update_target_indicator_scale()

func setup(container: GameContainer) -> void:
	_container_bounds = container.get_drop_bounds()
	_drop_height = GameContainer.HEIGHT

func enable() -> void:
	can_drop = true
	if _ghost:
		_ghost.visible = true
	if _drop_line:
		_drop_line.visible = true
	if _target_indicator:
		_target_indicator.visible = true

func disable() -> void:
	can_drop = false
	_touch_aiming = false
	_touch_index = -1
	if _ghost:
		_ghost.visible = false
	if _drop_line:
		_drop_line.visible = false
	if _target_indicator:
		_target_indicator.visible = false

func _process(_delta: float) -> void:
	if not can_drop:
		return
	_update_ghost()
	_update_target_position()
	_update_drop_line()
	_update_target_indicator()

func _is_in_drop_zone(screen_pos: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_3d()
	if camera:
		var tank_top_screen := camera.unproject_position(Vector3(0.0, GameContainer.HEIGHT, 0.0))
		var margin := viewport_size.y * 0.08
		return screen_pos.y < tank_top_screen.y + margin
	return screen_pos.y < viewport_size.y * DROP_ZONE_FRACTION

func _input(event: InputEvent) -> void:
	if not can_drop:
		return

	# Detect touch device — once set, mouse events are ignored for game controls
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_is_touch_device = true

	# === DESKTOP: mouse controls (only when NOT on a touch device) ===
	if not _is_touch_device:
		if event is InputEventMouseMotion:
			_update_cursor_from_screen(event.position)

		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not mb.is_echo():
				_do_drop()

		if event.is_action_pressed("drop"):
			_do_drop()

	# === MOBILE: touch in drop zone to aim, release to drop ===
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _is_in_drop_zone(st.position) and not _touch_aiming:
				_touch_aiming = true
				_touch_index = st.index
				_update_cursor_from_screen(st.position)
				get_viewport().set_input_as_handled()
		else:
			if st.index == _touch_index and _touch_aiming:
				_touch_aiming = false
				_touch_index = -1
				_do_drop()
				get_viewport().set_input_as_handled()

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index and _touch_aiming:
			_update_cursor_from_screen(sd.position)
			get_viewport().set_input_as_handled()

func _update_cursor_from_screen(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return
	var t := (_drop_height - from.y) / dir.y
	if t < 0:
		return
	var hit := from + dir * t
	hit.x = clampf(hit.x, _container_bounds.position.x, _container_bounds.position.x + _container_bounds.size.x)
	hit.z = clampf(hit.z, _container_bounds.position.y, _container_bounds.position.y + _container_bounds.size.y)
	hit.y = _drop_height
	_cursor_pos = hit

func _do_drop() -> void:
	if not can_drop:
		return
	can_drop = false
	_touch_aiming = false
	_touch_index = -1
	if _ghost:
		_ghost.visible = false
	if _drop_line:
		_drop_line.visible = false
	if _target_indicator:
		_target_indicator.visible = false
	animal_dropped.emit(current_tier, _cursor_pos)
	current_tier = next_tier
	next_tier = AnimalData.get_random_droppable_tier()
	_update_ghost_appearance()
	_update_target_indicator_scale()

func _create_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	_ghost.mesh = sphere
	_ghost.visible = false
	add_child(_ghost)
	_update_ghost_appearance()

func _update_ghost_appearance() -> void:
	if not _ghost:
		return
	var radius := AnimalData.get_radius(current_tier)
	var color := AnimalData.get_color(current_tier)
	var sphere: SphereMesh = _ghost.mesh as SphereMesh
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost.material_override = mat

func _update_ghost() -> void:
	if _ghost and _ghost.visible:
		_ghost.global_position = _cursor_pos

func _create_drop_line() -> void:
	_drop_line = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.radial_segments = 6
	_drop_line.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_line.material_override = mat
	_drop_line.visible = false
	add_child(_drop_line)

func _update_target_position() -> void:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		_target_hit_y = 0.0
		return

	var ray_from := Vector3(_cursor_pos.x, _cursor_pos.y, _cursor_pos.z)
	var ray_to := Vector3(_cursor_pos.x, -1.0, _cursor_pos.z)

	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_from
	query.to = ray_to
	query.collision_mask = 1 | 2  # Animals (layer 1) + container floor (layer 2)

	var result := space_state.intersect_ray(query)
	if result.size() > 0:
		_target_hit_y = result.position.y
		# If we hit an animal, add a small offset so the reticle sits on top
		var collider = result.collider
		if collider is Animal:
			var animal_radius := AnimalData.get_radius(collider.tier)
			_target_hit_y += animal_radius * 0.1
	else:
		_target_hit_y = 0.0

func _update_drop_line() -> void:
	if not _drop_line or not _drop_line.visible:
		return
	var top_y := _cursor_pos.y
	var bottom_y := _target_hit_y
	var height := top_y - bottom_y
	if height < 0.01:
		height = 0.01
	var cyl: CylinderMesh = _drop_line.mesh as CylinderMesh
	cyl.height = height
	_drop_line.global_position = Vector3(_cursor_pos.x, bottom_y + height / 2.0, _cursor_pos.z)

func _create_target_indicator() -> void:
	_target_indicator = Node3D.new()
	_target_indicator.visible = false
	add_child(_target_indicator)

	# Three concentric discs — inner, middle, outer
	_add_target_disc(0.15, 0.5, 1.5)
	_add_target_disc(0.35, 0.35, 1.0)
	_add_target_disc(0.55, 0.2, 0.5)

	_update_target_indicator_scale()

func _add_target_disc(radius: float, alpha: float, emission_energy: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 16
	mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(TARGET_COLOR.r, TARGET_COLOR.g, TARGET_COLOR.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = TARGET_COLOR
	mat.emission_energy_multiplier = emission_energy
	mat.roughness = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	_target_indicator.add_child(mesh_inst)

func _update_target_indicator_scale() -> void:
	if not _target_indicator:
		return
	var radius := AnimalData.get_radius(current_tier)
	# Scale proportionally to the animal's radius (base design is for radius ~0.5)
	var scale_factor := radius / 0.5
	_target_indicator.scale = Vector3(scale_factor, 1.0, scale_factor)

func _update_target_indicator() -> void:
	if not _target_indicator or not _target_indicator.visible:
		return
	_target_indicator.global_position = Vector3(_cursor_pos.x, _target_hit_y + 0.02, _cursor_pos.z)
