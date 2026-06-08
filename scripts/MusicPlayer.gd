extends AudioStreamPlayer

const REDUCTION_DB: float = -3.1
var _base_volume_db: float

func _ready() -> void:
	_base_volume_db = volume_db
	finished.connect(play)
	GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(state: GameManager.State) -> void:
	match state:
		GameManager.State.PLAYING:
			volume_db = _base_volume_db
		_:
			volume_db = _base_volume_db + REDUCTION_DB
