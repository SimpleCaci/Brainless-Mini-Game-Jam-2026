extends Node2D

@export var dog_path: NodePath
@export var barn_path: NodePath

# Distance tuning (pixels)
@export var lock_on_distance := 4000.0
@export var max_spin_distance := 12000.0
@export var snap_distance := 250.0

# Spin behavior
@export var min_spin_speed := 0.5     # rad/sec (near)
@export var max_spin_speed := 6.5     # rad/sec (far)
@export var turn_speed := 9.0         # lock-on smoothness

# Visual polish
@export var wobble_amp := 0.015        # subtle organic motion
@export var wobble_speed := 1.8

# Sprite faces UP by default
@export var point_up_offset := PI / 2

@onready var dog: Node2D = get_node(dog_path)
@onready var barn: Node2D = get_node(barn_path)

var wobble_t := randf() * TAU

func _process(delta: float) -> void:
	if dog == null or barn == null:
		return

	var to_barn := barn.global_position - dog.global_position
	var dist := to_barn.length()

	wobble_t += delta * wobble_speed
	var wobble := sin(wobble_t) * wobble_amp

	if dist > lock_on_distance:
		# Distance → normalized spin factor
		var t = clamp(
			(dist - lock_on_distance) / (max_spin_distance - lock_on_distance),
			0.0, 1.0
		)
		t = t * t  # ease-in

		var spin = lerp(min_spin_speed, max_spin_speed, t)
		rotation += (spin * delta) + wobble
	else:
		var target_angle := to_barn.angle() + point_up_offset

		if dist < snap_distance:
			# Hard lock when very close
			rotation = target_angle
		else:
			# Smooth magnetic lock-on
			rotation = lerp_angle(rotation, target_angle, delta * turn_speed)
