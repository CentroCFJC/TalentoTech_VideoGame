extends AudioStreamPlayer

const REDUCTION_DB: float = -3.1
const VIDEO_REDUCTION_DB: float = -2.5

var _base_volume_db: float
var _current_state: GameManager.State
var _video_reduction: bool = false

func _ready() -> void:
	_base_volume_db = volume_db
	_current_state = GameManager.current_state
	finished.connect(play)
	GameManager.state_changed.connect(_on_state_changed)
	add_to_group("music")
	_apply_volume()

func _on_state_changed(state: GameManager.State) -> void:
	_current_state = state
	_apply_volume()

func set_video_reduction(active: bool) -> void:
	_video_reduction = active
	_apply_volume()

func _apply_volume() -> void:
	var reduction: float = 0.0
	if _current_state != GameManager.State.PLAYING:
		reduction += REDUCTION_DB
	if _video_reduction:
		reduction += VIDEO_REDUCTION_DB
	volume_db = _base_volume_db + reduction
