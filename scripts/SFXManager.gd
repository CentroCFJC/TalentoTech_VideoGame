extends Node

const POOL_SIZE: int = 8
const VOLUME_DB: float = -12.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fx()
	_build_pool()

func _load_fx() -> void:
	var fx_paths: Array[String] = [
		"res://assets/audio/fx/arcade-game-achievement-bling-489759.mp3",
		"res://assets/audio/fx/coin_1.MP3",
		"res://assets/audio/fx/coin_2.MP3",
		"res://assets/audio/fx/coin_3.MP3",
		"res://assets/audio/fx/coin_4.MP3",
		"res://assets/audio/fx/coin_5.MP3",
		"res://assets/audio/fx/coin_6.MP3",
		"res://assets/audio/fx/coin_7.MP3",
		"res://assets/audio/fx/coin_8.MP3",
		"res://assets/audio/fx/correct-game-show-alert-499485.mp3",
		"res://assets/audio/fx/double_jump.mp3",
		"res://assets/audio/fx/fall down.MP3",
		"res://assets/audio/fx/game-collect-item-short-550419.mp3",
		"res://assets/audio/fx/jump.mp3",
		"res://assets/audio/fx/lolo_s-start-474092.mp3",
		"res://assets/audio/fx/SFXs 80s sound effect.MP3",
		"res://assets/audio/fx/video-game-death.mp3",
	]
	for path in fx_paths:
		var stream := load(path)
		if stream is AudioStream:
			var key := path.get_file().get_basename().to_lower()
			_streams[key] = stream
			print("[SFXManager] Cargado: ", key)

func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

func _get_player() -> AudioStreamPlayer:
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return p

func _play_stream(stream: AudioStream) -> void:
	var p := _get_player()
	p.stream = stream
	p.volume_db = VOLUME_DB
	p.stop()
	p.play(0.0)

func play(name: String) -> void:
	var key := name.to_lower()
	if not _streams.has(key):
		push_warning("SFXManager: efecto no encontrado: " + name)
		return
	_play_stream(_streams[key])

func play_random(prefix: String) -> void:
	var pre := prefix.to_lower()
	var matches: Array[String] = []
	for key in _streams.keys():
		if (key as String).begins_with(pre):
			matches.append(key as String)
	if matches.is_empty():
		push_warning("SFXManager: no hay efectos con prefijo: " + prefix)
		return
	var chosen: String = matches.pick_random()
	_play_stream(_streams[chosen])
