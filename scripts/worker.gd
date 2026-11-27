class_name Worker
extends Node3D
## Ein angeheuerter Arbeiter: holt selbstständig Holz und Stein und bringt es zur Basis.

enum State { IDLE, TO_NODE, WORKING, RETURNING }

const SPEED := 3.5
const CAPACITY := 3
const WORK_TIME_PER_UNIT := 1.0
const WORK_RANGE := 1.4
const DROP_RANGE := 2.6

var main: Main
var state := State.IDLE
var target_node: ResourceNode
var carry := 0
var carry_kind := "wood"
var prefer_kind := "wood"
var work_timer := 0.0
var walk_time := 0.0
var model: Node3D
var tool_pivot: Node3D
var carry_box: MeshInstance3D


func setup(game: Main, first_kind: String) -> void:
	main = game
	prefer_kind = first_kind


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	model.add_child(Util.capsule(0.32, 1.3, Color(0.95, 0.55, 0.15), Vector3(0, 0.65, 0)))
	model.add_child(Util.sphere(0.25, Color(1.0, 0.82, 0.62), Vector3(0, 1.45, 0)))
	model.add_child(Util.cylinder(0.3, 0.3, 0.12, Color(0.9, 0.8, 0.2), Vector3(0, 1.65, 0)))
	tool_pivot = Node3D.new()
	tool_pivot.position = Vector3(0.4, 0.8, 0)
	model.add_child(tool_pivot)
	tool_pivot.add_child(Util.box(Vector3(0.07, 0.07, 0.7), Color(0.5, 0.33, 0.18), Vector3(0, 0, -0.3)))
	carry_box = Util.box(Vector3(0.5, 0.35, 0.35), Color(0.55, 0.35, 0.2), Vector3(0, 1.0, 0.35))
	carry_box.visible = false
	model.add_child(carry_box)


func _process(delta: float) -> void:
	if main.game_over:
		return
	match state:
		State.IDLE:
			target_node = main.find_nearest_resource(position, 1000.0, prefer_kind)
			if target_node == null:
				target_node = main.find_nearest_resource(position, 1000.0)
			if target_node != null:
				state = State.TO_NODE
		State.TO_NODE:
			if not target_node.is_available():
				state = State.RETURNING if carry > 0 else State.IDLE
			elif _walk_to(target_node.position, WORK_RANGE, delta):
				state = State.WORKING
				work_timer = 0.0
		State.WORKING:
			if not target_node.is_available():
				state = State.RETURNING if carry > 0 else State.IDLE
				return
			Util.face(model, target_node.position - position)
			work_timer += delta
			if work_timer >= WORK_TIME_PER_UNIT:
				work_timer = 0.0
				_swing()
				var got := target_node.harvest(1)
				if got > 0:
					carry += got
					carry_kind = target_node.kind
				if carry >= CAPACITY:
					state = State.RETURNING
			carry_box.visible = carry > 0
		State.RETURNING:
			_update_carry_look()
			if _walk_to(Vector3.ZERO, DROP_RANGE, delta):
				main.add_resource(carry_kind, carry, position)
				carry = 0
				carry_box.visible = false
				prefer_kind = "stone" if prefer_kind == "wood" else "wood"
				state = State.IDLE


## Läuft Richtung Ziel. Gibt true zurück, sobald das Ziel erreicht ist.
func _walk_to(target: Vector3, reach: float, delta: float) -> bool:
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	if dist <= reach:
		model.position.y = 0.0
		return true
	var dir := to / dist
	position += dir * SPEED * delta
	Util.face(model, dir)
	walk_time += delta
	model.position.y = absf(sin(walk_time * 10.0)) * 0.1
	return false


func _update_carry_look() -> void:
	carry_box.visible = carry > 0
	var c := Color(0.55, 0.35, 0.2) if carry_kind == "wood" else Color(0.55, 0.55, 0.6)
	carry_box.material_override = Util.mat(c)


func _swing() -> void:
	var t := create_tween()
	t.tween_property(tool_pivot, "rotation:x", -1.2, 0.1)
	t.tween_property(tool_pivot, "rotation:x", 0.0, 0.2)
