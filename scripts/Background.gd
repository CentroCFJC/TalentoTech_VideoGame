extends ParallaxBackground

signal background_transition_finished

@onready var _sprite: Sprite2D = $Layer/Sprite

const BG_PATH_TEMPLATE: String = "res://assets/background/fondo_%d_%d.png"
const MAX_LEVEL: int = 6
const MIN_SERIES: int = 1
const MAX_SERIES: int = 3

# Configurable transition parameters (editable in the inspector).
@export var transition_duration: float = 1.2
@export var transition_blink_count: int = 3

var _current_series: int = -1
var _current_level: int = -1
var _pending_series: int = -1
var _pending_level: int = -1

var _transition_tween: Tween = null

func _ready() -> void:
	# The transition must run even when the game is paused.
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("background")

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
	# The background no longer changes instantly on key pickup. The new
	# background is queued and applied after the reward video finishes or is
	# minimized, via play_background_transition().
	request_background_change(GameManager.bg_series, count)

## Stores the next background to be applied during the post-video transition.
func request_background_change(series: int, level: int) -> void:
	series = clamp(series, MIN_SERIES, MAX_SERIES)
	level = clamp(level, 0, MAX_LEVEL)
	_pending_series = series
	_pending_level = level

## Plays a brief blink transition alternating between the current background
## and the pending one, ending on the pending (new) background. Emits
## background_transition_finished when done. Configurable via the exported
## transition_duration and transition_blink_count inspector properties.
func play_background_transition() -> void:
	if _pending_series == -1 or _pending_level == -1:
		background_transition_finished.emit()
		return

	if _transition_tween:
		_transition_tween.kill()

	var old_series: int = _current_series
	var old_level: int = _current_level
	var new_series: int = _pending_series
	var new_level: int = _pending_level

	# Nothing to transition if it would be the same background.
	if old_series == new_series and old_level == new_level:
		_pending_series = -1
		_pending_level = -1
		background_transition_finished.emit()
		return

	_transition_tween = create_tween()
	_transition_tween.set_parallel(false)

	var step_time: float = transition_duration / float(transition_blink_count * 2)
	for i in range(transition_blink_count * 2):
		var show_new: bool = (i % 2) == 1
		var series: int = new_series if show_new else old_series
		var level: int = new_level if show_new else old_level
		_transition_tween.tween_callback(func(): _set_background(series, level))
		_transition_tween.tween_interval(step_time)

	_transition_tween.tween_callback(func(): _finalize_transition())

func _finalize_transition() -> void:
	_pending_series = -1
	_pending_level = -1
	background_transition_finished.emit()

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
