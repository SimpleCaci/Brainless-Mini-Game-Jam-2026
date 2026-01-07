extends CanvasLayer

@export var ball_path: NodePath

@onready var strokes_label: Label = $StrokesLabel
@onready var speed_label: Label = $SpeedLabel

var ball: Node = null

func _ready() -> void:
	call_deferred("_bind_ball")

func _bind_ball() -> void:
	if ball_path == NodePath("") or ball_path.is_empty():
		push_error("HUD: ball_path is empty. Set HUD.ball_path to the Ball node in the Inspector.")
		return

	ball = get_node_or_null(ball_path)
	if ball == null:
		push_error("HUD: ball_path does not resolve. Current ball_path: %s" % str(ball_path))
		return

	# Optional: verify signals exist (prevents silent mismatch)
	if not ball.has_signal("shot_taken"):
		push_error("HUD: Ball node has no signal 'shot_taken'. Did you attach the correct Ball script?")
		return
	if not ball.has_signal("speed_changed"):
		push_error("HUD: Ball node has no signal 'speed_changed'. Did you attach the correct Ball script?")
		return

	ball.connect("shot_taken", Callable(self, "_on_shot_taken"))
	ball.connect("speed_changed", Callable(self, "_on_speed_changed"))

func _on_shot_taken(strokes: int) -> void:
	strokes_label.text = "Strokes: %d" % strokes

func _on_speed_changed(speed: float) -> void:
	speed_label.text = "Speed: %d" % int(speed)
