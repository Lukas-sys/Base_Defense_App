class_name Carrier
extends Node3D
## Grundlage für alle Figuren, die Dinge tragen können (Spieler und Personal).
## Getragene Gegenstände stapeln sich sichtbar vor der Figur.

const TRANSFER_INTERVAL := 0.08

var game: Game
var stack: Array[String] = []
var capacity := 4
var speed := 5.0
var harvest_radius := 0.9
var can_harvest := true
var transfer_timer := 0.0
var model: Node3D
var stack_root: Node3D
var walk_time := 0.0


func setup(g: Game) -> void:
	game = g


## Baut eine einfache Figur: Körper, Kopf, Mütze in der gewünschten Farbe.
func build_body(shirt: Color, cap: Color) -> void:
	model = Node3D.new()
	add_child(model)
	model.add_child(Util.capsule(0.32, 1.0, shirt, Vector3(0, 0.5, 0)))
	model.add_child(Util.sphere(0.33, Color(1.0, 0.8, 0.45), Vector3(0, 1.2, 0)))
	model.add_child(Util.sphere(0.34, cap, Vector3(0, 1.32, 0.02)))
	model.add_child(Util.box(Vector3(0.4, 0.06, 0.3), cap, Vector3(0, 1.32, -0.35)))
	model.add_child(Util.box(Vector3(0.07, 0.1, 0.05), Color(0.1, 0.1, 0.1), Vector3(0.12, 1.2, -0.31)))
	model.add_child(Util.box(Vector3(0.07, 0.1, 0.05), Color(0.1, 0.1, 0.1), Vector3(-0.12, 1.2, -0.31)))
	stack_root = Node3D.new()
	stack_root.position = Vector3(0, 0.55, -0.55)
	model.add_child(stack_root)


func is_full() -> bool:
	return stack.size() >= capacity


func has_item(kind: String) -> bool:
	return stack.has(kind)


func count_item(kind: String) -> int:
	return stack.count(kind)


func add_item(kind: String) -> void:
	stack.append(kind)
	_refresh_stack()


## Entfernt einen Gegenstand dieser Sorte (den obersten). Gibt true zurück, wenn es geklappt hat.
func take_item(kind: String) -> bool:
	for i in range(stack.size() - 1, -1, -1):
		if stack[i] == kind:
			stack.remove_at(i)
			_refresh_stack()
			return true
	return false


## Lässt sich in eine Richtung bewegen (Länge 0..1) und dreht die Figur passend.
func walk(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.05:
		model.position.y = 0.0
		return
	position += dir * speed * delta
	position = game.clamp_to_map(position)
	Util.face(model, dir)
	walk_time += delta
	model.position.y = absf(sin(walk_time * 12.0)) * 0.08


## Läuft zu einem Ziel. Gibt true zurück, wenn es erreicht ist.
func walk_to(target: Vector3, reach: float, delta: float) -> bool:
	var to := target - position
	to.y = 0.0
	if to.length() <= reach:
		model.position.y = 0.0
		return true
	walk(to.normalized(), delta)
	return false


func _refresh_stack() -> void:
	for child in stack_root.get_children():
		child.queue_free()
	var y := 0.0
	for kind in stack:
		var it := Util.item(kind)
		it.position = Vector3(0, y, 0)
		stack_root.add_child(it)
		y += Util.item_height(kind)
