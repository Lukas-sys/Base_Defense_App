extends Carrier
## Fußgänger, der im Gemüseladen einkauft: läuft auf dem Gehweg zur Kasse, wartet,
## bezahlt und geht auf der anderen Seite des Gehwegs wieder weg.
## (Ohne class_name, damit Updates ohne neues APK funktionieren.)

const SPEED := 4.0

var shop: Node3D
var order := {}
var target_x := 0.0
var leaving := false
var paid := 0.0
var bubble: Label3D
var bubble_bg: Sprite3D


func _ready() -> void:
	var shirts := [Color(0.95, 0.55, 0.3), Color(0.4, 0.65, 0.95), Color(0.85, 0.4, 0.6), Color(0.55, 0.8, 0.45), Color(0.98, 0.82, 0.3)]
	var shirt: Color = shirts[randi() % shirts.size()]
	var hair := [Color(0.3, 0.2, 0.15), Color(0.9, 0.75, 0.4), Color(0.15, 0.12, 0.1), Color(0.7, 0.35, 0.2)]
	var skins := [Color(1.0, 0.82, 0.6), Color(0.85, 0.62, 0.45), Color(0.6, 0.42, 0.3)]
	build_body(shirt, hair[randi() % hair.size()], skins[randi() % skins.size()])
	can_harvest = false
	bubble_bg = Sprite3D.new()
	bubble_bg.texture = Util.bubble_texture()
	bubble_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble_bg.no_depth_test = true
	bubble_bg.render_priority = 1
	bubble_bg.pixel_size = 0.008
	bubble_bg.position = Vector3(0, 2.0, 0)
	add_child(bubble_bg)
	bubble = Util.billboard_label("", 40, Color(0.2, 0.17, 0.17))
	bubble.outline_size = 0
	bubble.render_priority = 2
	bubble.position = Vector3(0, 2.0, 0)
	add_child(bubble)
	_update_bubble()


func _process(delta: float) -> void:
	var dir := 0.0
	if leaving:
		dir = 1.0
		position.x += SPEED * 1.2 * delta
		if position.x > shop.position.x + 16.0:
			queue_free()
	else:
		var dx := target_x - position.x
		if absf(dx) > 0.05:
			dir = signf(dx)
			position.x += dir * minf(absf(dx), SPEED * delta)
	if dir != 0.0:
		_turn_towards(Vector3(dir, 0, 0), delta)
		walk_time += delta
		var bob := absf(sin(walk_time * 12.0))
		body_root.position.y = bob * 0.1
		hand_l.position.z = -0.1 + sin(walk_time * 12.0) * 0.12
		hand_r.position.z = -0.1 - sin(walk_time * 12.0) * 0.12
	else:
		_turn_towards(Vector3(0, 0, 1), delta)
		_idle_pose(delta)


func is_at(x: float) -> bool:
	return not leaving and absf(position.x - x) < 0.05 and absf(target_x - x) < 0.01


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
	add_item(kind)
	_update_bubble()


func leave() -> void:
	leaving = true
	var t := create_tween()
	t.tween_property(self, "position:z", position.z - 0.7, 0.3)
	bubble.text = "Danke!"
	bubble.modulate = Color(0.2, 0.6, 0.25)
	bubble_bg.scale = Vector3(1.3, 1.0, 1)


func _update_bubble() -> void:
	var parts: PackedStringArray = []
	for k in order:
		if order[k] > 0:
			parts.append("%d %s" % [order[k], Game.ITEM_NAMES[k]])
	bubble.text = "\n".join(parts)
	bubble_bg.scale = Vector3(1.7, 0.35 + 0.65 * maxi(1, parts.size()), 1)
