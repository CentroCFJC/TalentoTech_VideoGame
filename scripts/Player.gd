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

# State
var current_speed: float = AUTO_RUN_SPEED
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dead: bool = false
var start_x: float = 0.0
var jumps_remaining: int = MAX_JUMPS

# Animation
var animation_timer: float = 0.0
const ANIMATION_FPS: float = 15.0

# Get gravity from project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2 | 16  # Environment + Hazards
	start_x = global_position.x
	
	# Connect to game state changes
	GameManager.state_changed.connect(_on_state_changed)
	
	# If we start in TITLE, freeze the player
	if GameManager.current_state == GameManager.State.TITLE:
		set_physics_process(false)

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYING:
			is_dead = false
			set_physics_process(true)
		GameManager.State.TITLE:
			set_physics_process(false)

func _process(delta: float) -> void:
	if not is_dead and is_on_floor():
		animation_timer += delta
		if animation_timer >= 1.0 / ANIMATION_FPS:
			animation_timer -= 1.0 / ANIMATION_FPS
			sprite.frame = (sprite.frame + 1) % 15
	elif not is_on_floor():
		# Optional: static jump frame
		sprite.frame = 0

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
	# Disable collision
	collision_shape.set_deferred("disabled", true)
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
