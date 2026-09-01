extends CanvasLayer

## HUD — Modern gameplay HUD with three top panels: progress, keys, skillups.

# Title screen
@onready var title_panel: Control = $TitlePanel

# Game Over screen
@onready var gameover_panel: Control = $GameOverPanel

# Game Over panel built from background image + dynamic labels
var _gameover_card: TextureRect = null
var _camper_cards: Array[Panel] = []
var _text_blur_shader: Shader = null
var _gameover_death_cause: Label = null
var _gameover_death_avoid: Label = null
var _gameover_death_cause_icon: TextureRect = null
var _gameover_death_detail_icon: TextureRect = null
var _gameover_restart_cta_label: Label = null

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
var _progress_title_label: Label = null
var _progress_score_value: Label = null
var _progress_best_value: Label = null
var _progress_bugs_value: Label = null
var _progress_servers_value: Label = null

# SkillUp rows — maps powerup type → SkillUpRowData
var _skillup_rows: Dictionary = {}

# Key progress panel
const KEY_SLOT_COUNT: int = 6
const KEY_ICON_PATH: String = "res://assets/powerups/powerup_key.png"
var _key_slots: Array[TextureRect] = []
var _video_paths: Array[String] = []
var _watched_videos: Array[String] = []

# Video playback
const VIDEO_FOLDER: String = "res://assets/videos/"
const THUMBNAIL_FOLDER: String = "res://assets/miniaturas/"
const LOW_QUALITY_VIDEO_SUFFIX: String = "_720p"
const VIDEO_BUFFERING_MSEC: int = 1200
var _video_panel: PanelContainer = null
var _video_player: VideoStreamPlayer = null
var _minimize_panel: PanelContainer = null
var _minimize_label: Label = null
var _minimize_tween: Tween = null
var _can_minimize_video: bool = false
var _is_pip_mode: bool = false

# Background transition state.
var _background: Node = null
var _is_transitioning: bool = false

const PIP_SIZE: Vector2 = Vector2(320, 180)
const PIP_MARGIN: Vector2 = Vector2(8, 8)

# Asset paths for HUD icons
const ICON_SCORE: String = "res://assets/powerups/score.png"
const ICON_BUG: String = "res://assets/bug/walk/frame_017.png"
const ICON_SERVER: String = "res://assets/server/server_red.png"
const ICON_CODE: String = "res://assets/powerups/powerup_code.png"
const ICON_CPU: String = "res://assets/powerups/powerup_cpu.png"
const ICON_LOGO: String = "res://assets/logos/logo.png"

const GAME_OVER_PANEL_TEXTURE: String = "res://assets/gameover/gameover_panel.png"
const GAME_OVER_PANEL_SIZE: Vector2 = Vector2(1085, 1450)

# Text placement rectangles in native panel coordinates (1085x1450)
const GAME_OVER_GRID_ORIGIN: Vector2 = Vector2(183, 370)
const GAME_OVER_CARD_SIZE: Vector2 = Vector2(350, 120)
const GAME_OVER_CARD_GAP: Vector2 = Vector2(20, 10)
const GAME_OVER_DEATH_TITLE_RECT: Rect2 = Rect2(Vector2(340, 815), Vector2(560, 140))
const GAME_OVER_DEATH_DETAIL_RECT: Rect2 = Rect2(Vector2(180, 1005), Vector2(570, 220))
const GAME_OVER_DEATH_CAUSE_ICON_RECT: Rect2 = Rect2(Vector2(210, 810), Vector2(150, 150))
const GAME_OVER_DEATH_DETAIL_ICON_RECT: Rect2 = Rect2(Vector2(750, 1050), Vector2(150, 150))
const GAME_OVER_CTA_RECT: Rect2 = Rect2(Vector2(180, 1225), Vector2(725, 150))

# Campista data: video basename → title + subtitle
const CAMPER_DATA: Array[Dictionary] = [
	{"video": "Andres-Felipe-Baja", "title": "ANDRÉS FELIPE SERNA", "subtitle": "Estudiante Ing. de Sistemas"},
	{"video": "Angela-", "title": "ANGELA MARÍA HENAO", "subtitle": "Campista y emprendedora"},
	{"video": "Familia-Tech", "title": "LA FAMILIA DOMINGUEZ", "subtitle": "Familia Campista"},
	{"video": "Jorge", "title": "JORGE LEONARDO MARÍN", "subtitle": "Ing. Industrial y Traductor"},
	{"video": "Video-La-Juanpis", "title": "LA JUANPIS", "subtitle": "Activista LGBTIQ+"},
	{"video": "Video-Sebastían-Baja", "title": "JUAN SEBASTIÁN CAMACHO", "subtitle": "Ganador Hackaton 2025 Armenia"},
]

class StatRow:
	var row: HBoxContainer
	var value_label: Label

class SkillUpRowData:
	var label: Label
	var slot_container: HBoxContainer
	var slots: Array[TextureRect]
	var icon_path: String

func _ready() -> void:
	_setup_mono_font()

	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.keys_changed.connect(_on_keys_changed)
	GameManager.bugs_eliminated_changed.connect(set_bugs_eliminated)
	GameManager.servers_secured_changed.connect(set_servers_secured)
	GameManager.max_stacks_changed.connect(_on_max_stacks_changed)

	_setup_progress_panel()
	_setup_key_panel()
	_setup_skillup_panel()
	_setup_logo()
	_setup_title_prompt()
	_setup_video_panel()
	_try_connect_player()
	_connect_background()

	process_mode = PROCESS_MODE_ALWAYS

	_setup_game_over_panel()

	_on_state_changed(GameManager.current_state)
	show()



func _try_connect_player() -> void:
	call_deferred("_connect_player_signal")

func _connect_player_signal() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_signal("powerup_changed") and not p.powerup_changed.is_connected(_on_powerup_changed):
			p.powerup_changed.connect(_on_powerup_changed)
		if p.has_signal("video_key_collected") and not p.video_key_collected.is_connected(_on_video_key_collected):
			p.video_key_collected.connect(_on_video_key_collected)

func _connect_background() -> void:
	_background = get_tree().get_first_node_in_group("background")
	if _background and _background.has_signal("background_transition_finished"):
		if not _background.background_transition_finished.is_connected(_on_background_transition_finished):
			_background.background_transition_finished.connect(_on_background_transition_finished)

# ── Panel visibility per game state ───────────────────────────

func _show_title_screen() -> void:
	if _is_pip_mode or (_video_panel and _video_panel.visible):
		_close_video_internal()

	SubtitleManager.clear_all()
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
	_minimize_panel.hide()

	if _title_prompt:
		_title_prompt.show()
		_start_title_breath()
	_kill_gameover_timer()

func _show_playing_hud() -> void:
	if _is_pip_mode or (_video_panel and _video_panel.visible):
		_close_video_internal()

	SubtitleManager.clear_all()
	_watched_videos.clear()

	title_panel.visible = false
	gameover_panel.visible = false
	_kill_gameover_timer()
	_stop_title_breath()
	if _progress_panel:
		_progress_panel.show()
		if _progress_title_label:
			_progress_title_label.text = "PROGRESO DE LA PARTIDA"
	if _key_panel:
		_key_panel.show()
		update_key_panel()
	if _skillup_panel:
		_skillup_panel.show()
		for type in GameManager.POWERUP_TYPES:
			_update_skill_row(type)
	if _logo_panel:
		_logo_panel.show()
	if _video_panel:
		_video_panel.hide()
	_minimize_panel.hide()

	_update_score(GameManager.score)
	if _progress_best_value:
		_progress_best_value.text = "%d" % GameManager.best_score
	set_bugs_eliminated(GameManager.bugs_eliminated)
	set_servers_secured(GameManager.servers_secured)
	_connect_player_signal()

func _show_game_over() -> void:
	print("[HUD] _show_game_over iniciado")
	if not gameover_panel or not is_instance_valid(gameover_panel):
		push_error("HUD: GameOverPanel no está disponible")
		return

	title_panel.visible = false
	gameover_panel.visible = true
	if _progress_panel:
		_progress_panel.show()
		if _progress_title_label:
			_progress_title_label.text = "RESULTADO DE LA PARTIDA"
	if _key_panel:
		_key_panel.hide()
	if _skillup_panel:
		_skillup_panel.hide()
	if _logo_panel:
		if not _is_pip_mode:
			_logo_panel.show()
	_minimize_panel.hide()

	print("[HUD] Actualizando tarjetas de campistas")
	# Update camper cards based on watched videos
	_update_camper_cards()

	print("[HUD] Construyendo UI de causa de muerte")
	_build_death_cause_ui()

	# Scale and center the panel card to fit the viewport
	if _gameover_card and is_instance_valid(_gameover_card):
		print("[HUD] Escalando tarjeta de game over")
		var viewport_size := get_viewport().get_visible_rect().size
		var margin := 40.0
		var available_size := viewport_size - Vector2(margin, margin)
		var card_scale := minf(available_size.x / GAME_OVER_PANEL_SIZE.x, available_size.y / GAME_OVER_PANEL_SIZE.y)
		_gameover_card.scale = Vector2(card_scale, card_scale)
		_gameover_card.position = (viewport_size - GAME_OVER_PANEL_SIZE * card_scale) * 0.5

	print("[HUD] Iniciando fade del game over")
	gameover_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(gameover_panel, "modulate:a", 1.0, 0.5)

	print("[HUD] Iniciando parpadeo del CTA")
	_start_blink(_gameover_restart_cta_label)

	if _gameover_timer:
		_gameover_timer.queue_free()
	_gameover_timer = Timer.new()
	_gameover_timer.one_shot = true
	_gameover_timer.wait_time = 60.0
	_gameover_timer.timeout.connect(_on_gameover_timeout)
	add_child(_gameover_timer)
	_gameover_timer.start()
	print("[HUD] _show_game_over completado")

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

func _create_icon_texture(path: String, container_size: Vector2, icon_size: Vector2, modulate: Color = Color.WHITE, texture_offset: Vector2 = Vector2.ZERO) -> Control:
	var container := Control.new()
	container.custom_minimum_size = container_size
	container.size = container_size
	container.clip_contents = true

	var icon := TextureRect.new()
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = modulate
	if ResourceLoader.exists(path):
		icon.texture = load(path)

	icon.position = (container_size - icon_size) * 0.5 + texture_offset
	container.add_child(icon)
	return container

func _setup_mono_font() -> void:
	_mono_font = SystemFont.new()
	_mono_font.font_names = PackedStringArray(["Courier New", "monospace", "Consolas", "Menlo"])
	_mono_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_mono_font.generate_mipmaps = true

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
	_progress_panel.offset_bottom = 190

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_progress_panel.add_child(vbox)

	_progress_title_label = _create_title_label("PROGRESO DE LA PARTIDA")
	vbox.add_child(_progress_title_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.60, 0.95, 0.5))
	vbox.add_child(sep)

	var score_row := _create_stat_row("PUNTUACIÓN", ICON_SCORE, Color(1.0, 0.85, 0.2))
	_progress_score_value = score_row.value_label
	vbox.add_child(score_row.row)

	var best_row := _create_stat_row("RÉCORD", ICON_SCORE, Color(1.0, 0.85, 0.2))
	_progress_best_value = best_row.value_label
	vbox.add_child(best_row.row)

	var bugs_row := _create_stat_row("BUGS ELIMINADOS", ICON_BUG, Color(0.4, 1.0, 0.6), Vector2(36, 36), Vector2(-2, -5))
	_progress_bugs_value = bugs_row.value_label
	vbox.add_child(bugs_row.row)

	var servers_row := _create_stat_row("SERVIDORES ASEGURADOS", ICON_SERVER, Color(0.55, 0.85, 1.0))
	_progress_servers_value = servers_row.value_label
	vbox.add_child(servers_row.row)

func _create_stat_row(name_text: String, icon_path: String, icon_color: Color, icon_size: Vector2 = Vector2(24, 24), icon_offset: Vector2 = Vector2.ZERO) -> StatRow:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := _create_icon_texture(icon_path, Vector2(36, 36), icon_size, icon_color, icon_offset)
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

	var ogv_files := _collect_video_paths()

	for i in range(mini(len(ogv_files), KEY_SLOT_COUNT)):
		var video_path := ogv_files[i]
		var basename := _get_video_basename(video_path)

		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(28, 28)
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		slot.modulate = Color(0.15, 0.15, 0.2, 0.55)

		var thumbnail_path: String = THUMBNAIL_FOLDER + basename + ".png"
		if ResourceLoader.exists(thumbnail_path):
			slot.texture = load(thumbnail_path)

		hbox.add_child(slot)
		_key_slots.append(slot)

func _get_video_basename(video_path: String) -> String:
	var basename := video_path.get_file().get_basename()
	if basename.ends_with(LOW_QUALITY_VIDEO_SUFFIX):
		basename = basename.trim_suffix(LOW_QUALITY_VIDEO_SUFFIX)
	return basename

func update_key_panel() -> void:
	for i in range(_key_slots.size()):
		if i < _video_paths.size() and _video_paths[i] in _watched_videos:
			_key_slots[i].modulate = Color.WHITE
		else:
			_key_slots[i].modulate = Color(0.15, 0.15, 0.2, 0.55)

func _on_keys_changed(_count: int) -> void:
	update_key_panel()

# ── SkillUp panel — top-right ─────────────────────────────────

func _get_skill_data_for_type(type: String) -> Dictionary:
	match type:
		"code":
			return {"name": "PROGRAMACIÓN", "icon_path": ICON_CODE, "accent": Color(0.2, 0.85, 0.5)}
		"cpu":
			return {"name": "CIBERSEGURIDAD", "icon_path": ICON_CPU, "accent": Color(0.7, 0.45, 1.0)}
	return {}

func _setup_skillup_panel() -> void:
	_skillup_panel = $PowerUpPanel
	if not _skillup_panel:
		return

	for child in _skillup_panel.get_children():
		child.queue_free()

	_skillup_rows.clear()

	_skillup_panel.add_theme_stylebox_override("panel", _create_hud_panel_style())
	_skillup_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_skillup_panel.offset_left  = -310
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

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	for type in GameManager.POWERUP_TYPES:
		var skill_data: Dictionary = _get_skill_data_for_type(type)
		if skill_data.is_empty():
			continue

		var label := Label.new()
		_apply_mono(label)
		label.text = skill_data.name
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3, 1.0))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)

		var slot_container := HBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 8)
		slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(slot_container)

		var slots: Array[TextureRect] = []
		var max_stacks := GameManager.max_stacks_per_powerup
		var slot_size := Vector2(36, 36)
		for i in range(max_stacks):
			var slot := TextureRect.new()
			slot.custom_minimum_size = slot_size
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.modulate = Color(0.08, 0.08, 0.1, 1.0)
			if ResourceLoader.exists(skill_data.icon_path):
				slot.texture = load(skill_data.icon_path)
			slot_container.add_child(slot)
			slots.append(slot)

		var row_data := SkillUpRowData.new()
		row_data.label = label
		row_data.slot_container = slot_container
		row_data.slots = slots
		row_data.icon_path = skill_data.icon_path
		_skillup_rows[type] = row_data
		_update_skill_row(type)


func _update_skill_row(type: String) -> void:
	if not _skillup_rows.has(type):
		return
	var data: SkillUpRowData = _skillup_rows[type]
	var count := GameManager.GetStackCount(type)
	var max_stacks := GameManager.max_stacks_per_powerup

	for i in range(max_stacks):
		if i < count:
			data.slots[i].modulate = Color.WHITE
		else:
			data.slots[i].modulate = Color(0.08, 0.08, 0.1, 1.0)

	if count > 0:
		data.label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	else:
		data.label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3, 1.0))

func _on_powerup_changed(type: String, _stacks: int) -> void:
	_update_skill_row(type)

func _on_max_stacks_changed(value: int) -> void:
	_setup_skillup_panel()

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
	_video_player.buffering_msec = VIDEO_BUFFERING_MSEC
	_video_player.volume_db = 0.0
	_video_panel.add_child(_video_player)

	_setup_minimize_label()

func _setup_minimize_label() -> void:
	_minimize_panel = PanelContainer.new()
	_minimize_panel.name = "MinimizePanel"

	_minimize_panel.anchor_top = 1.0
	_minimize_panel.anchor_bottom = 1.0
	_minimize_panel.anchor_left = 0.0
	_minimize_panel.anchor_right = 1.0

	_minimize_panel.offset_left = 60
	_minimize_panel.offset_right = -60
	_minimize_panel.offset_top = -55
	_minimize_panel.offset_bottom = -5

	_minimize_panel.z_index = 100
	_minimize_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_minimize_panel.hide()
	add_child(_minimize_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	_minimize_panel.add_theme_stylebox_override("panel", panel_style)

	_minimize_label = Label.new()
	_apply_mono(_minimize_label)
	_minimize_label.text = "Presione el botón para minimizar"
	_minimize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimize_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_minimize_label.add_theme_font_size_override("font_size", 22)
	_minimize_panel.add_child(_minimize_label)

func _collect_video_paths() -> Array[String]:
	if not _video_paths.is_empty():
		return _video_paths

	var files := DirAccess.get_files_at(VIDEO_FOLDER)
	var result: Array[String] = []

	for f in files:
		if f.ends_with(LOW_QUALITY_VIDEO_SUFFIX + ".ogv"):
			result.append(VIDEO_FOLDER + f)
		elif f.ends_with(".ogv"):
			result.append(VIDEO_FOLDER + f)
	result.sort()
	_video_paths = result
	return result

func _on_video_key_collected() -> void:
	if not _video_panel or not is_instance_valid(_video_panel):
		return

	_can_minimize_video = false
	_is_pip_mode = false

	_video_panel.anchors_preset = Control.PRESET_FULL_RECT
	_video_panel.offset_left = 60
	_video_panel.offset_top = 60
	_video_panel.offset_right = -60
	_video_panel.offset_bottom = -60
	_video_panel.z_index = 0

	var full_style := StyleBoxFlat.new()
	full_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	full_style.set_border_width_all(0)
	_video_panel.add_theme_stylebox_override("panel", full_style)

	var ogv_files := _collect_video_paths()
	if ogv_files.is_empty():
		return

	var unwatched: Array[String] = []
	for f in ogv_files:
		if f not in _watched_videos:
			unwatched.append(f)

	if unwatched.is_empty() and not ogv_files.is_empty():
		_watched_videos.clear()
		unwatched = ogv_files.duplicate()

	if unwatched.is_empty():
		return

	var chosen: String = unwatched.pick_random()
	_video_player.stream = load(chosen)
	_watched_videos.append(chosen)
	update_key_panel()

	if _logo_panel and is_instance_valid(_logo_panel):
		_logo_panel.hide()
	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.hide()

	_video_panel.modulate = Color(1, 1, 1, 0)
	_video_panel.show()
	var fade_tween := create_tween()
	fade_tween.tween_property(_video_panel, "modulate", Color.WHITE, 0.3)

	if _video_player.stream:
		_minimize_panel.hide()
		if _minimize_tween:
			_minimize_tween.kill()

		_minimize_tween = create_tween().bind_node(_minimize_panel)
		_minimize_tween.tween_interval(5.0)
		_minimize_tween.tween_callback(func():
			_can_minimize_video = true
			_minimize_panel.show()
			_minimize_panel.modulate.a = 1.0
			_minimize_tween = create_tween().bind_node(_minimize_panel).set_loops()
			_minimize_tween.tween_property(_minimize_panel, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
			_minimize_tween.tween_property(_minimize_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		)

		_video_player.play()
		SubtitleManager.start_subtitles(_video_player, chosen, _video_panel)

	get_tree().paused = true

	if not _video_player.finished.is_connected(_on_video_finished):
		_video_player.finished.connect(_on_video_finished)

	_set_music_video_duck(true)

func _input(event: InputEvent) -> void:
	if not (_video_panel and _video_panel.visible and not _is_pip_mode and _can_minimize_video):
		return
	var minimize := event.is_action_pressed("ui_accept")
	if OS.has_feature("mobile") and event is InputEventScreenTouch and event.pressed:
		minimize = true
	if minimize:
		_enter_pip_mode()
		get_viewport().set_input_as_handled()

func _enter_pip_mode() -> void:
	if _is_transitioning:
		return
	_can_minimize_video = false
	_is_pip_mode = true
	SFXManager.play("game-collect-item-short-550419")

	if _minimize_tween:
		_minimize_tween.kill()
		_minimize_tween = null
	_minimize_panel.hide()

	var pip_style := StyleBoxFlat.new()
	pip_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	pip_style.set_border_width_all(2)
	pip_style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	pip_style.corner_radius_top_left = 4
	pip_style.corner_radius_top_right = 4
	pip_style.corner_radius_bottom_left = 4
	pip_style.corner_radius_bottom_right = 4
	_video_panel.add_theme_stylebox_override("panel", pip_style)

	var viewport_size := get_viewport().get_visible_rect().size
	var pip_x := PIP_MARGIN.x
	var pip_y := viewport_size.y - PIP_SIZE.y - PIP_MARGIN.y

	var full_size := viewport_size - Vector2(120, 120)

	_video_panel.anchors_preset = Control.PRESET_TOP_LEFT
	_video_panel.z_index = 100
	_video_panel.position = Vector2(60, 60)
	_video_panel.size = full_size

	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pip_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pip_tween.set_parallel(true)
	pip_tween.tween_property(_video_panel, "position", Vector2(pip_x, pip_y), 0.7)
	pip_tween.tween_property(_video_panel, "size", PIP_SIZE, 0.7)

	# The game stays paused while the PIP animation runs, then the background
	# transition plays. Gameplay only resumes once the transition finishes.
	pip_tween.tween_callback(func():
		SubtitleManager.update_mode(true)
		_play_background_transition()
	)

	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.show()
		update_key_panel()

func _on_video_finished() -> void:
	# The video ended naturally: close it immediately so the background is
	# visible, then play the background transition before resuming gameplay.
	if _is_transitioning:
		return
	_close_video_internal()
	_play_background_transition()

func _close_video_internal() -> void:
	SubtitleManager.stop_subtitles()
	_can_minimize_video = false
	_is_pip_mode = false

	var music = get_tree().get_first_node_in_group("music")
	if music and music.has_method("fade_out_video_reduction"):
		music.fade_out_video_reduction()
	else:
		_set_music_video_duck(false)

	if _video_player:
		_video_player.stop()
		_video_player.stream = null
		if _video_player.finished.is_connected(_on_video_finished):
			_video_player.finished.disconnect(_on_video_finished)

	if _video_panel and is_instance_valid(_video_panel):
		_video_panel.modulate = Color.WHITE
		_video_panel.hide()

	if _minimize_tween:
		_minimize_tween.kill()
		_minimize_tween = null
	_minimize_panel.hide()

	if _logo_panel and is_instance_valid(_logo_panel):
		_logo_panel.show()
	if _key_panel and is_instance_valid(_key_panel):
		_key_panel.show()
		update_key_panel()

func _play_background_transition() -> void:
	_is_transitioning = true
	if not _background:
		_connect_background()
	if _background and _background.has_method("play_background_transition"):
		_background.play_background_transition()
	else:
		_on_background_transition_finished()

func _on_background_transition_finished() -> void:
	_is_transitioning = false
	get_tree().paused = false

func _set_music_video_duck(active: bool) -> void:
	var music = get_tree().get_first_node_in_group("music")
	if music and music.has_method("set_video_reduction"):
		music.set_video_reduction(active)

# ── Game Over panel — background image + dynamic labels ───────

func _setup_game_over_panel() -> void:
	print("[HUD] _setup_game_over_panel iniciado")
	if not gameover_panel:
		push_error("HUD: GameOverPanel no encontrado en la escena")
		return

	# Clear any legacy children
	for child in gameover_panel.get_children():
		child.queue_free()

	_gameover_card = TextureRect.new()
	_gameover_card.name = "GameOverCard"
	_gameover_card.custom_minimum_size = GAME_OVER_PANEL_SIZE
	_gameover_card.size = GAME_OVER_PANEL_SIZE
	_gameover_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gameover_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if ResourceLoader.exists(GAME_OVER_PANEL_TEXTURE):
		_gameover_card.texture = load(GAME_OVER_PANEL_TEXTURE)
		print("[HUD] GameOver: textura del panel cargada")
	gameover_panel.add_child(_gameover_card)

	# Shared blur shader for locked camper card text.
	_text_blur_shader = Shader.new()
	_text_blur_shader.code = """
shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * 0.25;
	color += texture(TEXTURE, UV + vec2(blur_size, 0.0) * TEXTURE_PIXEL_SIZE) * 0.125;
	color += texture(TEXTURE, UV - vec2(blur_size, 0.0) * TEXTURE_PIXEL_SIZE) * 0.125;
	color += texture(TEXTURE, UV + vec2(0.0, blur_size) * TEXTURE_PIXEL_SIZE) * 0.125;
	color += texture(TEXTURE, UV - vec2(0.0, blur_size) * TEXTURE_PIXEL_SIZE) * 0.125;
	color += texture(TEXTURE, UV + vec2(blur_size, blur_size) * TEXTURE_PIXEL_SIZE) * 0.0625;
	color += texture(TEXTURE, UV - vec2(blur_size, blur_size) * TEXTURE_PIXEL_SIZE) * 0.0625;
	color += texture(TEXTURE, UV + vec2(blur_size, -blur_size) * TEXTURE_PIXEL_SIZE) * 0.0625;
	color += texture(TEXTURE, UV - vec2(blur_size, -blur_size) * TEXTURE_PIXEL_SIZE) * 0.0625;
	COLOR = color;
}
"""

	# Camper cards grid (2 columns × 3 rows)
	_setup_camper_cards()

	# Death cause title
	_gameover_death_cause = _create_panel_label(GAME_OVER_DEATH_TITLE_RECT, 36, Color(1.0, 0.35, 0.25))
	_gameover_card.add_child(_gameover_death_cause)

	# Death cause hint / explanation
	_gameover_death_avoid = _create_panel_label(GAME_OVER_DEATH_DETAIL_RECT, 30, Color(0.55, 0.90, 1.0))
	_gameover_card.add_child(_gameover_death_avoid)

	# Death cause icon (bug / server / fall)
	_gameover_death_cause_icon = _create_gameover_icon(GAME_OVER_DEATH_CAUSE_ICON_RECT)
	_gameover_card.add_child(_gameover_death_cause_icon)

	# Death avoidance powerup icon
	_gameover_death_detail_icon = _create_gameover_icon(GAME_OVER_DEATH_DETAIL_ICON_RECT)
	_gameover_card.add_child(_gameover_death_detail_icon)

	# Restart CTA (pulsing)
	_gameover_restart_cta_label = _create_panel_label(GAME_OVER_CTA_RECT, 38, Color(0.35, 0.95, 1.0))
	_gameover_restart_cta_label.text = "PRESIONA EL BOTÓN PARA REINICIAR"
	_gameover_card.add_child(_gameover_restart_cta_label)

	print("[HUD] _setup_game_over_panel completado")

# ── Camper cards ───────────────────────────────────────────────

func _setup_camper_cards() -> void:
	_camper_cards.clear()
	for i in range(CAMPER_DATA.size()):
		var data: Dictionary = CAMPER_DATA[i]
		var card := _create_camper_card(data)
		var row: int = i / 2
		var col: int = i % 2
		card.position = Vector2(
			GAME_OVER_GRID_ORIGIN.x + col * (GAME_OVER_CARD_SIZE.x + GAME_OVER_CARD_GAP.x),
			GAME_OVER_GRID_ORIGIN.y + row * (GAME_OVER_CARD_SIZE.y + GAME_OVER_CARD_GAP.y)
		)
		card.size = GAME_OVER_CARD_SIZE
		_gameover_card.add_child(card)
		_camper_cards.append(card)

func _create_camper_card(data: Dictionary) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = GAME_OVER_CARD_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.16, 0.85)
	style.border_color = Color(0.35, 0.60, 0.95, 0.6)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.anti_aliasing = true
	card.add_theme_stylebox_override("panel", style)

	var thumb_size: float = 90.0
	var thumb_y: float = (GAME_OVER_CARD_SIZE.y - thumb_size) * 0.5
	var text_x: float = thumb_size + 20.0
	var text_w: float = GAME_OVER_CARD_SIZE.x - text_x - 20.0

	# Thumbnail
	var thumb := TextureRect.new()
	thumb.name = "Thumbnail"
	var thumb_path: String = THUMBNAIL_FOLDER + data["video"] + ".png"
	if ResourceLoader.exists(thumb_path):
		thumb.texture = load(thumb_path)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.position = Vector2(8, thumb_y)
	thumb.size = Vector2(thumb_size, thumb_size)
	thumb.clip_contents = true
	card.add_child(thumb)

	# Dark overlay on thumbnail (for undiscovered state)
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.position = Vector2(8, thumb_y)
	overlay.size = Vector2(thumb_size, thumb_size)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(overlay)

	# Title
	var title := Label.new()
	_apply_mono(title)
	title.name = "Title"
	title.text = data["title"]
	title.position = Vector2(text_x, 10)
	title.size = Vector2(text_w, 44)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	title.add_theme_constant_override("outline_size", 4)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _text_blur_shader:
		var title_blur := ShaderMaterial.new()
		title_blur.shader = _text_blur_shader
		title.material = title_blur
	card.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	_apply_mono(subtitle)
	subtitle.name = "Subtitle"
	subtitle.text = data["subtitle"]
	subtitle.position = Vector2(text_x, 58)
	subtitle.size = Vector2(text_w, 54)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	subtitle.add_theme_constant_override("outline_size", 3)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if _text_blur_shader:
		var subtitle_blur := ShaderMaterial.new()
		subtitle_blur.shader = _text_blur_shader
		subtitle.material = subtitle_blur
	card.add_child(subtitle)

	return card

func _update_camper_cards() -> void:
	for i in range(_camper_cards.size()):
		var card: Panel = _camper_cards[i]
		if i >= CAMPER_DATA.size():
			continue
		var data: Dictionary = CAMPER_DATA[i]
		var discovered: bool = _is_camper_discovered(data["video"])

		var thumb: TextureRect = card.get_node_or_null("Thumbnail")
		var overlay: ColorRect = card.get_node_or_null("Overlay")
		var title: Label = card.get_node_or_null("Title")
		var subtitle: Label = card.get_node_or_null("Subtitle")

		if discovered:
			if thumb:
				thumb.modulate = Color.WHITE
			if overlay:
				overlay.color = Color(0, 0, 0, 0)
			if title:
				title.visible = true
				title.modulate = Color.WHITE
				if title.material and title.material is ShaderMaterial:
					title.material.set_shader_parameter("blur_size", 0.0)
			if subtitle:
				subtitle.visible = true
				subtitle.modulate = Color.WHITE
				if subtitle.material and subtitle.material is ShaderMaterial:
					subtitle.material.set_shader_parameter("blur_size", 0.0)
			card.modulate = Color.WHITE
		else:
			if thumb:
				thumb.modulate = Color(0.45, 0.5, 0.6, 1.0)
			if overlay:
				overlay.color = Color(0.08, 0.12, 0.2, 0.25)
			if title:
				title.visible = false
			if subtitle:
				subtitle.visible = false
			card.modulate = Color(0.7, 0.7, 0.75, 0.85)

func _is_camper_discovered(camper_video: String) -> bool:
	for path in _video_paths:
		if _get_video_basename(path) == camper_video:
			return path in _watched_videos
	return false

func _create_panel_label(rect: Rect2, font_size: int, font_color: Color) -> Label:
	var lbl := Label.new()
	_apply_mono(lbl)
	lbl.position = rect.position
	lbl.size = rect.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _create_gameover_icon(rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = rect.position
	icon.size = rect.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func _build_death_cause_ui() -> void:
	if not _gameover_death_cause or not _gameover_death_avoid:
		return

	var cause := GameManager.death_cause
	var headline := ""
	var detail := ""
	var cause_icon_path := ""
	var detail_icon_path := ""
	var show_cause_icon := false
	var show_detail_icon := false

	match cause:
		"bug":
			headline = "¡Un bug te detuvo!"
			detail = "Adquiere la habilidad Programación para eliminar bugs facilmente."
			cause_icon_path = "res://assets/bug/walk/frame_017.png"
			detail_icon_path = "res://assets/powerups/powerup_code.png"
			show_cause_icon = true
			show_detail_icon = true
		"fall":
			headline = "¡Caíste al vacío!"
			detail = "Usa el doble salto para superar los vacíos más largos."
			cause_icon_path = "res://assets/rocket_v2/caida/frame_102.png"
			detail_icon_path = "res://assets/rocket_v2/doble_salto/frame_085.png"
			show_cause_icon = true
			show_detail_icon = true
		"server":
			headline = "¡Un servidor vulnerable bloqueó tu camino!"
			detail = "Adquiere la habilidad Ciberseguridad para corregir servidores vulnerables."
			cause_icon_path = "res://assets/server/server_red.png"
			detail_icon_path = "res://assets/powerups/powerup_cpu.png"
			show_cause_icon = true
			show_detail_icon = true
		_:
			_gameover_death_cause.visible = false
			_gameover_death_avoid.visible = false
			if _gameover_death_cause_icon:
				_gameover_death_cause_icon.visible = false
			if _gameover_death_detail_icon:
				_gameover_death_detail_icon.visible = false
			return

	_gameover_death_cause.visible = true
	_gameover_death_avoid.visible = true
	_gameover_death_cause.text = headline
	_gameover_death_avoid.text = detail

	if _gameover_death_cause_icon:
		if show_cause_icon and ResourceLoader.exists(cause_icon_path):
			var cause_tex := load(cause_icon_path)
			if cause_tex is Texture2D:
				_gameover_death_cause_icon.texture = cause_tex
		_gameover_death_cause_icon.visible = show_cause_icon
	if _gameover_death_detail_icon:
		if show_detail_icon and ResourceLoader.exists(detail_icon_path):
			var detail_tex := load(detail_icon_path)
			if detail_tex is Texture2D:
				_gameover_death_detail_icon.texture = detail_tex
		_gameover_death_detail_icon.visible = show_detail_icon
