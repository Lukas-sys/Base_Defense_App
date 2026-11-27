class_name Customer
extends Node3D
## Ein Kunde im Auto. Fährt an die Theke, bestellt, wartet aufs Essen, bezahlt und fährt weiter.

enum State { ARRIVING, WAITING, LEAVING }

const SPEED := 7.0

var game: Game
var state := State.ARRIVING
var order := {}  # z. B. {"pizza": 2, "pasta": 1}
var target_x := 0.0
var bubble: Label3D
var bubble_bg: Sprite3D
var car: Node3D
var drive_time := 0.0
var paid := 0.0


func setup(g: Game, wanted: Dictionary) -> void:
	game = g
	order = wanted


func _ready() -> void:
	var colors := [Color(0.3, 0.6, 0.95), Color(0.98, 0.55, 0.25), Color(0.98, 0.82, 0.3), Color(0.62, 0.45, 0.88), Color(0.95, 0.4, 0.45), Color(0.35, 0.8, 0.6)]
	var c: Color = colors[randi() % colors.size()]
	car = Node3D.new()
	add_child(car)
	var models := ["car_sedan", "car_hatchback", "car_stationwagon", "car_taxi"]
	if not Models.add(car, "city-builder-bits/" + models[randi() % models.size()], 3.2, Vector3(0, 0.18, 0), 90.0):
		_build_simple_car(c)
	bubble_bg = Sprite3D.new()
	bubble_bg.texture = Util.bubble_texture()
	bubble_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble_bg.no_depth_test = true
	bubble_bg.render_priority = 1
	bubble_bg.pixel_size = 0.01
	bubble_bg.position = Vector3(0, 2.6, 0)
	add_child(bubble_bg)
	bubble = Util.billboard_label("", 52, Color(0.2, 0.17, 0.17))
	bubble.outline_size = 0
	bubble.render_priority = 2
	bubble.position = Vector3(0, 2.6, 0)
	add_child(bubble)
	_update_bubble()


func _build_simple_car(c: Color) -> void:
	var glass := Color(0.72, 0.88, 0.98)
	car.add_child(Util.box(Vector3(2.7, 0.62, 1.45), c, Vector3(0, 0.6, 0), 0.5))
	car.add_child(Util.box(Vector3(1.6, 0.62, 1.32), c.lightened(0.1), Vector3(-0.2, 1.15, 0), 0.4))
	car.add_child(Util.box(Vector3(1.66, 0.42, 1.2), glass, Vector3(-0.2, 1.13, 0), 0.3))
	for x in [-0.85, 0.85]:
		for z in [-0.72, 0.72]:
			var wheel := Util.cylinder(0.3, 0.3, 0.22, Color(0.15, 0.15, 0.17), Vector3(x, 0.3, z))
			wheel.rotation_degrees = Vector3(90, 0, 0)
			car.add_child(wheel)


func _process(delta: float) -> void:
	match state:
		State.ARRIVING, State.WAITING:
			var dx := target_x - position.x
			if absf(dx) > 0.05:
				position.x += signf(dx) * minf(absf(dx), SPEED * delta)
				drive_time += delta
				car.position.y = absf(sin(drive_time * 18.0)) * 0.04
			else:
				car.position.y = 0.0
		State.LEAVING:
			position.x += SPEED * 1.3 * delta
			if position.x > Game.ROAD_END:
				queue_free()


func is_at_counter() -> bool:
	return state != State.LEAVING and absf(position.x - Game.COUNTER_POS.x) < 0.1 and target_x == Game.COUNTER_POS.x


func wants(kind: String) -> bool:
	return order.get(kind, 0) > 0


func is_done() -> bool:
	for k in order:
		if order[k] > 0:
			return false
	return true


func receive(kind: String, price: float) -> void:
	order[kind] -= 1
	paid += price
	_update_bubble()


func leave() -> void:
	state = State.LEAVING
	bubble.text = "Danke!"
	bubble.modulate = Color(0.2, 0.6, 0.25)
	bubble_bg.scale = Vector3(1.3, 1.0, 1)


func _update_bubble() -> void:
	var parts: PackedStringArray = []
	for k in order:
		if order[k] > 0:
			parts.append("%d %s" % [order[k], Game.ITEM_NAMES[k]])
	bubble.text = "\n".join(parts)
	bubble_bg.scale = Vector3(1.55, 0.35 + 0.65 * maxi(1, parts.size()), 1)
