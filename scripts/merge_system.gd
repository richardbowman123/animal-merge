extends Node
class_name MergeSystem

signal score_earned(points: int, position: Vector3, animal_name: String, tier: int)
signal merge_completed()

var _animals_node: Node3D
var _merging_queue: Array[Array] = []
var _merge_cooldown: float = 0.0
const CHAIN_MERGE_DELAY := 0.35

func setup(animals_node: Node3D) -> void:
	_animals_node = animals_node

func _process(delta: float) -> void:
	if _merge_cooldown > 0.0:
		_merge_cooldown -= delta
	else:
		_process_merge_queue()

func register_animal(animal: Animal) -> void:
	animal.merge_requested.connect(_on_merge_requested)

func _on_merge_requested(animal_a: Animal, animal_b: Animal) -> void:
	if animal_a.is_merging or animal_b.is_merging:
		return
	animal_a.is_merging = true
	animal_b.is_merging = true
	_merging_queue.append([animal_a, animal_b])

func _process_merge_queue() -> void:
	while _merging_queue.size() > 0:
		var pair: Array = _merging_queue.pop_front()
		var animal_a: Animal = pair[0]
		var animal_b: Animal = pair[1]
		if not is_instance_valid(animal_a) or not is_instance_valid(animal_b):
			continue
		_execute_merge(animal_a, animal_b)
		_merge_cooldown = CHAIN_MERGE_DELAY
		return

func _execute_merge(animal_a: Animal, animal_b: Animal) -> void:
	var tier := animal_a.tier
	var midpoint := (animal_a.global_position + animal_b.global_position) / 2.0

	# Freeze both animals so tweens control their movement
	animal_a.freeze = true
	animal_b.freeze = true

	# Whale + Whale = both disappear, huge bonus
	if tier == AnimalData.MAX_TIER:
		var points := AnimalData.get_score(tier) * 5
		var shrink := create_tween()
		shrink.set_parallel(true)
		shrink.tween_property(animal_a, "global_position", midpoint, 0.15).set_ease(Tween.EASE_IN)
		shrink.tween_property(animal_b, "global_position", midpoint, 0.15).set_ease(Tween.EASE_IN)
		shrink.tween_property(animal_a, "scale", Vector3(0.01, 0.01, 0.01), 0.15).set_ease(Tween.EASE_IN)
		shrink.tween_property(animal_b, "scale", Vector3(0.01, 0.01, 0.01), 0.15).set_ease(Tween.EASE_IN)
		shrink.set_parallel(false)
		shrink.tween_callback(func():
			_spawn_particles(midpoint, AnimalData.get_color(tier), AnimalData.get_radius(tier))
			score_earned.emit(points, midpoint, AnimalData.get_animal_name(tier) + " x2!", tier)
			if is_instance_valid(animal_a):
				animal_a.queue_free()
			if is_instance_valid(animal_b):
				animal_b.queue_free()
			merge_completed.emit()
		)
		return

	var new_tier := tier + 1
	var points := AnimalData.get_score(new_tier)

	# Phase 1: Shrink old animals toward the merge point
	var shrink := create_tween()
	shrink.set_parallel(true)
	shrink.tween_property(animal_a, "global_position", midpoint, 0.15).set_ease(Tween.EASE_IN)
	shrink.tween_property(animal_b, "global_position", midpoint, 0.15).set_ease(Tween.EASE_IN)
	shrink.tween_property(animal_a, "scale", Vector3(0.01, 0.01, 0.01), 0.15).set_ease(Tween.EASE_IN)
	shrink.tween_property(animal_b, "scale", Vector3(0.01, 0.01, 0.01), 0.15).set_ease(Tween.EASE_IN)
	shrink.set_parallel(false)
	shrink.tween_callback(func():
		# Remove old animals
		if is_instance_valid(animal_a):
			animal_a.queue_free()
		if is_instance_valid(animal_b):
			animal_b.queue_free()

		# Spawn new animal frozen at tiny scale
		var new_animal := Animal.create(new_tier)
		new_animal.freeze = true
		_animals_node.add_child(new_animal)
		new_animal.global_position = midpoint
		new_animal.scale = Vector3(0.01, 0.01, 0.01)
		register_animal(new_animal)

		_spawn_particles(midpoint, AnimalData.get_color(new_tier), AnimalData.get_radius(new_tier))
		score_earned.emit(points, midpoint, AnimalData.get_animal_name(new_tier), new_tier)

		# Phase 2: Pop the new animal into existence with overshoot
		var grow := create_tween()
		grow.tween_property(new_animal, "scale", Vector3(1.15, 1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
		grow.tween_property(new_animal, "scale", Vector3.ONE, 0.08).set_ease(Tween.EASE_IN_OUT)
		grow.tween_callback(func():
			if is_instance_valid(new_animal):
				new_animal.freeze = false
				new_animal.apply_central_impulse(Vector3(0, 0.8, 0))
				_apply_blast(midpoint, AnimalData.get_radius(new_tier), AnimalData.get_mass(new_tier), new_animal)
		)
		merge_completed.emit()
	)

func _apply_blast(origin: Vector3, new_radius: float, new_mass: float, exclude: Animal) -> void:
	var blast_radius := new_radius * 2.5
	var blast_force := new_mass * 1.5
	for child in _animals_node.get_children():
		if child is Animal and child != exclude and is_instance_valid(child):
			var animal := child as Animal
			var diff := animal.global_position - origin
			var dist := diff.length()
			if dist < blast_radius and dist > 0.01:
				var falloff := 1.0 - (dist / blast_radius)
				var impulse := diff.normalized() * blast_force * falloff
				animal.apply_central_impulse(impulse)

func _spawn_particles(pos: Vector3, color: Color, _radius: float) -> void:
	var particles := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = color

	particles.process_material = mat
	particles.amount = 20
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.draw_pass_1 = mesh

	# Add to tree BEFORE setting global_position
	_animals_node.add_child(particles)
	particles.global_position = pos

	# Auto cleanup
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
