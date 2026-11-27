class_name Player
extends Node3D
## Die Spielfigur: läuft herum, sammelt automatisch in der Nähe und kämpft automatisch.

const SPEED := 6.5
const GATHER_RANGE := 1.9
const RESPAWN_TIME := 5.0
const BASE_HEAL_PER_SECOND := 4.0

var main: Main
var max_hp := 100.0
var hp := 100.0
var alive := true
var gather_timer := 0.0
var attack_timer := 0.0
var respawn_timer := 0.0
var model: Node3D
var tool_pivot: Node3D


func setup(game: Main) -> void:
	main = game


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	model.add_child(Util.capsule(0.4, 1.6, Color(0.2, 0.45, 0.9), Vector3(0, 0.8, 0)))
	model.add_child(Util.sphere(0.3, Color(1.0, 0.82, 0.62), Vector3(0, 1.75, 0)))
	model.add_child(Util.box(Vector3(0.12, 0.08, 0.12), Color(0.1, 0.1, 0.1), Vector3(0.12, 1.8, -0.27)))
	model.add_child(Util.box(Vector3(0.12, 0.08, 0.12), Color(0.1, 0.1, 0.1), Vector3(-0.12, 1.8, -0.27)))
	# Werkzeug in der rechten Hand (schwingt beim Arbeiten)
	tool_pivot = Node3D.new()
	tool_pivot.position = Vector3(0.5, 1.0, 0)
	model.add_child(tool_pivot)
	tool_pivot.add_child(Util.box(Vector3(0.08, 0.08, 0.9), Color(0.5, 0.33, 0.18), Vector3(0, 0, -0.4)))
	tool_pivot.add_child(Util.box(Vector3(0.1, 0.35, 0.22), Color(0.75, 0.75, 0.8), Vector3(0, 0.1, -0.8)))


func _process(delta: float) -> void:
	if main.game_over:
		return
	if not alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return
	_move(delta)
	_gather(delta)
	_attack(delta)
	if position.length() < Main.BASE_RADIUS:
		hp = minf(max_hp, hp + BASE_HEAL_PER_SECOND * delta)


func _move(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	input += main.hud.joystick.output
	if input.length() > 1.0:
		input = input.normalized()
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 0.05:
		position += dir * SPEED * delta
		var limit := Main.MAP_RADIUS - 1.0
		if position.length() > limit:
			position = position.normalized() * limit
		Util.face(model, dir)
		model.position.y = absf(sin(Time.get_ticks_msec() * 0.015)) * 0.12
	else:
		model.position.y = 0.0


func _gather(delta: float) -> void:
	var node := main.find_nearest_resource(position, GATHER_RANGE)
	if node == null:
		gather_timer = 0.0
		return
	Util.face(model, node.position - position)
	gather_timer += delta
	if gather_timer >= main.gather_interval():
		gather_timer = 0.0
		_swing()
		var got := node.harvest(main.gather_yield())
		if got > 0:
			main.add_resource(node.kind, got, node.position)


func _attack(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	var enemy := main.find_nearest_enemy(position, main.weapon_range())
	if enemy == null:
		return
	attack_timer = main.weapon_cooldown()
	Util.face(model, enemy.position - position)
	_swing()
	main.spawn_projectile(position + Vector3(0, 1.2, 0), enemy, main.weapon_damage(), Color(1.0, 0.9, 0.3))


func _swing() -> void:
	var t := create_tween()
	t.tween_property(tool_pivot, "rotation:x", -1.2, 0.08)
	t.tween_property(tool_pivot, "rotation:x", 0.0, 0.15)


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		alive = false
		visible = false
		respawn_timer = RESPAWN_TIME
		main.hud.show_message("Du wurdest besiegt! Zurück in %d Sekunden ..." % int(RESPAWN_TIME))


func _respawn() -> void:
	alive = true
	visible = true
	hp = max_hp
	position = Vector3(0, 0, 2.0)
