class_name Tower
extends Node3D
## Ein Verteidigungsturm: schießt automatisch auf Gegner in Reichweite.

const RANGE := 10.0
const COOLDOWN := 1.0

var main: Main
var cooldown := 0.0
var head: Node3D


func setup(game: Main) -> void:
	main = game


func _ready() -> void:
	add_child(Util.cylinder(0.7, 0.9, 2.4, Color(0.5, 0.36, 0.22), Vector3(0, 1.2, 0)))
	add_child(Util.box(Vector3(1.8, 0.3, 1.8), Color(0.42, 0.3, 0.18), Vector3(0, 2.55, 0)))
	head = Node3D.new()
	head.position = Vector3(0, 2.9, 0)
	add_child(head)
	head.add_child(Util.box(Vector3(0.5, 0.4, 0.5), Color(0.3, 0.3, 0.35)))
	head.add_child(Util.box(Vector3(0.15, 0.15, 0.9), Color(0.2, 0.2, 0.22), Vector3(0, 0, -0.5)))
	# Aufbau-Animation
	scale = Vector3(1, 0.05, 1)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if main.game_over:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var enemy := main.find_nearest_enemy(position, RANGE)
	if enemy == null:
		return
	cooldown = COOLDOWN
	Util.face(head, enemy.position - position)
	main.spawn_projectile(position + Vector3(0, 3.0, 0), enemy, main.tower_damage(), Color(1.0, 0.5, 0.15))
