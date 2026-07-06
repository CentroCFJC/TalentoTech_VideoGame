extends Node

## DifficultyManager — Sistema centralizado de configuracion de dificultades.
##
## Almacena la configuracion de cada nivel de dificultad en un unico lugar para
## que cualquier sistema del juego pueda consultarla de forma agnostica.
##
## La arquitectura se basa en un Dictionary por nivel, de modo que anyadir
## nuevos parametros en el futuro (frecuencia de enemigos, probabilidad de bugs
## voladores, multiplicadores de puntuacion, etc.) NO requiere modificar el
## selector de dificultad ni los consumidores: basta con anyadir una clave aqui
## y leerla donde se necesite.
##
## El selector de dificultad (patron de nivel) lo unico que hace es llamar a
## `set_difficulty(level)` mediante un evento. Este sistema central es el
## responsable de aplicar los parametros a los sistemas dependientes (GameManager,
## Player, futuros spawners, etc.).

signal difficulty_changed(level: int)
signal difficulty_selected(level: int)

# Tres niveles unicos de dificultad, de menor a mayor.
enum Level { EASY = 1, MEDIUM = 2, HARD = 3 }

# Velocidad inicial del jugador ANTES de cruzar el selector de dificultad.
# Es mas baja que cualquier velocidad de dificultad para que el jugador tenga
# tiempo de leer las zonas y decidir; al cruzar el selector se acelera
# automaticamente hasta la velocidad unica de la dificultad elegida.
const PRE_SELECTION_SPEED: float = 240.0

# Configuracion centralizada y extensible.
# Cada entrada es un Dictionary; anyadir claves aqui no rompe consumidores.
#
# IMPORTANTE: cada dificultad define UNA sola velocidad de juego (`speed`) que
# se mantiene constante durante toda la sesion. No hay velocidad inicial/final
# ni incremento progresivo por distancia — la velocidad solo cambia al cruzar
# el selector de dificultad.
const DIFFICULTY_CONFIGS: Dictionary = {
	Level.EASY: {
		"label":                  "Nivel 1",
		# Velocidad unica de la sesion para esta dificultad.
		"speed":                  300.0,
		# Maximo de stacks por power-up.
		"max_stacks_per_powerup": 3,
	},
	Level.MEDIUM: {
		"label":                  "Nivel 2",
		"speed":                  360.0,
		"max_stacks_per_powerup": 2,
	},
	Level.HARD: {
		"label":                  "Nivel 3",
		"speed":                  420.0,
		"max_stacks_per_powerup": 1,
	},
}

# Configuracion por defecto (sin dificultad seleccionada). Usa la velocidad
# pre-selector baja; el jugador acelera a la velocidad de la dificultad al
# cruzar la barrera.
const DEFAULT_CONFIG: Dictionary = {
	"label":                  "",
	"speed":                  PRE_SELECTION_SPEED,
	"max_stacks_per_powerup": 3,
}

# Configuracion activa (Dictionary). Se actualiza al seleccionar dificultad.
# Antes de la seleccion contiene la configuracion por defecto.
var current_config: Dictionary = DEFAULT_CONFIG.duplicate()

# Nivel de dificultad actual (1, 2 o 3). 0 = sin seleccionar (usa default).
var current_difficulty: int = 0

# True cuando la seleccion ya fue realizada en esta partida. Evita que el
# selector u otros sistemas re-apliquen dificultad varias veces.
var is_locked: bool = false

func _ready() -> void:
	reset()

## Reinicia el estado para una nueva partida. Llamado por GameManager al iniciar.
func reset() -> void:
	is_locked = false
	current_difficulty = 0
	current_config = DEFAULT_CONFIG.duplicate()
	# Aplica la config default en los sistemas dependientes para que siempre
	# arranquen con valores coherentes (velocidad pre-selector y stacks).
	_apply_to_systems()

## Aplica la dificultad seleccionada. Solo ejecutable una vez por partida.
## El resto del juego debe llamar a este metodo (no modificar current_config
## directamente) para garantizar que los sistemas dependientes se actualicen.
func set_difficulty(level: int) -> void:
	if is_locked:
		return
	if not DIFFICULTY_CONFIGS.has(level):
		push_warning("DifficultyManager: nivel de dificultad invalido: %d" % level)
		return
	current_difficulty = level
	current_config = DIFFICULTY_CONFIGS[level].duplicate()
	is_locked = true
	_apply_to_systems()
	difficulty_changed.emit(level)
	difficulty_selected.emit(level)

## Acceso por clave desde cualquier sistema. Devuelve default si la clave no
## existe, lo que hace que anyadir parametros nuevos no rompa consumidores viejos.
func get_config(key: String, default: Variant = null) -> Variant:
	if current_config.has(key):
		return current_config[key]
	return default

## Atajos tipados para los parametros mas usados (evitan casts repetidos).
## `get_speed()` devuelve la velocidad unica target de la sesion: la velocidad
## pre-selector bajita mientras no se haya seleccionado dificultad, o la
## velocidad fija de la dificultad elegida en caso contrario.
func get_speed() -> float:
	return float(get_config("speed", PRE_SELECTION_SPEED))

func get_max_stacks_per_powerup() -> int:
	return int(get_config("max_stacks_per_powerup", 3))

## Aplica los parametros a los sistemas dependientes de forma centralizada.
## El selector NO toca GameManager / Player directamente; lo hace este metodo.
func _apply_to_systems() -> void:
	if GameManager:
		GameManager.SetMaxStacks(get_max_stacks_per_powerup())
	# La velocidad la lee Player dinamicamente via get_speed() y acelera hacia
	# ese valor, por lo que no hace falta ningun setter adicional aqui.