extends ParallaxBackground

@onready var _sprite: Sprite2D = $Layer/Sprite

const BG_PATHS: Array[String] = [
	"res://assets/background/fondo_1.png",
	"res://assets/background/fondo_2.jpg",
	"res://assets/background/fondo_3.jpg",
	"res://assets/background/fondo_4.png"
]

var _bg_textures: Array[Texture2D] = []

func _ready() -> void:
	for path in BG_PATHS:
		var tex := load(path) as Texture2D
		if tex:
			_bg_textures.append(tex)

	if _bg_textures.is_empty():
		return

	GameManager.state_changed.connect(_on_state_changed)
	if GameManager.current_state == GameManager.State.PLAYING:
		_pick_random_background()

func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		return
	_pick_random_background()

func _pick_random_background() -> void:
	if _bg_textures.is_empty():
		return
	_sprite.texture = _bg_textures[randi() % _bg_textures.size()]
	_apply_viewport_scale()

func _apply_viewport_scale() -> void:
	var tex: Texture2D = _sprite.texture
	if not tex:
		return
	var tex_size := tex.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return
	var viewport_w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1280.0)
	var viewport_h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 720.0)
	var s: float = maxf(viewport_w / tex_size.x, viewport_h / tex_size.y)
	_sprite.scale = Vector2(s, s)
