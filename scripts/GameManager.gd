extends Node

## GameManager — Autoload singleton managing game state and score for infinite runner.

# Signals
signal state_changed(new_state: State)
signal score_changed(score: int)

# Game states
enum State { TITLE, PLAYING, DEAD, GAME_OVER }
var current_state: State = State.TITLE

# Score
var score: int = 0
var best_score: int = 0

# Death cause — set before DEAD state is emitted so HUD can read it
var death_cause: String = ""

# High score file path
const SAVE_PATH: String = "user://highscore.save"

func _ready() -> void:
	current_state = State.TITLE
	_load_best_score()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		match current_state:
			State.TITLE:
				start_game()
			State.GAME_OVER:
				restart_game()

## Start a new game from title screen
func start_game() -> void:
	score = 0
	death_cause = ""
	score_changed.emit(score)
	current_state = State.PLAYING
	state_changed.emit(current_state)

## Called every frame by player to update score based on distance
func update_score_from_distance(player_x: float) -> void:
	if current_state != State.PLAYING:
		return
	var new_score: int = int(player_x / 10.0)
	if new_score > score:
		score = new_score
		score_changed.emit(score)

## Add bonus points directly (powerups, stomps, etc.)
func add_score(amount: int) -> void:
	if current_state != State.PLAYING:
		return
	score += amount
	score_changed.emit(score)

## Called when the player dies — cause is "bug", "fall", or ""
func on_player_death(cause: String = "") -> void:
	if current_state != State.PLAYING:
		return
	death_cause = cause
	current_state = State.DEAD
	state_changed.emit(current_state)
	
	# Transition to GAME_OVER after death animation
	await get_tree().create_timer(1.0).timeout
	
	# Update best score
	if score > best_score:
		best_score = score
		_save_best_score()
	
	current_state = State.GAME_OVER
	state_changed.emit(current_state)

## Restart the game
func restart_game() -> void:
	score = 0
	death_cause = ""
	score_changed.emit(score)
	current_state = State.PLAYING
	state_changed.emit(current_state)
	get_tree().reload_current_scene()

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
