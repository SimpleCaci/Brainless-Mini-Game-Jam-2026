# Transition.gd (attach to a CanvasLayer that has: ColorRect named Fade)
extends CanvasLayer
@onready var fade: ColorRect = $Fade

func fade_to_scene(path: String, dur: float = 0.35) -> void:
	fade.set_visible(true)
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, dur)
	t.tween_callback(func(): get_tree().change_scene_to_file(path))
	t.tween_property(fade, "color:a", 0.0, dur)
	t.tween_callback(func(): fade.visible = false)
