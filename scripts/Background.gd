extends ParallaxBackground

@onready var _sprite: Sprite2D = $Layer/Sprite

const BG_BASE_PATH: String = "res://assets/background/fondo_2_"
const MAX_LEVEL: int = 6

var _bg_textures: Array[Texture2D] = []
var _current_level: int = -1

func _ready() -> void:
	for i in range(MAX_LEVEL + 1):
		var path := BG_BASE_PATH + str(i) + ".png"
		var tex := load(path) as Texture2D
		if tex:
			_bg_textures.append(tex)

	if _bg_textures.is_empty():
		return

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.keys_changed.connect(_on_keys_changed)

	if GameManager.current_state == GameManager.State.PLAYING:
		_set_background_level(GameManager.keys_collected)

func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		return
	_set_background_level(GameManager.keys_collected)

func _on_keys_changed(count: int) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	_set_background_level(count)

func _set_background_level(level: int) -> void:
	level = clamp(level, 0, MAX_LEVEL)
	if level == _current_level:
		return
	if level < 0 or level >= _bg_textures.size():
		return
	_current_level = level
	_sprite.texture = _bg_textures[level]
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
