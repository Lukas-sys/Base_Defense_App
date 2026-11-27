class_name Station
extends Node3D
## Eine Maschine, die Zutaten verarbeitet: z. B. Weizen -> Pizza (Ofen) oder Weizen -> Nudeln.
## Vorne wird abgegeben (Eingang), seitlich liegt das fertige Essen (Ausgang).

const MAX_INPUT := 80
const MAX_OUTPUT := 40

var game: Game
var id := "oven"
var title := "Pizzaofen"
var input_kind := "wheat"
var output_kind := "pizza"
var base_time := 2.0
var input_stock := 0
var output_stock := 0
var timer := 0.0
var input_zone := Vector3.ZERO
var output_zone := Vector3.ZERO
var input_pile: Pile
var output_pile: Pile
var progress_item: Node3D
var body: Node3D
var steam: CPUParticles3D
var pulse := 0.0
var out_marker: Node3D
var belt = null  # Fließband zur Theke, wenn gekauft


func setup(g: Game, station_id: String, out_kind: String, color: Color) -> void:
	game = g
	id = station_id
	output_kind = out_kind
	body = Node3D.new()
	add_child(body)
	# Maschine: fertiges KayKit-Modell (Ofen bzw. Herd mit großem Topf), sonst einfache Formen
	var built := false
	if station_id == "oven":
		built = Models.add(body, "restaurant-bits/oven", 1.0, Vector3(0, 0, -0.15))
	else:
		built = Models.add(body, "restaurant-bits/stove_multi", 1.0, Vector3(0, 0, -0.15))
		if built:
			Models.add(body, "restaurant-bits/pot_large", 0.7, Vector3(0, 1.2, -0.2))
	if not built:
		var steel := Color(0.88, 0.9, 0.93)
		body.add_child(Util.box(Vector3(2.0, 1.25, 1.8), steel, Vector3(0, 0.625, 0)))
		body.add_child(Util.box(Vector3(2.08, 0.28, 1.88), color, Vector3(0, 1.3, 0)))
	body.add_child(Util.cylinder(0.14, 0.16, 1.2, Color(0.45, 0.47, 0.52), Vector3(-0.7, 2.3 if station_id == "oven" else 1.8, -0.75)))
	var sign := Util.billboard_label(title_for(station_id), 44, Color.WHITE)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	sign.outline_size = 8
	sign.position = Vector3(0, 0.25, 1.25)
	body.add_child(sign)
	# Dampf aus dem Schornstein
	steam = CPUParticles3D.new()
	steam.amount = 8
	steam.lifetime = 1.4
	steam.direction = Vector3.UP
	steam.spread = 12.0
	steam.initial_velocity_min = 0.6
	steam.initial_velocity_max = 1.0
	steam.gravity = Vector3(0, 0.3, 0)
	steam.scale_amount_min = 0.8
	steam.scale_amount_max = 1.6
	var puff := SphereMesh.new()
	puff.radius = 0.16
	puff.height = 0.32
	puff.radial_segments = 8
	puff.rings = 4
	steam.mesh = puff
	steam.material_override = Util.mat(Color(1, 1, 1))
	steam.position = Vector3(-0.7, 3.0 if station_id == "oven" else 2.5, -0.75)
	steam.emitting = false
	body.add_child(steam)
	# Förderband zum Ausgang mit Rollen und Beinen
	body.add_child(Util.box(Vector3(2.3, 0.12, 0.85), Color(0.42, 0.45, 0.5), Vector3(2.05, 0.68, 0), 0.3))
	var rx := 1.0
	while rx < 3.2:
		body.add_child(Util.box(Vector3(0.06, 0.02, 0.8), Color(0.7, 0.73, 0.78), Vector3(rx, 0.75, 0), 0.5))
		rx += 0.25
	body.add_child(Util.box(Vector3(2.3, 0.22, 0.1), color.darkened(0.1), Vector3(2.05, 0.74, 0.45), 0.4))
	body.add_child(Util.box(Vector3(2.3, 0.22, 0.1), color.darkened(0.1), Vector3(2.05, 0.74, -0.45), 0.4))
	for lx in [1.2, 2.9]:
		body.add_child(Util.box(Vector3(0.1, 0.62, 0.1), Color(0.35, 0.36, 0.4), Vector3(lx, 0.31, 0.3), 0.3))
		body.add_child(Util.box(Vector3(0.1, 0.62, 0.1), Color(0.35, 0.36, 0.4), Vector3(lx, 0.31, -0.3), 0.3))
	# Ablage für fertiges Essen
	body.add_child(Util.box(Vector3(1.5, 0.08, 1.4), Color(0.5, 0.52, 0.56), Vector3(3.5, 0.04, -0.05), 0.3))
	progress_item = Util.item(out_kind)
	progress_item.position = Vector3(1.0, 0.76, 0)
	body.add_child(progress_item)
	input_zone = position + Vector3(0, 0, 2.1)
	output_zone = position + Vector3(3.6, 0, 2.1)
	var in_marker := Util.zone_marker(Vector2(1.8, 1.6), Color(1, 1, 1, 1))
	in_marker.position = Vector3(0, 0, 2.1)
	add_child(in_marker)
	out_marker = Util.zone_marker(Vector2(1.8, 1.6), Color(0.45, 0.95, 0.35))
	out_marker.position = Vector3(3.6, 0, 2.1)
	add_child(out_marker)
	input_pile = Pile.new()
	input_pile.setup("wheat", 15, 3)
	input_pile.position = Vector3(-1.9, 0, 0.9)
	add_child(input_pile)
	output_pile = Pile.new()
	output_pile.setup(out_kind, MAX_OUTPUT, 2)
	output_pile.position = Vector3(3.2, 0.08, -0.35)
	add_child(output_pile)


func process_time() -> float:
	return base_time / (1.0 + 0.4 * game.level(id + "_speed"))


func wants_input() -> bool:
	return input_stock < MAX_INPUT


func _process(delta: float) -> void:
	if input_stock > 0 and output_stock < MAX_OUTPUT:
		timer += delta
		var t := clampf(timer / process_time(), 0.0, 1.0)
		progress_item.visible = true
		progress_item.position.x = lerpf(0.95, 3.1, t)
		steam.emitting = true
		pulse += delta * 14.0
		body.scale = Vector3(1.0 + sin(pulse) * 0.015, 1.0 - sin(pulse) * 0.015, 1.0)
		if timer >= process_time():
			timer = 0.0
			input_stock -= 1
			output_stock += 1
			_refresh()
	else:
		progress_item.visible = false
		steam.emitting = false
		body.scale = Vector3.ONE
	if belt != null and output_stock > 0 and belt.has_room():
		output_stock -= 1
		belt.push()
		_refresh()


## Mit Fließband gibt es kein Abholfeld mehr: alles fährt direkt zur Theke.
func attach_belt(b) -> void:
	belt = b
	out_marker.visible = false
	output_pile.visible = false


func put_input() -> void:
	input_stock += 1
	_refresh()


func take_output() -> void:
	output_stock -= 1
	_refresh()


func _refresh() -> void:
	input_pile.show_count(input_stock)
	output_pile.show_count(output_stock)


static func title_for(station_id: String) -> String:
	return "PIZZA" if station_id == "oven" else "NUDELN"
