extends Node2D

## CloudReserveManager — Nubes acumuladas orbitando alrededor de la cintura de Rocket.
## Efecto visual exclusivo: sin colisiones, sin fisica y sin afectar gameplay.
## Trayectoria eliptica: izquierda -> frente -> derecha -> detras -> izquierda.

const CLOUD_TEXTURE_PATH: String = "res://assets/clouds/cloud.png"
const MAX_CLOUDS: int = 3
const CLOUD_SCALE: float = 0.08

# Orbita eliptica alrededor de la cintura (coordenadas locales respecto al Player).
const ORBIT_RADIUS_X: float = 26.0
const ORBIT_RADIUS_Y: float = 8.0
const WAIST_Y_OFFSET: float = 10.0
const ORBIT_SPEED: float = 2.5  # radianes/segundo
const Z_DEPTH_SCALE: int = 5

var _cloud_sprites: Array[Sprite2D] = []
var _cloud_angles: Array[float] = []
var _player: CharacterBody2D = null
var _last_count: int = 0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_cloud_angles.resize(MAX_CLOUDS)
	_preload_clouds()

func _preload_clouds() -> void:
	var texture := load(CLOUD_TEXTURE_PATH) as Texture2D
	if not texture:
		push_error("CloudReserveManager: No se pudo cargar assets/clouds/cloud.png")
		return

	for i in range(MAX_CLOUDS):
		var sprite := Sprite2D.new()
		sprite.name = "CloudReserve%d" % i
		sprite.texture = texture
		sprite.scale = Vector2(CLOUD_SCALE, CLOUD_SCALE)
		sprite.visible = false
		sprite.modulate = Color.WHITE
		add_child(sprite)
		_cloud_sprites.append(sprite)

func _process(delta: float) -> void:
	if not _player:
		return
	for i in range(MAX_CLOUDS):
		if not _cloud_sprites[i].visible:
			continue
		_cloud_angles[i] -= ORBIT_SPEED * delta
		var angle := _cloud_angles[i]
		_cloud_sprites[i].position = Vector2(
			ORBIT_RADIUS_X * cos(angle),
			WAIST_Y_OFFSET + ORBIT_RADIUS_Y * sin(angle)
		)
		# Profundidad gradual: sin(angle) > 0 -> frente (y positiva, mas abajo);
		# sin(angle) < 0 -> detras (y negativa, mas arriba).
		_cloud_sprites[i].z_index = int(sin(angle) * Z_DEPTH_SCALE)

func set_cloud_count(count: int) -> void:
	count = clampi(count, 0, MAX_CLOUDS)
	var count_changed := count != _last_count
	_last_count = count

	for i in range(MAX_CLOUDS):
		_cloud_sprites[i].visible = i < count

	if count_changed and count > 0:
		# Distribuir uniformemente las nubes visibles a lo largo de la orbita.
		# La nube principal comienza en la izquierda (angle = PI) para moverse
		# inicialmente hacia la derecha pasando por delante.
		for i in range(count):
			_cloud_angles[i] = PI + float(i) * TAU / float(count)
