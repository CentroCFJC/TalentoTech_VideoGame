extends CharacterBody2D

## Enemy — Patrols back and forth; chases the player when detected.

enum EnemyState { PATROL, CHASE }

@export var patrol_speed: float = 80.0
@export var chase_speed: float = 150.0
@export var detection_range: float = 250.0

var state: EnemyState = EnemyState.PATROL
var direction: float = 1.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: CharacterBody2D = null
var is_dying: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_right: RayCast2D = $RayCastRight
@onready var ray_left: RayCast2D = $RayCastLeft
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	add_to_group("enemies")
	# Set collision layer (enemy = layer 3) and mask (environment = layer 2)
	collision_layer = 4  # Layer 3
	collision_mask = 2   # Environment only

	# Connect detection area signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		EnemyState.PATROL:
			_patrol(delta)
		EnemyState.CHASE:
			_chase(delta)

	move_and_slide()

	# Flip sprite based on direction
	if sprite:
		sprite.flip_h = direction < 0

func _patrol(_delta: float) -> void:
	velocity.x = direction * patrol_speed

	# Check for walls or edges
	if is_on_wall():
		direction *= -1.0
	elif is_on_floor():
		# Check if we're about to walk off an edge
		if direction > 0 and ray_right and not ray_right.is_colliding():
			direction = -1.0
		elif direction < 0 and ray_left and not ray_left.is_colliding():
			direction = 1.0

func _chase(_delta: float) -> void:
	if not is_instance_valid(player):
		state = EnemyState.PATROL
		return

	# Move toward player
	var dir_to_player: float = sign(player.global_position.x - global_position.x)
	direction = dir_to_player
	velocity.x = direction * chase_speed

	# If player is too far, go back to patrol
	if global_position.distance_to(player.global_position) > detection_range * 1.5:
		state = EnemyState.PATROL
		player = null

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body is CharacterBody2D and body.name == "Player":
		player = body as CharacterBody2D
		state = EnemyState.CHASE

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		# Add a small delay before going back to patrol
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self) and not is_dying:
			state = EnemyState.PATROL
			player = null

## Called when the player stomps on this enemy
func die() -> void:
	if is_dying:
		return
	is_dying = true

	# Disable collisions
	collision_layer = 0
	collision_mask = 0

	# Squash animation
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.15)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()
