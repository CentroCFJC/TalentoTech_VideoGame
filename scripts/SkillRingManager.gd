extends Node2D

## SkillRingManager — Gestiona los aros de habilidad del personaje.
## Cada habilidad tiene dos mitades sprite (back y front) que se renderizan
## detrás y delante del personaje respectivamente.

const SkillRing := preload("res://scripts/SkillRing.gd")

const RING_Y_OFFSET: float = 6.0

func _ready() -> void:
	_create_rings()

func _create_rings() -> void:
	_make_ring("CodeBack", "green", "back", -1)
	_make_ring("CodeFront", "green", "front", 1)
	_make_ring("CpuBack", "blue", "back", -1)
	_make_ring("CpuFront", "blue", "front", 1)

func _make_ring(name: String, prefix: String, half: String, z: int) -> SkillRing:
	var ring := SkillRing.new()
	ring.name = name
	ring.color_prefix = prefix
	ring.half = half
	ring.position.y = RING_Y_OFFSET
	ring.z_index = z
	ring.z_as_relative = true
	add_child(ring)
	return ring

func set_code_stacks(stacks: int) -> void:
	for child in get_children():
		var ring: SkillRing = child as SkillRing
		if ring and "Code" in ring.name:
			ring.set_stacks(stacks)

func set_cpu_stacks(stacks: int) -> void:
	for child in get_children():
		var ring: SkillRing = child as SkillRing
		if ring and "Cpu" in ring.name:
			ring.set_stacks(stacks)
