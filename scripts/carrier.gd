class_name Carrier
extends Node3D
## Grundlage für alle Figuren, die Dinge tragen können (Spieler und Personal).
## Getragene Gegenstände stapeln sich sichtbar vor der Figur.

const TRANSFER_INTERVAL := 0.05

var game: Game
var stack: Array[String] = []
var capacity := 4
var speed := 5.0
var harvest_radius := 0.9
var can_harvest := true
var harvest_bits := 0
var transfer_timer := 0.0
var model: Node3D
var body_root: Node3D
var hand_l: Node3D
var hand_r: Node3D
var moving := false
var stack_root: Node3D
var walk_time := 0.0
var is_machine := false  # Maschinen wippen nicht beim Fahren
var stack_columns := 1
var stack_spacing := 0.5


func setup(g: Game) -> void:
	game = g


## Baut eine niedliche Figur: runder Körper, großer Kopf, Mütze mit Schirm, Hände.
func build_body(shirt: Color, cap: Color, skin := Color(1.0, 0.82, 0.5)) -> void:
	model = Node3D.new()
	add_child(model)
	body_root = Node3D.new()
	model.add_child(body_root)
	var torso := Util.sphere(0.36, shirt, Vector3(0, 0.42, 0))
	torso.scale = Vector3(1.0, 1.15, 0.95)
	body_root.add_child(torso)
	body_root.add_child(Util.sphere(0.36, skin, Vector3(0, 1.02, 0)))
	var cap_dome := Util.hemisphere(0.38, cap, Vector3(0, 1.08, 0.02))
	body_root.add_child(cap_dome)
	var brim := Util.cylinder(0.24, 0.24, 0.05, cap, Vector3(0, 1.1, -0.34))
	brim.scale = Vector3(1.1, 1, 0.75)
	body_root.add_child(brim)
	body_root.add_child(Util.sphere(0.045, Color(0.12, 0.1, 0.1), Vector3(0.13, 0.98, -0.33)))
	body_root.add_child(Util.sphere(0.045, Color(0.12, 0.1, 0.1), Vector3(-0.13, 0.98, -0.33)))
	hand_l = Util.sphere(0.1, skin, Vector3(-0.38, 0.45, -0.1))
	hand_r = Util.sphere(0.1, skin, Vector3(0.38, 0.45, -0.1))
	body_root.add_child(hand_l)
	body_root.add_child(hand_r)
	# weicher runder Schatten unter der Figur
	var shadow := Util.cylinder(0.42, 0.42, 0.01, Color(0, 0, 0, 1), Vector3(0, 0.02, 0))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.18)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	add_child(shadow)
	stack_root = Node3D.new()
	stack_root.position = Vector3(0, 0.5, -0.62)
	body_root.add_child(stack_root)


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
		_idle_pose(delta)
		return
	position += dir * speed * delta
	position = game.clamp_to_map(position)
	_turn_towards(dir, delta)
	walk_time += delta
	moving = true
	if is_machine:
		body_root.position.y = absf(sin(walk_time * 20.0)) * 0.03
		return
	var bob := absf(sin(walk_time * 12.0))
	body_root.position.y = bob * 0.1
	body_root.scale = Vector3(1.0 + (1.0 - bob) * 0.05, 1.0 - (1.0 - bob) * 0.05, 1.0)
	hand_l.position.z = -0.1 + sin(walk_time * 12.0) * 0.12
	hand_r.position.z = -0.1 - sin(walk_time * 12.0) * 0.12
	stack_root.rotation.x = lerpf(stack_root.rotation.x, 0.12, 1.0 - exp(-8.0 * delta))


## Läuft zu einem Ziel. Gibt true zurück, wenn es erreicht ist.
func walk_to(target: Vector3, reach: float, delta: float) -> bool:
	var to := target - position
	to.y = 0.0
	if to.length() <= reach:
		_idle_pose(get_process_delta_time())
		return true
	walk(to.normalized(), delta)
	return false


func _idle_pose(delta: float) -> void:
	moving = false
	var k := 1.0 - exp(-10.0 * delta)
	if is_machine:
		body_root.position.y = lerpf(body_root.position.y, 0.0, k)
		return
	body_root.position.y = lerpf(body_root.position.y, 0.0, k)
	body_root.scale = body_root.scale.lerp(Vector3.ONE, k)
	hand_l.position.z = lerpf(hand_l.position.z, -0.1, k)
	hand_r.position.z = lerpf(hand_r.position.z, -0.1, k)
	stack_root.rotation.x = lerpf(stack_root.rotation.x, 0.0, k)


## Dreht die Figur weich in die Laufrichtung.
func _turn_towards(dir: Vector3, delta: float) -> void:
	var target := atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target, 1.0 - exp(-14.0 * delta))


func _refresh_stack() -> void:
	var old := stack_root.get_child_count()
	for child in stack_root.get_children():
		child.queue_free()
	var heights: Array[float] = []
	heights.resize(stack_columns)
	heights.fill(0.0)
	var i := 0
	for kind in stack:
		var it := Util.item(kind)
		var col := i % stack_columns
		var x := (col - (stack_columns - 1) * 0.5) * stack_spacing
		it.position = Vector3(x, heights[col], 0)
		stack_root.add_child(it)
		heights[col] += Util.item_height(kind)
		if i >= old:
			it.scale = Vector3.ONE * 0.3
			var t := it.create_tween()
			t.tween_property(it, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
