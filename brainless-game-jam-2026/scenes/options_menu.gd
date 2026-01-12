# OptionsMenu_ComfyCredits.gd (Godot 4)
# Pure-script OPTIONS scene that matches your vibe: minimal text, strong credits focus, comfy layout.
# Attach to a Control node in OptionsMenu.tscn.

extends Control

@export var back_scene_path: String = "res://scenes/main_menu.tscn"

@export var creator_name: String = "SimpleCaci"
@export var artist_name: String = "Pia"
@export var artist_instagram: String = "https://www.instagram.com/ch1yoxx/"

# If these buses don't exist, it won't error; it just won't apply.
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# Keep settings tiny (less text).
var _settings := {
	"music_volume": 0.85,
	"sfx_volume": 0.85
}

# Soft/pastel pixel-ish palette (close to your screenshot vibe)
const COL_BG_TOP   := Color(0.73, 0.86, 0.95, 0.2) # sky
const COL_BG_BOT   := Color(0.77, 0.88, 0.75, 0.2) # field
const COL_PANEL    := Color(0.74, 0.72, 0.67, 0.5) # button/panel beige
const COL_BORDER   := Color(0.25, 0.24, 0.23, 0.7) # dark outline
const COL_TEXT     := Color(0.15, 0.14, 0.13, 1)
const COL_MUTED    := Color(0.28, 0.27, 0.26, 0.7)
const COL_LINK     := Color(0.15, 0.35, 0.55, 1)

func _ready() -> void:
	_build_ui()
	_apply_all()

func _build_ui() -> void:
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# Background gradient (sky -> field)
	var bg := ColorRect.new()
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.color = COL_BG_TOP
	add_child(bg)

	var field := ColorRect.new()
	field.anchor_left = 0
	field.anchor_top = 0.55
	field.anchor_right = 1
	field.anchor_bottom = 1
	field.color = COL_BG_BOT
	add_child(field)

	# Center column
	var center := CenterContainer.new()
	center.anchor_left = 0
	center.anchor_top = 0
	center.anchor_right = 1
	center.anchor_bottom = 1
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	center.add_child(panel)

	panel.add_theme_stylebox_override("panel", _panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	# Small title (less text)
	var title := Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_TEXT)
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.55))
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)

	# Credits card (main focus)
	root.add_child(_credits_card())

	# Tiny settings row (minimal)
	var mini := VBoxContainer.new()
	mini.add_theme_constant_override("separation", 8)
	root.add_child(mini)

	mini.add_child(_mini_slider("Music", _settings["music_volume"], func(v):
		_settings["music_volume"] = v
		_set_bus_volume(BUS_MUSIC, v)
	))
	mini.add_child(_mini_slider("SFX", _settings["sfx_volume"], func(v):
		_settings["sfx_volume"] = v
		_set_bus_volume(BUS_SFX, v)
	))

	# Buttons
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	root.add_child(btns)

	var insta := _nice_button("Pia Art")
	insta.pressed.connect(func(): OS.shell_open(artist_instagram))
	btns.add_child(insta)

	var back := _nice_button("Back")
	back.pressed.connect(_go_back)
	btns.add_child(back)

func _credits_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(true))
	card.custom_minimum_size = Vector2(0, 200)

	var pad := VBoxContainer.new()
	pad.add_theme_constant_override("separation", 10)
	card.add_child(pad)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.add_theme_color_override("default_color", COL_MUTED)

	# Less text, more “credit-y”, comfy, centered, with a clean link.
	var bb := ""
	bb += "[center]"
	bb += "Made with love.\n\n"
	bb += "[b]%s[/b]\n" % creator_name
	bb += "Creator\n\n"
	bb += "[b]%s[/b]\n" % artist_name
	bb += "Artist\n\n"
	bb += "[url=%s][color=#%s]@ch1yoxx[/color][/url]\n" % [artist_instagram, _hex(COL_LINK)]
	bb += "[/center]"

	rt.text = bb
	rt.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	pad.add_child(rt)

	# Tiny footer line
	var foot := Label.new()
	foot.text = "Thank you for playing."
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", COL_TEXT)
	pad.add_child(foot)

	return card

func _mini_slider(label_text: String, initial: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", COL_TEXT)
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	slider.value_changed.connect(func(v: float): on_change.call(v))

	return row

func _nice_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(170, 44)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12

	var hover := normal.duplicate()
	hover.bg_color = Color(COL_PANEL.r + 0.03, COL_PANEL.g + 0.03, COL_PANEL.b + 0.03, COL_PANEL.a)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(COL_PANEL.r - 0.05, COL_PANEL.g - 0.05, COL_PANEL.b - 0.05, COL_PANEL.a)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", COL_TEXT)

	return b

func _panel_style(softer := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL if softer else Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.90)
	sb.border_color = COL_BORDER
	sb.border_width_left = 4 if softer else 5
	sb.border_width_top = 4 if softer else 5
	sb.border_width_right = 4 if softer else 5
	sb.border_width_bottom = 4 if softer else 5
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _go_back() -> void:
	get_tree().change_scene_to_file(back_scene_path)

func _apply_all() -> void:
	_set_bus_volume(BUS_MUSIC, _settings["music_volume"])
	_set_bus_volume(BUS_SFX, _settings["sfx_volume"])

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(linear, 0.0001, 1.0)))

func _hex(c: Color) -> String:
	return c.to_html(false)
