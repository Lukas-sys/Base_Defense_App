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
