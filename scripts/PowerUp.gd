extends Area2D

## PowerUp — Collectible item that applies a temporary effect to the player.
## Modular: add new types by extending the match in _apply_effect().

@export_enum("code", "cpu", "key") var type: String = "code"
@export var duration: float = 5.0

var is_collected: bool = false
var bob_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Set collision layer (collectibles = layer 4) and mask (player = layer 1)
	collision_layer = 8   # Layer 4
	collision_mask = 1    # Player

	# Connect body entered signal
	body_entered.connect(_on_body_entered)

	# Start floating animation
	_start_bob_animation()

	# Set sprite texture & color based on type
	_set_appearance_by_type()

func _set_appearance_by_type() -> void:
	if not sprite:
		return
	match type:
		"code":
			# Load the powerup_code sprite and keep its natural colors
			var code_tex = load("res://assets/powerups/powerup_code.png")
			if code_tex:
				sprite.texture = code_tex
			sprite.modulate = Color(1.0, 1.0, 1.0)   # Natural colors
			sprite.scale = Vector2(0.5, 0.5)          # Half size
		"cpu":
			var cpu_tex = load("res://assets/powerups/powerup_cpu.png")
			if cpu_tex:
				sprite.texture = cpu_tex
			sprite.modulate = Color(1.0, 1.0, 1.0)
			sprite.scale = Vector2(0.5, 0.5)
		"key":
			var key_tex = load("res://assets/powerups/powerup_key.png")
			if key_tex:
				sprite.texture = key_tex
			sprite.modulate = Color(1.0, 1.0, 1.0)
			sprite.scale = Vector2(0.8, 0.8)

func _start_bob_animation() -> void:
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(self, "position:y", position.y - 6, 0.6).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(self, "position:y", position.y + 6, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	# Check if it's the player
	if body.has_method("apply_powerup"):
		is_collected = true

		# Stop bobbing
		if bob_tween:
			bob_tween.kill()

		# Apply effect
		body.apply_powerup(type, duration)

		# Collection animation
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
