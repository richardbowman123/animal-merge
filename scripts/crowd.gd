extends Node3D
class_name Crowd

# Stadium amphitheatre of frozen Animal instances on benches around the container
# 11 sections (one per tier), each with 3 rows of stepped seating
# Benches are flat strips that give a clear stadium look

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

const INNER_RADIUS := 9.0
const ROW_GAP := 3.0        # Radial distance between row centres (fixed for all)
const ROW_HEIGHT_STEP := 3.0 # Vertical step per row — steep so back rows see over front
const ROWS := 3
const SECTION_GAP_DEG := 3.0
const SECTIONS := 11
const SPACING_MULTIPLIER := 2.5

const BENCH_HEIGHT := 0.3
const MIN_BENCH_DEPTH := 1.5
const MAX_BENCH_DEPTH := 2.8
const BENCH_COLOR := Color(0.2, 0.18, 0.16)

var _sections: Array[Array] = []  # Array of arrays of Animal
var _section_centers: Array[Vector3] = []

func _ready() -> void:
	_build_crowd()

func _build_crowd() -> void:
	var total_gap_deg := SECTION_GAP_DEG * float(SECTIONS)
	var usable_deg := 360.0 - total_gap_deg
	var section_deg := usable_deg / float(SECTIONS)

	for i in range(SECTIONS):
		_sections.append([])
		_section_centers.append(Vector3.ZERO)

	var current_angle_deg := 0.0
	for s in range(SECTIONS):
		var start_deg := current_angle_deg
		var end_deg := start_deg + section_deg
		_build_section(s, start_deg, end_deg)
		current_angle_deg = end_deg + SECTION_GAP_DEG

func _build_section(tier: int, start_deg: float, end_deg: float) -> void:
	var animal_radius := AnimalData.get_radius(tier)
	var animal_diameter := animal_radius * 2.0
	var bench_depth := clampf(animal_radius * 3.0, MIN_BENCH_DEPTH, MAX_BENCH_DEPTH)
	var mid_rad := deg_to_rad((start_deg + end_deg) / 2.0)
	var section_angle_rad := deg_to_rad(end_deg - start_deg)
	var center_sum := Vector3.ZERO
	var count := 0

	for row in range(ROWS):
		var row_radius := INNER_RADIUS + float(row) * ROW_GAP
		var row_y := float(row) * ROW_HEIGHT_STEP + 0.5

		# Chord width of this section at this radius (straight bench edge)
		var chord_width := 2.0 * row_radius * sin(section_angle_rad / 2.0)

		# Build the bench strip
		_build_bench(mid_rad, row_radius, row_y, chord_width, bench_depth)

		# Skip animals if they don't fit the chord
		if chord_width < animal_diameter:
			continue

		var start_rad := deg_to_rad(start_deg)
		var end_rad := deg_to_rad(end_deg)

		var slot_size := animal_radius * SPACING_MULTIPLIER
		var num_animals := int(chord_width / slot_size)
		if num_animals < 1:
			num_animals = 1

		var angle_step := (end_rad - start_rad) / float(num_animals)
		var angle_offset := angle_step * 0.5

		for i in range(num_animals):
			var angle := start_rad + angle_offset + float(i) * angle_step
			var x := row_radius * sin(angle)
			var z := row_radius * cos(angle)
			# Sit on top of the bench
			var animal_y := row_y + animal_radius
			var pos := Vector3(x, animal_y, z)

			var animal := Animal.create(tier)
			animal.freeze = true
			animal.collision_layer = 0
			animal.collision_mask = 0
			add_child(animal)
			animal.global_position = pos

			# Face inward — look_at points -Z at target, eyes are on +Z, so rotate 180
			var look_target := Vector3(0.0, animal_y, 0.0)
			if pos.distance_to(look_target) > 0.1:
				animal.look_at(look_target, Vector3.UP)
				animal.rotate_y(PI)

			_sections[tier].append(animal)
			center_sum += pos
			count += 1

	if count > 0:
		_section_centers[tier] = center_sum / float(count)
	else:
		_section_centers[tier] = Vector3(INNER_RADIUS * sin(mid_rad), 1.5, INNER_RADIUS * cos(mid_rad))

	_add_team_label(tier, start_deg, end_deg)

func _build_bench(mid_angle_rad: float, radius: float, y: float, width: float, depth: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, BENCH_HEIGHT, depth)
	mesh_inst.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = BENCH_COLOR
	mat.roughness = 0.85
	mesh_inst.material_override = mat

	add_child(mesh_inst)

	# Position at the midpoint of the section arc, bench top at y
	var x := radius * sin(mid_angle_rad)
	var z := radius * cos(mid_angle_rad)
	mesh_inst.position = Vector3(x, y - BENCH_HEIGHT / 2.0, z)

	# Rotate so the wide edge (X) is tangent to the circle
	mesh_inst.rotation.y = mid_angle_rad

func _add_team_label(tier: int, start_deg: float, end_deg: float) -> void:
	var mid_rad := deg_to_rad((start_deg + end_deg) / 2.0)
	var label_radius := INNER_RADIUS - 1.0
	var label_pos := Vector3(label_radius * sin(mid_rad), 0.5, label_radius * cos(mid_rad))

	var label := Label3D.new()
	label.text = "TEAM %s" % AnimalData.get_animal_name(tier).to_upper()
	label.font_size = 36
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.modulate = AnimalData.get_color(tier)
	label.outline_modulate = Color.BLACK
	label.outline_size = 10
	add_child(label)
	label.global_position = label_pos

	var look_target := Vector3(0.0, label_pos.y, 0.0)
	label.look_at(look_target, Vector3.UP)
	label.rotate_y(PI)

func react_to_merge(animal_tier: int) -> void:
	if animal_tier < 0 or animal_tier >= ANIMAL_CALLS.size():
		return

	var call_text: String = ANIMAL_CALLS[animal_tier]
	var center: Vector3 = _section_centers[animal_tier]

	_bounce_section(animal_tier)
	_show_call_label(call_text, center + Vector3(0, 2.0, 0), AnimalData.get_color(animal_tier))

func _bounce_section(animal_tier: int) -> void:
	var members: Array = _sections[animal_tier]
	for member in members:
		if is_instance_valid(member):
			var animal: Animal = member
			var orig_pos := animal.global_position
			var bounce_height := randf_range(0.2, 0.5)
			var tween := create_tween()
			tween.tween_property(animal, "global_position:y", orig_pos.y + bounce_height, 0.15).set_ease(Tween.EASE_OUT)
			tween.tween_property(animal, "global_position:y", orig_pos.y, 0.25).set_ease(Tween.EASE_IN)

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
