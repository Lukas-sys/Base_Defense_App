class_name Util
extends RefCounted
## Kleine Helfer, um einfache 3D-Formen (Platzhalter-Grafik) zu bauen.

static var _materials := {}


## Liefert ein (zwischengespeichertes) einfarbiges Material.
static func mat(color: Color, glowing := false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), glowing]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	_materials[key] = m
	return m


static func box(size: Vector3, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, color, pos)


static func cylinder(top_radius: float, bottom_radius: float, height: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	return _instance(mesh, color, pos)


static func sphere(radius: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _instance(mesh, color, pos)


static func capsule(radius: float, height: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _instance(mesh, color, pos)


static func _instance(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	return mi


## Richtet einen Knoten so aus, dass seine Vorderseite (-Z) in Richtung dir zeigt.
static func face(node: Node3D, dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		node.rotation.y = atan2(-dir.x, -dir.z)


## Baut das 3D-Modell eines tragbaren Gegenstands ("wheat", "pizza", "pasta").
static func item(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"wheat":
			root.add_child(box(Vector3(0.55, 0.22, 0.4), Color(0.93, 0.9, 0.8), Vector3(0, 0.11, 0)))
			root.add_child(box(Vector3(0.08, 0.23, 0.41), Color(0.9, 0.5, 0.15), Vector3(0.1, 0.11, 0)))
		"pizza":
			root.add_child(cylinder(0.3, 0.3, 0.08, Color(0.93, 0.75, 0.4), Vector3(0, 0.04, 0)))
			root.add_child(cylinder(0.25, 0.25, 0.04, Color(0.85, 0.25, 0.18), Vector3(0, 0.09, 0)))
			root.add_child(sphere(0.05, Color(0.98, 0.95, 0.85), Vector3(0.1, 0.11, 0.05)))
			root.add_child(sphere(0.05, Color(0.98, 0.95, 0.85), Vector3(-0.08, 0.11, -0.07)))
		"pasta":
			root.add_child(cylinder(0.27, 0.2, 0.16, Color(0.95, 0.95, 0.97), Vector3(0, 0.08, 0)))
			root.add_child(cylinder(0.23, 0.23, 0.05, Color(0.98, 0.85, 0.35), Vector3(0, 0.15, 0)))
			root.add_child(sphere(0.07, Color(0.8, 0.2, 0.15), Vector3(0, 0.18, 0)))
		"money":
			root.add_child(box(Vector3(0.5, 0.1, 0.28), Color(0.35, 0.78, 0.3), Vector3(0, 0.05, 0)))
			root.add_child(box(Vector3(0.1, 0.11, 0.29), Color(0.95, 0.8, 0.3), Vector3(0, 0.05, 0)))
	return root


## Höhe eines Gegenstands, wenn er gestapelt wird.
static func item_height(kind: String) -> float:
	match kind:
		"wheat":
			return 0.23
		"pizza":
			return 0.1
		"pasta":
			return 0.19
		"money":
			return 0.11
	return 0.2


## Gestrichelter Rahmen auf dem Boden (zeigt, wo man sich hinstellen soll).
static func zone_marker(size: Vector2, color: Color) -> Node3D:
	var root := Node3D.new()
	var m := mat(color)
	var dash := 0.45
	var gap := 0.3
	var thick := 0.12
	for side in 4:
		var horizontal := side < 2
		var length := size.x if horizontal else size.y
		var count := int(length / (dash + gap))
		var start := -length * 0.5 + (length - count * (dash + gap) + gap) * 0.5
		for i in count:
			var along := start + i * (dash + gap) + dash * 0.5
			var mi := MeshInstance3D.new()
			var b := BoxMesh.new()
			if horizontal:
				b.size = Vector3(dash, 0.02, thick)
				mi.position = Vector3(along, 0.02, size.y * 0.5 * (1 if side == 0 else -1))
			else:
				b.size = Vector3(thick, 0.02, dash)
				mi.position = Vector3(size.x * 0.5 * (1 if side == 2 else -1), 0.02, along)
			mi.mesh = b
			mi.material_override = m
			root.add_child(mi)
	return root


## Text, der flach auf dem Boden liegt.
static func floor_label(text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.double_sided = false
	return l


## Kurze Zahl für Geldbeträge: 950, 1.2K, 34K, 1.5M
static func money_text(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000.0:
		return "%dK" % int(value / 1000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(value))
