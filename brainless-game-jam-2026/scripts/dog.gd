extends CharacterBody2D
"""
DOG BALL — Physics Slingshot (Godot 4.x) — FULL VERSION (NO := anywhere)

Includes:
- PickupArea sheep trail (connects body_entered, calls join_trail on sheep)
- Stable bounce (consumes remainder) to reduce jitter
- Camera shake (uses cam.make_current(), adds trauma on shot + bounces)
- Forgiving re-shoot (you can aim again when slow enough)
- Aim dots (strength = dot count), pull zoom, squash/pop

Required child nodes:
- AnimatedSprite2D  (name: AnimatedSprite2D)
- Camera2D          (name: Camera2D)
- AudioStreamPlayer2D (name: AudioStreamPlayer2D)
- Area2D            (name: PickupArea) with CollisionShape2D
Optional:
- Particles2D or CPUParticles2D (name: ImpactParticles)
"""

signal shot_taken(strokes: int)
signal speed_changed(speed: float)

signal stopped_changed(stopped: bool)
signal can_shoot_changed(can_shoot: bool)
signal stop_progress_changed(progress: float)

# ----------------------------
# Tuning
# ----------------------------
@export var max_speed: float = 1500.0
@export var friction: float = 1100.0

@export var bounce: float = 0.98
@export var max_bounces_per_frame: int = 3

@export var max_pull: float = 360.0
@export var impulse_per_px: float = 9.0
@export var min_pull_to_shoot: float = 6.0

# Aim gating (forgiving)
@export var aim_lock_speed: float = 60.0
@export var can_shoot_speed: float = 80.0

# Stop detection for HUD
@export var stop_speed: float = 18.0
@export var settle_time: float = 0.20
@export var auto_zero_velocity: bool = true

# Camera zoom
@export var base_zoom: Vector2 = Vector2(1.5, 1.5)
@export var pulled_zoom: Vector2 = Vector2(0.8, 0.8)
@export var zoom_out_lerp_speed: float = 9.0
@export var zoom_in_lerp_speed: float = 2.2
@export var drag_relax_speed: float = 7.0

# Aim dots
@export var aim_dot_radius: float = 2.7
@export var aim_dot_spacing: float = 10.0
@export var aim_color: Color = Color(1, 1, 1, 1)
@export var aim_min_alpha: float = 0.25
@export var aim_min_dots: int = 2
@export var aim_max_dots: int = 24

# Juice: squash/pops
@export var pull_squash_amount: float = 0.20
@export var pull_squash_speed: float = 16.0
@export var release_pop_amount: float = 0.11
@export var release_pop_speed: float = 20.0
@export var pop_duration: float = 0.10
@export var impact_pop: float = 0.07
@export var impact_pop_speed: float = 18.0

# Shake
@export var shake_decay: float = 2.6
@export var max_shake_offset: float = 12.0
@export var max_shake_rotation_deg: float = 2.4
@export var shot_shake: float = 0.65
@export var bounce_shake: float = 0.32

# Optional keyboard nudges
@export var enable_nudges: bool = true
@export var nudge_force: float = 650.0
@export var nudge_max_speed_bonus: float = 1.12

# Optional SPACE boop
@export var enable_boop: bool = true
@export var boop_impulse: float = 260.0

# Sheep trail
@export var max_followers: int = 30

# Optional transition layer (your fade script)
@export var transition: CanvasLayer


@export var next_level_path: String = "res://scenes/win.tscn"

# ----------------------------
# Nodes
# ----------------------------
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var cam: Camera2D = $Camera2D
@onready var sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var impact_particles: CPUParticles2D = get_node_or_null("ImpactParticles") as CPUParticles2D

# ----------------------------
# State
# ----------------------------
var dragging: bool = false
var drag_current: Vector2 = Vector2.ZERO
var strokes: int = 0
var last_face_right: bool = false

var followers: Array[Node2D] = []

# Shake state
var trauma: float = 0.0
var base_cam_offset: Vector2 = Vector2.ZERO
var base_cam_rotation: float = 0.0

# Squash/pops
var base_sprite_scale: Vector2 = Vector2.ONE
var pop_timer: float = 0.0
var impact_pop_timer: float = 0.0

# Stop state
var is_stopped: bool = true
var can_shoot: bool = true
var settle_timer: float = 0.0

func _ready() -> void:
	drag_current = global_position
	base_cam_offset = cam.offset
	base_cam_rotation = cam.rotation
	base_sprite_scale = spr.scale

	cam.make_current()

	# IMPORTANT: PickupArea hookup (for sheep following)
	if has_node("PickupArea"):
		$PickupArea.body_entered.connect(_on_pickup_body_entered)
	else:
		push_error("Dog: missing PickupArea (Area2D) child.")

	_emit_state_signals(true)

func _on_pickup_body_entered(body: Node) -> void:
	if body == self:
		return
	if followers.size() >= max_followers:
		return
	if not (body is Node2D):
		return
	if not body.has_method("join_trail"):
		return
	if body.get("in_trail") == true:
		return

	var leader: Node2D = self if followers.is_empty() else followers[followers.size() - 1]
	body.call("join_trail", leader)
	followers.append(body)

func _process(_delta: float) -> void:
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		sfx.stop()
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _can_start_aim():
				return
			dragging = true
			drag_current = get_global_mouse_position()
			queue_redraw()

			if not sfx.playing:
				sfx.pitch_scale = 1.0
				sfx.play()
		else:
			if dragging:
				sfx.stop()
				if _shoot_from_drag():
					strokes += 1
					shot_taken.emit(strokes)
					pop_timer = pop_duration
			dragging = false
			queue_redraw()

	elif event is InputEventMouseMotion and dragging:
		drag_current = get_global_mouse_position()
		queue_redraw()

func arrived_at_goal() -> void:
	get_tree().change_scene_to_file(next_level_path)

func _physics_process(delta: float) -> void:
	if not dragging:
		drag_current = drag_current.lerp(global_position, drag_relax_speed * delta)

	var pull_vec: Vector2 = drag_current - global_position
	var pull_len: float = min(pull_vec.length(), max_pull)
	var pull_t: float = clamp(pull_len / max_pull, 0.0, 1.0)
	pull_t = ease(pull_t, 0.8)

	var desired_zoom: Vector2 = base_zoom.lerp(pulled_zoom, pull_t)
	var z_speed: float = zoom_out_lerp_speed if pull_t > 0.01 else zoom_in_lerp_speed
	cam.zoom = cam.zoom.lerp(desired_zoom, z_speed * delta)

	if dragging and sfx.playing:
		var target_pitch: float = lerp(0.85, 1.35, pull_t)
		sfx.pitch_scale = lerp(sfx.pitch_scale, target_pitch, clamp(10.0 * delta, 0.0, 1.0))

	_update_squash(delta, pull_t)

	if enable_nudges:
		_apply_nudges(delta)

	# friction
	var speed: float = velocity.length()
	if speed > 0.0:
		speed = max(speed - friction * delta, 0.0)
		velocity = velocity.normalized() * speed

	# cap speed
	var cap: float = max_speed * (nudge_max_speed_bonus if enable_nudges else 1.0)
	if velocity.length() > cap:
		velocity = velocity.normalized() * cap

	# stable bounce move
	_move_and_bounce(delta)

	_update_visuals(delta)
	_update_state(delta)
	_update_shake(delta)

	speed_changed.emit(velocity.length())

	if enable_boop and Input.is_action_just_pressed("ui_accept"):
		var d: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if d.length_squared() < 0.0001:
			d = Vector2.RIGHT
		velocity += d.normalized() * boop_impulse
		add_trauma(0.25)

func _can_start_aim() -> bool:
	return (velocity.length() < aim_lock_speed) and (not dragging)

func _shoot_from_drag() -> bool:
	var pull: Vector2 = drag_current - global_position
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len < min_pull_to_shoot:
		return false

	var dir: Vector2 = (-pull).normalized()
	var power: float = pull_len * impulse_per_px
	velocity += dir * power

	sfx.pitch_scale = 1.0
	sfx.play()
	add_trauma(shot_shake)

	settle_timer = 0.0
	_set_stopped(false)

	return true

func _move_and_bounce(delta: float) -> void:
	var remaining: Vector2 = velocity * delta
	var b: int = 0

	while b < max_bounces_per_frame and remaining.length_squared() > 0.000001:
		var col: KinematicCollision2D = move_and_collide(remaining)
		if col == null:
			break

		remaining = col.get_remainder()

		var n: Vector2 = col.get_normal()
		velocity = velocity.bounce(n) * bounce

		add_trauma(bounce_shake)
		impact_pop_timer = 0.10
		_emit_impact_particles(col.get_position(), n)

		if auto_zero_velocity and velocity.length() < stop_speed * 0.75:
			velocity = Vector2.ZERO
			break

		b += 1

func _apply_nudges(delta: float) -> void:
	var x: float = Input.get_axis("ui_left", "ui_right")
	var y: float = Input.get_axis("ui_up", "ui_down")
	var dir: Vector2 = Vector2(x, y)

	if dir.length_squared() < 0.001:
		return

	dir = dir.normalized()

	var slow_boost: float = 1.0
	if velocity.length() < 180.0:
		slow_boost = 1.35

	velocity += dir * (nudge_force * slow_boost) * delta

func _update_state(delta: float) -> void:
	var v: float = velocity.length()

	if v <= stop_speed:
		settle_timer += delta
		var prog: float = clamp(settle_timer / max(settle_time, 0.0001), 0.0, 1.0)
		stop_progress_changed.emit(prog)
		if settle_timer >= settle_time:
			_set_stopped(true)
			if auto_zero_velocity:
				velocity = Vector2.ZERO
	else:
		settle_timer = 0.0
		stop_progress_changed.emit(0.0)
		_set_stopped(false)

	var new_can_shoot: bool = (v < can_shoot_speed) and (not dragging)
	if new_can_shoot != can_shoot:
		can_shoot = new_can_shoot
		can_shoot_changed.emit(can_shoot)

func _set_stopped(stopped: bool) -> void:
	if stopped == is_stopped:
		return
	is_stopped = stopped
	stopped_changed.emit(is_stopped)

func _emit_state_signals(force: bool) -> void:
	if not force:
		return
	stopped_changed.emit(is_stopped)
	can_shoot_changed.emit(can_shoot)
	stop_progress_changed.emit(1.0 if is_stopped else 0.0)

func _update_visuals(delta: float) -> void:
	var moving: bool = velocity.length_squared() > 1.0

	if moving and abs(velocity.x) > 0.1:
		last_face_right = velocity.x > 0.0
	spr.flip_h = last_face_right

	if impact_pop_timer > 0.0:
		impact_pop_timer = max(impact_pop_timer - delta, 0.0)
		var amt: float = impact_pop * (impact_pop_timer / 0.10)
		var pop_scale: Vector2 = base_sprite_scale * Vector2(1.0 + amt, 1.0 - amt)
		spr.scale = spr.scale.lerp(pop_scale, impact_pop_speed * delta)
		return

	if moving:
		spr.play("run")
	else:
		spr.play("idle")

func _draw() -> void:
	if not dragging:
		return

	var pull: Vector2 = drag_current - global_position
	var pull_len: float = min(pull.length(), max_pull)
	if pull_len < 1.0:
		return

	var dir: Vector2 = (-pull).normalized()
	var t: float = clamp(pull_len / max_pull, 0.0, 1.0)
	t = ease(t, 0.8)

	var dots: int = int(round(lerp(float(aim_min_dots), float(aim_max_dots), t)))
	dots = clamp(dots, aim_min_dots, aim_max_dots)

	var c: Color = aim_color
	c.a = lerp(aim_min_alpha, aim_color.a, t)

	var i: int = 0
	while i < dots:
		var dist: float = float(i + 1) * aim_dot_spacing
		draw_circle(dir * dist, aim_dot_radius, c)
		i += 1

func _update_squash(delta: float, t: float) -> void:
	var target_scale: Vector2 = base_sprite_scale

	if dragging and t > 0.001:
		var amt: float = pull_squash_amount * t
		target_scale = base_sprite_scale * Vector2(1.0 - amt, 1.0 + amt)
		spr.scale = spr.scale.lerp(target_scale, clamp(pull_squash_speed * delta, 0.0, 1.0))
		pop_timer = 0.0
		return

	if pop_timer > 0.0:
		pop_timer = max(pop_timer - delta, 0.0)
		var pop_t: float = pop_timer / max(pop_duration, 0.0001)
		var pop_amt: float = release_pop_amount * pop_t
		target_scale = base_sprite_scale * Vector2(1.0 + pop_amt, 1.0 - pop_amt)
		spr.scale = spr.scale.lerp(target_scale, clamp(release_pop_speed * delta, 0.0, 1.0))
		return

	spr.scale = spr.scale.lerp(base_sprite_scale, clamp(release_pop_speed * delta, 0.0, 1.0))

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _update_shake(delta: float) -> void:
	if trauma <= 0.0:
		cam.offset = cam.offset.lerp(base_cam_offset, 12.0 * delta)
		cam.rotation = lerp(cam.rotation, base_cam_rotation, 12.0 * delta)
		return

	trauma = max(trauma - shake_decay * delta, 0.0)
	var s: float = trauma * trauma

	cam.offset = base_cam_offset + Vector2(
		randf_range(-1.0, 1.0) * max_shake_offset * s,
		randf_range(-1.0, 1.0) * max_shake_offset * s
	)

	cam.rotation = base_cam_rotation + deg_to_rad(max_shake_rotation_deg) * randf_range(-1.0, 1.0) * s

func _emit_impact_particles(world_pos: Vector2, normal: Vector2) -> void:
	if impact_particles == null:
		return
	impact_particles.global_position = world_pos
	impact_particles.rotation = normal.angle()
	impact_particles.emitting = false
	impact_particles.emitting = true
