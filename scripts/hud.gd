class_name Hud
extends CanvasLayer
## Bedienoberfläche: Geld, Standort-Bonus, Aufgabe und Joystick.

var game: Game
var joystick: Joystick
var money_label: Label
var bonus_label: Label
var goal_label: Label
var message_label: Label
var message_time := 0.0
var reset_button: Button
var reset_armed := 0.0


func setup(g: Game) -> void:
	game = g


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(joystick)

	# Geldanzeige oben rechts
	var money_bg := PanelContainer.new()
	money_bg.anchor_left = 1.0
	money_bg.anchor_right = 1.0
	money_bg.offset_left = -270
	money_bg.offset_right = -20
	money_bg.offset_top = 24
	money_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.75)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(10)
	style.border_color = Color(1, 1, 1, 0.9)
	style.set_border_width_all(3)
	money_bg.add_theme_stylebox_override("panel", style)
	root.add_child(money_bg)
	money_label = _label(44, Color(0.6, 1.0, 0.5))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_bg.add_child(money_label)

	# Standort und Bonus oben links
	bonus_label = _label(26, Color(1.0, 0.9, 0.5))
	bonus_label.position = Vector2(24, 30)
	root.add_child(bonus_label)

	# Aktuelle Aufgabe
	goal_label = _label(32, Color.WHITE)
	goal_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	goal_label.offset_left = -330
	goal_label.offset_right = 330
	goal_label.offset_top = 120
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(goal_label)

	# Meldungen
	message_label = _label(36, Color(1.0, 0.95, 0.55))
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.offset_left = -340
	message_label.offset_right = 340
	message_label.offset_top = -260
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message_label)

	# Neustart-Knopf (zweimal tippen)
	reset_button = Button.new()
	reset_button.text = "Neustart"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 20)
	reset_button.anchor_top = 1.0
	reset_button.anchor_bottom = 1.0
	reset_button.offset_left = 16
	reset_button.offset_top = -60
	reset_button.offset_right = 140
	reset_button.offset_bottom = -16
	reset_button.modulate = Color(1, 1, 1, 0.5)
	reset_button.pressed.connect(_on_reset)
	root.add_child(reset_button)


func _process(delta: float) -> void:
	money_label.text = "$ " + Util.money_text(floor(game.money))
	bonus_label.text = "Standort %d\nEinnahmen x%s" % [game.stars + 1, str(game.income_multiplier())]
	goal_label.text = game.goal_text()
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
	if reset_armed > 0.0:
		reset_armed -= delta
		if reset_armed <= 0.0:
			reset_button.text = "Neustart"


func show_message(text: String, seconds := 2.5) -> void:
	message_label.text = text
	message_time = seconds
	message_label.modulate.a = 1.0


func _on_reset() -> void:
	if reset_armed > 0.0:
		game.reset_save()
	else:
		reset_armed = 3.0
		reset_button.text = "Sicher?"
		show_message("Nochmal tippen, um den Spielstand zu löschen.")


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l
