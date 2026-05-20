extends CharacterBody2D

## Player controller — auto-run infinite runner. Only action: jump with spacebar.

# Movement constants
const AUTO_RUN_SPEED: float = 300.0
const SPEED_INCREMENT: float = 5.0        # +5 px/s per 500m
const MAX_SPEED: float = 500.0
const JUMP_VELOCITY: float = -520.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.1
const MAX_JUMPS: int = 2                  # Double jump
const DOUBLE_JUMP_MULTIPLIER: float = 0.85 # Second jump is slightly weaker

@export var run_animation_scale: float = 0.88

# State
var current_speed: float = AUTO_RUN_SPEED
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dead: bool = false
var start_x: float = 0.0
var jumps_remaining: int = MAX_JUMPS

# Get gravity from project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2 | 16  # Environment + Hazards
	start_x = global_position.x
	
	_setup_sprite_frames()
	
	# Connect to game state changes
	GameManager.state_changed.connect(_on_state_changed)
	
	# If we start in TITLE, freeze the player
	if GameManager.current_state == GameManager.State.TITLE:
		set_physics_process(false)

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYING:
			is_dead = false
			collision_layer = 1
			collision_mask = 2 | 16  # Environment + Hazards
			if sprite:
				sprite.modulate = Color.WHITE
				sprite.play("run")
			set_physics_process(true)
		GameManager.State.TITLE:
			set_physics_process(false)

func _process(_delta: float) -> void:
	_update_animation()
	_update_animation_scale_and_position()

func _update_animation_scale_and_position() -> void:
	if not sprite:
		return
	var s: float = 1.0
	if sprite.animation == "run":
		s = run_animation_scale
	sprite.scale = Vector2(s, s)
	sprite.position.y = 20.0 - 24.5 * s

func _update_animation() -> void:
	if is_dead:
		if sprite and sprite.animation != "death":
			sprite.play("death")
		return
		
	if not is_on_floor():
		if velocity.y < 0:
			if jumps_remaining == 0:
				if sprite and sprite.animation != "double_jump":
					sprite.play("double_jump")
			else:
				if sprite and sprite.animation != "jump":
					sprite.play("jump")
		else:
			if sprite and sprite.animation != "fall":
				sprite.play("fall")
	else:
		if sprite and sprite.animation != "run":
			sprite.play("run")

func _setup_sprite_frames() -> void:
	var sprite_frames = SpriteFrames.new()
	
	sprite_frames.add_animation("run")
	sprite_frames.add_animation("jump")
	sprite_frames.add_animation("double_jump")
	sprite_frames.add_animation("fall")
	sprite_frames.add_animation("death")
	
	sprite_frames.set_animation_speed("run", 12.0)
	sprite_frames.set_animation_speed("jump", 10.0)
	sprite_frames.set_animation_speed("double_jump", 12.0)
	sprite_frames.set_animation_speed("fall", 8.0)
	sprite_frames.set_animation_speed("death", 10.0)
	
	sprite_frames.set_animation_loop("run", true)
	sprite_frames.set_animation_loop("jump", false)
	sprite_frames.set_animation_loop("double_jump", false)
	sprite_frames.set_animation_loop("fall", true)
	sprite_frames.set_animation_loop("death", false)

	for i in range(1, 7):
		var path = "res://assets/rocket/Run_%d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("run", load(path))
			
	for i in range(1, 3):
		var path = "res://assets/rocket/Jump_%d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("jump", load(path))
			
	for i in range(1, 5):
		var path = "res://assets/rocket/DoubleJump_%d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("double_jump", load(path))
			
	for i in range(1, 3):
		var path = "res://assets/rocket/Fall_%d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("fall", load(path))
			
	for i in range(1, 5):
		var path = "res://assets/rocket/Death_%d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("death", load(path))

	sprite.sprite_frames = sprite_frames
	sprite.play("run")

func _physics_process(delta: float) -> void:
	if is_dead:
		# Still apply gravity during death animation
		velocity.y += gravity * delta
		move_and_slide()
		return

	# --- Progressive speed ---
	var distance_traveled: float = global_position.x - start_x
	current_speed = min(AUTO_RUN_SPEED + (distance_traveled / 500.0) * SPEED_INCREMENT, MAX_SPEED)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME
		jumps_remaining = MAX_JUMPS

	# --- Jump buffer ---
	jump_buffer_timer -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	# --- Jump (ground / coyote) ---
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jumps_remaining = MAX_JUMPS - 1
	# --- Double jump (air) ---
	elif Input.is_action_just_pressed("jump") and jumps_remaining > 0 and coyote_timer <= 0.0:
		velocity.y = JUMP_VELOCITY * DOUBLE_JUMP_MULTIPLIER
		jumps_remaining -= 1
		jump_buffer_timer = 0.0

	# Variable jump height: cut jump short on release
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# --- Auto-run (always move right) ---
	velocity.x = current_speed

	move_and_slide()

	# --- Update score ---
	GameManager.update_score_from_distance(global_position.x - start_x)

	# --- Fall death ---
	if global_position.y > 1000:
		die()

## Player death
func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Visual feedback
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3, 0.7)
		sprite.play("death")
	# Change collision to only detect environment (Layer 2) and ignore player collisions (Layer 1)
	collision_layer = 0
	collision_mask = 2
	# Death bounce
	velocity.y = -300
	velocity.x = 0
	# Notify game manager
	GameManager.on_player_death()

## Take damage from hazard
func take_damage() -> void:
	if is_dead:
		return
	die()
