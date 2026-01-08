extends CharacterBody2D

@export var follow_distance: float = 200.0
@export var follow_speed: float = 500.0
@export var accel: float = 2000.0

var target: Node2D = null
var in_trail: bool = false

func join_trail(t: Node2D) -> void:
	target = t
	in_trail = true

func _physics_process(delta: float) -> void:
	if not in_trail or target == null:
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
		move_and_slide()
		return
	$CollisionShape2D.disabled = true

	var to_target: Vector2 = target.global_position - global_position
	$AnimatedSprite2D.flip_h = target.global_position.x > global_position.x
		
	var dist: float = to_target.length()

	if dist > follow_distance:
		var desired: Vector2 = to_target.normalized() * follow_speed
		velocity = velocity.move_toward(desired, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)

	move_and_slide()
