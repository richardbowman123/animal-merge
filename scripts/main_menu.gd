extends Node3D

# Cinematic main menu — 3D arena with smart demo drops targeting merges

@onready var _container: GameContainer = $Container
@onready var _crowd: Crowd = $Crowd
@onready var _merge_system: MergeSystem = $MergeSystem
@onready var _animals: Node3D = $Animals
@onready var _camera_pivot: Node3D = $CinematicCamera
@onready var _camera: Camera3D = $CinematicCamera/Camera3D
@onready var _ui_layer: CanvasLayer = $UILayer

# Camera animation
var _cam_time := 0.0
const CAM_ORBIT_SPEED := 0.15
const CAM_TARGET := Vector3(0.0, 3.5, 0.0)

# Lighting animation
var _light_time := 0.0
var _spot_lights: Array[Light3D] = []

# Title animation
var _title_label: RichTextLabel
var _title_time := 0.0

# Demo drop state
var _held_animal: Animal = null
var _demo_tween: Tween = null
var _demo_active := false
var _demo_timer := 0.0
const DEMO_RESTART_DELAY := 2.0

func _ready() -> void:
	_setup_environment()
	_setup_cinematic_camera()
	_setup_ui()
	_merge_system.setup(_animals)
	_merge_system.score_earned.connect(_on_demo_score)
	_seed_demo_animals()
	_demo_timer = -1.0
	_demo_active = false

func _process(delta: float) -> void:
	_cam_time += delta
	_light_time += delta
	_title_time += delta
	_update_cinematic_camera()
	_update_lights()
	_update_title()

	# Demo cycle management
	if not _demo_active:
		_demo_timer += delta
		if _demo_timer >= DEMO_RESTART_DELAY:
			_start_demo_cycle()

# ─── Environment ────────────────────────────────────────────────
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.15, 0.25)
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.3
	env.tonemap_mode = 2  # Filmic

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Key light — warm from above
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50, 20, 0)
	key_light.light_energy = 0.8
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.shadow_enabled = true
	add_child(key_light)

	# Coloured spot lights that animate
	var spot_colors := [
		Color(0.3, 0.5, 1.0),   # Cool blue
		Color(1.0, 0.3, 0.5),   # Warm pink
		Color(0.3, 1.0, 0.5),   # Green
		Color(1.0, 0.8, 0.2),   # Gold
	]
	var spot_positions := [
		Vector3(-4, 10, -4),
		Vector3(4, 10, -4),
		Vector3(-4, 10, 4),
		Vector3(4, 10, 4),
	]
	for i in range(4):
		var spot := OmniLight3D.new()
		spot.position = spot_positions[i]
		spot.light_color = spot_colors[i]
		spot.light_energy = 2.0
		spot.omni_range = 12.0
		spot.omni_attenuation = 1.5
		add_child(spot)
		_spot_lights.append(spot)

# ─── Cinematic Camera ──────────────────────────────────────────
func _setup_cinematic_camera() -> void:
	_camera.fov = 50.0
	_camera.near = 0.1
	_camera.far = 100.0

func _update_cinematic_camera() -> void:
	if not _camera:
		return

	var t := _cam_time * CAM_ORBIT_SPEED
	var orbit_phase := fmod(t, TAU)

	var base_distance := 16.0
	var distance_variation := 4.0
	var distance := base_distance + sin(t * 0.4) * distance_variation

	var base_pitch := 30.0
	var pitch_variation := 15.0
	var pitch := base_pitch + sin(t * 0.25) * pitch_variation

	var yaw_rad := orbit_phase
	var pitch_rad := deg_to_rad(pitch)

	var offset := Vector3.ZERO
	offset.x = distance * cos(pitch_rad) * sin(yaw_rad)
	offset.y = distance * sin(pitch_rad)
	offset.z = distance * cos(pitch_rad) * cos(yaw_rad)

	var target := CAM_TARGET + Vector3(sin(t * 0.3) * 0.5, sin(t * 0.2) * 0.3, cos(t * 0.25) * 0.5)

	_camera.global_position = target + offset
	_camera.look_at(target, Vector3.UP)

# ─── Animated Lights ───────────────────────────────────────────
func _update_lights() -> void:
	for i in range(_spot_lights.size()):
		var light: OmniLight3D = _spot_lights[i] as OmniLight3D
		var pulse := 1.5 + sin(_light_time * (0.8 + float(i) * 0.3) + float(i) * 1.5) * 1.0
		light.light_energy = pulse
		var base_x: float = [-4.0, 4.0, -4.0, 4.0][i]
		var base_z: float = [-4.0, -4.0, 4.0, 4.0][i]
		light.position.x = base_x + sin(_light_time * 0.5 + float(i)) * 1.5
		light.position.z = base_z + cos(_light_time * 0.4 + float(i)) * 1.5

# ─── Demo Seed ────────────────────────────────────────────────
func _seed_demo_animals() -> void:
	# Pre-populate with pairs of same-tier animals for merge targets
	var seed_tiers := [0, 0, 1, 1, 2, 2, 0, 1, 0]
	var hw := GameContainer.WIDTH / 2.0 - 0.8
	var hd := GameContainer.DEPTH / 2.0 - 0.8

	for i in range(seed_tiers.size()):
		var tier: int = seed_tiers[i]
		var animal := Animal.create(tier)
		_animals.add_child(animal)
		var x := randf_range(-hw, hw)
		var z := randf_range(-hd, hd)
		animal.global_position = Vector3(x, randf_range(1.0, 4.0), z)
		_merge_system.register_animal(animal)

# ─── Demo Cycle ───────────────────────────────────────────────
func _start_demo_cycle() -> void:
	_demo_active = true

	var drop_tier := _pick_demo_tier()

	# Find a same-tier target to aim near
	var target_pos = _find_merge_target(drop_tier)
	var has_target := target_pos != null

	# Drop position — near the target if we have one, random otherwise
	var drop_x: float
	var drop_z: float
	if has_target:
		drop_x = clampf(target_pos.x + randf_range(-0.5, 0.5), -1.8, 1.8)
		drop_z = clampf(target_pos.z + randf_range(-0.5, 0.5), -1.8, 1.8)
	else:
		drop_x = randf_range(-1.5, 1.5)
		drop_z = randf_range(-1.5, 1.5)

	var spawn_y := GameContainer.HEIGHT + 1.5
	var drop_y := GameContainer.HEIGHT

	# Create the animal above the container
	_held_animal = Animal.create(drop_tier)
	_held_animal.freeze = true
	_held_animal.collision_layer = 0
	_held_animal.collision_mask = 0
	_animals.add_child(_held_animal)
	_held_animal.global_position = Vector3(drop_x, spawn_y, drop_z)

	if _demo_tween and _demo_tween.is_valid():
		_demo_tween.kill()

	_demo_tween = create_tween()

	# Gently lower into drop position
	_demo_tween.tween_property(_held_animal, "global_position:y", drop_y, 0.4).set_ease(Tween.EASE_OUT)

	# Brief pause
	_demo_tween.tween_interval(0.3)

	# Release — enable physics and let it fall
	_demo_tween.tween_callback(func():
		if is_instance_valid(_held_animal):
			_held_animal.freeze = false
			_held_animal.collision_layer = 1
			_held_animal.collision_mask = 1 | 2
			_merge_system.register_animal(_held_animal)
			_held_animal = null
	)

	# Watch the merge play out, then restart
	_demo_tween.tween_interval(2.5)
	_demo_tween.tween_callback(func():
		_demo_active = false
		_demo_timer = 0.0
	)

func _pick_demo_tier() -> int:
	# Prefer tiers that have a merge partner available
	for tier in range(AnimalData.MAX_DROPPABLE_TIER + 1):
		if _find_merge_target(tier) != null:
			return tier
	return AnimalData.get_random_droppable_tier()

func _find_merge_target(tier: int) -> Variant:
	for child in _animals.get_children():
		if child is Animal:
			var animal := child as Animal
			if animal == _held_animal:
				continue
			if animal.tier == tier and not animal.is_merging and not animal.freeze:
				return animal.global_position
	return null

func _on_demo_score(_points: int, _pos: Vector3, _name: String, tier: int) -> void:
	_crowd.react_to_merge(tier)

# ─── UI ────────────────────────────────────────────────────────
func _setup_ui() -> void:
	_title_label = RichTextLabel.new()
	_title_label.bbcode_enabled = true
	_title_label.fit_content = true
	_title_label.scroll_active = false
	var title_font: Font = load("res://fonts/FredokaOne-Regular.ttf")
	_title_label.add_theme_font_override("normal_font", title_font)
	_title_label.add_theme_font_override("bold_font", title_font)
	_title_label.text = _build_coloured_title()
	_title_label.add_theme_font_size_override("normal_font_size", 56)
	_title_label.add_theme_font_size_override("bold_font_size", 56)
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 1.0
	_title_label.anchor_top = 0.0
	_title_label.offset_top = 60
	_title_label.offset_bottom = 140
	_ui_layer.add_child(_title_label)

	var tagline := Label.new()
	tagline.text = "Drop. Merge. Grow!"
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 0.8))
	tagline.anchor_left = 0.0
	tagline.anchor_right = 1.0
	tagline.anchor_top = 0.0
	tagline.offset_top = 135
	tagline.offset_bottom = 170
	_ui_layer.add_child(tagline)

	# Button container — two buttons side by side
	var btn_container := HBoxContainer.new()
	btn_container.anchor_left = 0.5
	btn_container.anchor_right = 0.5
	btn_container.anchor_top = 1.0
	btn_container.anchor_bottom = 1.0
	btn_container.offset_left = -240
	btn_container.offset_top = -180
	btn_container.offset_right = 240
	btn_container.offset_bottom = -115
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)
	_ui_layer.add_child(btn_container)

	# "New Player" button
	var new_player_btn := Button.new()
	new_player_btn.text = "New Player"
	new_player_btn.add_theme_font_size_override("font_size", 26)
	new_player_btn.custom_minimum_size = Vector2(200, 65)
	new_player_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.15, 0.6, 0.3, 0.85)))
	new_player_btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.2, 0.7, 0.4, 0.95)))
	new_player_btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.1, 0.5, 0.25, 1.0)))
	new_player_btn.pressed.connect(_on_new_player_pressed)
	btn_container.add_child(new_player_btn)

	# "Jump In" button
	var jump_in_btn := Button.new()
	jump_in_btn.text = "Jump In"
	jump_in_btn.add_theme_font_size_override("font_size", 26)
	jump_in_btn.custom_minimum_size = Vector2(200, 65)
	jump_in_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.2, 0.4, 1.0, 0.85)))
	jump_in_btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.3, 0.5, 1.0, 0.95)))
	jump_in_btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.15, 0.3, 0.8, 1.0)))
	jump_in_btn.pressed.connect(_on_play_pressed)
	btn_container.add_child(jump_in_btn)

func _build_coloured_title(brightness: float = 1.0) -> String:
	# Each letter gets a different animal colour — cycles through the tiers
	var title := "ANIMAL MERGE"
	var letter_colors: Array[Color] = [
		AnimalData.get_color(0),   # A - Mouse pink
		AnimalData.get_color(1),   # N - Frog green
		AnimalData.get_color(4),   # I - Fox orange
		AnimalData.get_color(8),   # M - Bear brown
		AnimalData.get_color(10),  # A - Whale blue
		AnimalData.get_color(9),   # L - Elephant slate
		Color.TRANSPARENT,         # (space)
		AnimalData.get_color(2),   # M - Rabbit tan
		AnimalData.get_color(1),   # E - Frog green
		AnimalData.get_color(0),   # R - Mouse pink
		AnimalData.get_color(4),   # G - Fox orange
		AnimalData.get_color(10),  # E - Whale blue
	]
	var bbcode := "[center]"
	for i in range(title.length()):
		var ch := title[i]
		if ch == " ":
			bbcode += " "
			continue
		var c: Color = letter_colors[i]
		# Apply brightness pulse
		c = Color(
			clampf(c.r * brightness, 0.0, 1.0),
			clampf(c.g * brightness, 0.0, 1.0),
			clampf(c.b * brightness, 0.0, 1.0)
		)
		var hex := c.to_html(false)
		bbcode += "[color=#%s][b]%s[/b][/color]" % [hex, ch]
	bbcode += "[/center]"
	return bbcode

func _update_title() -> void:
	if not _title_label:
		return
	var pulse := 0.85 + sin(_title_time * 1.5) * 0.3
	_title_label.text = _build_coloured_title(pulse)

func _make_btn_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _on_new_player_pressed() -> void:
	GameState.show_tutorial = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_play_pressed() -> void:
	GameState.show_tutorial = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var vh := float(get_viewport().get_visible_rect().size.y)
			if st.position.y > vh * 0.75:
				_on_play_pressed()
