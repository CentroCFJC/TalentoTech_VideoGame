extends Area2D

## Hazard — Damages the player on contact (spikes, kill zones, etc.)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage()
