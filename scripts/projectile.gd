class_name Projectile
extends Node3D
## Ein Geschoss, das sein Ziel verfolgt und beim Treffer Schaden macht.

const SPEED := 20.0

var target: Enemy
var damage := 10.0


func setup(enemy: Enemy, dmg: float, color: Color) -> void:
	target = enemy
	damage = dmg
	var ball := Util.sphere(0.15, color)
	ball.material_override = Util.mat(color, true)
	add_child(ball)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var aim := target.position + Vector3(0, 1.0, 0)
	var to := aim - position
	var step := SPEED * delta
	if to.length() <= step:
		target.take_damage(damage)
		queue_free()
	else:
		position += to.normalized() * step
