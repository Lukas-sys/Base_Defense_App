class_name Helper
extends Carrier
## Angestelltes Personal, das selbstständig arbeitet:
##   "farmer"    – Erntehelfer: erntet Weizen und bringt ihn zu den Maschinen
##   "harvester" – Erntemaschine: das Gleiche, nur schneller und mit großem Korntank
##   "waiter"    – Kellner: bringt fertiges Essen von den Maschinen zur Theke
##   "cashier" – steht an der Kasse und bedient die Kunden

enum State { FETCH, DELIVER }

var role := "harvester"
var state := State.FETCH
var target_station: Station
var idle_spot := Vector3.ZERO
var register_index := 0


func setup_role(g: Game, helper_role: String) -> void:
	setup(g)
	role = helper_role


func _ready() -> void:
	match role:
		"farmer":
			build_body(Color(0.45, 0.6, 0.3), Color(0.9, 0.8, 0.35))
			speed = 4.6
		"harvester":
			_build_machine(Color(0.86, 0.26, 0.22))
		"waiter":
			build_body(Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.25))
			speed = 5.4
			can_harvest = false
		"cashier":
			build_body(Color(0.85, 0.3, 0.3), Color(0.85, 0.3, 0.3))
			can_harvest = false
		"gardener":
			build_body(Color(0.35, 0.6, 0.85), Color(0.95, 0.85, 0.5))
			speed = 4.8
		"veg_harvester":
			_build_machine(Color(0.3, 0.65, 0.35))
		"veg_cashier":
			build_body(Color(0.35, 0.7, 0.35), Color(0.98, 0.98, 0.98))
			can_harvest = false
	idle_spot = position


func _process(delta: float) -> void:
	match role:
		"farmer":
			capacity = game.helper_capacity()
			_farmer(delta)
		"harvester":
			capacity = game.harvester_capacity()
			speed = game.harvester_speed()
			harvest_radius = 1.25
			_farmer(delta)
		"waiter":
			capacity = game.helper_capacity()
			_waiter(delta)
		"cashier":
			walk_to(game.counter.cash_zone_of(register_index) + Vector3(0.3, 0, 0), 0.2, delta)
		"gardener":
			capacity = game.helper_capacity()
			_gardener(delta)
		"veg_harvester":
			capacity = game.harvester_capacity()
			speed = game.harvester_speed()
			harvest_radius = 1.0
			_gardener(delta)
		"veg_cashier":
			walk_to(game.veg_shop.cash_zone + Vector3(0.3, 0, 0), 0.2, delta)


## Gärtner: erntet in den Gemüsebeeten und bringt alles zum Gemüseladen.
func _gardener(delta: float) -> void:
	if state == State.FETCH:
		if is_full():
			state = State.DELIVER
			return
		var plant := Vector3.INF
		for f in game.veg_fields():
			var p := f.nearest_grown(position)
			if p != Vector3.INF and (plant == Vector3.INF or position.distance_squared_to(p) < position.distance_squared_to(plant)):
				plant = p
		if plant == Vector3.INF:
			if stack.size() > 0:
				state = State.DELIVER
			return
		walk_to(plant, 0.3, delta)
	else:
		if stack.is_empty():
			state = State.FETCH
			return
		if walk_to(game.veg_shop.drop_zone, 0.5, delta) and not (game.veg_shop.accepts("tomato") or game.veg_shop.accepts("carrot")):
			pass  # Laden voll: warten


func _farmer(delta: float) -> void:
	if state == State.FETCH:
		if is_full():
			state = State.DELIVER
			target_station = game.station_needing_input()
			return
		var plant := game.field.nearest_grown(position)
		if plant == Vector3.INF:
			if stack.size() > 0:
				state = State.DELIVER
				target_station = game.station_needing_input()
			return
		walk_to(plant, 0.3, delta)
	else:
		if target_station == null:
			target_station = game.station_needing_input()
			if target_station == null:
				return
		if not has_item("wheat"):
			state = State.FETCH
			return
		if walk_to(target_station.input_zone, 0.5, delta) and not target_station.wants_input():
			# Maschine voll: kurz warten, dann eine andere probieren
			target_station = game.station_needing_input()


func _waiter(delta: float) -> void:
	if state == State.FETCH:
		if target_station == null or target_station.output_stock == 0:
			target_station = game.station_with_output()
		if is_full() or (target_station == null and stack.size() > 0):
			state = State.DELIVER
			return
		if target_station == null:
			walk_to(idle_spot, 0.3, delta)
			return
		walk_to(target_station.output_zone, 0.5, delta)
		if stack.size() > 0 and target_station.output_stock == 0 and _in_zone(target_station.output_zone):
			state = State.DELIVER
	else:
		if stack.is_empty():
			state = State.FETCH
			target_station = null
			return
		walk_to(game.counter.drop_zone, 0.5, delta)


func _in_zone(p: Vector3) -> bool:
	return absf(position.x - p.x) < 0.9 and absf(position.z - p.z) < 0.8


## Kleiner Mähdrescher: rote Karosserie, Fahrerkabine, gelbe Haspel vorn, Korntank hinten.
func _build_machine(paint: Color) -> void:
	is_machine = true
	stack_columns = 3
	stack_spacing = 0.42
	model = Node3D.new()
	add_child(model)
	body_root = Node3D.new()
	model.add_child(body_root)
	var red := paint
	body_root.add_child(Util.box(Vector3(1.3, 0.6, 1.9), red, Vector3(0, 0.6, 0.1), 0.3))
	body_root.add_child(Util.box(Vector3(0.9, 0.62, 0.8), Color(0.72, 0.88, 0.98), Vector3(0, 1.2, -0.25), 0.3))
	body_root.add_child(Util.box(Vector3(1.0, 0.1, 0.9), red.lightened(0.15), Vector3(0, 1.55, -0.25), 0.4))
	# Haspel vorne
	var reel := Util.cylinder(0.28, 0.28, 1.9, Color(0.98, 0.8, 0.22), Vector3(0, 0.45, -1.15), 10)
	reel.rotation_degrees = Vector3(0, 0, 90)
	body_root.add_child(reel)
	body_root.add_child(Util.box(Vector3(2.0, 0.12, 0.5), Color(0.4, 0.42, 0.46), Vector3(0, 0.2, -1.1), 0.3))
	for x in [-0.62, 0.62]:
		for z in [-0.45, 0.75]:
			var wheel := Util.cylinder(0.32 if z > 0 else 0.4, 0.32 if z > 0 else 0.4, 0.22, Color(0.16, 0.16, 0.18), Vector3(x, 0.38 if z < 0 else 0.32, z), 12)
			wheel.rotation_degrees = Vector3(0, 0, 90)
			body_root.add_child(wheel)
	hand_l = Node3D.new()
	hand_r = Node3D.new()
	body_root.add_child(hand_l)
	body_root.add_child(hand_r)
	var shadow := Util.box(Vector3(1.6, 0.01, 2.4), Color(0, 0, 0), Vector3(0, 0.02, 0), 0.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.18)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	add_child(shadow)
	stack_root = Node3D.new()
	stack_root.position = Vector3(0, 0.95, 0.65)
	body_root.add_child(stack_root)
