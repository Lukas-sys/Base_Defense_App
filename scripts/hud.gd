class_name Hud
extends CanvasLayer
## Die Bedienoberfläche: Rohstoffe, Lebensbalken, Upgrade-Knöpfe und Meldungen.

const UPGRADE_IDS := ["worker", "axe", "weapon", "wall", "tower"]

var main: Main
var joystick: Joystick
var wood_label: Label
var stone_label: Label
var phase_label: Label
var hq_bar: ProgressBar
var player_bar: ProgressBar
var buttons := {}
var night_button: Button
var message_label: Label
var message_time := 0.0
var game_over_panel: PanelContainer
var game_over_label: Label


func setup(game: Main) -> void:
	main = game


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	joystick = Joystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(joystick)

	# Oben links: Rohstoffe und Lebensbalken
	var info := VBoxContainer.new()
	info.position = Vector2(16, 12)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 4)
	root.add_child(info)
	wood_label = _label(26, Color(0.95, 0.75, 0.5))
	info.add_child(wood_label)
	stone_label = _label(26, Color(0.85, 0.88, 0.95))
	info.add_child(stone_label)
	info.add_child(_label(16, Color.WHITE, "Basis"))
	hq_bar = _bar(Color(0.85, 0.65, 0.2))
	info.add_child(hq_bar)
	info.add_child(_label(16, Color.WHITE, "Du"))
	player_bar = _bar(Color(0.3, 0.8, 0.35))
	info.add_child(player_bar)

	# Oben Mitte: Tag/Nacht-Anzeige
	phase_label = _label(28, Color.WHITE)
	phase_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.offset_left = -300
	phase_label.offset_right = 300
	phase_label.offset_top = 12
	root.add_child(phase_label)

	# Mitte: kurze Meldungen
	message_label = _label(30, Color(1.0, 0.95, 0.6))
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.offset_left = -400
	message_label.offset_right = 400
	message_label.offset_top = -160
	message_label.offset_bottom = -110
	root.add_child(message_label)

	# Rechts: Upgrade-Knöpfe
	var shop := VBoxContainer.new()
	shop.anchor_left = 1.0
	shop.anchor_right = 1.0
	shop.offset_left = -290
	shop.offset_right = -14
	shop.offset_top = 12
	shop.add_theme_constant_override("separation", 8)
	root.add_child(shop)
	for id in UPGRADE_IDS:
		var b := _button()
		b.pressed.connect(_on_upgrade_pressed.bind(id))
		shop.add_child(b)
		buttons[id] = b
	night_button = _button()
	night_button.text = "Nacht jetzt starten"
	night_button.pressed.connect(func() -> void: main.start_night_now())
	shop.add_child(night_button)

	_build_game_over(root)


func _process(delta: float) -> void:
	wood_label.text = "Holz: %d" % main.wood
	stone_label.text = "Stein: %d" % main.stone
	hq_bar.max_value = main.hq_max_hp
	hq_bar.value = main.hq_hp
	player_bar.max_value = main.player.max_hp
	player_bar.value = main.player.hp
	if main.is_night:
		phase_label.text = "NACHT %d  –  Gegner übrig: %d" % [main.day, main.enemies_left()]
		phase_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	else:
		phase_label.text = "Tag %d  –  Nacht beginnt in %d s" % [main.day, ceili(main.phase_time)]
		phase_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	for id in UPGRADE_IDS:
		var b: Button = buttons[id]
		b.text = main.upgrade_text(id)
		b.disabled = not main.can_buy(id)
	night_button.disabled = main.is_night
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)


func show_message(text: String, seconds := 2.5) -> void:
	message_label.text = text
	message_time = seconds
	message_label.modulate.a = 1.0


func show_game_over(days: int) -> void:
	game_over_label.text = "Deine Basis ist gefallen!\n\nDu hast %d Nächte überlebt." % (days - 1)
	game_over_panel.visible = true


func _on_upgrade_pressed(id: String) -> void:
	main.buy(id)


func _build_game_over(root: Control) -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.offset_left = -260
	game_over_panel.offset_right = 260
	game_over_panel.offset_top = -150
	game_over_panel.offset_bottom = 150
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	game_over_panel.add_theme_stylebox_override("panel", style)
	game_over_panel.visible = false
	root.add_child(game_over_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	game_over_panel.add_child(box)
	game_over_label = _label(28, Color.WHITE)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(game_over_label)
	var restart := _button()
	restart.text = "Nochmal spielen"
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	box.add_child(restart)


func _label(size: int, color: Color, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(276, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.32, 0.2, 0.9)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.42, 0.26, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.24, 0.15, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	return b
