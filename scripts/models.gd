class_name Models
extends RefCounted
## Lädt die fertigen 3D-Modelle aus assets/kaykit (KayKit von Kay Lousberg, Lizenz CC0).

const BASE := "res://assets/kaykit/"

static var _cache := {}


## Erzeugt ein Modell, z. B. Models.spawn("restaurant-bits/oven").
## Gibt null zurück, falls die Datei fehlt (dann wird die einfache Grafik benutzt).
static func spawn(name: String, scale := 1.0, pos := Vector3.ZERO, rot_y_deg := 0.0) -> Node3D:
	var path := BASE + name + ".gltf"
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _cache[path]
	if scene == null:
		push_warning("Modell fehlt: " + path)
		return null
	var node := scene.instantiate() as Node3D
	node.scale = Vector3.ONE * scale
	node.position = pos
	node.rotation_degrees.y = rot_y_deg
	return node


## Fügt ein Modell als Kind hinzu (falls vorhanden). Gibt true zurück, wenn es geklappt hat.
static func add(parent: Node, name: String, scale := 1.0, pos := Vector3.ZERO, rot_y_deg := 0.0) -> bool:
	var n := spawn(name, scale, pos, rot_y_deg)
	if n == null:
		return false
	parent.add_child(n)
	return true
