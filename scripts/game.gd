extends Node3D

enum State { READY, AIMING, DROPPING, GAME_OVER }

var _state: State = State.READY
var _score: int = 0
var _death_timer: float = 0.0
const DEATH_TIME := 3.0
const DROP_COOLDOWN := 0.75

# Node references
@onready var _camera_rig = $CameraRig
@onready var _drop_system = $DropSystem
@onready var _merge_system = $MergeSystem
@onready var _container = $Container
@onready var _animals: Node3D = $Animals
@onready var _crowd: Crowd = $Crowd

# UI elements
var _score_label: Label
var _animal_label: Label
var _message_label: Label
var _game_over_panel: PanelContainer
var _final_score_label: Label
var _restart_button: Button
var _ui_layer: CanvasLayer

func _ready() -> void:
	_setup_environment()
	_setup_ui()
	_drop_system.setup(_container)
	_merge_system.setup(_animals)
	_drop_system.animal_dropped.connect(_on_animal_dropped)
	_merge_system.score_earned.connect(_on_score_earned)
	_merge_system.merge_completed.connect(_on_merge_completed)
	_start_game()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.3

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var dir_light := DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 1.2
	dir_light.shadow_enabled = true
	add_child(dir_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20, -60, 0)
	fill_light.light_energy = 0.4
	fill_light.shadow_enabled = false
	add_child(fill_light)

func _setup_ui() -> void:
	_ui_layer = $UILayer

	# Score label - top left
	_score_label = Label.new()
	_score_label.text = "Score: 0"
	_score_label.add_theme_font_size_override("font_size", 32)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.anchor_left = 0.0
	_score_label.anchor_top = 0.0
	_score_label.offset_left = 20
	_score_label.offset_top = 15
	_ui_layer.add_child(_score_label)

	# Current/Next animal info - top right
	_animal_label = Label.new()
	_animal_label.text = ""
	_animal_label.add_theme_font_size_override("font_size", 22)
	_animal_label.add_theme_color_override("font_color", Color.WHITE)
	_animal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_animal_label.anchor_left = 1.0
	_animal_label.anchor_right = 1.0
	_animal_label.anchor_top = 0.0
	_animal_label.offset_left = -220
	_animal_label.offset_top = 15
	_animal_label.offset_right = -20
	_animal_label.offset_bottom = 80
	_ui_layer.add_child(_animal_label)

	# Center message label
	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_font_size_override("font_size", 48)
	_message_label.add_theme_color_override("font_color", Color.WHITE)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.3
	_message_label.offset_left = -300
	_message_label.offset_top = -100
	_message_label.offset_right = 300
	_message_label.offset_bottom = -20
	_message_label.visible = false
	_ui_layer.add_child(_message_label)

	# Game over panel
	_game_over_panel = PanelContainer.new()
	_game_over_panel.anchor_left = 0.5
	_game_over_panel.anchor_right = 0.5
	_game_over_panel.anchor_top = 0.5
	_game_over_panel.anchor_bottom = 0.5
	_game_over_panel.offset_left = -150
	_game_over_panel.offset_top = -80
	_game_over_panel.offset_right = 150
	_game_over_panel.offset_bottom = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_game_over_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(game_over_label)

	_final_score_label = Label.new()
	_final_score_label.add_theme_font_size_override("font_size", 24)
	_final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_score_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_final_score_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	_restart_button = Button.new()
	_restart_button.text = "Play Again"
	_restart_button.add_theme_font_size_override("font_size", 22)
	_restart_button.custom_minimum_size = Vector2(200, 45)
	_restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(_restart_button)

	_game_over_panel.add_child(vbox)
	_game_over_panel.visible = false
	_ui_layer.add_child(_game_over_panel)

func _start_game() -> void:
	_score = 0
	_death_timer = 0.0
	_state = State.AIMING
	_game_over_panel.visible = false
	_message_label.visible = false
	_update_score_ui()
	_update_animal_ui()
	_drop_system.enable()
	_container.set_warning_level(0)

	# Clear any existing animals
	for child in _animals.get_children():
		child.queue_free()

func _process(delta: float) -> void:
	match _state:
		State.AIMING:
			_update_animal_ui()
		State.DROPPING:
			pass
		State.GAME_OVER:
			pass

	if _state != State.GAME_OVER:
		_check_death_line(delta)

func _check_death_line(delta: float) -> void:
	var yellow_y: float = _container.yellow_line_y
	var orange_y: float = _container.orange_line_y
	var death_y: float = _container.death_line_y
	var highest_warning := 0
	var any_above_red := false

	for child in _animals.get_children():
		if child is Animal:
			var animal := child as Animal
			if animal.is_merging:
				continue
			# Skip animals still falling from being dropped
			if animal.linear_velocity.y < -2.0:
				continue
			var top_y := animal.global_position.y + AnimalData.get_radius(animal.tier)
			if top_y > death_y:
				highest_warning = 3
				any_above_red = true
			elif top_y > orange_y and highest_warning < 2:
				highest_warning = 2
			elif top_y > yellow_y and highest_warning < 1:
				highest_warning = 1

	_container.set_warning_level(highest_warning)

	if any_above_red:
		_death_timer += delta
		if _death_timer >= DEATH_TIME:
			_trigger_game_over()
	else:
		_death_timer = 0.0

func _trigger_game_over() -> void:
	_state = State.GAME_OVER
	_drop_system.disable()
	_container.set_warning_level(3)
	for child in _animals.get_children():
		if child is Animal:
			(child as Animal).freeze = true
	_final_score_label.text = "Score: %d" % _score
	_game_over_panel.visible = true

func _on_animal_dropped(tier: int, pos: Vector3) -> void:
	_state = State.DROPPING
	var animal := Animal.create(tier)
	_animals.add_child(animal)
	animal.global_position = pos
	_merge_system.register_animal(animal)
	# Re-enable dropping after a short cooldown
	var timer := get_tree().create_timer(DROP_COOLDOWN)
	timer.timeout.connect(_on_drop_cooldown_finished)

func _on_drop_cooldown_finished() -> void:
	if _state == State.DROPPING:
		_state = State.AIMING
		_drop_system.enable()

func _on_score_earned(points: int, pos: Vector3, _animal_name: String, animal_tier: int) -> void:
	_score += points
	_update_score_ui()
	_spawn_score_popup(points, pos)
	_crowd.react_to_merge(animal_tier)

func _on_merge_completed() -> void:
	pass

func _update_score_ui() -> void:
	_score_label.text = "Score: %d" % _score

func _update_animal_ui() -> void:
	var current_name := AnimalData.get_animal_name(_drop_system.current_tier)
	var next_name := AnimalData.get_animal_name(_drop_system.next_tier)
	_animal_label.text = "Drop: %s\nNext: %s" % [current_name, next_name]

func _spawn_score_popup(points: int, world_pos: Vector3) -> void:
	var label_3d := Label3D.new()
	label_3d.text = "+%d" % points
	label_3d.font_size = 64
	label_3d.pixel_size = 0.008
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.modulate = Color.YELLOW
	label_3d.outline_modulate = Color.BLACK
	label_3d.outline_size = 16
	# Add to tree BEFORE setting global_position
	add_child(label_3d)
	label_3d.global_position = world_pos + Vector3(0, 0.5, 0)

	var tween := create_tween()
	tween.tween_property(label_3d, "global_position", world_pos + Vector3(0, 2.5, 0), 1.0)
	tween.parallel().tween_property(label_3d, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label_3d.queue_free)

func _on_restart_pressed() -> void:
	_start_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
