extends Node3D
## Gemüseladen: ein Marktstand mit Kisten. Tomaten und Karotten werden vorne abgelegt,
## Fußgänger stellen sich hinten auf dem Gehweg an und kaufen ein.
## (Ohne class_name, damit Updates ohne neues APK funktionieren.)

const SERVE_INTERVAL := 0.15
const MAX_STOCK := 80
const QUEUE_SPACING := 1.25
const LANE_Z := -1.6  # Gehweg hinter dem Stand (relativ zum Stand)
const PedestrianScript := preload("res://scripts/pedestrian.gd")

var game: Game
var stock := {"tomato": 0, "carrot": 0}
var piles := {}
var drop_zone := Vector3.ZERO
var cash_zone := Vector3.ZERO
var money_pile: MoneyPile
var shoppers: Array = []
var spawn_timer := 1.0
var serve_timer := 0.0
var sales := 0


func setup(g: Game) -> void:
	game = g
	var wood := Color(0.78, 0.55, 0.34)
	# Tresen aus Holz mit heller Platte
	add_child(Util.box(Vector3(4.8, 0.95, 1.2), wood, Vector3(0, 0.475, 0), 0.15))
	add_child(Util.box(Vector3(5.0, 0.12, 1.4), Color(0.95, 0.9, 0.78), Vector3(0, 1.0, 0), 0.3))
	for x in [-2.2, -0.75, 0.75, 2.2]:
		add_child(Util.box(Vector3(0.1, 0.9, 1.22), wood.darkened(0.15), Vector3(x, 0.45, 0), 0.3))
	# Markise grün-weiß
	for i in 8:
		var c := Color(0.35, 0.7, 0.35) if i % 2 == 0 else Color(1, 1, 1)
		var stripe := Util.box(Vector3(0.62, 0.08, 1.7), c, Vector3(-2.17 + i * 0.62, 2.55, -0.25), 0.3)
		stripe.rotation_degrees = Vector3(-14, 0, 0)
		add_child(stripe)
	for px in [-2.3, 2.3]:
		add_child(Util.box(Vector3(0.12, 1.5, 0.12), Color(0.96, 0.96, 0.94), Vector3(px, 1.8, -0.8), 0.4))
	var sign := Util.billboard_label("GEMÜSE", 52, Color.WHITE)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	sign.outline_size = 10
	sign.outline_modulate = Color(0.25, 0.5, 0.25)
	sign.position = Vector3(0, 2.75, 0.55)
	sign.rotation_degrees = Vector3(-14, 0, 0)
	add_child(sign)
	# Deko-Kisten neben dem Stand
	Models.add(self, "restaurant-bits/crate_lettuce", 0.5, Vector3(-3.3, 0.03, -0.2))
	Models.add(self, "restaurant-bits/crate_potatoes", 0.5, Vector3(-3.3, 0.03, 0.8))
	Models.add(self, "restaurant-bits/crate_onions", 0.5, Vector3(3.2, 0.03, -0.2))
	# Kasse
	add_child(Util.box(Vector3(0.6, 0.35, 0.45), Color(0.3, 0.3, 0.34), Vector3(1.9, 1.24, 0.2), 0.3))
	add_child(Util.box(Vector3(0.5, 0.2, 0.06), Color(0.45, 0.9, 0.55), Vector3(1.9, 1.34, 0.44), 0.3))
	var p := Pile.new()
	p.setup("tomato", 24, 3)
	p.position = Vector3(-1.95, 1.06, -0.3)
	add_child(p)
	piles["tomato"] = p
	var q := Pile.new()
	q.setup("carrot", 24, 3)
	q.position = Vector3(-0.15, 1.06, -0.3)
	add_child(q)
	piles["carrot"] = q
	drop_zone = position + Vector3(-0.6, 0, 1.6)
	cash_zone = position + Vector3(1.8, 0, 1.6)
	var dm := Util.zone_marker(Vector2(1.8, 1.4), Color(1, 1, 1))
	dm.position = Vector3(-0.6, 0, 1.6)
	add_child(dm)
	var cm := Util.zone_marker(Vector2(1.8, 1.4), Color(0.45, 0.95, 0.35))
	cm.position = Vector3(1.8, 0, 1.6)
	add_child(cm)
	var cash_label := Util.floor_label("KASSE", 48, Color(0.45, 0.95, 0.35))
	cash_label.position = Vector3(1.8, 0.05, 2.6)
	add_child(cash_label)
	money_pile = MoneyPile.new()
	money_pile.position = position + Vector3(4.2, 0, 1.8)
	get_parent().add_child.call_deferred(money_pile)


func accepts(kind: String) -> bool:
	return stock.has(kind) and stock[kind] < MAX_STOCK


func put(kind: String) -> void:
	stock[kind] += 1
	piles[kind].show_count(stock[kind])


func _staffed() -> bool:
	return game.level("veg_cashier") > 0 or game._in_zone(game.player.position, cash_zone, Vector2(0.9, 0.7))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var max_queue: int = 5 + game.level("veg_customers")
	spawn_timer -= delta
	if spawn_timer <= 0.0 and shoppers.size() < max_queue:
		spawn_timer = 2.0 / (1.0 + 0.35 * game.level("veg_customers"))
		_spawn_shopper()
	for i in shoppers.size():
		shoppers[i].target_x = position.x + i * QUEUE_SPACING
	_serve(delta)


func _spawn_shopper() -> void:
	var kinds := ["tomato"]
	if game.level("carrots") > 0:
		kinds.append("carrot")
	var order := {}
	for i in randi_range(1, 3 + game.level("veg_customers") / 2):
		var k: String = kinds[randi() % kinds.size()]
		order[k] = order.get(k, 0) + 1
	var s = PedestrianScript.new()
	s.setup(game)
	s.shop = self
	s.order = order
	s.position = position + Vector3(15.0, 0, LANE_Z)
	s.target_x = s.position.x
	game.add_child(s)
	shoppers.append(s)


func _serve(delta: float) -> void:
	if shoppers.is_empty():
		return
	var front = shoppers[0]
	if not _staffed() or not front.is_at(position.x):
		serve_timer = 0.0
		return
	serve_timer -= delta
	if serve_timer > 0.0:
		return
	serve_timer = SERVE_INTERVAL
	for kind in stock:
		if stock[kind] > 0 and front.wants(kind):
			stock[kind] -= 1
			piles[kind].show_count(stock[kind])
			front.receive(kind, game.price(kind))
			break
	if front.is_done():
		shoppers.pop_front()
		money_pile.add(front.paid)
		sales += 1
		game.total_sales += 1
		game.popup_text(money_pile.position, "+$" + Util.money_text(front.paid), Color(0.6, 1.0, 0.5))
		front.leave()
