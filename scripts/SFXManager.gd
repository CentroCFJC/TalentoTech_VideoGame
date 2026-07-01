extends Node

## SFXManager — Gestor centralizado de efectos de sonido.
## Carga automaticamente todos los audios de assets/audio/fx/ al inicio
## y los reproduce bajo demanda mediante un pool de AudioStreamPlayer para
## permitir la reproduccion simultanea de varios efectos sin interrumpirse
## entre si ni interferir con la musica de fondo (manejada por MusicPlayer).

const FX_FOLDER: String = "res://assets/audio/fx/"
const POOL_SIZE: int = 8
const VALID_EXTENSIONS: Array[String] = [".mp3", ".wav", ".ogg", ".opus"]
const VOLUME_DB: float = -12.0

# nombre (basename lowercase) -> AudioStream
var _streams: Dictionary = {}
# indice de prefijo -> array de nombres (para play_random)
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fx()
	_build_pool()

func _load_fx() -> void:
	var dir := DirAccess.open(FX_FOLDER)
	if not dir:
		push_warning("SFXManager: no se pudo abrir la carpeta de efectos: " + FX_FOLDER)
		return
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var lower := file.to_lower()
			var ok_ext := false
			for ext in VALID_EXTENSIONS:
				if lower.ends_with(ext):
					ok_ext = true
					break
			if ok_ext:
				var path := FX_FOLDER + file
				if ResourceLoader.exists(path):
					var stream := load(path)
					if stream is AudioStream:
						_streams[file.get_basename().to_lower()] = stream
		file = dir.get_next()
	dir.list_dir_end()

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

## Reproduce un efecto por nombre (basename sin extension, case-insensitive).
## Si el efecto no existe, emite un warning y no hace nada.
func play(name: String) -> void:
	var key := name.to_lower()
	if not _streams.has(key):
		push_warning("SFXManager: efecto no encontrado: " + name)
		return
	_play_stream(_streams[key])

## Reproduce un efecto aleatorio entre todos los cargados cuyo nombre
## comienza con el prefijo dado (case-insensitive). Si no hay coincidencias,
## no hace nada.
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