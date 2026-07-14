extends Node

## SubtitleManager — Independent subtitle system for video playback.
## Loads .json subtitle files, parses them, and displays synchronized subtitles
## that remain visible even when the video is minimized.

signal subtitles_started
signal subtitles_ended

# ── Configurable style ─────────────────────────────────────────
@export var font_size: int = 24
@export var font_color: Color = Color.WHITE
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.85)
@export var outline_size: int = 5
@export var bottom_margin: int = 24
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var shadow_offset: Vector2 = Vector2(2, 2)

# ── Internal state ─────────────────────────────────────────────
var _subtitles: Array[Dictionary] = []
var _current_index: int = -1
var _video_player: VideoStreamPlayer = null
var _video_panel: PanelContainer = null
var _is_active: bool = false
var _is_pip_mode: bool = false

var _canvas_layer: CanvasLayer = null
var _subtitle_label: Label = null
var _container: Control = null

var _mono_font: SystemFont = null

const SUBTITLE_EXTENSIONS: PackedStringArray = [".json"]

# ── Lifecycle ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_font()
	_create_ui()

func _process(_delta: float) -> void:
	if not _is_active:
		return
	if not _video_player or not is_instance_valid(_video_player):
		stop_subtitles()
		return

	if not _video_player.is_playing():
		return

	var current_time: float = _video_player.stream_position
	_update_subtitle_display(current_time)

# ── Public API ─────────────────────────────────────────────────

func start_subtitles(video_player: VideoStreamPlayer, video_path: String, video_panel: PanelContainer) -> void:
	stop_subtitles()

	if not video_player or not is_instance_valid(video_player):
		push_warning("[SubtitleManager] Invalid video player")
		return

	_video_player = video_player
	_video_panel = video_panel
	_is_pip_mode = false

	# Find and load subtitle file
	var json_path := _find_subtitle_path(video_path)
	if json_path.is_empty():
		print("[SubtitleManager] No subtitle file found for: ", video_path)
		return

	_subtitles = _load_json(json_path)
	if _subtitles.is_empty():
		print("[SubtitleManager] Subtitle file is empty or invalid: ", json_path)
		return

	_current_index = -1
	_is_active = true
	_position_for_expanded()
	_show_label()
	subtitles_started.emit()
	print("[SubtitleManager] Started with ", _subtitles.size(), " entries")

func update_mode(is_pip: bool) -> void:
	if not _is_active:
		return
	_is_pip_mode = is_pip
	if is_pip:
		_position_for_screen()
	else:
		_position_for_expanded()

func stop_subtitles() -> void:
	if not _is_active:
		return
	_is_active = false
	_current_index = -1
	_subtitles.clear()
	_hide_label()
	_video_player = null
	_video_panel = null
	subtitles_ended.emit()
	print("[SubtitleManager] Stopped")

func clear_all() -> void:
	_is_active = false
	_current_index = -1
	_subtitles.clear()
	_hide_label()
	_video_player = null
	_video_panel = null

# ── Subtitle File Discovery ──────────────────────────────────

func _find_subtitle_path(video_path: String) -> String:
	var base := video_path.get_basename()
	for ext in SUBTITLE_EXTENSIONS:
		var json_path := base + ext
		var exists := FileAccess.file_exists(json_path)
		print("[SubtitleManager] Buscando JSON: ", json_path, " -> ", "EXISTE" if exists else "NO EXISTE")
		if exists:
			return json_path
	var alt_base := base.trim_suffix("_720p")
	if alt_base != base:
		for ext in SUBTITLE_EXTENSIONS:
			var json_path := alt_base + ext
			var exists := FileAccess.file_exists(json_path)
			print("[SubtitleManager] Buscando JSON (fallback): ", json_path, " -> ", "EXISTE" if exists else "NO EXISTE")
			if exists:
				return json_path
	print("[SubtitleManager] No se encontro archivo JSON para: ", video_path)
	return ""

# ── JSON Loader ───────────────────────────────────────────────

func _load_json(json_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_warning("[SubtitleManager] No se pudo abrir: ", json_path)
		return result
	print("[SubtitleManager] Archivo JSON abierto correctamente: ", json_path)

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_warning("[SubtitleManager] Error al parsear JSON: ", json.get_error_message(), " (linea ", json.get_error_line(), ")")
		return result

	var data = json.data
	if typeof(data) != TYPE_ARRAY:
		push_warning("[SubtitleManager] El JSON no es un array")
		return result

	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("start") or not entry.has("end") or not entry.has("text"):
			push_warning("[SubtitleManager] Entrada JSON invalida: ", entry)
			continue
		result.append({
			"start": float(entry["start"]),
			"end": float(entry["end"]),
			"text": str(entry["text"])
		})

	print("[SubtitleManager] JSON cargado con ", result.size(), " entradas")
	return result

# ── Subtitle Display ──────────────────────────────────────────

func _update_subtitle_display(current_time: float) -> void:
	# Find the subtitle that should be displayed at current_time
	var new_index := -1
	for i in range(_subtitles.size()):
		var sub: Dictionary = _subtitles[i]
		if current_time >= sub["start"] and current_time <= sub["end"]:
			new_index = i
			break

	# Only update label if subtitle changed
	if new_index == _current_index:
		return

	_current_index = new_index

	if _current_index >= 0:
		_subtitle_label.text = _subtitles[_current_index]["text"]
		_subtitle_label.visible = true
	else:
		_subtitle_label.text = ""
		_subtitle_label.visible = false

# ── UI Setup ──────────────────────────────────────────────────

func _setup_font() -> void:
	_mono_font = SystemFont.new()
	_mono_font.font_names = PackedStringArray(["Arial", "Helvetica", "Segoe UI", "sans-serif"])
	_mono_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_mono_font.generate_mipmaps = true

func _create_ui() -> void:
	# Canvas layer above everything
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "SubtitleLayer"
	_canvas_layer.layer = 128
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)

	# Container that fills the screen
	_container = Control.new()
	_container.name = "SubtitleContainer"
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.z_index = 100
	_canvas_layer.add_child(_container)

	# Subtitle label
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.max_lines_visible = 3
	_subtitle_label.visible = false
	_subtitle_label.z_index = 100

	_apply_style()

	_container.add_child(_subtitle_label)

func _apply_style() -> void:
	if not _subtitle_label:
		return

	_subtitle_label.add_theme_font_size_override("font_size", font_size)
	_subtitle_label.add_theme_color_override("font_color", font_color)
	_subtitle_label.add_theme_color_override("font_outline_color", outline_color)
	_subtitle_label.add_theme_constant_override("outline_size", outline_size)
	_subtitle_label.add_theme_color_override("font_shadow_color", shadow_color)
	_subtitle_label.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	_subtitle_label.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))
	_subtitle_label.add_theme_constant_override("shadow_outline_size", 1)

	if _mono_font:
		_subtitle_label.add_theme_font_override("font", _mono_font)

func _show_label() -> void:
	if _subtitle_label:
		_subtitle_label.visible = true
		_subtitle_label.text = ""

func _hide_label() -> void:
	if _subtitle_label:
		_subtitle_label.visible = false
		_subtitle_label.text = ""

# ── Positioning ───────────────────────────────────────────────

func _position_for_expanded() -> void:
	if not _subtitle_label or not _video_panel:
		return

	# When expanded, position higher above the video bottom edge
	_subtitle_label.anchor_left = 0.0
	_subtitle_label.anchor_top = 1.0
	_subtitle_label.anchor_right = 1.0
	_subtitle_label.anchor_bottom = 1.0
	_subtitle_label.offset_left = 80
	_subtitle_label.offset_right = -80
	_subtitle_label.offset_top = -bottom_margin - 120
	_subtitle_label.offset_bottom = -bottom_margin - 60

func _position_for_screen() -> void:
	if not _subtitle_label:
		return

	# When minimized or no video, position at bottom of game screen
	_subtitle_label.anchor_left = 0.0
	_subtitle_label.anchor_top = 1.0
	_subtitle_label.anchor_right = 1.0
	_subtitle_label.anchor_bottom = 1.0
	_subtitle_label.offset_left = 40
	_subtitle_label.offset_right = -40
	_subtitle_label.offset_top = -bottom_margin - 60
	_subtitle_label.offset_bottom = -bottom_margin
