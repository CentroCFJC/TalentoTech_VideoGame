extends ParallaxBackground

@onready var _sprite: Sprite2D = $Layer/Sprite

const BG_PATH_TEMPLATE: String = "res://assets/background/fondo_%d_%d.png"
const MAX_LEVEL: int = 6
const MIN_SERIES: int = 1
const MAX_SERIES: int = 3

var _current_series: int = -1
var _current_level: int = -1

func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.keys_changed.connect(_on_keys_changed)

	if GameManager.current_state == GameManager.State.PLAYING:
		_set_background(GameManager.bg_series, GameManager.keys_collected)

func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		return
	_set_background(GameManager.bg_series, GameManager.keys_collected)

func _on_keys_changed(count: int) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
	_set_background(GameManager.bg_series, count)

func _set_background(series: int, level: int) -> void:
	series = clamp(series, MIN_SERIES, MAX_SERIES)
	level = clamp(level, 0, MAX_LEVEL)
	if series == _current_series and level == _current_level:
		return
	var path := BG_PATH_TEMPLATE % [series, level]
	var tex := load(path) as Texture2D
	if not tex:
		return
	_current_series = series
	_current_level = level
	_sprite.texture = tex
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
