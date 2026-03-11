extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_top = -200
	vbox.offset_right = 200
	vbox.offset_bottom = 200

	# Title
	var title := Label.new()
	title.text = "ANIMAL MERGE"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Drop animals into the box.\nMatch two to merge them bigger!"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.add_theme_font_size_override("font_size", 28)
	play_btn.custom_minimum_size = Vector2(220, 55)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)

	# Quit button
	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.custom_minimum_size = Vector2(220, 45)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer3)

	# Controls info
	var controls := Label.new()
	controls.text = "Controls:\nLeft Click - Drop animal\nRight Click Drag - Orbit camera\nQ/E - Rotate camera\nScroll - Zoom\nSpace - Drop\nEsc - Menu"
	controls.add_theme_font_size_override("font_size", 14)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(controls)

	add_child(vbox)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
