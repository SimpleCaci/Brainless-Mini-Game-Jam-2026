extends Sprite2D

@onready var pond_area: Area2D = $Area2D
@export var game_over_scene: String = "res://scenes/lose.tscn" # change if needed

func _ready() -> void:
	pond_area.body_entered.connect(_on_pond_body_entered)

func _on_pond_body_entered(body: Node) -> void:
	# If your dog is a CharacterBody2D/RigidBody2D, this will catch it.
	# Easiest: name your dog node "Dog" or put it in group "dog".
	if body.name == "Dog" or body.is_in_group("dog"):
		get_tree().change_scene_to_file(game_over_scene)
