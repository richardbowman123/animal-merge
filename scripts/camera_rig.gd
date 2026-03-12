extends Node3D
class_name CameraRig

const ORBIT_SPEED := 2.0
const MOUSE_ORBIT_SPEED := 0.005
const TOUCH_ORBIT_SPEED := 0.008
const MIN_PITCH := 0.0
const MAX_PITCH := 80.0
const ZOOM_SPEED := 0.5
const MIN_DISTANCE := 5.0
const MAX_DISTANCE := 20.0
const DROP_ZONE_FRACTION := 0.33  # Top third is drop zone, bottom two-thirds is orbit

var _yaw := 0.0
var _pitch := 35.0
var _distance := 16.0
var _target := Vector3(0.0, 3.5, 0.0)
var _is_orbiting := false
var _last_mouse_pos := Vector2.ZERO
var _orbit_touch_index := -1
var _is_touch_device := false  # Set true on first touch event

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_is_touch_device = DisplayServer.is_touchscreen_available()
	if not has_node("Camera3D"):
		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.fov = 50.0
		cam.near = 0.1
		cam.far = 100.0
		add_child(cam)
		_camera = cam
	_update_camera()

func _process(delta: float) -> void:
	if Input.is_action_pressed("orbit_left"):
		_yaw += ORBIT_SPEED * delta * 60.0
	if Input.is_action_pressed("orbit_right"):
		_yaw -= ORBIT_SPEED * delta * 60.0
	_update_camera()

func _is_in_orbit_zone(screen_pos: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if _camera:
		var tank_top_screen := _camera.unproject_position(Vector3(0.0, GameContainer.HEIGHT, 0.0))
		var margin := viewport_size.y * 0.08
		return screen_pos.y >= tank_top_screen.y + margin
	return screen_pos.y >= viewport_size.y * DROP_ZONE_FRACTION

func _unhandled_input(event: InputEvent) -> void:
	# Detect touch device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_is_touch_device = true

	# === DESKTOP: right-click drag to orbit, scroll to zoom ===
	if not _is_touch_device:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_is_orbiting = mb.pressed
				_last_mouse_pos = mb.position
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(_distance - ZOOM_SPEED, MIN_DISTANCE)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(_distance + ZOOM_SPEED, MAX_DISTANCE)

		if event is InputEventMouseMotion and _is_orbiting:
			var mm := event as InputEventMouseMotion
			_yaw -= mm.relative.x * MOUSE_ORBIT_SPEED * 60.0
			_pitch -= mm.relative.y * MOUSE_ORBIT_SPEED * 60.0
			_pitch = clampf(_pitch, MIN_PITCH, MAX_PITCH)

	# === MOBILE: single finger drag in bottom two-thirds orbits ===
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _is_in_orbit_zone(st.position) and _orbit_touch_index == -1:
				_orbit_touch_index = st.index
		else:
			if st.index == _orbit_touch_index:
				_orbit_touch_index = -1

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _orbit_touch_index:
			_yaw -= sd.relative.x * TOUCH_ORBIT_SPEED * 60.0
			_pitch -= sd.relative.y * TOUCH_ORBIT_SPEED * 60.0
			_pitch = clampf(_pitch, MIN_PITCH, MAX_PITCH)

func _update_camera() -> void:
	if not _camera:
		return
	var yaw_rad := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)
	var offset := Vector3.ZERO
	offset.x = _distance * cos(pitch_rad) * sin(yaw_rad)
	offset.y = _distance * sin(pitch_rad)
	offset.z = _distance * cos(pitch_rad) * cos(yaw_rad)
	_camera.global_position = _target + offset
	_camera.look_at(_target, Vector3.UP)

func get_camera() -> Camera3D:
	return _camera

func get_yaw_degrees() -> float:
	return _yaw
