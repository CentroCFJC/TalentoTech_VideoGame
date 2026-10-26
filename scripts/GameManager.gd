extends Node

## GameManager — Autoload singleton managing game state and score for infinite runner.

# Signals
signal state_changed(new_state: State)
signal score_changed(score: int)
signal visible_score_changed(score: int)
signal visible_best_score_changed(score: int)
signal score_reward_earned(amount: int)
signal keys_changed(count: int)
signal bugs_eliminated_changed(count: int)
signal servers_secured_changed(count: int)
signal falls_prevented_changed(count: int)
signal powerups_acquired_changed(count: int)
signal max_stacks_changed(value: int)

# Game states
enum State { TITLE, PLAYING, DEAD, GAME_OVER }
var current_state: State = State.TITLE

# Internal distance score: drives key-chunk spawn and video progression.
# NOT shown to the player.
var score: int = 0
var is_new_record: bool = false

# Visible score: derived from per-run counters and actions.
var visible_score: int = 0
const BUG_POINTS: int = 10
const SERVER_POINTS: int = 50
const FALL_POINTS: int = 60
const POWERUP_POINTS: int = 1
const KEY_POINTS: int = 200

# Best visible scores per difficulty (keys: DifficultyManager.Level values).
var best_scores_by_difficulty: Dictionary = {
	DifficultyManager.Level.EASY: 0,
	DifficultyManager.Level.MEDIUM: 0,
	DifficultyManager.Level.HARD: 0,
}

# Persistent save path for visible high scores per difficulty.
const VISIBLE_SAVE_PATH: String = "user://visible_highscores.save"

# Death cause — set before DEAD state is emitted so HUD can read it
var death_cause: String = ""

# Key collection progress (max 6)
var keys_collected: int = 0

# Background series rotation (cycles 1 → 2 → 3 → 1 each session)
var bg_series: int = 3

# Per-run statistics
var bugs_eliminated: int = 0
var servers_secured: int = 0
var falls_prevented: int = 0
var powerups_acquired: int = 0

# Power-up stack system
const POWERUP_TYPES := ["cloud", "code", "cpu"]
var max_stacks_per_powerup: int = 3
var _powerup_stacks: Dictionary = {}

# High score file path
# Delay entre el SFX de inicio y la transicion a PLAYING (segundos)
const START_SFX_DELAY: float = 0.6
# Guard para evitar re-entrada en start_game/restart_game durante el delay
var _is_transitioning: bool = false

func _ready() -> void:
	current_state = State.TITLE
	_load_best_scores()
	_init_powerup_stacks()
	if DifficultyManager:
		DifficultyManager.difficulty_selected.connect(_on_difficulty_selected)
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
	visible_score = 0
	is_new_record = false
	death_cause = ""
	keys_collected = 0
	bugs_eliminated = 0
	servers_secured = 0
	falls_prevented = 0
	powerups_acquired = 0
	ResetAllStacks()
	# Reinicia la configuracion de dificultad para esta nueva partida; el
	# selector de dificultad volvera a aparecer una unica vez al inicio.
	if DifficultyManager:
		DifficultyManager.reset()
	keys_changed.emit(keys_collected)
	score_changed.emit(score)
	visible_score_changed.emit(visible_score)
	bugs_eliminated_changed.emit(bugs_eliminated)
	servers_secured_changed.emit(servers_secured)
	falls_prevented_changed.emit(falls_prevented)
	powerups_acquired_changed.emit(powerups_acquired)
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

	# Save best visible score if this run set a new record during gameplay.
	if is_new_record:
		_save_best_scores()

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
	visible_score = 0
	is_new_record = false
	death_cause = ""
	keys_collected = 0
	bugs_eliminated = 0
	servers_secured = 0
	falls_prevented = 0
	powerups_acquired = 0
	ResetAllStacks()
	if DifficultyManager:
		DifficultyManager.reset()
	keys_changed.emit(keys_collected)
	score_changed.emit(score)
	visible_score_changed.emit(visible_score)
	bugs_eliminated_changed.emit(bugs_eliminated)
	servers_secured_changed.emit(servers_secured)
	falls_prevented_changed.emit(falls_prevented)
	powerups_acquired_changed.emit(powerups_acquired)
	current_state = State.PLAYING
	state_changed.emit(current_state)
	_is_transitioning = false

## Increment per-run bug elimination counter (Programación skill)
func add_bug_eliminated() -> void:
	if current_state != State.PLAYING:
		return
	bugs_eliminated += 1
	bugs_eliminated_changed.emit(bugs_eliminated)
	score_reward_earned.emit(BUG_POINTS)
	_update_visible_score()

## Increment per-run server secured counter (Ciberseguridad skill)
func add_server_secured() -> void:
	if current_state != State.PLAYING:
		return
	servers_secured += 1
	servers_secured_changed.emit(servers_secured)
	score_reward_earned.emit(SERVER_POINTS)
	_update_visible_score()

## Increment per-run fall prevention counter (Arquitectura en la nube skill)
func add_fall_prevented() -> void:
	if current_state != State.PLAYING:
		return
	falls_prevented += 1
	falls_prevented_changed.emit(falls_prevented)
	score_reward_earned.emit(FALL_POINTS)
	_update_visible_score()

## Register acquisition of any power-up for the visible score.
func add_powerup_acquired() -> void:
	if current_state != State.PLAYING:
		return
	powerups_acquired += 1
	powerups_acquired_changed.emit(powerups_acquired)
	score_reward_earned.emit(POWERUP_POINTS)
	_update_visible_score()

## Register acquisition of a key for the visible score.
## Does NOT affect internal key-chunk/video progression logic.
func add_key_collected() -> void:
	if current_state != State.PLAYING:
		return
	score_reward_earned.emit(KEY_POINTS)
	_update_visible_score()

## Recalculates the visible score from the existing per-run counters.
## Also updates the per-difficulty best record live when the current score
## surpasses the stored value.
func _update_visible_score() -> void:
	visible_score = (bugs_eliminated * BUG_POINTS) \
		+ (servers_secured * SERVER_POINTS) \
		+ (falls_prevented * FALL_POINTS) \
		+ (powerups_acquired * POWERUP_POINTS) \
		+ (keys_collected * KEY_POINTS)
	visible_score_changed.emit(visible_score)

	var current_difficulty: int = DifficultyManager.current_difficulty
	if current_difficulty != 0:
		var current_best: int = best_scores_by_difficulty.get(current_difficulty, 0)
		if visible_score > current_best:
			best_scores_by_difficulty[current_difficulty] = visible_score
			is_new_record = true
			visible_best_score_changed.emit(visible_score)

## Called when a difficulty is selected mid-run: the current visible score
## immediately becomes the record for that difficulty if it is higher.
func _on_difficulty_selected(level: int) -> void:
	if level == 0:
		return
	var current_best: int = best_scores_by_difficulty.get(level, 0)
	if visible_score > current_best:
		best_scores_by_difficulty[level] = visible_score
		is_new_record = true
		visible_best_score_changed.emit(visible_score)

## Current visible score; useful for HUD and game-over checks.
func get_visible_score() -> int:
	return visible_score

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

## Save best visible scores per difficulty to file.
func _save_best_scores() -> void:
	var file := FileAccess.open(VISIBLE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(best_scores_by_difficulty)

## Load best visible scores per difficulty from file.
func _load_best_scores() -> void:
	if FileAccess.file_exists(VISIBLE_SAVE_PATH):
		var file := FileAccess.open(VISIBLE_SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				best_scores_by_difficulty = data
