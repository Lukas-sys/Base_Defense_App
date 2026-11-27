class_name Counter
extends Node3D
## Die Theke: Essen wird hier abgelegt. Steht jemand an der Kasse, wird der vorderste
## Kunde bedient und das Geld landet auf dem Geldstapel.

const SERVE_INTERVAL := 0.3
const MAX_STOCK := 24

var game: Game
var stock := {"pizza": 0, "pasta": 0}
var piles := {}
var serve_timer := 0.0
var drop_zone := Vector3.ZERO
var cash_zone := Vector3.ZERO


func setup(g: Game) -> void:
	game = g
	add_child(Util.box(Vector3(4.6, 1.0, 1.2), Color(0.2, 0.45, 0.8), Vector3(0, 0.5, 0)))
	add_child(Util.box(Vector3(4.8, 0.12, 1.4), Color(0.92, 0.92, 0.9), Vector3(0, 1.06, 0)))
	var p := Pile.new()
	p.setup("pizza", MAX_STOCK, 3)
	p.position = Vector3(-1.9, 1.12, -0.2)
	add_child(p)
	piles["pizza"] = p
	var q := Pile.new()
	q.setup("pasta", MAX_STOCK, 3)
	q.position = Vector3(0.6, 1.12, -0.2)
	add_child(q)
	piles["pasta"] = q
	drop_zone = position + Vector3(-1.4, 0, 1.6)
	cash_zone = position + Vector3(1.4, 0, 1.6)
	var dm := Util.zone_marker(Vector2(1.8, 1.4), Color(1, 1, 1))
	dm.position = Vector3(-1.4, 0, 1.6)
	add_child(dm)
	var cm := Util.zone_marker(Vector2(1.8, 1.4), Color(0.4, 0.95, 0.4))
	cm.position = Vector3(1.4, 0, 1.6)
	add_child(cm)
	var cash_label := Util.floor_label("KASSE", 48, Color(0.4, 0.95, 0.4))
	cash_label.position = Vector3(1.4, 0.05, 2.6)
	add_child(cash_label)


func put(kind: String) -> void:
	stock[kind] += 1
	piles[kind].show_count(stock[kind])


func has_room(kind: String) -> bool:
	return stock[kind] < MAX_STOCK


## Wird jeden Frame vom Spiel aufgerufen. staffed = steht jemand an der Kasse?
func serve(customer: Customer, staffed: bool, delta: float) -> void:
	if customer == null or not staffed or not customer.is_at_counter():
		serve_timer = 0.0
		return
	serve_timer -= delta
	if serve_timer > 0.0:
		return
	serve_timer = SERVE_INTERVAL
	for kind in stock:
		if stock[kind] > 0 and customer.wants(kind):
			stock[kind] -= 1
			piles[kind].show_count(stock[kind])
			customer.receive(kind, game.price(kind))
			break
	if customer.is_done():
		game.on_customer_paid(customer)
