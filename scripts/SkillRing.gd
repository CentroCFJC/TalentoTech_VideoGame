extends Node2D

## SkillRing — Aro de habilidad con sprites de assets/barreras/.
## Recorta la mitad superior/inferior y centra automáticamente según el
## contenido real (píxeles no transparentes) de la imagen completa,
## para que ambos halves queden correctamente alineados.

@export var color_prefix: String = "green"
@export var half: String = "back"
@export var sprite_scale: float = 0.165

const BASE_PATH: String = "res://assets/barreras/"

var _stacks: int = 0
var _sprite: Sprite2D = null
var _textures: Array[Texture2D] = []
var _ref_center_y: float = 0.0

func _ready() -> void:
	_load_textures()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)
	visible = false
	_compute_reference_y()

func _load_textures() -> void:
	_textures.resize(3)
	for i in range(3):
		var path: String = BASE_PATH + color_prefix + "-" + str(i + 1) + ".png"
		if ResourceLoader.exists(path):
			_textures[i] = load(path)

func _content_center(img: Image) -> Vector2:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = 0
	var max_y: int = 0
	var found: bool = false
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.01:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
				found = true
	if not found:
		return Vector2(w / 2.0, h / 2.0)
	return Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)

func _compute_reference_y() -> void:
	var tex: Texture2D = _textures[0]
	if not tex:
		return
	var img: Image = tex.get_image()
	if not img:
		return
	_ref_center_y = _content_center(img).y

func set_stacks(value: int) -> void:
	value = clampi(value, 0, _textures.size())
	if value == _stacks:
		return
	_stacks = value
	visible = _stacks > 0 and _sprite != null
	if _stacks > 0 and _sprite:
		_apply_texture(_stacks - 1)

func _apply_texture(idx: int) -> void:
	var tex: Texture2D = _textures[idx]
	if not tex:
		return
	var img: Image = tex.get_image()
	if not img:
		return

	var w: int = img.get_width()
	var full_h: int = img.get_height()
	var half_h: int = full_h / 2
	var region: Rect2i
	if half == "back":
		region = Rect2i(0, 0, w, half_h)
	else:
		region = Rect2i(0, half_h, w, full_h - half_h)
	var cropped: Image = img.get_region(region)
	if not cropped:
		return

	# X: centrado por nivel (cada PNG puede tener el contenido en X diferente)
	# Y: centrado por referencia del nivel 1 (consistente entre niveles)
	var cc: Vector2 = _content_center(img)
	var pos_x: float = -cc.x * sprite_scale
	var pos_y: float
	if half == "back":
		pos_y = -_ref_center_y * sprite_scale
	else:
		pos_y = (-_ref_center_y + half_h) * sprite_scale

	_sprite.position = Vector2(pos_x, pos_y)
	_sprite.texture = ImageTexture.create_from_image(cropped)
