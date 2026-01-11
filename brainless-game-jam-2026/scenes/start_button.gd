extends Button

@export var idle_scale_amp := 0.006   # tiny (0.004–0.008 range)
@export var idle_speed := 1.2         # calm, slow

var base_scale: Vector2
var t := 0.0

func _ready() -> void:
	base_scale = scale
	pivot_offset = size * 0.5
	t = randf() * TAU  # desync buttons

func _process(delta: float) -> void:
	t += delta * idle_speed
	var s := 1.0 + sin(t) * idle_scale_amp
	scale = base_scale * s
