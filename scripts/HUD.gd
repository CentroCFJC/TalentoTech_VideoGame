extends CanvasLayer

## HUD — Displays score, best score, title screen, and game over screen.

# Game UI (visible during PLAYING)
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var best_label: Label = $MarginContainer/HBoxContainer/BestLabel

# Title screen
@onready var title_panel: CenterContainer = $TitlePanel
@onready var title_label: Label = $TitlePanel/VBoxContainer/TitleLabel
@onready var title_best_label: Label = $TitlePanel/VBoxContainer/BestScoreLabel
@onready var title_prompt: Label = $TitlePanel/VBoxContainer/PromptLabel

# Game Over screen
@onready var gameover_panel: CenterContainer = $GameOverPanel
@onready var gameover_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var gameover_score_label: Label = $GameOverPanel/VBoxContainer/ScoreResultLabel
@onready var gameover_best_label: Label = $GameOverPanel/VBoxContainer/BestResultLabel
@onready var gameover_record_label: Label = $GameOverPanel/VBoxContainer/NewRecordLabel
@onready var gameover_prompt: Label = $GameOverPanel/VBoxContainer/RestartPromptLabel

func _ready() -> void:
	# Connect to GameManager signals
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	
	# Initialize based on current GameManager state
	_on_state_changed(GameManager.current_state)

func _show_title_screen() -> void:
	title_panel.visible = true
	gameover_panel.visible = false
	score_label.visible = false
	best_label.visible = false
	
	title_best_label.text = "Best Score: %d" % GameManager.best_score
	
	# Animate prompt blinking
	_start_blink(title_prompt)

func _show_playing_hud() -> void:
	title_panel.visible = false
	gameover_panel.visible = false
	score_label.visible = true
	best_label.visible = true
	
	_update_score(0)
	best_label.text = "Best: %d" % GameManager.best_score

func _show_game_over() -> void:
	title_panel.visible = false
	gameover_panel.visible = true
	score_label.visible = true
	best_label.visible = true
	
	gameover_score_label.text = "Score: %d" % GameManager.score
	gameover_best_label.text = "Best: %d" % GameManager.best_score
	
	# Check for new record
	if GameManager.score >= GameManager.best_score and GameManager.score > 0:
		gameover_record_label.text = "¡NUEVO RECORD!"
		gameover_record_label.visible = true
	else:
		gameover_record_label.visible = false
	
	# Fade in game over panel
	gameover_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(gameover_panel, "modulate:a", 1.0, 0.5)
	
	# Blink restart prompt
	_start_blink(gameover_prompt)

func _update_score(amount: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % amount

func _on_score_changed(score: int) -> void:
	_update_score(score)

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.TITLE:
			_show_title_screen()
		GameManager.State.PLAYING:
			_show_playing_hud()
		GameManager.State.DEAD:
			pass  # Keep showing score during death animation
		GameManager.State.GAME_OVER:
			_show_game_over()

func _start_blink(label: Label) -> void:
	if not label:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
