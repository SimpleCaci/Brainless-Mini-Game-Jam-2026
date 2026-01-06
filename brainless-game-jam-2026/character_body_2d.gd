extends CharacterBody2D

@export var max_speed: float = 1800.0
@export var friction: float = 1400.0          # px/s^2
@export var max_pull: float = 250.0           # px
@export var impulse_per_px: float = 8.0       # (px/s) per px of pull

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = get_global_mouse_position()
			drag_current = drag_start
		else:
			if dragging:
				_apply_drag_shot()
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	# Friction / deceleration
	var speed: float = velocity.length()
	if speed > 0.0:
		speed = max(speed - friction * delta, 0.0)
		velocity = velocity.normalized() * speed

	# Cap speed
	var vlen: float = velocity.length()
	if vlen > max_speed:
		velocity = velocity / vlen * max_speed

	move_and_slide()

func _apply_drag_shot() -> void:
	var pull: Vector2 = drag_current - drag_start
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return

	# Golf-style: release shoots opposite the pull direction
	var shot_dir: Vector2 = (-pull).normalized()
	var impulse: Vector2 = shot_dir * (pull_len * impulse_per_px)

	velocity += impulse

func _process(_delta: float) -> void:
	if dragging:
		queue_redraw()

func _draw() -> void:
	if not dragging:
		return

	var pull: Vector2 = drag_current - drag_start
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return

	# Draw a simple aim/pull line from the ball (local origin) toward the dragged point
	var end_global: Vector2 = drag_start + pull.normalized() * pull_len
	var end_local: Vector2 = to_local(end_global)

	draw_line(Vector2.ZERO, end_local, Color.WHITE, 2.0)
