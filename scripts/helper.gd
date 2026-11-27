class_name Helper
extends Carrier
## Angestelltes Personal, das selbstständig arbeitet:
##   "farmer"  – erntet Weizen und bringt ihn zu den Maschinen
##   "waiter"  – bringt fertiges Essen von den Maschinen zur Theke
##   "cashier" – steht an der Kasse und bedient die Kunden

enum State { FETCH, DELIVER }

var role := "farmer"
var state := State.FETCH
var target_station: Station
var idle_spot := Vector3.ZERO


func setup_role(g: Game, helper_role: String) -> void:
	setup(g)
	role = helper_role


func _ready() -> void:
	match role:
		"farmer":
			build_body(Color(0.45, 0.6, 0.3), Color(0.9, 0.8, 0.35))
			speed = 4.6
		"waiter":
			build_body(Color(0.95, 0.95, 0.95), Color(0.2, 0.2, 0.25))
			speed = 5.4
			can_harvest = false
		"cashier":
			build_body(Color(0.85, 0.3, 0.3), Color(0.85, 0.3, 0.3))
			can_harvest = false
	idle_spot = position


func _process(delta: float) -> void:
	capacity = game.helper_capacity()
	match role:
		"farmer":
			_farmer(delta)
		"waiter":
			_waiter(delta)
		"cashier":
			walk_to(game.counter.cash_zone + Vector3(0.3, 0, 0), 0.2, delta)


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
