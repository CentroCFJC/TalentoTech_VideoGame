extends ParallaxBackground

@onready var _sprite: Sprite2D = $Layer/Sprite

var _bg_antioquia: Texture2D
var _bg_caldas: Texture2D

func _ready() -> void:
	_bg_antioquia = load("res://assets/background/antioquia.jpeg")
	_bg_caldas = load("res://assets/background/caldas.jpeg")
	_update_background(0)
	GameManager.score_changed.connect(_on_score_changed)
	_apply_viewport_scale()

func _on_score_changed(score: int) -> void:
	_update_background(score)

func _update_background(score: int) -> void:
	var use_caldas: bool = (score / 1000) % 2 == 1
	_sprite.texture = _bg_caldas if use_caldas else _bg_antioquia

func _apply_viewport_scale() -> void:
	var tex: Texture2D = _sprite.texture
	if not tex:
		return
	var tex_w: float = tex.get_size().x
	if tex_w == 0:
		return
	var viewport_w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1280.0)
	_sprite.scale = Vector2(viewport_w / tex_w, viewport_w / tex_w)
