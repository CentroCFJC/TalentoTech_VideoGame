extends Area2D

const MOVE_SPEED: float = 25.0
const EDGE_RAY_LENGTH: float = 20.0
const EDGE_RAY_DOWN: float = 20.0
const WALL_RAY_LENGTH: float = 20.0

var direction: int = -1
var _sprite: AnimatedSprite2D
var _edge_ray: RayCast2D
var _wall_ray: RayCast2D

func _ready() -> void:
	for child in get_children():
		if child is AnimatedSprite2D:
			_sprite = child
			break

	_edge_ray = RayCast2D.new()
	_edge_ray.name = "EdgeRay"
	_edge_ray.enabled = true
	_edge_ray.collision_mask = 2
	_edge_ray.target_position = Vector2(direction * EDGE_RAY_LENGTH, EDGE_RAY_DOWN)
	add_child(_edge_ray)

	_wall_ray = RayCast2D.new()
	_wall_ray.name = "WallRay"
	_wall_ray.enabled = true
	_wall_ray.collision_mask = 2
	_wall_ray.target_position = Vector2(direction * WALL_RAY_LENGTH, 0)
	add_child(_wall_ray)

func _process(delta: float) -> void:
	_edge_ray.force_raycast_update()
	_wall_ray.force_raycast_update()

	if not _edge_ray.is_colliding() or _wall_ray.is_colliding():
		direction *= -1
		_edge_ray.target_position.x = direction * EDGE_RAY_LENGTH
		_wall_ray.target_position.x = direction * WALL_RAY_LENGTH
		if _sprite:
			_sprite.scale.x = -_sprite.scale.x

	global_position.x += direction * MOVE_SPEED * delta
