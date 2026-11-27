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
var paid := 0.0


func setup(g: Game, wanted: Dictionary) -> void:
	game = g
	order = wanted


func _ready() -> void:
	var colors := [Color(0.25, 0.55, 0.9), Color(0.95, 0.5, 0.2), Color(0.95, 0.8, 0.25), Color(0.6, 0.35, 0.8), Color(0.9, 0.3, 0.35)]
	var c: Color = colors[randi() % colors.size()]
	add_child(Util.box(Vector3(2.6, 0.7, 1.4), c, Vector3(0, 0.6, 0)))
	add_child(Util.box(Vector3(1.5, 0.6, 1.3), c.lightened(0.15), Vector3(-0.2, 1.2, 0)))
	add_child(Util.box(Vector3(1.4, 0.45, 1.32), Color(0.7, 0.85, 0.95), Vector3(-0.2, 1.2, 0)))
	for x in [-0.85, 0.85]:
		for z in [-0.7, 0.7]:
			var wheel := Util.cylinder(0.28, 0.28, 0.2, Color(0.12, 0.12, 0.12), Vector3(x, 0.28, z))
			wheel.rotation_degrees = Vector3(90, 0, 0)
			add_child(wheel)
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.font_size = 64
	bubble.outline_size = 14
	bubble.pixel_size = 0.01
	bubble.position = Vector3(0, 2.4, 0)
	add_child(bubble)
	_update_bubble()


func _process(delta: float) -> void:
	match state:
		State.ARRIVING, State.WAITING:
			var dx := target_x - position.x
			if absf(dx) > 0.05:
				position.x += signf(dx) * minf(absf(dx), SPEED * delta)
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
	bubble.modulate = Color(0.5, 1.0, 0.5)


func _update_bubble() -> void:
	var parts: PackedStringArray = []
	for k in order:
		if order[k] > 0:
			parts.append("%d %s" % [order[k], Game.ITEM_NAMES[k]])
	bubble.text = "\n".join(parts)
