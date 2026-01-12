extends Control

@onready var hover_sfx: AudioStreamPlayer2D = $hoverSFX
@onready var click_sfx: AudioStreamPlayer2D = $clickSFX

func _ready() -> void:
	for butt in get_tree().get_nodes_in_group("ui_buttons"):
		if butt is BaseButton:
			butt.mouse_entered.connect(Callable(self, "_on_hover"))
			butt.pressed.connect(Callable(self, "_on_click"))

func _on_hover() -> void:
	hover_sfx.stop()
	hover_sfx.play()

func _on_click() -> void:
	click_sfx.stop()
	click_sfx.play()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level1.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")
