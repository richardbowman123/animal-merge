extends Node3D
class_name Crowd

# Stadium-style banks of animal spectators around the container
# Each section contains small spheres coloured to match an animal tier
# When a merge creates an animal, that section reacts with the animal's call

const ANIMAL_CALLS := [
	"Squeak!",   # Mouse
	"Ribbit!",   # Frog
	"Thump!",    # Rabbit
	"Meow!",     # Cat
	"Yip!",      # Fox
	"Honk!",     # Penguin
	"Neigh!",    # Zebra
	"ROAR!",     # Lion
	"GROWL!",    # Bear
	"TRUMPET!",  # Elephant
	"WHOOO!",    # Whale
]

const CROWD_MEMBER_RADIUS := 0.18
const ROWS := 4
const ROW_HEIGHT := 0.8
const ROW_DEPTH := 0.5
const CONTAINER_WIDTH := 5.0
const CONTAINER_DEPTH := 5.0
const CONTAINER_HEIGHT := 9.0
const STANDOFF := 0.8  # Gap between container wall and first row

var _sections: Array[Array] = []  # Array of arrays of MeshInstance3D
var _section_labels: Array[Label3D] = []  # Reaction labels per section
var _section_centers: Array[Vector3] = []  # Center position of each section

func _ready() -> void:
	_build_crowd()

func _build_crowd() -> void:
	# Initialize section arrays for all 11 tiers
	for i in range(AnimalData.TIERS.size()):
		_sections.append([])
		_section_labels.append(null)
		_section_centers.append(Vector3.ZERO)

	# Place crowd around three sides (back, left, right)
	# Front is where the camera looks from, so skip it
	var hw := CONTAINER_WIDTH / 2.0
	var hd := CONTAINER_DEPTH / 2.0

	# Distribute 11 animal sections across 3 walls
	# Back wall: 4 sections, Left wall: 4 sections, Right wall: 3 sections
	var back_tiers := [0, 1, 2, 3]
	var left_tiers := [4, 5, 6, 7]
	var right_tiers := [8, 9, 10]

	# Back wall (z = -hd - STANDOFF, facing +z)
	_build_wall_sections(back_tiers, Vector3(-hw, 0, -hd - STANDOFF), Vector3(1, 0, 0), Vector3(0, 0, -1), CONTAINER_WIDTH)

	# Left wall (x = -hw - STANDOFF, facing +x)
	_build_wall_sections(left_tiers, Vector3(-hw - STANDOFF, 0, -hd), Vector3(0, 0, 1), Vector3(-1, 0, 0), CONTAINER_DEPTH)

	# Right wall (x = hw + STANDOFF, facing -x)
	_build_wall_sections(right_tiers, Vector3(hw + STANDOFF, 0, -hd), Vector3(0, 0, 1), Vector3(1, 0, 0), CONTAINER_DEPTH)

func _build_wall_sections(tiers: Array, start_pos: Vector3, along_dir: Vector3, outward_dir: Vector3, wall_length: float) -> void:
	var section_width := wall_length / float(tiers.size())
	var spacing := CROWD_MEMBER_RADIUS * 2.2
	var members_per_row := int(section_width / spacing)
	if members_per_row < 2:
		members_per_row = 2

	for s in range(tiers.size()):
		var t: int = tiers[s]
		var color: Color = AnimalData.get_color(t)
		var section_start := start_pos + along_dir * (float(s) * section_width)
		var section_center := section_start + along_dir * (section_width / 2.0)
		var center_sum := Vector3.ZERO
		var count := 0

		for row in range(ROWS):
			var row_offset := outward_dir * (float(row) * ROW_DEPTH)
			var y := float(row) * ROW_HEIGHT + 0.5
			# Stagger odd rows
			var stagger := spacing * 0.5 if row % 2 == 1 else 0.0

			for m in range(members_per_row):
				var along_offset := along_dir * (float(m) * spacing + spacing * 0.5 + stagger)
				var pos := section_start + along_offset + row_offset + Vector3(0, y, 0)

				var mesh_inst := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = CROWD_MEMBER_RADIUS
				sphere.height = CROWD_MEMBER_RADIUS * 2.0
				sphere.radial_segments = 8
				sphere.rings = 4
				mesh_inst.mesh = sphere

				# Slight colour variation for natural look
				var varied_color := color
				varied_color.r += randf_range(-0.05, 0.05)
				varied_color.g += randf_range(-0.05, 0.05)
				varied_color.b += randf_range(-0.05, 0.05)

				var mat := StandardMaterial3D.new()
				mat.albedo_color = varied_color
				mat.roughness = 0.8
				mesh_inst.material_override = mat
				mesh_inst.position = pos
				add_child(mesh_inst)
				_sections[t].append(mesh_inst)
				center_sum += pos
				count += 1

		# Store the center of this section for reaction labels
		if count > 0:
			_section_centers[t] = center_sum / float(count)
		else:
			_section_centers[t] = section_center + Vector3(0, 1.5, 0)

func react_to_merge(animal_tier: int) -> void:
	if animal_tier < 0 or animal_tier >= ANIMAL_CALLS.size():
		return

	var call_text: String = ANIMAL_CALLS[animal_tier]
	var center: Vector3 = _section_centers[animal_tier]

	# Bounce the crowd members in this section
	_bounce_section(animal_tier)

	# Show the animal call as a floating label above the section
	_show_call_label(call_text, center + Vector3(0, 2.0, 0), AnimalData.get_color(animal_tier))

func _bounce_section(animal_tier: int) -> void:
	var members: Array = _sections[animal_tier]
	for member in members:
		if is_instance_valid(member):
			var mesh_inst: MeshInstance3D = member
			var orig_pos := mesh_inst.position
			var bounce_height := randf_range(0.2, 0.5)
			var tween := create_tween()
			tween.tween_property(mesh_inst, "position:y", orig_pos.y + bounce_height, 0.15).set_ease(Tween.EASE_OUT)
			tween.tween_property(mesh_inst, "position:y", orig_pos.y, 0.25).set_ease(Tween.EASE_IN)

func _show_call_label(text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.outline_size = 14
	add_child(label)
	label.global_position = pos

	var tween := create_tween()
	tween.tween_property(label, "global_position:y", pos.y + 1.5, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.tween_callback(label.queue_free)
