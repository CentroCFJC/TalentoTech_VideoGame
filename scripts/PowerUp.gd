extends Area2D

## PowerUp — Collectible item that applies a temporary effect to the player.
## Modular: add new types by extending the match in _apply_effect().

@export_enum("code", "cpu", "key") var type: String = "code"
@export var duration: float = 5.0

var is_collected: bool = false
var bob_tween: Tween
var _beam_material: ShaderMaterial = null

const BEAM_WIDTH: float = 55.0
const BEAM_HEIGHT: float = 1200.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var beam: Sprite2D = $Beam
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_start_bob_animation()
	_set_appearance_by_type()

func _set_appearance_by_type() -> void:
	if not sprite:
		return
	match type:
		"code":
			var code_tex = load("res://assets/powerups/powerup_code.png")
			if code_tex:
				sprite.texture = code_tex
			sprite.modulate = Color(1.0, 1.0, 1.0)
			sprite.scale = Vector2(0.5, 0.5)
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
			_create_beam()
			_expand_collision()

func _create_beam() -> void:
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/beam.gdshader")
	shader_mat.set_shader_parameter("beam_color", Color(1.0, 0.85, 0.2, 1.0))
	shader_mat.set_shader_parameter("alpha_scale", 0.3)
	_beam_material = shader_mat

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	beam.texture = ImageTexture.create_from_image(img)
	beam.material = shader_mat
	beam.scale = Vector2(BEAM_WIDTH, BEAM_HEIGHT)
	beam.show()

func _expand_collision() -> void:
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(BEAM_WIDTH, BEAM_HEIGHT)
	collision_shape.shape = rect_shape

func _process(_delta: float) -> void:
	if type != "key" or not _beam_material:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_beam_material.set_shader_parameter("time_value", t)

func _start_bob_animation() -> void:
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(self, "position:y", position.y - 6, 0.6).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(self, "position:y", position.y + 6, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if body.has_method("apply_powerup"):
		is_collected = true

		if bob_tween:
			bob_tween.kill()

		body.apply_powerup(type, duration)

		if type == "key" and is_instance_valid(beam):
			beam.hide()

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
