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

# Touch aiming state
var _touch_aiming := false  # Whether a finger is currently dragging in the drop zone
var _touch_index := -1      # Which finger is aiming

const DROP_ZONE_FRACTION := 0.35  # Top 35% of screen is the drop zone

func _ready() -> void:
	current_tier = AnimalData.get_random_droppable_tier()
	next_tier = AnimalData.get_random_droppable_tier()
	_create_ghost()
	_create_drop_line()

func setup(container: GameContainer) -> void:
	_container_bounds = container.get_drop_bounds()
	_drop_height = GameContainer.HEIGHT

func enable() -> void:
	can_drop = true
	if _ghost:
		_ghost.visible = true
	if _drop_line:
		_drop_line.visible = true

func disable() -> void:
	can_drop = false
	_touch_aiming = false
	_touch_index = -1
	if _ghost:
		_ghost.visible = false
	if _drop_line:
		_drop_line.visible = false

func _process(_delta: float) -> void:
	if not can_drop:
		return
	_update_ghost()
	_update_drop_line()

func is_in_drop_zone(screen_pos: Vector2) -> bool:
	var viewport_height := float(get_viewport().get_visible_rect().size.y)
	return screen_pos.y < viewport_height * DROP_ZONE_FRACTION

func _unhandled_input(event: InputEvent) -> void:
	if not can_drop:
		return

	# --- Desktop mouse controls (unchanged) ---
	if event is InputEventMouseMotion:
		_update_cursor_from_screen(event.position)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not mb.is_echo():
			_do_drop()

	if event.is_action_pressed("drop"):
		_do_drop()

	# --- Touch controls: drag to aim, release to drop ---
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			# Finger went down — claim it if it's in the drop zone
			if is_in_drop_zone(st.position) and not _touch_aiming:
				_touch_aiming = true
				_touch_index = st.index
				_update_cursor_from_screen(st.position)
		else:
			# Finger lifted — drop the animal if this was our aiming finger
			if st.index == _touch_index and _touch_aiming:
				_touch_aiming = false
				_touch_index = -1
				_do_drop()

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		# Update cursor if this is our aiming finger
		if sd.index == _touch_index and _touch_aiming:
			_update_cursor_from_screen(sd.position)

func _update_cursor_from_screen(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	# Intersect with the horizontal plane at drop height
	if abs(dir.y) < 0.001:
		return
	var t := (_drop_height - from.y) / dir.y
	if t < 0:
		return
	var hit := from + dir * t
	# Clamp to container bounds
	hit.x = clampf(hit.x, _container_bounds.position.x, _container_bounds.position.x + _container_bounds.size.x)
	hit.z = clampf(hit.z, _container_bounds.position.y, _container_bounds.position.y + _container_bounds.size.y)
	hit.y = _drop_height
	_cursor_pos = hit

func _do_drop() -> void:
	if not can_drop:
		return
	can_drop = false
	if _ghost:
		_ghost.visible = false
	if _drop_line:
		_drop_line.visible = false
	animal_dropped.emit(current_tier, _cursor_pos)
	current_tier = next_tier
	next_tier = AnimalData.get_random_droppable_tier()
	_update_ghost_appearance()

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

func _update_drop_line() -> void:
	if not _drop_line or not _drop_line.visible:
		return
	var top_y := _cursor_pos.y
	var bottom_y := 0.0
	var height := top_y - bottom_y
	var cyl: CylinderMesh = _drop_line.mesh as CylinderMesh
	cyl.height = height
	_drop_line.global_position = Vector3(_cursor_pos.x, bottom_y + height / 2.0, _cursor_pos.z)
