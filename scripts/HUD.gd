extends CanvasLayer

## HUD — Displays score, best score, title screen, and game over screen.

# Game UI (visible during PLAYING)
@onready var score_label: Label = $MarginContainer/HBoxContainer/ScoreLabel
@onready var best_label: Label = $MarginContainer/HBoxContainer/BestLabel

# Title screen
@onready var title_panel: Control = $TitlePanel

# Game Over screen
@onready var gameover_panel: CenterContainer = $GameOverPanel
@onready var gameover_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var gameover_score_label: Label = $GameOverPanel/VBoxContainer/ScoreResultLabel
@onready var gameover_best_label: Label = $GameOverPanel/VBoxContainer/BestResultLabel
@onready var gameover_record_label: Label = $GameOverPanel/VBoxContainer/NewRecordLabel
@onready var gameover_prompt: Label = $GameOverPanel/VBoxContainer/RestartPromptLabel

# PowerUp notification
@onready var powerup_panel: PanelContainer = $PowerUpPanel

# Best score + logo panel (built dynamically)
var _best_panel: PanelContainer = null

# Game Over — contextual cause block
var _cause_box: Control = null
var gameover_vbox: VBoxContainer = null

# PowerUp slot nodes (built dynamically in _setup_powerup_panel)
var _panel_score_label: Label = null
var _panel_best_label: Label = null
var _slot_code_icon: TextureRect = null
var _slot_cpu_icon: TextureRect = null
var _slot_code_status: Label = null
var _slot_cpu_status: Label = null

# Key progress panel
const KEY_SLOT_COUNT: int = 6
const KEY_ICON_PATH: String = "res://assets/powerups/powerup_key.png"

var _key_panel: PanelContainer = null
var _key_slots: Array[TextureRect] = []

# Video playback
var _video_panel: PanelContainer = null
var _video_player: VideoStreamPlayer = null
var _skip_panel: PanelContainer = null
var _skip_label: Label = null
var _skip_tween: Tween = null
var _can_skip_video: bool = false

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.keys_changed.connect(_on_keys_changed)

	# Hide old top bar — score/best live inside PowerUpPanel now
	$MarginContainer.hide()

	_setup_powerup_panel()
	_setup_best_panel()
	_setup_key_panel()
	_setup_video_panel()
	_try_connect_player()

	process_mode = PROCESS_MODE_ALWAYS

	gameover_vbox = $GameOverPanel/VBoxContainer
	_setup_game_over_card()

	if gameover_prompt:
		gameover_prompt.text = "▶ Presiona El Botón para reiniciar"

	_on_state_changed(GameManager.current_state)

func _try_connect_player() -> void:
	call_deferred("_connect_player_signal")

func _connect_player_signal() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_signal("powerup_changed") and not p.powerup_changed.is_connected(_on_powerup_changed):
			p.powerup_changed.connect(_on_powerup_changed)
		if p.has_signal("video_key_collected") and not p.video_key_collected.is_connected(_on_video_key_collected):
			p.video_key_collected.connect(_on_video_key_collected)

func _show_title_screen() -> void:
	title_panel.visible = true
	gameover_panel.visible = false
	score_label.visible = false
	best_label.visible = false
	powerup_panel.hide()
	if _best_panel:
		_best_panel.hide()
	if _key_panel:
		_key_panel.hide()
	if _video_panel:
		_video_panel.hide()
	_skip_panel.hide()

func _show_playing_hud() -> void:
	title_panel.visible = false
	gameover_panel.visible = false
	score_label.visible = false
	best_label.visible = false
	powerup_panel.show()
	if _best_panel:
		_best_panel.show()
	if _key_panel:
		_key_panel.show()
		update_key_panel(GameManager.keys_collected)
	if _video_panel:
		_video_panel.hide()
	_skip_panel.hide()

	_update_score(GameManager.score)
	if _panel_best_label:
		_panel_best_label.text = "Best: %d" % GameManager.best_score
	_connect_player_signal()

func _show_game_over() -> void:
	title_panel.visible = false
	gameover_panel.visible = true
	score_label.visible = true
	best_label.visible = true
	powerup_panel.hide()
	if _best_panel:
		_best_panel.hide()
	if _key_panel:
		_key_panel.hide()
	_skip_panel.hide()

	gameover_score_label.text = "Score: %d" % GameManager.score
	gameover_best_label.text = "Best: %d" % GameManager.best_score

	if GameManager.score >= GameManager.best_score and GameManager.score > 0:
		gameover_record_label.text = "¡NUEVO RECORD!"
		gameover_record_label.visible = true
	else:
		gameover_record_label.visible = false

	_build_death_cause_ui()

	gameover_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(gameover_panel, "modulate:a", 1.0, 0.5)
	_start_blink(gameover_prompt)

func _update_score(amount: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % amount
	if _panel_score_label:
		_panel_score_label.text = "Score: %d" % amount

func _on_score_changed(score: int) -> void:
	_update_score(score)

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.TITLE:
			_show_title_screen()
		GameManager.State.PLAYING:
			_show_playing_hud()
		GameManager.State.DEAD:
			pass
		GameManager.State.GAME_OVER:
			_show_game_over()

func _start_blink(label: Label) -> void:
	if not label:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

# ── Video panel (full-screen, replaces best panel) ────────────

func _setup_video_panel() -> void:
	_video_panel = PanelContainer.new()
	_video_panel.name = "VideoPanel"
	_video_panel.hide()
	add_child(_video_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.set_border_width_all(0)
	_video_panel.add_theme_stylebox_override("panel", style)

	_video_panel.anchors_preset = Control.PRESET_FULL_RECT
	_video_panel.offset_left  = 60
	_video_panel.offset_top   = 60
	_video_panel.offset_right = -60
	_video_panel.offset_bottom = -60

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "KeyVideoPlayer"
	_video_player.autoplay = false
	_video_player.expand = true
	_video_player.process_mode = PROCESS_MODE_ALWAYS
	_video_panel.add_child(_video_player)

	_setup_skip_label()

func _setup_skip_label() -> void:
	_skip_panel = PanelContainer.new()
	_skip_panel.name = "SkipPanel"
	
	_skip_panel.anchor_top = 1.0
	_skip_panel.anchor_bottom = 1.0
	_skip_panel.anchor_left = 0.0
	_skip_panel.anchor_right = 1.0
	
	_skip_panel.offset_left = 60
	_skip_panel.offset_right = -60
	_skip_panel.offset_top = -55
	_skip_panel.offset_bottom = -5
	
	_skip_panel.z_index = 100
	_skip_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_skip_panel.hide()
	add_child(_skip_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	_skip_panel.add_theme_stylebox_override("panel", panel_style)

	_skip_label = Label.new()
	_skip_label.text = "Presiona el botón para omitir"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_skip_label.add_theme_font_size_override("font_size", 22)
	_skip_panel.add_child(_skip_label)

func _on_video_key_collected() -> void:
	if not _video_panel or not is_instance_valid(_video_panel):
		return

	_can_skip_video = false

	var files := DirAccess.get_files_at("res://assets/videos/")
	var ogv_files: Array[String] = []
	for f in files:
		if f.ends_with(".ogv"):
			ogv_files.append("res://assets/videos/" + f)

	if ogv_files.is_empty():
		return

	_video_player.stream = load(ogv_files.pick_random())

	if _best_panel and is_instance_valid(_best_panel):
		_best_panel.hide()
	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.hide()

	_video_panel.modulate = Color(1, 1, 1, 0)
	_video_panel.show()
	var fade_tween := create_tween()
	fade_tween.tween_property(_video_panel, "modulate", Color.WHITE, 0.3)

	if _video_player.stream:
		_skip_panel.hide()
		if _skip_tween:
			_skip_tween.kill()
		
		_skip_tween = create_tween().bind_node(_skip_panel)
		_skip_tween.tween_interval(5.0)
		_skip_tween.tween_callback(func():
			_can_skip_video = true
			_skip_panel.show()
			_skip_panel.modulate.a = 1.0
			_skip_tween = create_tween().bind_node(_skip_panel).set_loops()
			_skip_tween.tween_property(_skip_panel, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
			_skip_tween.tween_property(_skip_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		)
		
		_video_player.play()

	get_tree().paused = true

	if not _video_player.finished.is_connected(_close_video):
		_video_player.finished.connect(_close_video)

	_set_music_video_duck(true)

func _input(event: InputEvent) -> void:
	if _video_panel and _video_panel.visible and _can_skip_video and event.is_action_pressed("ui_accept"):
		_close_video()
		get_viewport().set_input_as_handled()

func _close_video() -> void:
	_can_skip_video = false
	get_tree().paused = false

	var music = get_tree().get_first_node_in_group("music")
	if music and music.has_method("fade_out_video_reduction"):
		music.fade_out_video_reduction()
	else:
		_set_music_video_duck(false)

	if _video_player:
		_video_player.stream = null
		if _video_player.finished.is_connected(_close_video):
			_video_player.finished.disconnect(_close_video)

	if _video_panel and is_instance_valid(_video_panel):
		_video_panel.modulate = Color.WHITE
		_video_panel.hide()

	if _skip_tween:
		_skip_tween.kill()
		_skip_tween = null
	_skip_panel.hide()

	if _best_panel and is_instance_valid(_best_panel):
		_best_panel.show()
	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.show()
		update_key_panel(GameManager.keys_collected)

func _set_music_video_duck(active: bool) -> void:
	var music = get_tree().get_first_node_in_group("music")
	if music and music.has_method("set_video_reduction"):
		music.set_video_reduction(active)

# ── PowerUp HUD — top-left box with Score + two skillup slots ──

func _on_powerup_changed(type: String, active: bool) -> void:
	var icon: TextureRect
	var status_label: Label
	match type:
		"code":
			icon = _slot_code_icon
			status_label = _slot_code_status
		"cpu":
			icon = _slot_cpu_icon
			status_label = _slot_cpu_status
		_:
			return

	if active:
		if icon:
			icon.modulate = Color.WHITE
		if status_label:
			status_label.text = "✔ Listo"
			status_label.show()
	else:
		if icon:
			icon.modulate = Color(0.25, 0.25, 0.3)
		if status_label:
			status_label.text = ""
			status_label.hide()

func _setup_powerup_panel() -> void:
	if not powerup_panel:
		return

	# Clear old children
	for child in powerup_panel.get_children():
		child.queue_free()

	# Panel style — small semi-transparent card top-left
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.16, 0.82)
	style.border_color = Color(0.35, 0.60, 0.95, 0.65)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 10
	style.content_margin_top    = 6
	style.content_margin_right  = 10
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	powerup_panel.add_theme_stylebox_override("panel", style)

	# Make fully visible (scene resets this)
	powerup_panel.modulate = Color.WHITE

	# Position top-left
	powerup_panel.anchors_preset = Control.PRESET_TOP_LEFT
	powerup_panel.offset_left  = 10
	powerup_panel.offset_top   = 10
	powerup_panel.offset_right = 280
	powerup_panel.offset_bottom = 160

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# ── Score line (bigger) ──────────────────────────────────
	_panel_score_label = Label.new()
	_panel_score_label.text = "Score: 0"
	_panel_score_label.add_theme_font_size_override("font_size", 22)
	_panel_score_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(_panel_score_label)

	# ── Thin separator ──────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.60, 0.95, 0.35))
	vbox.add_child(sep)

	# ── SkillUp slots ───────────────────────────────────────
	powerup_panel.add_child(vbox)

	_slot_code_icon = _build_slot(vbox, "code",
		"SkillUp: Programación", "res://assets/powerups/powerup_code.png")
	_slot_cpu_icon = _build_slot(vbox, "cpu",
		"SkillUp: Hardware", "res://assets/powerups/powerup_cpu.png")

func _setup_best_panel() -> void:
	_best_panel = PanelContainer.new()
	_best_panel.name = "BestPanel"
	_best_panel.hide()
	add_child(_best_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.16, 0.82)
	style.border_color = Color(0.35, 0.60, 0.95, 0.65)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 12
	style.content_margin_top    = 8
	style.content_margin_right  = 12
	style.content_margin_bottom = 8
	style.anti_aliasing = true
	_best_panel.add_theme_stylebox_override("panel", style)

	_best_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_best_panel.offset_left  = -220
	_best_panel.offset_top   = 10
	_best_panel.offset_right = -10
	_best_panel.offset_bottom = 140

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var logo := TextureRect.new()
	if ResourceLoader.exists("res://assets/logos/logo.png"):
		logo.texture = load("res://assets/logos/logo.png")
	logo.custom_minimum_size = Vector2(0, 90)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	vbox.add_child(logo)

	_panel_best_label = Label.new()
	_panel_best_label.text = "Best: %d" % GameManager.best_score
	_panel_best_label.add_theme_font_size_override("font_size", 16)
	_panel_best_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0, 1))
	_panel_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_panel_best_label)

	_best_panel.add_child(vbox)

# ── Key Progress Panel — top center ────────────────────────────

func _setup_key_panel() -> void:
	_key_panel = PanelContainer.new()
	_key_panel.name = "KeyPanel"
	_key_panel.hide()
	add_child(_key_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.16, 0.82)
	style.border_color = Color(0.35, 0.60, 0.95, 0.65)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left   = 10
	style.content_margin_top    = 6
	style.content_margin_right  = 10
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	_key_panel.add_theme_stylebox_override("panel", style)

	_key_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_key_panel.offset_left  = -110
	_key_panel.offset_top   = 10
	_key_panel.offset_right = 110
	_key_panel.offset_bottom = 48

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var key_tex: Texture2D = null
	if ResourceLoader.exists(KEY_ICON_PATH):
		key_tex = load(KEY_ICON_PATH)

	for i in range(KEY_SLOT_COUNT):
		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(28, 28)
		if key_tex:
			slot.texture = key_tex
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		slot.modulate = Color(0.15, 0.15, 0.2, 0.55)
		hbox.add_child(slot)
		_key_slots.append(slot)

	_key_panel.add_child(hbox)

func update_key_panel(count: int) -> void:
	count = clampi(count, 0, KEY_SLOT_COUNT)
	for i in range(KEY_SLOT_COUNT):
		if i < count:
			_key_slots[i].modulate = Color.WHITE
		else:
			_key_slots[i].modulate = Color(0.15, 0.15, 0.2, 0.55)

func _on_keys_changed(count: int) -> void:
	update_key_panel(count)

func _build_slot(parent: VBoxContainer, key: String, display_name: String, icon_path: String) -> TextureRect:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.modulate = Color(0.25, 0.25, 0.3)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var status_label := Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1))
	status_label.hide()
	row.add_child(status_label)

	# Store status label reference
	match key:
		"code":
			_slot_code_status = status_label
		"cpu":
			_slot_cpu_status = status_label

	parent.add_child(row)
	return icon

# ── Game Over cause block ───────────────────────────────────────

## Builds (or rebuilds) the contextual death-cause section inside the Game Over panel.
func _build_death_cause_ui() -> void:
	if _cause_box and is_instance_valid(_cause_box):
		_cause_box.queue_free()
		_cause_box = null

	var cause := GameManager.death_cause
	var vbox: VBoxContainer = gameover_vbox

	var headline  := ""
	var detail    := ""
	var img_paths : Array[String] = []

	match cause:
		"bug":
			headline  = "¡Bug crítico en el sistema!"
			detail    = "Consigue SkillUp: Programación para\nprotegerte de los bugs."
			img_paths = ["res://assets/bug/bug_1.png",
						 "res://assets/powerups/powerup_code.png"]
		"fall":
			headline  = "Rocket no vio el abismo..."
			detail    = "¡Usa el doble salto para\ncruzar los vacíos!"
			img_paths = []
		"server":
			headline  = "¡Servidor bloqueó tu camino!"
			detail    = "Consigue SkillUp: Hardware para\natravesar servidores sin daño."
			img_paths = ["res://assets/server/server_red.png",
						 "res://assets/powerups/powerup_cpu.png"]
		_:
			return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var sep := HSeparator.new()
	box.add_child(sep)

	var lbl_head := Label.new()
	lbl_head.text = headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_size_override("font_size", 19)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl_head)

	var lbl_detail := Label.new()
	lbl_detail.text = detail
	lbl_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_detail.add_theme_font_size_override("font_size", 16)
	lbl_detail.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	lbl_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl_detail)

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
	vbox.move_child(box, gameover_prompt.get_index())

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

func _setup_game_over_card() -> void:
	if not gameover_panel or not gameover_vbox:
		return

	gameover_panel.remove_child(gameover_vbox)

	var card := PanelContainer.new()
	card.name = "GameOverCard"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.85)
	style.border_color = Color(0.35, 0.60, 0.95, 0.80)
	style.set_border_width_all(3)
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.anti_aliasing = true

	style.content_margin_left   = 32
	style.content_margin_top    = 28
	style.content_margin_right  = 32
	style.content_margin_bottom = 28

	card.add_theme_stylebox_override("panel", style)
	card.add_child(gameover_vbox)
	gameover_panel.add_child(card)
