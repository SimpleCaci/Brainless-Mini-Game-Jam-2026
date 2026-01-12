extends CanvasLayer
"""
HUD for the dog/ball.
Shows:
- Strokes
- Speed
- State (STOPPED / MOVING / SETTLING / AIMING)
- Ready indicator (CAN SHOOT / WAIT)
- Optional settle progress bar (if you add one)

Requires the ball script signals:
shot_taken(int), speed_changed(float),
stopped_changed(bool), can_shoot_changed(bool), stop_progress_changed(float)
"""

@export var ball_path: NodePath

@onready var strokes_label: Label = $StrokesLabel
@onready var speed_label: Label = $SpeedLabel
@onready var state_label: Label = $StateLabel          # add this Label
@onready var ready_label: Label = $ReadyLabel          # add this Label
@onready var settle_bar: ProgressBar = get_node_or_null("SettleBar") as ProgressBar # optional

var ball: Node = null
var _strokes: int = 0
var _speed: float = 0.0
var _stopped: bool = true
var _can_shoot: bool = true
var _settle_prog: float = 1.0

func _ready() -> void:
	await get_tree().process_frame
	_bind_ball()
	_refresh()

func _bind_ball() -> void:
	if ball_path.is_empty():
		push_error("HUD: ball_path is empty.")
		return

	ball = get_node_or_null(ball_path)
	if ball == null:
		push_error("HUD: ball_path does not resolve: %s" % str(ball_path))
		return

	# Core
	if ball.has_signal("shot_taken"):
		ball.shot_taken.connect(_on_shot_taken)
	else:
		push_error("HUD: missing signal shot_taken on %s" % ball.name)

	if ball.has_signal("speed_changed"):
		ball.speed_changed.connect(_on_speed_changed)
	else:
		push_error("HUD: missing signal speed_changed on %s" % ball.name)

	# Stop/ready (new)
	if ball.has_signal("stopped_changed"):
		ball.stopped_changed.connect(_on_stopped_changed)
	if ball.has_signal("can_shoot_changed"):
		ball.can_shoot_changed.connect(_on_can_shoot_changed)
	if ball.has_signal("stop_progress_changed"):
		ball.stop_progress_changed.connect(_on_stop_progress_changed)

func _on_shot_taken(strokes: int) -> void:
	_strokes = strokes
	_refresh()

func _on_speed_changed(speed: float) -> void:
	_speed = speed
	_refresh()

func _on_stopped_changed(stopped: bool) -> void:
	_stopped = stopped
	_refresh()

func _on_can_shoot_changed(can_shoot: bool) -> void:
	_can_shoot = can_shoot
	_refresh()

func _on_stop_progress_changed(progress: float) -> void:
	_settle_prog = clamp(progress, 0.0, 1.0)
	if settle_bar:
		settle_bar.value = _settle_prog * 100.0
	_refresh()

func _refresh() -> void:
	strokes_label.text = "Strokes: %d" % _strokes
	speed_label.text = "Speed: %.1f" % _speed

	# State text (simple but informative)
	# If you want “AIMING” specifically, expose ball.dragging or add a dragging_changed signal.
	var state := "STOPPED" if _stopped else "MOVING"
	if not _stopped and _settle_prog > 0.0 and _settle_prog < 1.0:
		state = "SETTLING"
	state_label.text = "State: %s" % state

	ready_label.text = "CAN SHOOT" if _can_shoot else "WAIT"

	# Optional: hide settle bar when not relevant
	if settle_bar:
		settle_bar.visible = (not _stopped) and (_settle_prog < 1.0)
