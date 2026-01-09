extends Node2D


@export var ball_path: NodePath
var ball: Node
var win_game := false

func _ready() -> void:
	if has_node("GoalArea"):
		$GoalArea.body_entered.connect(_on_pickup_body_entered)

	ball = get_node_or_null(ball_path)
	if ball:
		ball.shot_taken.connect(_on_win_game)

func _on_pickup_body_entered(body: Node) -> void:
	if body.name == "dog":
		body.call("arrived_at_goal")

func _on_win_game(w: bool) -> void:
	if w:
		$AnimatedSprite2D.set_animation("open")
