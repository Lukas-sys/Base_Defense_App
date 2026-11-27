class_name Hud
extends CanvasLayer
## Bedienoberfläche: Geld, Standort-Bonus, Aufgabe und Joystick.

var game: Game
var joystick: Joystick
var money_label: Label
var bonus_label: Label
var goal_label: Label
var goal_panel: PanelContainer
var shown_money := 0.0
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
	var theme := Theme.new()
	theme.default_font = Util.font()
	root.theme = theme
	add_child(root)

	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(joystick)

	# Geldanzeige oben rechts: Geldschein-Symbol + Betrag in einer runden "Pille"
	var money_bg := PanelContainer.new()
	money_bg.anchor_left = 1.0
	money_bg.anchor_right = 1.0
	money_bg.offset_left = -290
	money_bg.offset_right = -24
	money_bg.offset_top = 28
	money_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_bg.add_theme_stylebox_override("panel", _pill(Color(0.18, 0.2, 0.24, 0.82)))
	root.add_child(money_bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_bg.add_child(row)
	var bill := PanelContainer.new()
	bill.custom_minimum_size = Vector2(62, 40)
	bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bill_style := StyleBoxFlat.new()
	bill_style.bg_color = Color(0.42, 0.82, 0.34)
	bill_style.set_corner_radius_all(8)
	bill.add_theme_stylebox_override("panel", bill_style)
	var band := ColorRect.new()
	band.color = Color(0.98, 0.85, 0.35)
	band.custom_minimum_size = Vector2(12, 40)
	band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bill.add_child(band)
	row.add_child(bill)
	money_label = _label(42, Color.WHITE)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(money_label)

	# Standort und Bonus oben links
	bonus_label = _label(24, Color.WHITE)
	bonus_label.position = Vector2(24, 30)
	root.add_child(bonus_label)

	# Aktuelle Aufgabe
	goal_panel = PanelContainer.new()
	goal_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	goal_panel.offset_left = -300
	goal_panel.offset_right = 300
	goal_panel.offset_top = 128
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_panel.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.92)))
	root.add_child(goal_panel)
	goal_label = _label(28, Color(0.22, 0.2, 0.24))
	goal_label.add_theme_constant_override("outline_size", 0)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(goal_label)

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
	# Geldanzeige zählt weich hoch/runter
	shown_money = lerpf(shown_money, game.money, 1.0 - exp(-12.0 * delta))
	if absf(shown_money - game.money) < 1.0:
		shown_money = game.money
	money_label.text = Util.money_text(floor(shown_money))
	bonus_label.text = "Standort %d\nEinnahmen x%s" % [game.stars + 1, str(game.income_multiplier())]
	var goal := game.goal_text()
	goal_panel.visible = goal != ""
	goal_label.text = goal
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


func _pill(color: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(40)
	st.content_margin_left = 22
	st.content_margin_right = 26
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.shadow_color = Color(0, 0, 0, 0.18)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 3)
	return st


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l
