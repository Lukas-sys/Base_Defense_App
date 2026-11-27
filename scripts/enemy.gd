class_name Enemy
extends Node3D
## Ein Nacht-Monster: läuft zur Basis und greift sie an. Ist der Spieler nah, jagt es ihn.

const CHASE_RANGE := 6.5
const PLAYER_HIT_RANGE := 1.3

var main: Main
var max_hp := 30.0
var hp := 30.0
var speed := 2.3
var dps := 8.0
var dead := false
var model: Node3D
var hp_bar: MeshInstance3D
var walk_time := 0.0


func setup(game: Main, day: int) -> void:
	main = game
	max_hp = 25.0 + 12.0 * (day - 1)
	hp = max_hp
	speed = 2.2 + 0.08 * day
	dps = 6.0 + 1.5 * day


func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	model.add_child(Util.box(Vector3(0.9, 1.0, 0.8), Color(0.55, 0.12, 0.15), Vector3(0, 0.7, 0)))
	model.add_child(Util.box(Vector3(0.7, 0.55, 0.6), Color(0.45, 0.1, 0.12), Vector3(0, 1.45, -0.05)))
	var eye_l := Util.box(Vector3(0.14, 0.1, 0.05), Color(1.0, 0.85, 0.1), Vector3(0.16, 1.5, -0.36))
	var eye_r := Util.box(Vector3(0.14, 0.1, 0.05), Color(1.0, 0.85, 0.1), Vector3(-0.16, 1.5, -0.36))
	eye_l.material_override = Util.mat(Color(1.0, 0.85, 0.1), true)
	eye_r.material_override = Util.mat(Color(1.0, 0.85, 0.1), true)
	model.add_child(eye_l)
	model.add_child(eye_r)
	hp_bar = Util.box(Vector3(1.0, 0.1, 0.1), Color(0.9, 0.15, 0.15), Vector3(0, 2.1, 0))
	add_child(hp_bar)


func _process(delta: float) -> void:
	if dead or main.game_over:
		return
	var target := Vector3.ZERO
	var hit_range := Main.HQ_HIT_RADIUS
	var chasing_player := false
	var player := main.player
	if player.alive and position.distance_to(player.position) < CHASE_RANGE:
		target = player.position
		hit_range = PLAYER_HIT_RANGE
		chasing_player = true
	var to_target := target - position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > hit_range:
		var dir := to_target / dist
		position += dir * speed * delta
		Util.face(model, dir)
		walk_time += delta
		model.position.y = absf(sin(walk_time * 9.0)) * 0.15
	else:
		Util.face(model, to_target)
		model.position.y = 0.0
		if chasing_player:
			player.take_damage(dps * delta)
		else:
			main.damage_hq(dps * delta)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	hp_bar.scale.x = maxf(0.01, hp / max_hp)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3(1.2, 0.85, 1.2), 0.05)
	t.tween_property(model, "scale", Vector3.ONE, 0.1)
	if hp <= 0.0:
		main.on_enemy_killed(self)
