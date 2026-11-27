class_name ResourceNode
extends Node3D
## Ein Baum (Holz) oder Felsen (Stein). Kann abgebaut werden und wächst wieder nach.

const RESPAWN_TIME := 25.0

var kind := "wood"  # "wood" oder "stone"
var max_amount := 5
var amount := 5
var respawn_timer := 0.0
var visual: Node3D
var stump: MeshInstance3D


func setup(resource_kind: String) -> void:
	kind = resource_kind
	max_amount = 5 if kind == "wood" else 6
	amount = max_amount


func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s := randf_range(0.8, 1.25)
	if kind == "wood":
		visual.add_child(Util.cylinder(0.18, 0.25, 1.2, Color(0.45, 0.28, 0.15), Vector3(0, 0.6, 0)))
		visual.add_child(Util.cylinder(0.0, 1.0, 1.6, Color(0.18, 0.5, 0.22), Vector3(0, 1.8, 0)))
		visual.add_child(Util.cylinder(0.0, 0.75, 1.3, Color(0.22, 0.58, 0.26), Vector3(0, 2.5, 0)))
		stump = Util.cylinder(0.22, 0.27, 0.3, Color(0.4, 0.26, 0.14), Vector3(0, 0.15, 0))
	else:
		var rock := Util.sphere(0.8, Color(0.52, 0.52, 0.56), Vector3(0, 0.35, 0))
		rock.scale = Vector3(1.2, 0.75, 1.0)
		visual.add_child(rock)
		var rock2 := Util.sphere(0.45, Color(0.6, 0.6, 0.64), Vector3(0.55, 0.25, 0.3))
		visual.add_child(rock2)
		stump = Util.sphere(0.3, Color(0.45, 0.45, 0.48), Vector3(0, 0.1, 0))
	visual.scale = Vector3.ONE * s
	visual.rotation.y = randf() * TAU
	stump.visible = false
	add_child(stump)


func is_available() -> bool:
	return amount > 0


## Baut bis zu n Einheiten ab und gibt zurück, wie viel wirklich abgebaut wurde.
func harvest(n: int) -> int:
	var got := mini(n, amount)
	amount -= got
	_wobble()
	if amount <= 0:
		visual.visible = false
		stump.visible = true
		respawn_timer = RESPAWN_TIME
	return got


func _process(delta: float) -> void:
	if amount > 0:
		return
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		amount = max_amount
		stump.visible = false
		visual.visible = true
		var target := visual.scale
		visual.scale = Vector3.ONE * 0.1
		var t := create_tween()
		t.tween_property(visual, "scale", target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _wobble() -> void:
	var t := create_tween()
	t.tween_property(visual, "rotation:z", 0.12, 0.06)
	t.tween_property(visual, "rotation:z", -0.08, 0.08)
	t.tween_property(visual, "rotation:z", 0.0, 0.08)
