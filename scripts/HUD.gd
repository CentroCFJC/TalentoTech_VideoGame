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

# PowerUp notification
@onready var powerup_panel: PanelContainer = $PowerUpPanel
@onready var powerup_name_label: Label = $PowerUpPanel/VBoxContainer/PowerUpNameLabel
@onready var powerup_msg_label: Label = $PowerUpPanel/VBoxContainer/PowerUpMsgLabel
@onready var powerup_timer_label: Label = $PowerUpPanel/VBoxContainer/PowerUpTimerLabel

var powerup_hide_tween: Tween = null

# Game Over — contextual cause block
var _cause_box: Control = null
var gameover_vbox: VBoxContainer = null

# PowerUp custom nodes
var powerup_icon_rect: TextureRect = null
var powerup_pulse_tween: Tween = null

func _ready() -> void:
	# Connect to GameManager signals
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	
	# Hide powerup panel initially
	if powerup_panel:
		powerup_panel.modulate.a = 0.0
		_setup_powerup_panel()

	# Connect to player powerup signal once in PLAYING
	_try_connect_player()
	
	# Set up the Game Over card container dynamically
	gameover_vbox = $GameOverPanel/VBoxContainer
	_setup_game_over_card()

	# Override prompt texts to use "El Botón"
	if title_prompt:
		title_prompt.text = "▶ Presiona El Botón para jugar"
	if gameover_prompt:
		gameover_prompt.text = "▶ Presiona El Botón para reiniciar"
	
	# Initialize based on current GameManager state
	_on_state_changed(GameManager.current_state)

func _try_connect_player() -> void:
	# The player may not be ready yet; defer until next frame
	call_deferred("_connect_player_signal")

func _connect_player_signal() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_signal("powerup_changed") and not p.powerup_changed.is_connected(_on_powerup_changed):
			p.powerup_changed.connect(_on_powerup_changed)

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
	
	# Connect player signal (player is now in tree)
	_connect_player_signal()

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
	
	# Build cause-specific block
	_build_death_cause_ui()
	
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

# ── PowerUp HUD ────────────────────────────────────────────────

func _on_powerup_changed(type: String, time_left: float) -> void:
	if not powerup_panel:
		return

	if type == "":
		_stop_powerup_animation()
		# Powerup expired — fade out panel
		if powerup_hide_tween:
			powerup_hide_tween.kill()
		powerup_hide_tween = create_tween()
		powerup_hide_tween.tween_property(powerup_panel, "modulate:a", 0.0, 0.4)
		return

	# Show / update panel
	match type:
		"code":
			if powerup_icon_rect:
				powerup_icon_rect.texture = load("res://assets/powerups/powerup_code.png")
			powerup_msg_label.text = "SkillUp: Programación: Puedes eliminar bugs!"
			powerup_timer_label.text = "%.1f s" % maxf(time_left, 0.0)

	# Fade in if not already visible
	if powerup_panel.modulate.a < 0.9:
		_start_powerup_animation()
		if powerup_hide_tween:
			powerup_hide_tween.kill()
		var tween := create_tween()
		tween.tween_property(powerup_panel, "modulate:a", 1.0, 0.3)
	else:
		# Just update timer while active
		powerup_timer_label.text = "%.1f s" % maxf(time_left, 0.0)

	# Flash warning when low time
	if time_left <= 3.0 and time_left > 0.0:
		powerup_timer_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		powerup_timer_label.modulate = Color(0.4, 1.0, 0.6)

# ── Game Over cause block ───────────────────────────────────────

## Builds (or rebuilds) the contextual death-cause section inside the Game Over panel.
func _build_death_cause_ui() -> void:
	# Remove previous cause block if it exists
	if _cause_box and is_instance_valid(_cause_box):
		_cause_box.queue_free()
		_cause_box = null
	
	var cause := GameManager.death_cause
	var vbox: VBoxContainer = gameover_vbox
	
	# ── Per-cause content ──────────────────────────────────────
	var headline  := ""
	var detail    := ""
	var img_paths : Array[String] = []
	
	match cause:
		"bug":
			headline  = "Rocket cayó víctima de un bug."
			detail    = "Con el SkillUp: Programación\npodrás derrotarlo."
			img_paths = ["res://assets/bug/bug_1.png",
						 "res://assets/powerups/powerup_code.png"]
		"fall":
			headline  = "Rocket no vio el abismo..."
			detail    = "¡Usa el doble salto para\ncruzar los vacíos!"
			img_paths = []
		_:
			# Unknown cause — no extra block
			return
	
	# ── Build the container ────────────────────────────────────
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	
	# Separator line
	var sep := HSeparator.new()
	box.add_child(sep)
	
	# Headline label
	var lbl_head := Label.new()
	lbl_head.text = headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_size_override("font_size", 19)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl_head)
	
	# Detail label
	var lbl_detail := Label.new()
	lbl_detail.text = detail
	lbl_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_detail.add_theme_font_size_override("font_size", 16)
	lbl_detail.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	lbl_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl_detail)
	
	# Image row (if any)
	if img_paths.size() > 0:
		var img_row := HBoxContainer.new()
		img_row.alignment = BoxContainer.ALIGNMENT_CENTER
		img_row.add_theme_constant_override("separation", 18)
		for path in img_paths:
			if ResourceLoader.exists(path):
				img_row.add_child(_make_circle_icon(path, 52))
		box.add_child(img_row)
	
	_cause_box = box
	vbox.add_child(box)
	# Place the block just before the restart prompt
	vbox.move_child(box, gameover_prompt.get_index())

## Creates a small circular icon (Panel + TextureRect) for the cause block.
func _make_circle_icon(img_path: String, size: int) -> Panel:
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(size, size)
	
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.08, 0.14, 0.88)
	style.border_color = Color(0.55, 0.85, 1.0, 0.95)
	style.set_border_width_all(2)
	var r: int = int(size / 2.0)
	style.corner_radius_top_left     = r
	style.corner_radius_top_right    = r
	style.corner_radius_bottom_left  = r
	style.corner_radius_bottom_right = r
	style.anti_aliasing = true
	circle.add_theme_stylebox_override("panel", style)
	
	var tex_rect := TextureRect.new()
	tex_rect.texture       = load(img_path)
	tex_rect.anchor_left   = 0.0; tex_rect.anchor_top    = 0.0
	tex_rect.anchor_right  = 1.0; tex_rect.anchor_bottom = 1.0
	tex_rect.offset_left   =  6;  tex_rect.offset_top    =  6
	tex_rect.offset_right  = -6;  tex_rect.offset_bottom = -6
	tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	circle.add_child(tex_rect)
	return circle

## Wraps the Game Over content in a stylized semi-transparent card panel.
func _setup_game_over_card() -> void:
	if not gameover_panel or not gameover_vbox:
		return
	
	gameover_panel.remove_child(gameover_vbox)
	
	var card := PanelContainer.new()
	card.name = "GameOverCard"
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.85)      # Opacity 85%, dark slate blue
	style.border_color = Color(0.35, 0.60, 0.95, 0.80)  # Bright blue border
	style.set_border_width_all(3)
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.anti_aliasing = true
	
	# Padding inside the card
	style.content_margin_left   = 32
	style.content_margin_top    = 28
	style.content_margin_right  = 32
	style.content_margin_bottom = 28
	
	card.add_theme_stylebox_override("panel", style)
	card.add_child(gameover_vbox)
	gameover_panel.add_child(card)

## Constructs and positions the custom PowerUp notification panel on the left under the score counters.
func _setup_powerup_panel() -> void:
	if not powerup_panel:
		return
	
	# Clear default children
	for child in powerup_panel.get_children():
		child.queue_free()
	
	# Card design styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.85)      # Opacity 85%, dark blue
	style.border_color = Color(0.40, 1.00, 0.60, 0.80)  # Green border
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left   = 14
	style.content_margin_top    = 10
	style.content_margin_right  = 16
	style.content_margin_bottom = 10
	style.anti_aliasing = true
	powerup_panel.add_theme_stylebox_override("panel", style)
	
	# Reposition panel on the left under the score (Y ~ 70)
	powerup_panel.anchors_preset = Control.PRESET_TOP_LEFT
	powerup_panel.anchor_left   = 0.0
	powerup_panel.anchor_top    = 0.0
	powerup_panel.anchor_right   = 0.0
	powerup_panel.anchor_bottom  = 0.0
	powerup_panel.offset_left   = 20.0
	powerup_panel.offset_top    = 70.0
	powerup_panel.offset_right   = 460.0
	powerup_panel.offset_bottom  = 150.0
	powerup_panel.grow_horizontal = Control.GROW_DIRECTION_END
	powerup_panel.grow_vertical   = Control.GROW_DIRECTION_END
	
	# Horizontal layout inside panel
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 16)
	
	# Column 1 (Left): Icon (centered in helper Control) + Timer
	var col_left := VBoxContainer.new()
	col_left.alignment = BoxContainer.ALIGNMENT_CENTER
	col_left.add_theme_constant_override("separation", 4)
	
	var icon_container := Control.new()
	icon_container.custom_minimum_size = Vector2(48, 48)
	
	powerup_icon_rect = TextureRect.new()
	powerup_icon_rect.custom_minimum_size = Vector2(48, 48)
	powerup_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	powerup_icon_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	powerup_icon_rect.pivot_offset = Vector2(24, 24)
	icon_container.add_child(powerup_icon_rect)
	col_left.add_child(icon_container)
	
	powerup_timer_label = Label.new()
	powerup_timer_label.text = "10.0 s"
	powerup_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powerup_timer_label.add_theme_font_size_override("font_size", 14)
	powerup_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	col_left.add_child(powerup_timer_label)
	
	hbox.add_child(col_left)
	
	# Column 2 (Right): Detailed message text
	powerup_msg_label = Label.new()
	powerup_msg_label.add_theme_font_size_override("font_size", 15)
	powerup_msg_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	powerup_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	powerup_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	powerup_msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(powerup_msg_label)
	
	# Dummy name label to avoid null references in other parts of HUD code
	powerup_name_label = Label.new()
	
	powerup_panel.add_child(hbox)

## Starts the scale up/down looping animation on the powerup icon.
func _start_powerup_animation() -> void:
	if not powerup_icon_rect:
		return
	_stop_powerup_animation()
	
	powerup_icon_rect.scale = Vector2.ONE
	powerup_pulse_tween = create_tween().set_loops()
	powerup_pulse_tween.tween_property(powerup_icon_rect, "scale", Vector2(1.2, 1.2), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	powerup_pulse_tween.tween_property(powerup_icon_rect, "scale", Vector2(0.85, 0.85), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Stops the icon scaling animation and resets scale to default.
func _stop_powerup_animation() -> void:
	if powerup_pulse_tween:
		powerup_pulse_tween.kill()
		powerup_pulse_tween = null
	if powerup_icon_rect:
		powerup_icon_rect.scale = Vector2.ONE
