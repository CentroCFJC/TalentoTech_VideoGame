extends AudioStreamPlayer

@export var game_music: AudioStream
@export var splash_music: AudioStream

var _base_volume_db: float
var _current_state: GameManager.State

var _is_video_playing: bool = false
var _is_fading: bool = false
var _fade_timer: float = 0.0
var _fade_duration: float = 2.0
var _fade_start_linear: float = 0.0
var _fade_end_linear: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_volume_db = volume_db
	_current_state = GameManager.current_state
	finished.connect(play)
	GameManager.state_changed.connect(_on_state_changed)
	add_to_group("music")
	_apply_stream_for_state(_current_state)
	_apply_volume()
	# Iniciar reproduccion segun el estado inicial (la escena trae autoplay=false)
	if _current_state == GameManager.State.PLAYING or _current_state == GameManager.State.TITLE:
		play(0.0)

func _on_state_changed(state: GameManager.State) -> void:
	var old_state = _current_state
	_current_state = state

	if state == GameManager.State.GAME_OVER:
		# Sin musica en la pantalla de game over
		stop()
		_is_fading = false
		return

	if state == GameManager.State.DEAD and GameManager.death_cause != "fall":
		# Muerte por bug/servidor: detener la musica de inmediato
		stop()
		_is_fading = false
		return

	if state == GameManager.State.PLAYING and old_state != GameManager.State.PLAYING:
		_apply_stream_for_state(state)
		play(0.0)
		_is_fading = false
		_apply_volume()
		return

	# DEAD por caida: la musica sigue sonando brevemente hasta el game over.

func _apply_stream_for_state(state: GameManager.State) -> void:
	var target: AudioStream = game_music
	if state == GameManager.State.TITLE:
		target = splash_music
	if stream != target:
		var was_playing: bool = playing
		stop()
		stream = target
		if was_playing:
			play(0.0)

func _process(delta: float) -> void:
	if _is_fading:
		_fade_timer += delta
		if _fade_timer >= _fade_duration:
			_is_fading = false
			volume_db = _base_volume_db + linear_to_db(_fade_end_linear)
		else:
			var current_linear = lerp(_fade_start_linear, _fade_end_linear, _fade_timer / _fade_duration)
			current_linear = max(0.0001, current_linear)
			volume_db = _base_volume_db + linear_to_db(current_linear)

func set_video_reduction(active: bool) -> void:
	_is_video_playing = active
	_is_fading = false
	if active:
		stream_paused = true
	else:
		stream_paused = false
		_apply_volume()

func fade_out_video_reduction(duration: float = 2.0) -> void:
	_is_video_playing = false
	stream_paused = false
	
	var target_linear := _get_target_linear()
	
	_fade_start_linear = 0.0001
	_fade_end_linear = target_linear
	volume_db = _base_volume_db + linear_to_db(_fade_start_linear)
	_fade_duration = duration
	_fade_timer = 0.0
	_is_fading = true

func _apply_volume() -> void:
	if _is_fading:
		return
		
	if _is_video_playing:
		stream_paused = true
		return
	else:
		stream_paused = false
	
	var target_linear := _get_target_linear()
	volume_db = _base_volume_db + linear_to_db(target_linear)

func _get_target_linear() -> float:
	if _current_state == GameManager.State.TITLE:
		return 0.7
	return 1.0
