extends CharacterBody2D

signal shot_taken(strokes: int)
signal speed_changed(speed: float)

@export var max_speed: float = 18000.0
@export var friction: float = 1000.0
@export var max_pull: float = 250.0
@export var impulse_per_px: float = 8.0

@export var max_tilt_deg: float = 25.0
@export var turn_speed: float = 14.0
@export var return_speed: float = 6.0

# Trail pickup (requires a child Area2D named PickupArea with a CollisionShape2D)
@export var max_followers: int = 30

@onready var spr: AnimatedSprite2D = $AnimatedSprite2D

var dragging: bool = false
var drag_current: Vector2 = Vector2.ZERO
var strokes: int = 0

var last_face_right: bool = false
var followers: Array[Node2D] = []

func _ready() -> void:
	if has_node("PickupArea"):
		$PickupArea.body_entered.connect(_on_pickup_body_entered)

func _on_pickup_body_entered(body: Node) -> void:
	if followers.size() >= max_followers:
		return
	if not body.has_method("join_trail"):
		return
	if body.get("in_trail") == true:
		return

	var leader: Node2D = self if followers.is_empty() else followers.back()
	body.call("join_trail", leader)
	followers.append(body)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_current = get_global_mouse_position()
			queue_redraw()
		else:
			if dragging and _shoot():
				strokes += 1
				shot_taken.emit(strokes)
			dragging = false
			queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()
		
func arrived_at_goal() -> void:
	max_speed = 10000000.0
	friction = -5
	$Popup.popup()
	
func _physics_process(delta: float) -> void:
	rotation = 0.0

	# friction
	var speed: float = velocity.length()
	if speed > 0.0:
		speed = max(speed - friction * delta, 0.0)
		velocity = velocity.normalized() * speed

	# cap speed
	if speed > max_speed:
		velocity = velocity.normalized() * max_speed

	# move + bounce (pure physics)
	var col: KinematicCollision2D = move_and_collide(velocity * delta)
	if col:
		velocity = velocity.bounce(col.get_normal())

	var moving: bool = velocity.length_squared() > 1.0

	# remember left/right while moving
	if moving and abs(velocity.x) > 0.1:
		last_face_right = velocity.x > 0.0

	# flip horizontally (art faces LEFT by default)
	# if art faces RIGHT by default → invert this
	spr.flip_h = last_face_right

	if moving:
		# during motion: follow trajectory (no clamp)
		var aim: float = atan2(velocity.y, abs(velocity.x))
		spr.rotation = lerp_angle(spr.rotation, aim, 1.0 - exp(-turn_speed * delta))
	else:
		# when stopped: clamp + return to clean pose
		var diff: float = wrapf(spr.rotation, -PI, PI)
		diff = clamp(diff, -deg_to_rad(max_tilt_deg), deg_to_rad(max_tilt_deg))
		spr.rotation = lerp_angle(spr.rotation, diff, 1.0 - exp(-return_speed * delta))

	speed_changed.emit(velocity.length())

func _shoot() -> bool:
	var pull: Vector2 = drag_current - global_position
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return false

	var shot_dir: Vector2 = (-pull).normalized()
	velocity += shot_dir * (pull_len * impulse_per_px)

	if abs(shot_dir.x) > 0.1:
		last_face_right = shot_dir.x > 0.0

	return true

func _draw() -> void:
	if not dragging:
		return

	var pull: Vector2 = drag_current - global_position
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len <= 0.0:
		return

	var end_global: Vector2 = global_position + pull.normalized() * pull_len
	draw_line(Vector2.ZERO, to_local(end_global), Color.WHITE, 2.0)
