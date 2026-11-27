class_name Field
extends Node3D
## Ein Feld oder Beet (Weizen, Tomaten, Karotten). Wer hindurchläuft, erntet automatisch
## (wenn noch Platz im Korb ist). Abgeerntete Pflanzen wachsen nach einiger Zeit wieder nach.

const SPACING := 0.62

var game: Game
var kind := "wheat"
var columns := 17
var base_rows := 5
var rows_per_level := 3
var plant_scale := 1.5
var regrow_time := 16.0  # Sekunden, bis eine Pflanze nachgewachsen ist
var rows := 5
var fence: Node3D
var grown: PackedByteArray = PackedByteArray()
var regrow: PackedFloat32Array = PackedFloat32Array()
var positions: PackedVector3Array = PackedVector3Array()
var multimesh: MultiMesh
var soil: MeshInstance3D
var border: MeshInstance3D
var spins: PackedFloat32Array = PackedFloat32Array()
var grown_count := 0


func _ready() -> void:
	var mmi := MultiMeshInstance3D.new()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = Util.plant_mesh(kind)
	mmi.multimesh = multimesh
	mmi.material_override = Util.vertex_color_mat()
	add_child(mmi)
	border = MeshInstance3D.new()
	border.material_override = Util.mat(Color(0.93, 0.86, 0.68))
	add_child(border)
	soil = MeshInstance3D.new()
	soil.material_override = Util.mat(Color(0.56, 0.3, 0.22))
	add_child(soil)
	set_level(0)


## Vor add_child aufrufen, um ein anderes Beet zu bauen.
func configure(crop: String, cols: int, start_rows: int, per_level: int) -> void:
	kind = crop
	columns = cols
	base_rows = start_rows
	rows_per_level = per_level
	plant_scale = 1.5 if crop == "wheat" else 1.25
	regrow_time = 40.0 if crop == "wheat" else 45.0  # langsam genug, dass größere Felder sich lohnen


## Größe des Feldes festlegen (mehr Reihen pro Stufe).
func set_level(level: int) -> void:
	rows = base_rows + rows_per_level * level
	var total := rows * columns
	grown.resize(total)
	regrow.resize(total)
	positions.resize(total)
	spins.resize(total)
	multimesh.instance_count = total
	for r in rows:
		for c in columns:
			var i := r * columns + c
			var jitter := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
			positions[i] = Vector3((c - (columns - 1) * 0.5) * SPACING, 0, r * SPACING) + jitter
			spins[i] = randf() * TAU
			grown[i] = 1
			regrow[i] = 0.0
			_set_plant(i, 1.0)
	grown_count = total
	var w := columns * SPACING + 0.5
	var d := rows * SPACING + 0.5
	soil.mesh = Util.rounded_box_mesh(Vector3(w, 0.06, d), 0.02)
	soil.position = Vector3(0, 0.0, (rows - 1) * SPACING * 0.5)
	border.mesh = Util.rounded_box_mesh(Vector3(w + 0.4, 0.04, d + 0.4), 0.02)
	border.position = soil.position
	_build_fence()


func width() -> float:
	return columns * SPACING


## Liegt ein Punkt (Weltkoordinaten) im Feld oder knapp daneben?
func covers(p: Vector3) -> bool:
	var local := p - position
	return absf(local.x) < width() * 0.5 + 0.6 and local.z > -1.0 and local.z < size_z() + 1.0


func _build_fence() -> void:
	if fence != null:
		fence.queue_free()
	fence = Node3D.new()
	add_child(fence)
	var c := Color(0.92, 0.85, 0.65)
	var z0 := -0.6
	var z1 := size_z() + 0.2
	var x := width() * 0.5 + 0.5
	for side in [-1.0, 1.0]:
		var z := z0
		while z <= z1:
			fence.add_child(Util.box(Vector3(0.18, 0.6, 0.18), c, Vector3(side * x, 0.3, z)))
			z += 1.0
		fence.add_child(Util.box(Vector3(0.08, 0.1, z1 - z0), c, Vector3(side * x, 0.45, (z0 + z1) * 0.5)))
	var xx := -x
	while xx <= x:
		fence.add_child(Util.box(Vector3(0.18, 0.6, 0.18), c, Vector3(xx, 0.3, z1)))
		xx += 1.0
	fence.add_child(Util.box(Vector3(x * 2.0, 0.1, 0.08), c, Vector3(0, 0.45, z1)))


func size_z() -> float:
	return rows * SPACING


func _set_plant(i: int, height: float) -> void:
	var h := maxf(height, 0.05)
	var basis := Basis(Vector3.UP, spins[i]).scaled(Vector3(plant_scale, h * plant_scale * 0.75, plant_scale))
	multimesh.set_instance_transform(i, Transform3D(basis, positions[i] + Vector3(0, 0.02, 0)))


## Erntet alle reifen Halme im Umkreis eines Trägers, solange er Platz hat.
func harvest_near(carrier: Carrier) -> void:
	var local := carrier.position - position
	var r2 := carrier.harvest_radius * carrier.harvest_radius
	for i in positions.size():
		if carrier.is_full():
			return
		if grown[i] == 0:
			continue
		var d := positions[i] - local
		if d.x * d.x + d.z * d.z <= r2:
			grown[i] = 0
			regrow[i] = regrow_time
			grown_count -= 1
			_set_plant(i, 0.08)
			carrier.harvest_bits += 1
			if carrier.harvest_bits >= 1:
				carrier.harvest_bits = 0
				carrier.add_item(kind)
			if game != null:
				game.on_harvest(positions[i] + position)


## Liefert die Weltposition des nächsten reifen Halms (oder null-Ersatz Vector3.INF).
func nearest_grown(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var local := from - position
	for i in positions.size():
		if grown[i] == 0:
			continue
		var d := positions[i].distance_squared_to(local)
		if d < best_d:
			best_d = d
			best = positions[i]
	if best == Vector3.INF:
		return best
	return best + position


func _process(delta: float) -> void:
	for i in positions.size():
		if grown[i] == 1:
			continue
		regrow[i] -= delta
		if regrow[i] <= 0.0:
			grown[i] = 1
			grown_count += 1
			_set_plant(i, 1.0)
		else:
			_set_plant(i, 1.0 - regrow[i] / regrow_time)
