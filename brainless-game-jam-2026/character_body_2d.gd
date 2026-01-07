extends CharacterBody2D

signal shot_taken(strokes: int)
signal speed_changed(speed: float)

@export var max_speed: float = 1800.0
@export var friction: float = 1400.0          # px/s^2
@export var max_pull: float = 250.0           # px
@export var impulse_per_px: float = 8.0       # (px/s) per px of pull

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO
var strokes: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = get_global_mouse_position()
			drag_current = drag_start
			queue_redraw()
		else:
			if dragging and _apply_drag_shot():
				strokes += 1
				shot_taken.emit(strokes)
			dragging = false
			queue_redraw()

	elif event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()

func _physics_process(delta: float) -> void:
	# friction
	var speed: float = velocity.length()
	if speed > 0.0:
		speed = max(speed - friction * delta, 0.0)
		velocity = velocity.normalized() * speed

	# cap speed
	var vlen: float = velocity.length()
	if vlen > max_speed:
		velocity = velocity / vlen * max_speed

	# move + bounce
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal())

	# optional: face movement direction
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()

	speed_changed.emit(velocity.length())

func _apply_drag_shot() -> bool:
	var pull: Vector2 = drag_current - drag_start
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return false

	var shot_dir: Vector2 = (-pull).normalized()
	velocity += shot_dir * (pull_len * impulse_per_px)
	return true

func _draw() -> void:
	if not dragging:
		return

	var pull: Vector2 = drag_current - drag_start
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return

	var end_global: Vector2 = drag_start + pull.normalized() * pull_len
	var end_local: Vector2 = to_local(end_global)
	draw_line(Vector2.ZERO, end_local, Color.WHITE, 2.0)
