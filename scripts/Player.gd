extends CharacterBody2D

## Player controller — auto-run infinite runner. Only action: jump with spacebar.

# Movement constants
# La velocidad del auto-run es controlada por DifficultyManager: una velocidad
# unica por sesion que se mantiene constante (sin incremento por distancia).
# AUTO_RUN_SPEED solo se usa como fallback si DifficultyManager no existe.
const AUTO_RUN_SPEED: float = 300.0
# Velocidad a la que current_speed acelera hacia la velocidad target tras
# cruzar el selector de dificultad (en px/s por segundo). Un valor bajo da una
# aceleracion suave y perceptible.
const SPEED_ACCELERATION: float = 900.0
const JUMP_VELOCITY: float = -520.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.1
const MAX_JUMPS: int = 2                  # Double jump
const DOUBLE_JUMP_MULTIPLIER: float = 0.85 # Second jump is slightly weaker

@export var run_animation_scale: float = 0.88

# Altura objetivo del sprite en pantalla (px). Los frames nuevos (256x246)
# se escalan dinamicamente para coincidir con la altura original (49px),
# manteniendo el tamano y la fisica del juego sin importar la resolucion del arte.
const TARGET_SPRITE_HEIGHT: float = 49.0
# Altura de referencia canónica del arte nuevo (correr recortado). salto/caida
# son 256px (sin barra) pero comparten esta referencia para que el personaje
# se vea del mismo tamano en todas las animaciones nuevas.
const NEW_ART_REFERENCE_HEIGHT: float = 246.0

# State
var current_speed: float = AUTO_RUN_SPEED
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_dead: bool = false
var is_falling_out: bool = false
var fall_timeout: float = 0.0
var start_x: float = 0.0
var jumps_remaining: int = MAX_JUMPS
var _jump_lockout_timer: float = 0.0

signal powerup_changed(type: String, stacks: int)

# Get gravity from project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSFX
@onready var double_jump_sfx: AudioStreamPlayer2D = $DoubleJumpSFX
@onready var skill_ring_manager: Node2D = $SkillRingManager

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
			# Reseteo completo del estado del player (no se recarga la escena)
			is_dead = false
			is_falling_out = false
			fall_timeout = 0.0
			jumps_remaining = MAX_JUMPS
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			_jump_lockout_timer = 0.15
			velocity = Vector2.ZERO
			# Restaurar posicion inicial y distancia de referencia
			global_position = Vector2(100, 440)
			start_x = global_position.x
			# Velocidad inicial: la velocidad pre-selector bajita. Al cruzar el
			# selector de dificultad, current_speed acelerara suavemente hacia
			# la velocidad unica de la dificultad elegida.
			current_speed = DifficultyManager.get_speed() if DifficultyManager else AUTO_RUN_SPEED
			# Resetear colisiones
			collision_layer = 1
			collision_mask = 2 | 16  # Environment + Hazards
			# Reparentar la camara de vuelta al Player si fue desprendida por la caida
			var cam: Camera2D = get_node_or_null("Camera2D")
			if not cam:
				cam = get_viewport().get_camera_2d()
				if cam and cam.get_parent() != self:
					cam.reparent(self)
					# Asegurar posicion relativa correcta de la camara
					cam.position = Vector2.ZERO
			visible = true
			if sprite:
				sprite.modulate = Color.WHITE
				sprite.play("run")
			_update_skill_rings()
			set_physics_process(true)
		GameManager.State.TITLE:
			set_physics_process(false)
			visible = false
		GameManager.State.GAME_OVER:
			set_physics_process(false)
			visible = false

# ── DEBUG: Simula powerups con teclas ─────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if GameManager.current_state != GameManager.State.PLAYING:
		return

	match event.keycode:
		KEY_V:
			if GameManager.keys_collected >= 6:
				return
			apply_powerup("key", 0.0)
		KEY_P:
			var code_stacks := GameManager.GetStackCount("code")
			var cpu_stacks := GameManager.GetStackCount("cpu")
			if code_stacks >= GameManager.max_stacks_per_powerup and cpu_stacks >= GameManager.max_stacks_per_powerup:
				GameManager.ResetAllStacks()
			else:
				GameManager.AddStack("code")
				GameManager.AddStack("cpu")
			_update_skill_rings()
			emit_signal("powerup_changed", "code", GameManager.GetStackCount("code"))
			emit_signal("powerup_changed", "cpu", GameManager.GetStackCount("cpu"))
# ── END DEBUG ──

func _process(delta: float) -> void:
	_update_animation()
	_update_animation_scale_and_position()

func _update_animation_scale_and_position() -> void:
	if not sprite:
		return
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var tex_h: float = float(tex.get_height()) if tex else TARGET_SPRITE_HEIGHT
	var s: float
	match sprite.animation:
		"run", "jump", "double_jump", "fall", "death":
			# Arte nuevo: usar referencia unificada para mismo tamano de personaje
			s = TARGET_SPRITE_HEIGHT / NEW_ART_REFERENCE_HEIGHT
			if sprite.animation == "run":
				s *= run_animation_scale
		_:
			# Arte viejo: escalar dinamicamente segun altura real del frame
			s = TARGET_SPRITE_HEIGHT / tex_h
	sprite.scale = Vector2(s, s)
	# Pegar los pies al borde inferior del CollisionShape2D (y = +20)
	# Bajamos 8 px extra para que el sprite no parezca flotar sobre el suelo.
	var displayed_h: float = tex_h * s
	sprite.position.y = 28.0 - displayed_h * 0.5

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
			if sprite.animation == "double_jump" and sprite.is_playing():
				pass  # Esperar a que termine el doble salto antes de caer
			elif sprite and sprite.animation != "fall":
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

	sprite_frames.set_animation_speed("run", 32.0)
	sprite_frames.set_animation_speed("jump", 30.0)
	sprite_frames.set_animation_speed("double_jump", 60.0)
	sprite_frames.set_animation_speed("fall", 30.0)
	sprite_frames.set_animation_speed("death", 45.0)
	
	sprite_frames.set_animation_loop("run", true)
	sprite_frames.set_animation_loop("jump", false)
	sprite_frames.set_animation_loop("double_jump", false)
	sprite_frames.set_animation_loop("fall", false)
	sprite_frames.set_animation_loop("death", false)

	for i in range(1, 53):
		var path = "res://assets/rocket_v2/correr/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("run", load(path))
			
	for i in range(33, 77):
		var path = "res://assets/rocket_v2/salto/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("jump", load(path))
			
	for i in range(30, 92):
		var path = "res://assets/rocket_v2/doble_salto/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("double_jump", load(path))
			
	for i in range(77, 103):
		var path = "res://assets/rocket_v2/caida/frame_%03d.png" % i
		if ResourceLoader.exists(path):
			sprite_frames.add_frame("fall", load(path))
			
	for i in range(35, 122):
		var path = "res://assets/rocket_v2/death/frame_%03d.png" % i
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
		SFXManager.play("fall down")
		var cam: Camera2D = $Camera2D
		if cam and is_instance_valid(cam) and get_tree().current_scene and is_instance_valid(get_tree().current_scene):
			if cam.get_parent() != get_tree().current_scene:
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

	# --- Target speed (constante por sesion segun dificultad) ---
	# No hay incremento progresivo por distancia: la velocidad target viene de
	# DifficultyManager y se mantiene constante toda la sesion. Antes de cruzar
	# el selector la target es la velocidad pre-selector bajita; al cruzar la
	# barrera, DifficultyManager actualiza la target y current_speed acelera
	# suavemente hacia ella.
	var target_speed: float = DifficultyManager.get_speed() if DifficultyManager else AUTO_RUN_SPEED
	var diff: float = target_speed - current_speed
	if absf(diff) > 0.01:
		# Acelera (o decelera) hacia la velocidad target a ritmo constante.
		var step: float = SPEED_ACCELERATION * delta
		if absf(diff) <= step:
			current_speed = target_speed
		else:
			current_speed += signf(diff) * step

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

	# --- Jump lockout (prevents the jump button used to start the game from also jumping) ---
	if _jump_lockout_timer > 0.0:
		_jump_lockout_timer -= delta
	else:
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
	_clear_skill_rings()
	if cause == "fall":
		GameManager.on_player_death(cause)
		return
	# Muerte por bug o servidor
	SFXManager.play("video-game-death")
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

var _cause_to_powerup := {"bug": "code", "server": "cpu"}

## Take damage from hazard. Returns true if player survived (consumed a charge).
func take_damage(cause: String = "bug") -> bool:
	if is_dead:
		return false
	var powerup_type: String = _cause_to_powerup.get(cause, "")
	if powerup_type != "" and GameManager.ConsumeStack(powerup_type):
		var stacks := GameManager.GetStackCount(powerup_type)
		emit_signal("powerup_changed", powerup_type, stacks)
		_update_skill_rings()
		return true
	die(cause)
	return false

# ── PowerUp System ─────────────────────────────────────────────
signal video_key_collected

## Called by PowerUp.gd when the player touches a collectible
func apply_powerup(type: String, _duration: float) -> void:
	match type:
		"code", "cpu":
			SFXManager.play("correct-game-show-alert-499485")
			GameManager.AddStack(type)
			var stacks := GameManager.GetStackCount(type)
			emit_signal("powerup_changed", type, stacks)
			_update_skill_rings()
		"key":
			SFXManager.play("correct-game-show-alert-499485")
			GameManager.keys_collected += 1
			GameManager.keys_changed.emit(GameManager.keys_collected)
			emit_signal("video_key_collected")

func _update_skill_rings() -> void:
	if skill_ring_manager and is_instance_valid(skill_ring_manager):
		skill_ring_manager.set_code_stacks(GameManager.GetStackCount("code"))
		skill_ring_manager.set_cpu_stacks(GameManager.GetStackCount("cpu"))

func _clear_skill_rings() -> void:
	if skill_ring_manager and is_instance_valid(skill_ring_manager):
		skill_ring_manager.set_code_stacks(0)
		skill_ring_manager.set_cpu_stacks(0)
