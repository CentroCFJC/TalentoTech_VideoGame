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
var is_falling_out: bool = false
var fall_timeout: float = 0.0
var start_x: float = 0.0
var jumps_remaining: int = MAX_JUMPS

# ── PowerUp charge state (one-time death evade) ───────────────
var has_code_charge: bool = false
var has_cpu_charge: bool = false
signal powerup_changed(type: String, active: bool)

# Get gravity from project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSFX
@onready var double_jump_sfx: AudioStreamPlayer2D = $DoubleJumpSFX

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2 | 16  # Environment + Hazards
	start_x = global_position.x
	
	_setup_sprite_frames()
	
	# Connect to game state changes
	GameManager.state_changed.connect(_on_state_changed)
	
	# If we start in TITLE, freeze and hide the player
	if GameManager.current_state == GameManager.State.TITLE:
		set_physics_process(false)
		visible = false

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.PLAYING:
			is_dead = false
			is_falling_out = false
			visible = true
			collision_layer = 1
			collision_mask = 2 | 16  # Environment + Hazards
			if sprite:
				sprite.modulate = Color.WHITE
				sprite.play("run")
			set_physics_process(true)
		GameManager.State.TITLE:
			set_physics_process(false)
			visible = false
		GameManager.State.GAME_OVER:
			set_physics_process(false)
			visible = false

# ── DEBUG: Simula la obtención de una key con la tecla V ─────
# Eliminar este bloque antes de la versión final.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.keycode == KEY_V and event.pressed and not event.echo):
		return
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	if GameManager.keys_collected >= 6:
		return
	apply_powerup("key", 0.0)
# ── END DEBUG ──

func _process(delta: float) -> void:
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
		if sprite and sprite.animation != "death" and not is_falling_out:
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
		velocity.y += gravity * delta
		move_and_slide()
		return

	# ---- Disable hazard detection early when falling below playable area ----
	# Hazards (bugs/servers) are Area2Ds using mask=1 (Player layer).
	# Clear collision_layer so their body_entered cannot fire before is_falling_out kicks in.
	if global_position.y > 500 and not is_on_floor() and velocity.y > 0 and not is_falling_out:
		collision_layer = 0
		collision_mask = 2  # Only environment (layer 2) for landing on lower platforms

	# --- Fall death — fall off-screen before dying ---
	if global_position.y > 1000 and not is_falling_out:
		is_falling_out = true
		collision_layer = 0
		collision_mask = 0
		fall_timeout = 2.5
		var cam: Camera2D = $Camera2D
		if cam:
			cam.reparent(get_tree().current_scene)

	if is_falling_out:
		velocity.y += gravity * delta
		velocity.x = 0
		move_and_slide()
		fall_timeout -= delta
		# Primary: fall well past camera bottom before dying
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam:
			var cam_bottom: float = cam.global_position.y + get_viewport_rect().size.y * 0.5 / cam.zoom.y
			if global_position.y > cam_bottom + 400:
				die("fall")
				return
		# Fallback: force death after timeout even if camera check never passes
		if fall_timeout <= 0:
			die("fall")
		return

	# --- Progressive speed ---
	var distance_traveled: float = global_position.x - start_x
	current_speed = min(AUTO_RUN_SPEED + (distance_traveled / 500.0) * SPEED_INCREMENT, MAX_SPEED)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		# Restore collision if it was disabled by early fall hazard protection
		if not is_falling_out and collision_layer == 0:
			collision_layer = 1
			collision_mask = 2 | 16
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
		if jump_sfx:
			jump_sfx.play()
	# --- Double jump (air) ---
	elif Input.is_action_just_pressed("jump") and jumps_remaining > 0 and coyote_timer <= 0.0:
		velocity.y = JUMP_VELOCITY * DOUBLE_JUMP_MULTIPLIER
		jumps_remaining -= 1
		jump_buffer_timer = 0.0
		if double_jump_sfx:
			double_jump_sfx.play()

	# Variable jump height: cut jump short on release
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# --- Auto-run (always move right) ---
	velocity.x = current_speed

	move_and_slide()

	# --- Update score ---
	GameManager.update_score_from_distance(global_position.x - start_x)

	# (Bug stomp removed — power-ups are now one-time death evades)

## Player death — cause: "bug", "fall", or ""
func die(cause: String = "") -> void:
	if is_dead:
		return
	is_dead = true
	if cause == "fall":
		GameManager.on_player_death(cause)
		return
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
	# Notify game manager with cause
	GameManager.on_player_death(cause)

## Take damage from hazard. Returns true if player survived (consumed a charge).
func take_damage(cause: String = "bug") -> bool:
	if is_dead:
		return false
	if cause == "bug" and has_code_charge:
		has_code_charge = false
		emit_signal("powerup_changed", "code", false)
		return true
	if cause == "server" and has_cpu_charge:
		has_cpu_charge = false
		emit_signal("powerup_changed", "cpu", false)
		return true
	die(cause)
	return false

# ── PowerUp System ─────────────────────────────────────────────
signal video_key_collected

## Called by PowerUp.gd when the player touches a collectible
func apply_powerup(type: String, _duration: float) -> void:
	match type:
		"code":
			has_code_charge = true
			emit_signal("powerup_changed", "code", true)
		"cpu":
			has_cpu_charge = true
			emit_signal("powerup_changed", "cpu", true)
		"key":
			GameManager.keys_collected += 1
			GameManager.keys_changed.emit(GameManager.keys_collected)
			emit_signal("video_key_collected")
