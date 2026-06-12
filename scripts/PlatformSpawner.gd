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

# Obstacle offset (horizontal half-width used for centering)
const OBSTACLE_OFFSET: float = 30.0

# Patterns enum
enum Pattern {
	FLAT_GROUND,
	GROUND_GAP_SMALL,
	GROUND_GAP_LARGE,
	STEP_UP,
	STEP_DOWN,
	FLOATING_CHAIN,
	OBSTACLE_CORRIDOR,
	OBSTACLE_GAP_COMBO,
	MULTI_OBSTACLE_FIELD,
	KEY_EASY
}

# Key pattern — easy section every 1000 points
var _next_key_score: int = 1000
var _key_chunks_remaining: int = 0

# Server settings
const SERVER_WIDTH: float = 48.0
const SERVER_HEIGHT: float = 48.0

# State
var next_chunk_x: float = 0.0
var last_platform_y: float = GROUND_Y
var active_chunks: Array[Node2D] = []
var camera: Camera2D = null
var rng := RandomNumberGenerator.new()
var last_server_spawn_x: float = -2000.0

# Collision shapes (created once, shared)
var ground_shape: RectangleShape2D

# PowerUp spawning
var powerup_scene: PackedScene = null

func _ready() -> void:
	rng.randomize()
	
	# Pre-load the PowerUp scene
	if ResourceLoader.exists("res://scenes/PowerUp.tscn"):
		powerup_scene = load("res://scenes/PowerUp.tscn")
	
	# Connect to game state
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYING:
			_next_key_score = 1000
			_key_chunks_remaining = 0
		GameManager.State.TITLE:
			_next_key_score = 1000
			_key_chunks_remaining = 0

func _on_score_changed(score: int) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	if score >= _next_key_score and _key_chunks_remaining == 0:
		_key_chunks_remaining = 8
		_next_key_score += 1000

func _process(delta: float) -> void:
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

func _spawn_powerup(chunk: Node2D, world_x: float, world_y: float, p_type: String) -> void:
	if not powerup_scene:
		return
	var pu: Area2D = powerup_scene.instantiate()
	pu.type = p_type
	pu.duration = 10.0
	
	# Fix Tween bug: set local position BEFORE adding to tree so _ready() caches the right Y
	pu.position = Vector2(world_x - chunk.global_position.x, world_y - chunk.global_position.y)
	chunk.add_child(pu)

## Spawns a power-up at the beginning of an obstacle pattern chunk
func _spawn_powerup_for_obstacle_pattern(chunk: Node2D, chunk_x: float) -> void:
	if not powerup_scene:
		return
	# Don't spawn power-ups until obstacles can actually appear
	if GameManager.score < 50:
		return
	var p_type: String
	if GameManager.score < 150:
		p_type = "code"
	else:
		p_type = "code" if rng.randf() > 0.5 else "cpu"
	var spawn_world_x: float = chunk_x + 100.0
	var spawn_world_y: float = last_platform_y - PLATFORM_HEIGHT * 0.5 - rng.randf_range(10.0, 180.0)
	_spawn_powerup(chunk, spawn_world_x, spawn_world_y, p_type)

func _get_difficulty() -> int:
	var distance: float = next_chunk_x
	return mini(int(distance / DIFFICULTY_INTERVAL), MAX_DIFFICULTY)

func _get_available_patterns(difficulty: int) -> Array[Pattern]:
	var patterns: Array[Pattern] = [Pattern.FLAT_GROUND, Pattern.GROUND_GAP_SMALL, Pattern.STEP_UP]
	
	if difficulty >= 2:
		patterns.append(Pattern.GROUND_GAP_LARGE)
		patterns.append(Pattern.STEP_DOWN)
		patterns.append(Pattern.OBSTACLE_CORRIDOR)
	if difficulty >= 3:
		patterns.append(Pattern.FLOATING_CHAIN)
		patterns.append(Pattern.OBSTACLE_GAP_COMBO)
	if difficulty >= 4:
		patterns.append(Pattern.MULTI_OBSTACLE_FIELD)
	
	return patterns

func _generate_chunk(chunk_x: float) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % int(chunk_x)
	chunk.global_position = Vector2(chunk_x, 0)
	add_child(chunk)
	active_chunks.append(chunk)
	
	var difficulty: int = _get_difficulty()
	var patterns := _get_available_patterns(difficulty)
	
	# Chunk 0: intro flat, Chunks 1-2: movement tutorials, Chunks 3-4: powerup tutorials, Chunk 5: cooldown flat
	var pattern: Pattern
	if chunk_x < CHUNK_WIDTH:
		_build_flat_ground(chunk)
		return
	elif chunk_x < CHUNK_WIDTH * 2:
		_build_jump_tutorial(chunk)
		return
	elif int(chunk_x / CHUNK_WIDTH) == 2:
		_build_doublejump_tutorial(chunk)
		return
	elif int(chunk_x / CHUNK_WIDTH) == 3:
		_build_code_tutorial(chunk)
		return
	elif int(chunk_x / CHUNK_WIDTH) == 4:
		_build_cpu_tutorial(chunk)
		return
	elif int(chunk_x / CHUNK_WIDTH) == 5:
		_build_flat_ground(chunk)
		return
	elif _key_chunks_remaining > 0:
		if _key_chunks_remaining == 8:
			last_platform_y = GROUND_Y
		var spawn_key: bool = _key_chunks_remaining == 5
		_build_key_easy(chunk)
		_key_chunks_remaining -= 1
		if spawn_key:
			_spawn_key_powerup(chunk, chunk_x)
		return
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
		Pattern.OBSTACLE_CORRIDOR:
			_build_obstacle_corridor(chunk)
		Pattern.OBSTACLE_GAP_COMBO:
			_build_obstacle_gap_combo(chunk)
		Pattern.MULTI_OBSTACLE_FIELD:
			_build_multi_obstacle_field(chunk)

	# Spawn power-up at the start of obstacle patterns
	if pattern in [Pattern.OBSTACLE_CORRIDOR, Pattern.OBSTACLE_GAP_COMBO, Pattern.MULTI_OBSTACLE_FIELD]:
		_spawn_powerup_for_obstacle_pattern(chunk, chunk_x)

# ── Pattern Builders ──────────────────────────────────────────

func _build_flat_ground(chunk: Node2D) -> void:
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)

## Jump tutorial — first chunk: small gap with jump instruction panel.
func _build_jump_tutorial(chunk: Node2D) -> void:
	var gap_size: float = 80.0
	var gap_start: float = 730.0

	# Ground before gap
	_create_platform(chunk, 0, last_platform_y, gap_start)
	# Ground after gap
	var after_start: float = gap_start + gap_size
	_create_platform(chunk, after_start, last_platform_y, CHUNK_WIDTH - after_start)

	# Tutorial panel — jump instruction before the gap
	_create_tutorial_panel(
		chunk,
		"Pulsa el botón para Saltar",
		"res://assets/rocket/Jump_2.png",
		Vector2(120, last_platform_y - 165)
	)

## Double-jump tutorial — second chunk: bigger gap with double-jump instruction panel.
func _build_doublejump_tutorial(chunk: Node2D) -> void:
	var gap_size: float = 180.0
	var gap_start: float = 630.0

	# Ground before gap
	_create_platform(chunk, 0, last_platform_y, gap_start)
	# Ground after gap
	var after_start: float = gap_start + gap_size
	_create_platform(chunk, after_start, last_platform_y, CHUNK_WIDTH - after_start)

	# Tutorial panel — double-jump instruction before the gap
	_create_tutorial_panel(
		chunk,
		"Pulsa de nuevo para doble salto",
		"res://assets/rocket/DoubleJump_3.png",
		Vector2(30, last_platform_y - 165)
	)

## Code tutorial — powerup_code protects from bugs.
func _build_code_tutorial(chunk: Node2D) -> void:
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)

	# Tutorial panel
	_create_powerup_tutorial_panel(
		chunk,
		"SkillUp: Programación te protege de bugs",
		"res://assets/powerups/powerup_code.png",
		"res://assets/bug/bug_1.png",
		Vector2(30.0, last_platform_y - 165)
	)

	# Powerup then bug further ahead
	_spawn_powerup(chunk, chunk.global_position.x + 250.0, GROUND_Y - 60.0, "code")
	_create_obstacle(chunk, 650.0, last_platform_y - PLATFORM_HEIGHT * 0.5, "bug")

## CPU tutorial — powerup_cpu protects from servers.
func _build_cpu_tutorial(chunk: Node2D) -> void:
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)

	# Tutorial panel
	_create_powerup_tutorial_panel(
		chunk,
		"SkillUp: Hardware te ayuda a dominar servidores",
		"res://assets/powerups/powerup_cpu.png",
		"res://assets/server/server_red.png",
		Vector2(30.0, last_platform_y - 165)
	)

	# Powerup then server further ahead
	_spawn_powerup(chunk, chunk.global_position.x + 250.0, GROUND_Y - 60.0, "cpu")
	_create_obstacle(chunk, 650.0, last_platform_y - PLATFORM_HEIGHT * 0.5, "server")

## Creates a tutorial panel: text + icon → icon.
func _create_powerup_tutorial_panel(chunk: Node2D, text: String, icon1_path: String, icon2_path: String, pos: Vector2) -> void:
	# Background panel for contrast
	var bg := PanelContainer.new()
	bg.position = pos

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.55)
	bg_style.content_margin_left = 10
	bg_style.content_margin_right = 10
	bg_style.content_margin_top = 6
	bg_style.content_margin_bottom = 6
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.anti_aliasing = true
	bg.add_theme_stylebox_override("panel", bg_style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	row.add_child(_make_icon_arrow_icon(icon1_path, icon2_path))

	bg.add_child(row)
	chunk.add_child(bg)

## Creates an [Icon] → [Icon] horizontal group.
func _make_icon_arrow_icon(icon1_path: String, icon2_path: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)

	hbox.add_child(_make_circle_icon(icon1_path, 44))

	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.95))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(arrow)

	hbox.add_child(_make_circle_icon(icon2_path, 44))
	return hbox

## Creates a circular icon panel.
func _make_circle_icon(img_path: String, size: int) -> Panel:
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(size, size)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.08, 0.14, 0.88)
	style.border_color = Color(0.55, 0.85, 1.0, 0.95)
	style.set_border_width_all(2)
	var r: int = int(size / 2.0)
	style.corner_radius_top_left     = r
	style.corner_radius_top_right    = r
	style.corner_radius_bottom_left  = r
	style.corner_radius_bottom_right = r
	style.anti_aliasing = true
	circle.add_theme_stylebox_override("panel", style)

	var tex_rect := TextureRect.new()
	if ResourceLoader.exists(img_path):
		tex_rect.texture = load(img_path)
	tex_rect.anchor_left   = 0.0; tex_rect.anchor_top    = 0.0
	tex_rect.anchor_right  = 1.0; tex_rect.anchor_bottom = 1.0
	tex_rect.offset_left   =  6;  tex_rect.offset_top    =  6
	tex_rect.offset_right  = -6;  tex_rect.offset_bottom = -6
	tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	circle.add_child(tex_rect)
	return circle

## Creates a styled tutorial panel: [TEXT] then [CIRCLE IMAGE] (image "adelante").
func _create_tutorial_panel(chunk: Node2D, message: String, image_path: String, pos: Vector2) -> void:
	# Background panel for contrast
	var bg := PanelContainer.new()
	bg.position = pos

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.55)
	bg_style.content_margin_left = 10
	bg_style.content_margin_right = 10
	bg_style.content_margin_top = 6
	bg_style.content_margin_bottom = 6
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.anti_aliasing = true
	bg.add_theme_stylebox_override("panel", bg_style)

	# Root row — laid out horizontally
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	# ── 1. Label (left / "atras", the player reads it first) ──
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# ── 2. Circular icon panel (right / "adelante") ──
	const ICON_SIZE := 56          # smaller → less pixelation
	const PADDING   := 6           # inset from circle edge

	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)

	var style := StyleBoxFlat.new()
	style.bg_color        = Color(0.08, 0.08, 0.14, 0.88)
	style.border_color    = Color(0.55, 0.85, 1.0, 0.95)
	style.set_border_width_all(2)
	var r: int = ICON_SIZE / 2
	style.corner_radius_top_left     = r
	style.corner_radius_top_right    = r
	style.corner_radius_bottom_left  = r
	style.corner_radius_bottom_right = r
	style.anti_aliasing              = true
	circle.add_theme_stylebox_override("panel", style)

	var tex_rect := TextureRect.new()
	if ResourceLoader.exists(image_path):
		tex_rect.texture = load(image_path)
	# Fill the circle minus the padding border
	tex_rect.anchor_left   = 0.0;  tex_rect.anchor_top    = 0.0
	tex_rect.anchor_right  = 1.0;  tex_rect.anchor_bottom = 1.0
	tex_rect.offset_left   =  PADDING;  tex_rect.offset_top    =  PADDING
	tex_rect.offset_right  = -PADDING;  tex_rect.offset_bottom = -PADDING
	tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	circle.add_child(tex_rect)

	row.add_child(circle)
	bg.add_child(row)
	chunk.add_child(bg)

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

func _build_obstacle_corridor(chunk: Node2D) -> void:
	# Ground with bugs/servers on it, and a floating platform to help jump over
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)
	
	# Place 2-3 obstacles on the ground
	var num_obstacles: int = rng.randi_range(2, 3)
	var spacing: float = CHUNK_WIDTH / (num_obstacles + 1)
	
	for i in num_obstacles:
		var obs_x: float = (i + 1) * spacing - OBSTACLE_OFFSET
		_create_obstacle(chunk, obs_x, last_platform_y - PLATFORM_HEIGHT * 0.5)
	
	# Add a floating platform to help jump over
	_create_platform(chunk, CHUNK_WIDTH * 0.3, last_platform_y - 100.0, 120.0)

func _build_obstacle_gap_combo(chunk: Node2D) -> void:
	var gap_start: float = rng.randf_range(250.0, 400.0)
	# Max gap reduced to 150 to ensure jumpable at all speeds
	var gap_size: float = rng.randf_range(100.0, 150.0)
	
	# Ground before gap with obstacle set back from edge (30px margin)
	_create_platform(chunk, 0, last_platform_y, gap_start)
	_create_obstacle(chunk, gap_start - OBSTACLE_OFFSET * 2 - 30.0, last_platform_y - PLATFORM_HEIGHT * 0.5)
	
	# Ground after gap with obstacle set back from landing (safe landing zone of 80px)
	var after_x: float = gap_start + gap_size
	var after_width: float = CHUNK_WIDTH - after_x
	_create_platform(chunk, after_x, last_platform_y, after_width)
	_create_obstacle(chunk, after_x + 80.0, last_platform_y - PLATFORM_HEIGHT * 0.5)

func _build_multi_obstacle_field(chunk: Node2D) -> void:
	# Ground with many obstacle clusters (bugs and servers)
	_create_platform(chunk, 0, last_platform_y, CHUNK_WIDTH)
	
	var num_clusters: int = rng.randi_range(3, 4)
	var spacing: float = CHUNK_WIDTH / (num_clusters + 1)
	
	# Each obstacle unit is ~65px wide; guarantee 100px safe gap between clusters
	var obs_unit: float = OBSTACLE_OFFSET * 2 + 5.0
	var max_cluster_size: int = maxi(1, int((spacing - 100.0) / obs_unit))
	max_cluster_size = mini(max_cluster_size, 3)  # Never more than triple
	
	for i in num_clusters:
		var cluster_x: float = (i + 1) * spacing
		var cluster_size: int = rng.randi_range(1, max_cluster_size)
		for j in cluster_size:
			_create_obstacle(chunk, cluster_x + j * obs_unit - cluster_size * OBSTACLE_OFFSET,
				last_platform_y - PLATFORM_HEIGHT * 0.5)

# ── Key Pattern ───────────────────────────────────────────────

## Very easy section — almost flat with tiny gaps, no obstacles.
func _build_key_easy(chunk: Node2D) -> void:
	var x: float = 0.0
	while x < CHUNK_WIDTH - 60.0:
		var plat_width: float = rng.randf_range(180.0, 300.0)
		plat_width = mini(plat_width, CHUNK_WIDTH - x)
		var plat_y: float = last_platform_y + rng.randf_range(-8.0, 8.0)
		plat_y = clampf(plat_y, GROUND_Y - 30.0, GROUND_Y + 10.0)
		_create_platform(chunk, x, plat_y, plat_width)
		x += plat_width + rng.randf_range(25.0, 40.0)
		last_platform_y = plat_y

func _spawn_key_powerup(chunk: Node2D, chunk_x: float) -> void:
	if not powerup_scene:
		return
	var pu: Area2D = powerup_scene.instantiate()
	pu.type = "key"
	pu.duration = 0.0
	pu.position = Vector2(120.0, last_platform_y - PLATFORM_HEIGHT * 0.5 - 60.0)
	chunk.add_child(pu)

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

func _create_obstacle(chunk: Node2D, local_x: float, platform_surface_y: float, type: String = "") -> void:
	var world_x = chunk.global_position.x + local_x
	
	if type == "":
		if GameManager.score < 50:
			return
		elif GameManager.score < 150:
			type = "bug"
		else:
			type = "server" if rng.randf() < 0.5 else "bug"
			
	if type == "server":
		if world_x - last_server_spawn_x < 1000.0:
			type = "bug"
		else:
			last_server_spawn_x = world_x
			
	if type == "bug":
		var bug_area := Area2D.new()
		
		var bug_scale := Vector2(0.65, 0.65)
		var bug_height: float = 65.0 * bug_scale.y
		var bug_center_y: float = platform_surface_y - (bug_height * 0.5) + 6.0
		
		bug_area.position = Vector2(local_x + OBSTACLE_OFFSET, bug_center_y)
		bug_area.collision_layer = 16  # Hazards (Layer 5)
		bug_area.collision_mask = 1    # Player
		bug_area.add_to_group("bugs")
		
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(30, 30)
		col.shape = shape
		bug_area.add_child(col)
		
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/bug/bug_1.png")
		sprite.scale = bug_scale
		bug_area.add_child(sprite)
		
		bug_area.body_entered.connect(_on_spike_body_entered.bind(bug_area))
		bug_area.monitoring = true
		chunk.add_child(bug_area)
		
	elif type == "server":
		var num_servers: int = rng.randi_range(1, 2)
		var cluster_group: String = "server_cluster_%d" % int(local_x + OBSTACLE_OFFSET)
		for i in num_servers:
			var server_y: float = platform_surface_y - (i * SERVER_HEIGHT) - SERVER_HEIGHT * 0.5
			var server := Area2D.new()
			server.position = Vector2(local_x + OBSTACLE_OFFSET, server_y)
			server.collision_layer = 16  # Hazards
			server.collision_mask = 1    # Player
			server.add_to_group(cluster_group)
			
			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(SERVER_WIDTH, SERVER_HEIGHT)
			col.shape = shape
			server.add_child(col)
			
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/server/server_red.png")
			server.add_child(sprite)
			
			if sprite.texture:
				var tex_size = sprite.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(SERVER_WIDTH / tex_size.x, SERVER_HEIGHT / tex_size.y)
					
			server.body_entered.connect(_on_server_body_entered.bind(server))
			server.monitoring = true
			chunk.add_child(server)

func _on_spike_body_entered(body: Node2D, spike: Area2D) -> void:
	if not body.has_method("take_damage"):
		return
	# take_damage returns true if the player survived by consuming a charge
	if body.take_damage("bug"):
		if spike.has_method("queue_free") and not spike.is_queued_for_deletion():
			var bug_sprite: Sprite2D = null
			for child in spike.get_children():
				if child is Sprite2D:
					bug_sprite = child
					break
			spike.collision_layer = 0
			spike.collision_mask = 0
			var tween := spike.create_tween()
			if bug_sprite:
				tween.tween_property(bug_sprite, "scale", Vector2(1.5, 0.1), 0.15)
				tween.tween_property(bug_sprite, "modulate:a", 0.0, 0.2)
			tween.tween_callback(spike.queue_free)



func _on_server_body_entered(body: Node2D, server: Area2D) -> void:
	if not body.has_method("take_damage"):
		return
	# Already disabled by another server in the same cluster (hit simultaneously)
	if server.collision_layer == 0:
		return
	# take_damage returns true if the player survived by consuming a charge
	if body.take_damage("server"):
		# Disable all stacked servers in this cluster so the player doesn't
		# get hit twice by the same stack
		for group in server.get_groups():
			if group.begins_with("server_cluster_"):
				for s in get_tree().get_nodes_in_group(group):
					s.collision_layer = 0
					s.collision_mask = 0
					if s != server:
						var sibling_sprite: Sprite2D = null
						for child in s.get_children():
							if child is Sprite2D:
								sibling_sprite = child
								break
						if sibling_sprite:
							var tween := s.create_tween()
							tween.tween_property(sibling_sprite, "modulate", Color(0.2, 0.75, 1.0), 0.2)
				break
		var server_sprite: Sprite2D = null
		for child in server.get_children():
			if child is Sprite2D:
				server_sprite = child
				break
		if server_sprite:
			var tween := server.create_tween()
			tween.tween_property(server_sprite, "modulate", Color(0.2, 0.75, 1.0), 0.2)
