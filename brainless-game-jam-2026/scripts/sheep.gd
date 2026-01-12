extends CharacterBody2D
class_name Sheep

# =========================
#   FOLLOW (TRAIL) TUNING
# =========================
@export var follow_distance: float = 55.0
@export var slow_radius: float = 160.0
@export var follow_speed: float = 650.0
@export var accel: float = 2400.0
@export var brake_accel: float = 2600.0
@export var teleport_distance: float = 750.0

# =========================
#   WANDER (IDLE) TUNING
# =========================
@export var home_radius: float = 360.0          # sheep tries to remain within this radius of home_position
@export var wander_radius: float = 240.0        # max random target offset from current position
@export var wander_speed: float = 220.0
@export var wander_arrive_dist: float = 14.0
@export var wander_pause_range: Vector2 = Vector2(0.8, 2.0)
@export var wander_move_range: Vector2 = Vector2(1.2, 3.0)

# =========================
#   DOG PRESSURE / PANIC
# =========================
@export var dog_path: NodePath                 # assign the dog/player node in inspector
@export var alert_radius: float = 260.0        # sheep becomes alert (faces away, starts moving)
@export var panic_radius: float = 150.0        # sheep runs away quickly
@export var panic_speed: float = 560.0
@export var panic_accel: float = 3200.0
@export var calm_time: float = 1.2             # time with dog far before returning to wander

# =========================
#   FLOCKING (LIGHTWEIGHT)
# =========================
@export var neighbor_radius: float = 140.0
@export var separation_radius: float = 55.0
@export var cohesion_weight: float = 0.55
@export var separation_weight: float = 1.15
@export var alignment_weight: float = 0.30
@export var max_flock_force: float = 650.0

# =========================
#   RANDOM PERSONALITY
# =========================
@export var randomize_stats: bool = true
@export var speed_mult_range: Vector2 = Vector2(0.85, 1.25)       # affects wander/follow speed
@export var nervousness_range: Vector2 = Vector2(0.70, 1.40)      # affects acceleration + panic tendency
@export var stubbornness_range: Vector2 = Vector2(0.60, 1.30)     # affects how strongly they resist pen entry / how long they pause

var speed_mult: float = 1.0
var nervousness: float = 1.0
var stubbornness: float = 1.0

# =========================
#   STATE
# =========================
enum State { WANDER, PANIC, FOLLOW }
var state: State = State.WANDER

var target: Node2D = null
var in_trail: bool = false

var dog: Node2D = null
var home_position: Vector2
var calm_timer: float = 0.0

# Wander timers/targets
var wander_target: Vector2
var wander_move_timer: float = 0.0
var wander_pause_timer: float = 0.0
var is_paused: bool = false

# Cached
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var neigh_query: Area2D = get_node_or_null("NeighborArea") # optional (faster), otherwise uses groups

func _ready() -> void:
	home_position = global_position

	if dog_path != NodePath():
		dog = get_node_or_null(dog_path)

	# Optional: if you use groups, add sheep to group for neighbor scan
	# Project Settings -> Groups: "sheep"
	add_to_group("sheep")

	if randomize_stats:
		randomize()
		speed_mult = randf_range(speed_mult_range.x, speed_mult_range.y)
		nervousness = randf_range(nervousness_range.x, nervousness_range.y)
		stubbornness = randf_range(stubbornness_range.x, stubbornness_range.y)

		# Apply modifiers
		follow_speed *= speed_mult
		wander_speed *= speed_mult
		panic_speed *= lerp(0.9, 1.2, clamp(nervousness - 0.7, 0.0, 1.0))
		accel *= nervousness
		brake_accel *= nervousness
		panic_accel *= nervousness

		# Stubborn sheep pause longer and move a bit less decisively
		wander_pause_range = Vector2(wander_pause_range.x * stubbornness, wander_pause_range.y * stubbornness)
		wander_arrive_dist *= lerp(1.0, 1.35, clamp(stubbornness - 1.0, 0.0, 1.0))

	_pick_new_wander_target()
	_set_anim_idle()

# =========================
#   PUBLIC API
# =========================
func join_trail(t: Node2D) -> void:
	target = t
	in_trail = true
	state = State.FOLLOW
	col.disabled = false

func leave_trail() -> void:
	in_trail = false
	target = null
	state = State.WANDER
	_pick_new_wander_target()

# =========================
#   MAIN LOOP
# =========================
func _physics_process(delta: float) -> void:
	# If you have a dog reference, decide PANIC/WANDER unless in FOLLOW
	if state != State.FOLLOW:
		_update_panic_state(delta)

	# FOLLOW overrides panic/wander (because you explicitly "captured" it into a trail)
	if in_trail and target != null:
		state = State.FOLLOW

	match state:
		State.FOLLOW:
			_process_follow(delta)
		State.PANIC:
			_process_panic(delta)
		State.WANDER:
			_process_wander(delta)

	move_and_slide()

# =========================
#   STATE DECISION: PANIC
# =========================
func _update_panic_state(delta: float) -> void:
	if dog == null:
		state = State.WANDER
		return

	var to_dog = dog.global_position - global_position
	var dist = to_dog.length()

	if dist <= panic_radius:
		state = State.PANIC
		calm_timer = 0.0
		return

	if dist <= alert_radius:
		# Alert: still WANDER, but will bias movement away in wander logic
		state = State.WANDER
		calm_timer = 0.0
		return

	# Dog is far: count down to calm (prevents rapid toggling)
	calm_timer += delta
	if calm_timer >= calm_time:
		state = State.WANDER

# =========================
#   WANDER
# =========================
func _process_wander(delta: float) -> void:
	# Pause/move cycle
	if is_paused:
		wander_pause_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, brake_accel * delta)
		_set_anim_idle()

		if wander_pause_timer <= 0.0:
			is_paused = false
			wander_move_timer = randf_range(wander_move_range.x, wander_move_range.y)
			_pick_new_wander_target()
		return

	wander_move_timer -= delta
	if wander_move_timer <= 0.0:
		is_paused = true
		wander_pause_timer = randf_range(wander_pause_range.x, wander_pause_range.y)
		return

	# Ensure we don't drift too far from home_position (keeps herds on-map)
	var home_offset = global_position - home_position
	if home_offset.length() > home_radius:
		wander_target = home_position + home_offset.normalized() * (home_radius * 0.65)

	# Base direction toward wander target
	var to_target = wander_target - global_position
	var dist = to_target.length()

	if dist <= wander_arrive_dist:
		# choose a new point soon, but don't hard-stop instantly
		_pick_new_wander_target()

	var dir = Vector2.ZERO
	if dist > 0.001:
		dir = to_target / dist

	# If dog is near (alert zone), bias away even when not panicking
	if dog != null:
		var to_dog = dog.global_position - global_position
		var dog_dist = to_dog.length()
		if dog_dist <= alert_radius and dog_dist > 0.001:
			var away = (-to_dog / dog_dist)
			var t = clamp((alert_radius - dog_dist) / max(1.0, alert_radius - panic_radius), 0.0, 1.0)
			dir = (dir + away * (0.9 * t)).normalized()

	# Add lightweight flocking influence
	var flock_force = _compute_flock_force()
	dir = (dir + flock_force).normalized()

	var desired = dir * wander_speed
	velocity = velocity.move_toward(desired, accel * delta)
	_set_anim_walk()
	_face_velocity()

# =========================
#   PANIC (RUN AWAY HARD)
# =========================
func _process_panic(delta: float) -> void:
	if dog == null:
		state = State.WANDER
		return

	var to_dog = dog.global_position - global_position
	var dist = to_dog.length()

	# If we somehow exited panic zone, calm via timer logic
	if dist > panic_radius:
		# drift back to wander slowly but keep moving away a bit
		velocity = velocity.move_toward(Vector2.ZERO, brake_accel * delta)
		_set_anim_run()
		return

	var away = Vector2.ZERO
	if dist > 0.001:
		away = (-to_dog / dist)

	# Panic also respects flock separation slightly to prevent stacking
	var sep_force = _compute_separation_only()
	var dir = (away + sep_force).normalized()

	var desired = dir * panic_speed
	velocity = velocity.move_toward(desired, panic_accel * delta)
	_set_anim_run()
	_face_velocity()

# =========================
#   FOLLOW (YOUR ORIGINAL, CLEANED)
# =========================
func _process_follow(delta: float) -> void:
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, brake_accel * delta)
		_set_anim_idle()
		return

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	if dist > teleport_distance:
		global_position = target.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		velocity = Vector2.ZERO
		return

	if abs(to_target.x) > 0.1:
		spr.flip_h = to_target.x > 0.0

	if dist <= follow_distance:
		velocity = velocity.move_toward(Vector2.ZERO, brake_accel * delta)
		_set_anim_idle()
		return

	var dir = Vector2.ZERO
	if dist > 0.001:
		dir = to_target / dist

	var factor = 1.0
	if dist < slow_radius:
		factor = clamp((dist - follow_distance) / max(1.0, slow_radius - follow_distance), 0.0, 1.0)
		factor = ease(factor, 0.8)

	var desired = dir * (follow_speed * factor)
	velocity = velocity.move_toward(desired, accel * delta)
	_set_anim_run()

# =========================
#   FLOCKING (LIGHTWEIGHT)
# =========================
func _compute_flock_force() -> Vector2:
	# Strategy:
	# - Cohesion: move slightly toward neighbors center
	# - Separation: avoid crowding
	# - Alignment: match average neighbor velocity direction
	# Implemented with minimal loops; if too slow, reduce neighbor_radius or use an Area2D for overlap.
	var neighbors = _get_neighbors()
	if neighbors.size() == 0:
		return Vector2.ZERO

	var pos_sum = Vector2.ZERO
	var vel_sum = Vector2.ZERO
	var sep_sum = Vector2.ZERO
	var count = 0

	for n in neighbors:
		if n == self:
			continue

		var offset = n.global_position - global_position
		var d = offset.length()
		if d <= 0.001:
			continue
		if d > neighbor_radius:
			continue

		count += 1
		pos_sum += n.global_position
		vel_sum += n.velocity

		if d < separation_radius:
			sep_sum += (-offset / d) * ((separation_radius - d) / separation_radius)

	if count == 0:
		return Vector2.ZERO

	var center = pos_sum / float(count)
	var cohesion = (center - global_position).normalized()

	var alignment = Vector2.ZERO
	if vel_sum.length() > 0.001:
		alignment = (vel_sum / float(count)).normalized()

	var separation = Vector2.ZERO
	if sep_sum.length() > 0.001:
		separation = sep_sum.normalized()

	var force = cohesion * cohesion_weight + separation * separation_weight + alignment * alignment_weight
	if force.length() > 1.0:
		force = force.normalized()

	# Clamp to avoid overpowering player influence
	force *= min(1.0, max_flock_force / max(1.0, follow_speed))
	return force

func _compute_separation_only() -> Vector2:
	var neighbors = _get_neighbors()
	if neighbors.size() == 0:
		return Vector2.ZERO

	var sep_sum = Vector2.ZERO
	for n in neighbors:
		if n == self:
			continue
		var offset = n.global_position - global_position
		var d = offset.length()
		if d <= 0.001:
			continue
		if d < separation_radius:
			sep_sum += (-offset / d) * ((separation_radius - d) / separation_radius)

	if sep_sum.length() <= 0.001:
		return Vector2.ZERO

	return sep_sum.normalized() * 0.6

func _get_neighbors() -> Array:
	# Fast path if you provide a child Area2D named NeighborArea with a CircleShape2D sized to neighbor_radius.
	# Then use get_overlapping_bodies() (requires monitoring, collision layers/masks).
	if neigh_query != null and neigh_query.monitoring:
		var bodies = neigh_query.get_overlapping_bodies()
		# Filter sheep only
		var out = []
		for b in bodies:
			if b is Sheep:
				out.append(b)
		return out

	# Fallback: group scan (fine for small herds; for large herds, prefer Area2D overlap)
	return get_tree().get_nodes_in_group("sheep")

# =========================
#   WANDER TARGET PICKING
# =========================
func _pick_new_wander_target() -> void:
	var angle = randf_range(0.0, TAU)
	var dist = randf_range(60.0, wander_radius)

	var candidate = global_position + Vector2(cos(angle), sin(angle)) * dist

	# Keep candidate inside home radius soft boundary
	var from_home = candidate - home_position
	if from_home.length() > home_radius:
		candidate = home_position + from_home.normalized() * (home_radius * 0.9)

	wander_target = candidate

# =========================
#   ANIMATION HELPERS
# =========================
func _set_anim_idle() -> void:
	if spr.animation != "idle":
		spr.play("idle")

func _set_anim_walk() -> void:
	if spr.animation != "walk":
		spr.play("walk")
	else:
		if spr.animation != "idle":
			spr.play("idle")

func _set_anim_run() -> void:
	if spr.animation != "run":
		spr.play("run")
	else:
		if spr.animation != "walk":
			spr.play("walk")
		else:
			if spr.animation != "idle":
				spr.play("idle")

func _face_velocity() -> void:
	if abs(velocity.x) > 1.0:
		spr.flip_h = velocity.x > 0.0
