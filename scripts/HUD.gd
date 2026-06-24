extends CanvasLayer

## HUD — Modern gameplay HUD with three top panels: progress, keys, skillups.

# Title screen
@onready var title_panel: Control = $TitlePanel

# Game Over screen
@onready var gameover_panel: CenterContainer = $GameOverPanel
@onready var gameover_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var gameover_score_label: Label = $GameOverPanel/VBoxContainer/ScoreResultLabel
@onready var gameover_best_label: Label = $GameOverPanel/VBoxContainer/BestResultLabel
@onready var gameover_record_label: Label = $GameOverPanel/VBoxContainer/NewRecordLabel
@onready var gameover_prompt: Label = $GameOverPanel/VBoxContainer/RestartPromptLabel

# Top panels (built dynamically)
var _progress_panel: PanelContainer = null
var _key_panel: PanelContainer = null
var _skillup_panel: PanelContainer = null
var _logo_panel: PanelContainer = null
var _logo: TextureRect = null

var _title_prompt: Label = null
var _title_breath_tween: Tween = null

var _gameover_timer: Timer = null

var _mono_font: SystemFont

# Progress panel row values
var _progress_score_value: Label = null
var _progress_best_value: Label = null
var _progress_bugs_value: Label = null
var _progress_servers_value: Label = null

# SkillUp rows
var _skillup_code_icon: TextureRect = null
var _skillup_code_name: Label = null
var _skillup_code_bar: ColorRect = null
var _skillup_cpu_icon: TextureRect = null
var _skillup_cpu_name: Label = null
var _skillup_cpu_bar: ColorRect = null

# Key progress panel
const KEY_SLOT_COUNT: int = 6
const KEY_ICON_PATH: String = "res://assets/powerups/powerup_key.png"
var _key_slots: Array[TextureRect] = []

# Game Over — contextual cause block
var _cause_box: Control = null
var gameover_vbox: VBoxContainer = null

# Video playback
var _video_panel: PanelContainer = null
var _video_player: VideoStreamPlayer = null
var _skip_panel: PanelContainer = null
var _skip_label: Label = null
var _skip_tween: Tween = null
var _can_skip_video: bool = false

# Asset paths for HUD icons
const ICON_SCORE: String = "res://assets/powerups/score.png"
const ICON_BUG: String = "res://assets/bug/bug_1.png"
const ICON_SERVER: String = "res://assets/server/server_red.png"
const ICON_CODE: String = "res://assets/powerups/powerup_code.png"
const ICON_CPU: String = "res://assets/powerups/powerup_cpu.png"
const ICON_LOGO: String = "res://assets/logos/logo.png"

class StatRow:
	var row: HBoxContainer
	var value_label: Label

class SkillUpRow:
	var row: VBoxContainer
	var icon: TextureRect
	var name_label: Label
	var bar: ColorRect

func _ready() -> void:
	_setup_mono_font()

	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.keys_changed.connect(_on_keys_changed)
	GameManager.bugs_eliminated_changed.connect(set_bugs_eliminated)
	GameManager.servers_secured_changed.connect(set_servers_secured)

	_setup_progress_panel()
	_setup_key_panel()
	_setup_skillup_panel()
	_setup_logo()
	_setup_title_prompt()
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

# ── Panel visibility per game state ───────────────────────────

func _show_title_screen() -> void:
	title_panel.visible = true
	gameover_panel.visible = false
	if _progress_panel:
		_progress_panel.hide()
	if _key_panel:
		_key_panel.hide()
	if _skillup_panel:
		_skillup_panel.hide()
	if _logo_panel:
		_logo_panel.hide()
	if _video_panel:
		_video_panel.hide()
	_skip_panel.hide()

	if _title_prompt:
		_title_prompt.show()
		_start_title_breath()
	_kill_gameover_timer()

func _show_playing_hud() -> void:
	title_panel.visible = false
	gameover_panel.visible = false
	_kill_gameover_timer()
	_stop_title_breath()
	if _progress_panel:
		_progress_panel.show()
	if _key_panel:
		_key_panel.show()
		update_key_panel(GameManager.keys_collected)
	if _skillup_panel:
		_skillup_panel.show()
	if _logo_panel:
		_logo_panel.show()
	if _video_panel:
		_video_panel.hide()
	_skip_panel.hide()

	_update_score(GameManager.score)
	if _progress_best_value:
		_progress_best_value.text = "%d" % GameManager.best_score
	set_bugs_eliminated(GameManager.bugs_eliminated)
	set_servers_secured(GameManager.servers_secured)
	_connect_player_signal()

func _show_game_over() -> void:
	title_panel.visible = false
	gameover_panel.visible = true
	if _progress_panel:
		_progress_panel.hide()
	if _key_panel:
		_key_panel.hide()
	if _skillup_panel:
		_skillup_panel.hide()
	if _logo_panel:
		_logo_panel.show()
	_skip_panel.hide()

	gameover_score_label.text = "Puntuación: %d" % GameManager.score
	gameover_best_label.text = "Récord: %d" % GameManager.best_score

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

	if _gameover_timer:
		_gameover_timer.queue_free()
	_gameover_timer = Timer.new()
	_gameover_timer.one_shot = true
	_gameover_timer.wait_time = 60.0
	_gameover_timer.timeout.connect(_on_gameover_timeout)
	add_child(_gameover_timer)
	_gameover_timer.start()

func _on_gameover_timeout() -> void:
	if GameManager.current_state != GameManager.State.GAME_OVER:
		return
	GameManager.current_state = GameManager.State.TITLE
	get_tree().reload_current_scene()

func _kill_gameover_timer() -> void:
	if _gameover_timer:
		_gameover_timer.queue_free()
		_gameover_timer = null

func _update_score(amount: int) -> void:
	if _progress_score_value:
		_progress_score_value.text = "%d" % amount

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

# ── Shared styling helpers ────────────────────────────────────

func _create_hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.16, 0.9)
	style.border_color = Color(0.35, 0.60, 0.95, 0.8)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left   = 12
	style.content_margin_top    = 10
	style.content_margin_right  = 12
	style.content_margin_bottom = 10
	style.anti_aliasing = true
	return style

func _create_title_label(text: String) -> Label:
	var lbl := Label.new()
	_apply_mono(lbl)
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	return lbl

func _create_icon_texture(path: String, size: Vector2, modulate: Color = Color.WHITE) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = modulate
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	return icon

func _setup_mono_font() -> void:
	_mono_font = SystemFont.new()
	_mono_font.font_names = PackedStringArray(["Courier New", "monospace", "Consolas", "Menlo"])
	_mono_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_mono_font.generate_mipmaps = true

	for label in [gameover_label, gameover_score_label, gameover_best_label, gameover_record_label, gameover_prompt]:
		if label:
			label.add_theme_font_override("font", _mono_font)

func _apply_mono(label: Label) -> void:
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)

# ── Progress panel — top-left ─────────────────────────────────

func _setup_progress_panel() -> void:
	_progress_panel = PanelContainer.new()
	_progress_panel.name = "ProgressPanel"
	_progress_panel.hide()
	add_child(_progress_panel)

	_progress_panel.add_theme_stylebox_override("panel", _create_hud_panel_style())
	_progress_panel.anchors_preset = Control.PRESET_TOP_LEFT
	_progress_panel.offset_left   = 10
	_progress_panel.offset_top    = 10
	_progress_panel.offset_right  = 270
	_progress_panel.offset_bottom = 200

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_progress_panel.add_child(vbox)

	vbox.add_child(_create_title_label("PROGRESO DE LA PARTIDA"))

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.60, 0.95, 0.5))
	vbox.add_child(sep)

	var score_row := _create_stat_row("PUNTUACIÓN", ICON_SCORE, Color(1.0, 0.85, 0.2))
	_progress_score_value = score_row.value_label
	vbox.add_child(score_row.row)

	var best_row := _create_stat_row("RÉCORD", ICON_SCORE, Color(1.0, 0.85, 0.2))
	_progress_best_value = best_row.value_label
	vbox.add_child(best_row.row)

	var bugs_row := _create_stat_row("BUGS ELIMINADOS", ICON_BUG, Color(0.4, 1.0, 0.6))
	_progress_bugs_value = bugs_row.value_label
	vbox.add_child(bugs_row.row)

	var servers_row := _create_stat_row("SERVIDORES ASEGURADOS", ICON_SERVER, Color(0.55, 0.85, 1.0))
	_progress_servers_value = servers_row.value_label
	vbox.add_child(servers_row.row)

func _create_stat_row(name_text: String, icon_path: String, icon_color: Color) -> StatRow:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := _create_icon_texture(icon_path, Vector2(24, 24), icon_color)
	row.add_child(icon)

	var name_label := Label.new()
	_apply_mono(name_label)
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0, 1.0))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value := Label.new()
	_apply_mono(value)
	value.text = "0"
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)

	var result := StatRow.new()
	result.row = row
	result.value_label = value
	return result

func set_bugs_eliminated(value: int) -> void:
	if _progress_bugs_value:
		_progress_bugs_value.text = "%d" % value

func set_servers_secured(value: int) -> void:
	if _progress_servers_value:
		_progress_servers_value.text = "%d" % value

# ── Key panel — top-center ────────────────────────────────────

func _setup_key_panel() -> void:
	_key_panel = PanelContainer.new()
	_key_panel.name = "KeyPanel"
	_key_panel.hide()
	add_child(_key_panel)

	_key_panel.add_theme_stylebox_override("panel", _create_hud_panel_style())
	_key_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_key_panel.offset_left  = -120
	_key_panel.offset_top   = 10
	_key_panel.offset_right = 120
	_key_panel.offset_bottom = 56

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_key_panel.add_child(hbox)

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

func update_key_panel(count: int) -> void:
	count = clampi(count, 0, KEY_SLOT_COUNT)
	for i in range(KEY_SLOT_COUNT):
		if i < count:
			_key_slots[i].modulate = Color.WHITE
		else:
			_key_slots[i].modulate = Color(0.15, 0.15, 0.2, 0.55)

func _on_keys_changed(count: int) -> void:
	update_key_panel(count)

# ── SkillUp panel — top-right ─────────────────────────────────

func _setup_skillup_panel() -> void:
	_skillup_panel = $PowerUpPanel
	if not _skillup_panel:
		return

	for child in _skillup_panel.get_children():
		child.queue_free()

	_skillup_panel.add_theme_stylebox_override("panel", _create_hud_panel_style())
	_skillup_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_skillup_panel.offset_left  = -240
	_skillup_panel.offset_top   = 10
	_skillup_panel.offset_right = -10
	_skillup_panel.offset_bottom = 150
	_skillup_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_skillup_panel.modulate = Color.WHITE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_skillup_panel.add_child(vbox)

	vbox.add_child(_create_title_label("HABILIDADES"))

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.60, 0.95, 0.5))
	vbox.add_child(sep)

	var code_row := _create_skillup_row("PROGRAMACIÓN", ICON_CODE, Color(0.2, 0.85, 0.5))
	_skillup_code_icon = code_row.icon
	_skillup_code_name = code_row.name_label
	_skillup_code_bar = code_row.bar
	vbox.add_child(code_row.row)

	var cpu_row := _create_skillup_row("CIBERSEGURIDAD", ICON_CPU, Color(0.7, 0.45, 1.0))
	_skillup_cpu_icon = cpu_row.icon
	_skillup_cpu_name = cpu_row.name_label
	_skillup_cpu_bar = cpu_row.bar
	vbox.add_child(cpu_row.row)

func _create_skillup_row(name_text: String, icon_path: String, accent: Color) -> SkillUpRow:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(header)

	var icon := _create_icon_texture(icon_path, Vector2(32, 32), Color(0.08, 0.08, 0.1))
	header.add_child(icon)

	var name_label := Label.new()
	_apply_mono(name_label)
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 4)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_bg.color = Color(0.15, 0.18, 0.28, 1.0)
	bar_container.add_child(bar_bg)

	var bar := ColorRect.new()
	bar.name = "SkillUpBarFill"
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.color = accent.darkened(0.7)
	bar.modulate.a = 0.35
	bar_container.add_child(bar)

	var result := SkillUpRow.new()
	result.row = row
	result.icon = icon
	result.name_label = name_label
	result.bar = bar
	return result

func _on_powerup_changed(type: String, active: bool) -> void:
	var icon: TextureRect
	var name_label: Label
	var bar: ColorRect
	var accent: Color
	match type:
		"code":
			icon = _skillup_code_icon
			name_label = _skillup_code_name
			bar = _skillup_code_bar
			accent = Color(0.2, 0.85, 0.5)
		"cpu":
			icon = _skillup_cpu_icon
			name_label = _skillup_cpu_name
			bar = _skillup_cpu_bar
			accent = Color(0.7, 0.45, 1.0)
		_:
			return

	if active:
		if icon:
			icon.modulate = Color.WHITE
		if name_label:
			name_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
		if bar:
			bar.color = accent
			bar.modulate.a = 1.0
	else:
		if icon:
			icon.modulate = Color(0.08, 0.08, 0.1, 1.0)
		if name_label:
			name_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3, 1.0))
		if bar:
			bar.color = accent.darkened(0.7)
			bar.modulate.a = 0.35

# ── Logo — bottom-left ────────────────────────────────────────

func _setup_logo() -> void:
	_logo = TextureRect.new()
	_logo.name = "LogoWatermark"
	_logo.custom_minimum_size = Vector2(120, 60)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(ICON_LOGO):
		_logo.texture = load(ICON_LOGO)

	_logo_panel = PanelContainer.new()
	_logo_panel.name = "LogoPanel"
	_logo_panel.hide()
	_logo_panel.z_index = 10
	_logo_panel.add_theme_stylebox_override("panel", _create_hud_panel_style())
	_logo_panel.anchor_left   = 0.0
	_logo_panel.anchor_top    = 1.0
	_logo_panel.anchor_right  = 0.0
	_logo_panel.anchor_bottom = 1.0
	_logo_panel.offset_left   = 10
	_logo_panel.offset_top    = -80
	_logo_panel.offset_right  = 154
	_logo_panel.offset_bottom = -10
	_logo_panel.add_child(_logo)
	add_child(_logo_panel)

# ── Title screen prompt ───────────────────────────────────────

func _setup_title_prompt() -> void:
	_title_prompt = Label.new()
	_apply_mono(_title_prompt)
	_title_prompt.text = "PRESIONA EL BOTÓN PARA INICIAR"
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_prompt.add_theme_font_size_override("font_size", 32)
	_title_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_prompt.add_theme_constant_override("outline_size", 4)

	_title_prompt.anchor_left   = 0.5
	_title_prompt.anchor_right  = 0.5
	_title_prompt.anchor_top    = 0.0
	_title_prompt.anchor_bottom = 0.0
	_title_prompt.offset_left   = -350
	_title_prompt.offset_top    = 210
	_title_prompt.offset_right  = 350
	_title_prompt.offset_bottom = 255

	title_panel.add_child(_title_prompt)

func _start_title_breath() -> void:
	if not _title_prompt or not _title_prompt.visible:
		return
	_title_prompt.pivot_offset = _title_prompt.size * 0.5
	_title_breath_tween = create_tween().set_loops()
	_title_breath_tween.tween_property(_title_prompt, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_breath_tween.tween_property(_title_prompt, "scale", Vector2(0.95, 0.95), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_title_breath() -> void:
	if _title_breath_tween:
		_title_breath_tween.kill()
		_title_breath_tween = null

# ── Video panel (full-screen) ─────────────────────────────────

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
	_apply_mono(_skip_label)
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

	if _logo_panel and is_instance_valid(_logo_panel):
		_logo_panel.hide()
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

	if _logo_panel and is_instance_valid(_logo_panel):
		_logo_panel.show()
	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.show()
		update_key_panel(GameManager.keys_collected)

func _set_music_video_duck(active: bool) -> void:
	var music = get_tree().get_first_node_in_group("music")
	if music and music.has_method("set_video_reduction"):
		music.set_video_reduction(active)

# ── Game Over cause block ─────────────────────────────────────

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
			detail    = "Consigue la habilidad: Programación para\nprotegerte de los bugs."
			img_paths = ["res://assets/bug/bug_1.png",
						 "res://assets/powerups/powerup_code.png"]
		"fall":
			headline  = "Rocket no vio el abismo..."
			detail    = "¡Usa el doble salto para\ncruzar los vacíos!"
			img_paths = []
		"server":
			headline  = "¡Un servidor vulnerable bloqueó tu camino!"
			detail    = "Consigue la habilidad: Ciberseguridad para\ndetectar y corregir vulnerabilidades."
			img_paths = ["res://assets/server/server_red.png",
						 "res://assets/powerups/powerup_cpu.png"]
		_:
			return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var sep := HSeparator.new()
	box.add_child(sep)

	var lbl_head := Label.new()
	_apply_mono(lbl_head)
	lbl_head.text = headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_size_override("font_size", 19)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lbl_head)

	var lbl_detail := Label.new()
	_apply_mono(lbl_detail)
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
