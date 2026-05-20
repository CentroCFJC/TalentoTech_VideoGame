extends Node2D

## PlatformSpawner — Procedural generation of platforms, gaps, and spikes.

# Chunk settings
const CHUNK_WIDTH: float = 800.0
const SPAWN_AHEAD: int = 3               # Chunks generated ahead of camera
const DESTROY_BEHIND: float = 1200.0      # Destroy chunks this far behind camera

# Platform settings
const GROUND_Y: float = 500.0            # Base ground level
const MIN_PLATFORM_WIDTH: float = 150.0
const MAX_PLATFORM_WIDTH: float = 400.0
const MAX_GAP_WIDTH: float = 200.0
const MIN_GAP_WIDTH: float = 80.0
const MAX_HEIGHT_DIFF: float = 120.0
const PLATFORM_HEIGHT: float = 20.0

# Difficulty
const DIFFICULTY_INTERVAL: float = 1000.0
const MAX_DIFFICULTY: int = 4

# Spike settings
const SPIKE_WIDTH: float = 60.0
const SPIKE_HEIGHT: float = 12.0

# Patterns enum
enum Pattern {
	FLAT_GROUND,
	GROUND_GAP_SMALL,
	GROUND_GAP_LARGE,
	STEP_UP,
	STEP_DOWN,
	FLOATING_CHAIN,
	SPIKE_CORRIDOR,
	SPIKE_GAP_COMBO,
	MULTI_SPIKE_FIELD
}

# State
var next_chunk_x: float = 0.0
var last_platform_y: float = GROUND_Y
var active_chunks: Array[Node2D] = []
var camera: Camera2D = null
var rng := RandomNumberGenerator.new()

# Collision shapes (created once, shared)
var ground_shape: RectangleShape2D
var spike_shape: RectangleShape2D

func _ready() -> void:
	rng.randomize()
	
	# Pre-create shared shapes
	spike_shape = RectangleShape2D.new()
	spike_shape.size = Vector2(SPIKE_WIDTH, SPIKE_HEIGHT)
	
	# Connect to game state
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		# Reset is handled by scene reload for restart
		pass

func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	
	if not camera:
		camera = get_viewport().get_camera_2d()
		if not camera:
			return
	
	var camera_x: float = camera.global_position.x
	var screen_width: float = get_viewport_rect().size.x / camera.zoom.x
	var visible_right: float = camera_x + screen_width
	
	# Generate chunks ahead
	while next_chunk_x < visible_right + CHUNK_WIDTH * SPAWN_AHEAD:
		_generate_chunk(next_chunk_x)
		next_chunk_x += CHUNK_WIDTH
	
	# Destroy chunks behind
	var destroy_threshold: float = camera_x - DESTROY_BEHIND
	var to_remove: Array[Node2D] = []
	for chunk in active_chunks:
		if chunk.global_position.x + CHUNK_WIDTH < destroy_threshold:
			to_remove.append(chunk)
	
	for chunk in to_remove:
		active_chunks.erase(chunk)
		chunk.queue_free()

func _get_difficulty() -> int:
	var distance: float = next_chunk_x
	return mini(int(distance / DIFFICULTY_INTERVAL), MAX_DIFFICULTY)

func _get_available_patterns(difficulty: int) -> Array[Pattern]:
	var patterns: Array[Pattern] = [Pattern.FLAT_GROUND, Pattern.GROUND_GAP_SMALL, Pattern.STEP_UP]
	
	if difficulty >= 2:
		patterns.append(Pattern.GROUND_GAP_LARGE)
		patterns.append(Pattern.STEP_DOWN)
		patterns.append(Pattern.SPIKE_CORRIDOR)
	if difficulty >= 3:
		patterns.append(Pattern.FLOATING_CHAIN)
		patterns.append(Pattern.SPIKE_GAP_COMBO)
	if difficulty >= 4:
		patterns.append(Pattern.MULTI_SPIKE_FIELD)
	
	return patterns

func _generate_chunk(chunk_x: float) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % int(chunk_x)
	chunk.global_position = Vector2(chunk_x, 0)
	add_child(chunk)
	active_chunks.append(chunk)
	
	var difficulty: int = _get_difficulty()
	var patterns := _get_available_patterns(difficulty)
	
	# First 2 chunks (1600px, roughly 5 seconds at 300px/s) are always flat ground
	var pattern: Pattern
	if chunk_x < CHUNK_WIDTH * 2:
		pattern = Pattern.FLAT_GROUND
	else:
		pattern = patterns[rng.randi_range(0, patterns.size() - 1)]
	
	match pattern:
		Pattern.FLAT_GROUND:
			_build_flat_ground(chunk)
		Pattern.GROUND_GAP_SMALL:
			_build_ground_gap(chunk, false)
		Pattern.GROUND_GAP_LARGE:
			_build_ground_gap(chunk, true)
		Pattern.STEP_UP:
			_build_steps(chunk, true)
		Pattern.STEP_DOWN:
			_build_steps(chunk, false)
		Pattern.FLOATING_CHAIN:
			_build_floating_chain(chunk)
		Pattern.SPIKE_CORRIDOR:
			_build_spike_corridor(chunk)
		Pattern.SPIKE_GAP_COMBO:
			_build_spike_gap_combo(chunk)
		Pattern.MULTI_SPIKE_FIELD:
			_build_multi_spike_field(chunk)

# ── Pattern Builders ──────────────────────────────────────────

func _build_flat_ground(chunk: Node2D) -> void:
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)
	
	# Add tutorial label if it's the first chunk
	if chunk.global_position.x == 0:
		var label := Label.new()
		label.text = "Usa El Boton para saltar.\nPresionalo de nuevo en el aire para doble salto."
		label.position = Vector2(CHUNK_WIDTH * 0.5 - 200, last_platform_y - 200)
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chunk.add_child(label)

func _build_ground_gap(chunk: Node2D, large: bool) -> void:
	var gap_size: float = MIN_GAP_WIDTH if not large else rng.randf_range(150.0, MAX_GAP_WIDTH)
	var gap_start: float = rng.randf_range(200.0, CHUNK_WIDTH - gap_size - 200.0)
	
	# Ground before gap
	_create_platform(chunk, 0, last_platform_y, gap_start)
	# Ground after gap
	_create_platform(chunk, gap_start + gap_size, last_platform_y, CHUNK_WIDTH - gap_start - gap_size)
	
	# For large gaps, add a floating platform in the middle
	if large:
		var mid_x: float = gap_start + gap_size * 0.5 - 50.0
		_create_platform(chunk, mid_x, last_platform_y - rng.randf_range(60.0, 100.0), 100.0)

func _build_steps(chunk: Node2D, going_up: bool) -> void:
	var num_steps: int = rng.randi_range(2, 4)
	var step_width: float = CHUNK_WIDTH / (num_steps + 1)
	var height_step: float = 50.0 if going_up else -40.0
	
	var current_y: float = last_platform_y
	
	for i in num_steps:
		var step_x: float = i * step_width
		_create_platform(chunk, step_x, current_y, step_width - 30.0)
		current_y -= height_step
	
	# Final section
	_create_platform(chunk, num_steps * step_width, current_y, CHUNK_WIDTH - num_steps * step_width)
	
	# Clamp to reasonable range
	last_platform_y = clampf(current_y, GROUND_Y - 200.0, GROUND_Y + 50.0)

func _build_floating_chain(chunk: Node2D) -> void:
	var num_platforms: int = rng.randi_range(3, 5)
	var section_width: float = CHUNK_WIDTH / num_platforms
	# Ensure minimum platform width so gaps are jumpable
	var min_plat_width: float = maxf(80.0, section_width - 120.0)
	
	for i in num_platforms:
		var plat_width: float = rng.randf_range(min_plat_width, 140.0)
		var x_pos: float = i * section_width + (section_width - plat_width) * 0.5
		# Limit height change per platform to 60px to prevent impossible sequences
		var y_pos: float = last_platform_y - rng.randf_range(-30.0, 60.0)
		y_pos = clampf(y_pos, GROUND_Y - 150.0, GROUND_Y)
		_create_platform(chunk, x_pos, y_pos, plat_width)
		last_platform_y = y_pos

func _build_spike_corridor(chunk: Node2D) -> void:
	# Ground with spikes on it, and floating platforms to jump over
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)
	
	# Place 2-3 spike groups on the ground
	var num_spikes: int = rng.randi_range(2, 3)
	var spacing: float = CHUNK_WIDTH / (num_spikes + 1)
	
	for i in num_spikes:
		var spike_x: float = (i + 1) * spacing - SPIKE_WIDTH * 0.5
		_create_spike(chunk, spike_x, last_platform_y - PLATFORM_HEIGHT * 0.5 - SPIKE_HEIGHT * 0.5)
	
	# Add a floating platform to help jump over
	_create_platform(chunk, CHUNK_WIDTH * 0.3, last_platform_y - 100.0, 120.0)

func _build_spike_gap_combo(chunk: Node2D) -> void:
	var gap_start: float = rng.randf_range(250.0, 400.0)
	# Max gap reduced from 180→150 to ensure jumpable at all speeds
	var gap_size: float = rng.randf_range(100.0, 150.0)
	
	# Ground before gap with spikes set back from edge (30px margin)
	_create_platform(chunk, 0, last_platform_y, gap_start)
	_create_spike(chunk, gap_start - SPIKE_WIDTH - 30.0, last_platform_y - PLATFORM_HEIGHT * 0.5 - SPIKE_HEIGHT * 0.5)
	
	# Ground after gap with spikes set back from landing (safe landing zone of 80px)
	var after_x: float = gap_start + gap_size
	var after_width: float = CHUNK_WIDTH - after_x
	_create_platform(chunk, after_x, last_platform_y, after_width)
	_create_spike(chunk, after_x + 80.0, last_platform_y - PLATFORM_HEIGHT * 0.5 - SPIKE_HEIGHT * 0.5)

func _build_multi_spike_field(chunk: Node2D) -> void:
	# Ground with many spike clusters
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)
	
	var num_clusters: int = rng.randi_range(3, 4)
	var spacing: float = CHUNK_WIDTH / (num_clusters + 1)
	
	# Calculate max cluster size that guarantees a 100px safe gap between clusters
	var spike_unit: float = SPIKE_WIDTH + 5.0  # 65px per spike in cluster
	var max_cluster_size: int = maxi(1, int((spacing - 100.0) / spike_unit))
	max_cluster_size = mini(max_cluster_size, 3)  # Never more than triple
	
	for i in num_clusters:
		var cluster_x: float = (i + 1) * spacing
		var cluster_size: int = rng.randi_range(1, max_cluster_size)
		for j in cluster_size:
			_create_spike(chunk, cluster_x + j * spike_unit - cluster_size * SPIKE_WIDTH * 0.5, 
				last_platform_y - PLATFORM_HEIGHT * 0.5 - SPIKE_HEIGHT * 0.5)

# ── Node Creation Helpers ─────────────────────────────────────

func _create_platform(chunk: Node2D, local_x: float, world_y: float, width: float) -> void:
	if width < 20.0:
		return
	
	var platform := StaticBody2D.new()
	platform.position = Vector2(local_x + width * 0.5, world_y)
	platform.collision_layer = 2  # Environment
	platform.collision_mask = 0
	
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, PLATFORM_HEIGHT)
	var col := CollisionShape2D.new()
	col.shape = shape
	platform.add_child(col)
	
	# Visual — main body
	var visual := ColorRect.new()
	visual.size = Vector2(width, PLATFORM_HEIGHT)
	visual.position = Vector2(-width * 0.5, -PLATFORM_HEIGHT * 0.5)
	visual.color = Color(0.28, 0.5, 0.25, 1)  # Green ground color
	platform.add_child(visual)
	
	# Visual — top edge (grass)
	var grass := ColorRect.new()
	grass.size = Vector2(width, 6.0)
	grass.position = Vector2(-width * 0.5, -PLATFORM_HEIGHT * 0.5)
	grass.color = Color(0.35, 0.7, 0.3, 1)  # Bright green
	platform.add_child(grass)
	
	chunk.add_child(platform)

func _create_spike(chunk: Node2D, local_x: float, world_y: float) -> void:
	var spike := Area2D.new()
	
	# Calculate bottom of the bug resting on top of the platform
	var platform_top: float = world_y + SPIKE_HEIGHT * 0.5
	
	# Scale the bug down (0.65 scale makes the 65x65 sprite about 42x42 px)
	var bug_scale := Vector2(0.65, 0.65)
	var bug_height: float = 65.0 * bug_scale.y
	
	# Position the bug's center, pushing it down slightly (6.0 px) to offset transparent margins
	var bug_center_y: float = platform_top - (bug_height * 0.5) + 6.0
	
	spike.position = Vector2(local_x + SPIKE_WIDTH * 0.5, bug_center_y)
	spike.collision_layer = 16  # Hazards (Layer 5)
	spike.collision_mask = 1    # Player
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# For a ~42px bug, a 30x30 collision box is centered and forgiving
	shape.size = Vector2(30, 30)
	col.shape = shape
	spike.add_child(col)
	
	# Visual — load and scale the bug sprite
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/bug/bug_1.png")
	sprite.scale = bug_scale
	spike.add_child(sprite)
	
	# Connect signal for damage
	spike.body_entered.connect(_on_spike_body_entered)
	spike.monitoring = true
	
	chunk.add_child(spike)

func _on_spike_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
