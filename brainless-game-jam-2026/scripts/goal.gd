extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if has_node("GoalArea"):
		$GoalArea.body_entered.connect(_on_pickup_body_entered)

func _on_pickup_body_entered(body: Node) -> void:
		body.call("arrived_at_goal")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
