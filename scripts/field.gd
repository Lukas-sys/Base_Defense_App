class_name Field
extends Node3D
## Das Weizenfeld. Wer hindurchläuft, erntet automatisch (wenn noch Platz im Korb ist).
## Abgeerntete Halme wachsen nach einiger Zeit wieder nach.

const SPACING := 0.7
const COLUMNS := 15
const BASE_ROWS := 5
const ROWS_PER_LEVEL := 3
const REGROW_TIME := 9.0

var rows := BASE_ROWS
var grown: PackedByteArray = PackedByteArray()
var regrow: PackedFloat32Array = PackedFloat32Array()
var positions: PackedVector3Array = PackedVector3Array()
var multimesh: MultiMesh
var soil: MeshInstance3D
var grown_count := 0


func _ready() -> void:
	var mmi := MultiMeshInstance3D.new()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.0
	stalk.bottom_radius = 0.26
	stalk.height = 1.25
	stalk.radial_segments = 5
	stalk.rings = 1
	multimesh.mesh = stalk
	mmi.multimesh = multimesh
	mmi.material_override = Util.mat(Color(0.98, 0.82, 0.25))
	add_child(mmi)
	soil = MeshInstance3D.new()
	soil.material_override = Util.mat(Color(0.52, 0.3, 0.22))
	add_child(soil)
	set_level(0)


## Größe des Feldes festlegen (mehr Reihen pro Stufe).
func set_level(level: int) -> void:
	rows = BASE_ROWS + ROWS_PER_LEVEL * level
	var total := rows * COLUMNS
	grown.resize(total)
	regrow.resize(total)
	positions.resize(total)
	multimesh.instance_count = total
	for r in rows:
		for c in COLUMNS:
			var i := r * COLUMNS + c
			var jitter := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
			positions[i] = Vector3((c - (COLUMNS - 1) * 0.5) * SPACING, 0, r * SPACING) + jitter
			grown[i] = 1
			regrow[i] = 0.0
			_set_plant(i, 1.0)
	grown_count = total
	var plane := BoxMesh.new()
	plane.size = Vector3(COLUMNS * SPACING + 0.6, 0.04, rows * SPACING + 0.6)
	soil.mesh = plane
	soil.position = Vector3(0, 0.0, (rows - 1) * SPACING * 0.5)


func size_z() -> float:
	return rows * SPACING


func _set_plant(i: int, height: float) -> void:
	var h := maxf(height, 0.05)
	var basis := Basis().scaled(Vector3(1.0, h, 1.0))
	multimesh.set_instance_transform(i, Transform3D(basis, positions[i] + Vector3(0, h * 0.62, 0)))


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
			regrow[i] = REGROW_TIME
			grown_count -= 1
			_set_plant(i, 0.08)
			carrier.add_item("wheat")


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
			_set_plant(i, 1.0 - regrow[i] / REGROW_TIME)
