class_name Station
extends Node3D
## Eine Maschine, die Zutaten verarbeitet: z. B. Weizen -> Pizza (Ofen) oder Weizen -> Nudeln.
## Vorne wird abgegeben (Eingang), seitlich liegt das fertige Essen (Ausgang).

const MAX_INPUT := 30
const MAX_OUTPUT := 24

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


func setup(g: Game, station_id: String, out_kind: String, color: Color) -> void:
	game = g
	id = station_id
	output_kind = out_kind
	body = Node3D.new()
	add_child(body)
	# Maschine
	body.add_child(Util.box(Vector3(2.0, 1.2, 1.8), Color(0.45, 0.47, 0.5), Vector3(0, 0.6, 0)))
	body.add_child(Util.box(Vector3(2.1, 0.25, 1.9), color, Vector3(0, 1.3, 0)))
	body.add_child(Util.cylinder(0.35, 0.45, 0.9, Color(0.35, 0.36, 0.4), Vector3(-0.5, 1.9, 0.2)))
	body.add_child(Util.box(Vector3(0.9, 0.5, 0.06), Color(0.2, 0.2, 0.22), Vector3(0, 0.6, 0.91)))
	# Förderband zum Ausgang
	body.add_child(Util.box(Vector3(2.2, 0.15, 0.9), Color(0.7, 0.75, 0.8), Vector3(2.0, 0.65, 0)))
	body.add_child(Util.box(Vector3(2.2, 0.5, 0.15), Color(0.4, 0.45, 0.55), Vector3(2.0, 0.35, 0.4)))
	body.add_child(Util.box(Vector3(2.2, 0.5, 0.15), Color(0.4, 0.45, 0.55), Vector3(2.0, 0.35, -0.4)))
	progress_item = Util.item(out_kind)
	progress_item.position = Vector3(1.0, 0.73, 0)
	body.add_child(progress_item)
	input_zone = position + Vector3(0, 0, 2.1)
	output_zone = position + Vector3(3.6, 0, 2.1)
	var in_marker := Util.zone_marker(Vector2(1.8, 1.6), Color(1, 1, 1, 1))
	in_marker.position = Vector3(0, 0, 2.1)
	add_child(in_marker)
	var out_marker := Util.zone_marker(Vector2(1.8, 1.6), Color(0.4, 0.95, 0.4))
	out_marker.position = Vector3(3.6, 0, 2.1)
	add_child(out_marker)
	input_pile = Pile.new()
	input_pile.setup("wheat", 15, 3)
	input_pile.position = Vector3(-1.9, 0, 0.9)
	add_child(input_pile)
	output_pile = Pile.new()
	output_pile.setup(out_kind, MAX_OUTPUT, 2)
	output_pile.position = Vector3(3.2, 0, -0.3)
	add_child(output_pile)


func process_time() -> float:
	return base_time / (1.0 + 0.35 * game.level(id + "_speed"))


func wants_input() -> bool:
	return input_stock < MAX_INPUT


func _process(delta: float) -> void:
	if input_stock > 0 and output_stock < MAX_OUTPUT:
		timer += delta
		var t := clampf(timer / process_time(), 0.0, 1.0)
		progress_item.visible = true
		progress_item.position.x = lerpf(0.9, 3.0, t)
		if timer >= process_time():
			timer = 0.0
			input_stock -= 1
			output_stock += 1
			_refresh()
	else:
		progress_item.visible = false


func put_input() -> void:
	input_stock += 1
	_refresh()


func take_output() -> void:
	output_stock -= 1
	_refresh()


func _refresh() -> void:
	input_pile.show_count(input_stock)
	output_pile.show_count(output_stock)
