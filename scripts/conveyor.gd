extends Node3D
## Fließband von einer Maschine direkt zur Theke.
## Fertiges Essen fährt sichtbar über das Band und landet automatisch in der Auslage.
## (Absichtlich ohne class_name, damit Updates ohne neues APK funktionieren.)

const SPEED := 3.2
const GAP := 0.6

var game: Game
var kind := "pizza"
var points := PackedVector3Array()
var lengths := PackedFloat32Array()
var total := 0.0
var items: Array = []  # [{"node": Node3D, "d": float}]
var stripes: Array[Node3D] = []
var stripe_shift := 0.0


func setup(g: Game, item_kind: String, path: PackedVector3Array) -> void:
	game = g
	kind = item_kind
	points = path
	lengths.resize(points.size())
	lengths[0] = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		lengths[i] = total
	for i in range(1, points.size()):
		_build_segment(points[i - 1], points[i], i == points.size() - 1)
	var s := 0.0
	while s < total:
		var stripe := Util.box(Vector3(0.66, 0.02, 0.08), Color(0.62, 0.65, 0.7), Vector3.ZERO, 0.4)
		add_child(stripe)
		stripes.append(stripe)
		s += 0.4
	_place_stripes()


func _build_segment(a: Vector3, b: Vector3, last: bool) -> void:
	var seg := Node3D.new()
	var dir := b - a
	var extra := 0.0 if last else 0.36
	seg.position = (a + b) * 0.5
	seg.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	add_child(seg)
	var seg_len := dir.length() + extra
	seg.add_child(Util.box(Vector3(0.78, 0.12, seg_len), Color(0.3, 0.32, 0.36), Vector3(0, -0.07, 0), 0.25))
	for side in [-1.0, 1.0]:
		seg.add_child(Util.box(Vector3(0.08, 0.2, seg_len), Color(0.98, 0.78, 0.25), Vector3(side * 0.42, 0.0, 0), 0.4))
	# Beine bis zum Boden
	var steps := maxi(1, int(dir.length() / 1.6))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		if p.y < 0.3:
			continue
		for side in [-0.3, 0.3]:
			var off: Vector3 = seg.basis.x * side
			add_child(Util.box(Vector3(0.1, p.y - 0.1, 0.1), Color(0.4, 0.42, 0.46), Vector3(p.x + off.x, (p.y - 0.1) * 0.5, p.z + off.z), 0.3))


func point_at(d: float) -> Vector3:
	d = clampf(d, 0.0, total)
	for i in range(1, points.size()):
		if d <= lengths[i]:
			var seg_len := lengths[i] - lengths[i - 1]
			var t := 0.0 if seg_len <= 0.0 else (d - lengths[i - 1]) / seg_len
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


func _dir_at(d: float) -> Vector3:
	return (point_at(d + 0.05) - point_at(d - 0.05)).normalized()


func has_room() -> bool:
	return items.is_empty() or items.back()["d"] > GAP


func push() -> void:
	var node := Util.item(kind)
	add_child(node)
	node.position = point_at(0.0)
	items.append({"node": node, "d": 0.0})


func _place_stripes() -> void:
	for i in stripes.size():
		var d := fmod(i * 0.4 + stripe_shift, total)
		var st := stripes[i]
		st.position = point_at(d) + Vector3(0, -0.005, 0)
		var dir := _dir_at(d)
		if dir.length() > 0.1:
			st.basis = Basis.looking_at(dir, Vector3.UP)


func _process(delta: float) -> void:
	stripe_shift = fmod(stripe_shift + SPEED * delta, 0.4)
	_place_stripes()
	var limit := total
	for entry in items:
		entry["d"] = minf(entry["d"] + SPEED * delta, limit)
		entry["node"].position = point_at(entry["d"]) + Vector3(0, 0.02, 0)
		limit = entry["d"] - GAP
	if not items.is_empty() and items[0]["d"] >= total - 0.01 and game.counter.has_room(kind):
		var first: Dictionary = items.pop_front()
		first["node"].queue_free()
		game.counter.put(kind)
