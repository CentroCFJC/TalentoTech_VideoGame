extends Node

## GameManager — Autoload singleton managing game state and score for infinite runner.

# Signals
signal state_changed(new_state: State)
signal score_changed(score: int)
signal keys_changed(count: int)
signal bugs_eliminated_changed(count: int)
signal servers_secured_changed(count: int)
signal max_stacks_changed(value: int)

# Game states
enum State { TITLE, PLAYING, DEAD, GAME_OVER }
var current_state: State = State.TITLE

# Score
var score: int = 0
var best_score: int = 0
var is_new_record: bool = false

# Death cause — set before DEAD state is emitted so HUD can read it
var death_cause: String = ""

# Key collection progress (max 6)
var keys_collected: int = 0

# Background series rotation (cycles 1 → 2 → 3 → 1 each session)
var bg_series: int = 3

# Per-run statistics
var bugs_eliminated: int = 0
var servers_secured: int = 0

# Power-up stack system
const POWERUP_TYPES := ["code", "cpu"]
var max_stacks_per_powerup: int = 3
var _powerup_stacks: Dictionary = {}

# High score file path
const SAVE_PATH: String = "user://highscore.save"
# Delay entre el SFX de inicio y la transicion a PLAYING (segundos)
const START_SFX_DELAY: float = 0.6
# Guard para evitar re-entrada en start_game/restart_game durante el delay
var _is_transitioning: bool = false

func _ready() -> void:
	current_state = State.TITLE
	_load_best_score()
	_init_powerup_stacks()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _init_powerup_stacks() -> void:
	for type in POWERUP_TYPES:
		_powerup_stacks[type] = 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if _on_primary_action_pressed():
			get_viewport().set_input_as_handled()

## Entrada táctil (solo móvil): el tap ejecuta la misma acción que el botón físico.
func _input(event: InputEvent) -> void:
	if not OS.has_feature("mobile"):
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		_on_primary_action_pressed()
		Input.action_press("jump")
	else:
		Input.action_release("jump")

func _on_primary_action_pressed() -> bool:
	match current_state:
		State.TITLE:
			if not _is_transitioning:
				start_game()
				return true
		State.GAME_OVER:
			if not _is_transitioning:
				restart_game()
				return true
	return false

## Start a new game from title screen
func start_game() -> void:
	_is_transitioning = true
	# Asegurar que el HUD siga mostrando el titulo durante el delay
	current_state = State.TITLE
	SFXManager.play("lolo_s-start-474092")
	await get_tree().create_timer(START_SFX_DELAY).timeout
	bg_series = bg_series % 3 + 1
	score = 0
	is_new_record = false
	death_cause = ""
	keys_collected = 0
	bugs_eliminated = 0
	servers_secured = 0
	ResetAllStacks()
	# Reinicia la configuracion de dificultad para esta nueva partida; el
	# selector de dificultad volvera a aparecer una unica vez al inicio.
	if DifficultyManager:
		DifficultyManager.reset()
	keys_changed.emit(keys_collected)
	score_changed.emit(score)
	bugs_eliminated_changed.emit(bugs_eliminated)
	servers_secured_changed.emit(servers_secured)
	current_state = State.PLAYING
	state_changed.emit(current_state)
	_is_transitioning = false

## Called every frame by player to update score based on distance
func update_score_from_distance(player_x: float) -> void:
	if current_state != State.PLAYING:
		return
	var new_score: int = int(player_x / 10.0)
	if new_score > score:
		score = new_score
		score_changed.emit(score)

## Called when the player dies — cause is "bug", "fall", or ""
func on_player_death(cause: String = "") -> void:
	if current_state != State.PLAYING:
		return
	print("[GameManager] on_player_death causa=", cause)
	death_cause = cause
	current_state = State.DEAD
	state_changed.emit(current_state)

	# Esperar a que termine la animacion de muerte antes de pasar al game over.
	# Las muertes por caida no reproducen la animacion, asi que usamos un delay fijo.
	if cause != "fall":
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.sprite and is_instance_valid(player.sprite):
			var sf = player.sprite.sprite_frames
			if sf and sf.has_animation("death") and sf.get_animation_speed("death") > 0.0:
				var frames_count: int = sf.get_frame_count("death")
				var death_fps: float = sf.get_animation_speed("death")
				var death_duration: float = float(frames_count) / death_fps + 0.1
				await get_tree().create_timer(death_duration).timeout
			else:
				await get_tree().create_timer(2.0).timeout
		else:
			await get_tree().create_timer(2.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	# Update best score
	is_new_record = score > best_score
	if is_new_record:
		best_score = score
		_save_best_score()

	print("[GameManager] Transición a GAME_OVER")
	current_state = State.GAME_OVER
	state_changed.emit(current_state)

## Restart the game
func restart_game() -> void:
	_is_transitioning = true
	# Mantener el estado GAME_OVER durante el delay para que el HUD siga
	# mostrando el panel de game over sin ningun tipo de transicion.
	SFXManager.play("lolo_s-start-474092")
	await get_tree().create_timer(START_SFX_DELAY).timeout
	bg_series = bg_series % 3 + 1
	score = 0
	is_new_record = false
	death_cause = ""
	keys_collected = 0
	bugs_eliminated = 0
	servers_secured = 0
	ResetAllStacks()
	if DifficultyManager:
		DifficultyManager.reset()
	keys_changed.emit(keys_collected)
	score_changed.emit(score)
	bugs_eliminated_changed.emit(bugs_eliminated)
	servers_secured_changed.emit(servers_secured)
	current_state = State.PLAYING
	state_changed.emit(current_state)
	_is_transitioning = false

## Increment per-run bug elimination counter (Programación skill)
func add_bug_eliminated() -> void:
	if current_state != State.PLAYING:
		return
	bugs_eliminated += 1
	bugs_eliminated_changed.emit(bugs_eliminated)

## Increment per-run server secured counter (Ciberseguridad skill)
func add_server_secured() -> void:
	if current_state != State.PLAYING:
		return
	servers_secured += 1
	servers_secured_changed.emit(servers_secured)

# ── Power-Up Stack System ──────────────────────────────────────

func AddStack(type: String) -> void:
	if not _powerup_stacks.has(type):
		return
	if _powerup_stacks[type] < max_stacks_per_powerup:
		_powerup_stacks[type] += 1

func ConsumeStack(type: String) -> bool:
	if not _powerup_stacks.has(type):
		return false
	if _powerup_stacks[type] > 0:
		_powerup_stacks[type] -= 1
		return true
	return false

func GetStackCount(type: String) -> int:
	return _powerup_stacks.get(type, 0)

func ResetAllStacks() -> void:
	for type in POWERUP_TYPES:
		_powerup_stacks[type] = 0

func SetMaxStacks(value: int) -> void:
	max_stacks_per_powerup = max(value, 1)
	max_stacks_changed.emit(max_stacks_per_powerup)

## Save best score to file
func _save_best_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(best_score)

## Load best score from file
func _load_best_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			best_score = file.get_32()
