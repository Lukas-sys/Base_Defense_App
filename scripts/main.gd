class_name Game
extends Node3D
## Hofküche – das Herz des Spiels.
##
## Kreislauf:  Weizen ernten -> zum Ofen bringen -> Pizzen zur Theke -> Kunden bedienen
##             -> Geld einsammeln -> Geld auf Bezahlfelder bringen -> Upgrade/Personal/neue Maschine
## Langzeit:   Jedes Upgrade hat mehrere Stufen. Ist alles ausgebaut, zieht man an einen
##             neuen Standort: Es geht von vorn los, aber mit dauerhaft höheren Einnahmen.

const SAVE_PATH := "user://hofkueche_save.json"
const ROAD_Z := -13.2
const ROAD_START := -24.0
const ROAD_END := 24.0
const COUNTER_POS := Vector3(0, 0, -10)
const QUEUE_SPACING := 3.4
const FIELD_POS := Vector3(0, 0, 1.6)
const MAP_X := 8.5

const ITEM_NAMES := {"pizza": "Pizza", "pasta": "Nudeln"}
const BASE_PRICE := {"pizza": 5.0, "pasta": 9.0}

## Alle Upgrades. "req" = welche Upgrades (mit Mindeststufe) vorher gekauft sein müssen.
const UPGRADES := {
	"capacity": {"title": "Größerer Korb", "max": 10, "base": 15.0, "growth": 1.55, "pos": Vector3(-3.4, 0, -0.2), "req": {}},
	"field": {"title": "Feld vergrößern", "max": 3, "base": 40.0, "growth": 2.6, "pos": Vector3(0, 0, -0.2), "req": {"capacity": 1}},
	"farmer": {"title": "Erntehelfer", "max": 4, "base": 70.0, "growth": 2.4, "pos": Vector3(3.4, 0, -0.2), "req": {"field": 1}},
	"oven_speed": {"title": "Ofen schneller", "max": 10, "base": 50.0, "growth": 1.7, "pos": Vector3(-6.8, 0, -1.8), "req": {"farmer": 1}},
	"cashier": {"title": "Kassierer", "max": 1, "base": 160.0, "growth": 1.0, "pos": Vector3(-4.2, 0, -8.4), "req": {"farmer": 1}},
	"waiter": {"title": "Kellner", "max": 3, "base": 220.0, "growth": 2.6, "pos": Vector3(6.9, 0, -8.4), "req": {"cashier": 1}},
	"customers": {"title": "Werbeschild: mehr Kunden", "max": 5, "base": 140.0, "growth": 2.0, "pos": Vector3(7.1, 0, 3.0), "req": {"cashier": 1}},
	"pasta": {"title": "Nudelmaschine", "max": 1, "base": 600.0, "growth": 1.0, "pos": Vector3(2.0, 0, -5.0), "req": {"waiter": 1}},
	"pasta_speed": {"title": "Nudeln schneller", "max": 10, "base": 300.0, "growth": 1.7, "pos": Vector3(7.1, 0, 6.5), "req": {"pasta": 1}},
	"prices": {"title": "Bessere Zutaten (+25% Preis)", "max": 10, "base": 450.0, "growth": 1.9, "pos": Vector3(-7.1, 0, 3.0), "req": {"pasta": 1}},
	"mower": {"title": "Erntemaschine (breiter ernten)", "max": 3, "base": 250.0, "growth": 3.0, "pos": Vector3(-7.1, 0, 6.5), "req": {"field": 2}},
	"new_location": {"title": "Neuer Standort (Einnahmen x2)", "max": 1, "base": 20000.0, "growth": 1.0, "pos": Vector3(0, 0, -0.2), "req": {"field": 3, "pasta": 1, "farmer": 3, "waiter": 2, "prices": 3}},
}

var money := 0.0
var stars := 0
var levels := {}
var tile_paid := {}
var tutorial_step := 0
var total_sales := 0

var player: Player
var hud: Hud
var camera: Camera3D
var field: Field
var counter: Counter
var money_pile: MoneyPile
var stations: Array[Station] = []
var oven: Station
var pasta_machine: Station
var helpers: Array[Helper] = []
var customers: Array[Customer] = []
var tiles := {}
var arrow: Node3D
var spawn_timer := 1.0
var save_timer := 0.0
var autopilot_input := Vector2.ZERO
var fence: Node3D

var smoke_test := false
var screenshot_dir := ""
var shot_time := 0.0
var shot_index := 0
var smoke_time := 0.0
var smoke_phase := 0


func _ready() -> void:
	randomize()
	smoke_test = "--smoke" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			screenshot_dir = arg.substr(14)
			smoke_test = true
	if smoke_test:
		Engine.time_scale = 4.0
		print("Selbsttest gestartet")
	else:
		_load_game()
	_build_world()
	player = Player.new()
	player.setup(self)
	player.position = Vector3(0.3, 0, -2.0)
	add_child(player)
	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-52, 0, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 12.5
	camera.far = 80.0
	add_child(camera)
	camera.position = player.position + _camera_offset()
	hud = Hud.new()
	hud.setup(self)
	add_child(hud)
	_apply_levels()
	_refresh_tiles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


func _process(delta: float) -> void:
	camera.position = camera.position.lerp(player.position + _camera_offset(), 1.0 - exp(-6.0 * delta))
	player.capacity = 4 + 2 * level("capacity")
	player.harvest_radius = 0.9 + 0.55 * level("mower")
	_carrier_interact(player, delta)
	for h in helpers:
		_carrier_interact(h, delta)
	_player_only(delta)
	_update_customers(delta)
	_update_tutorial()
	_update_arrow()
	save_timer += delta
	if save_timer > 10.0:
		save_timer = 0.0
		save_game()
	if screenshot_dir != "":
		_screenshot_step(delta)
	elif smoke_test:
		_smoke_step(delta)


func _camera_offset() -> Vector3:
	return Vector3(0, 22.0, 17.2)


func clamp_to_map(p: Vector3) -> Vector3:
	var max_z := FIELD_POS.z + field.size_z() + 1.2
	return Vector3(clampf(p.x, -MAP_X, MAP_X), p.y, clampf(p.z, -11.0, max_z))


# ------------------------------------------------------------ Werte & Stufen

func level(id: String) -> int:
	return int(levels.get(id, 0))


func income_multiplier() -> float:
	return pow(2.0, stars)


func price(kind: String) -> float:
	return BASE_PRICE[kind] * (1.0 + 0.25 * level("prices")) * income_multiplier()


func helper_capacity() -> int:
	return 3 + level("capacity") / 2


func upgrade_cost(id: String) -> float:
	var u: Dictionary = UPGRADES[id]
	var c: float = u["base"] * pow(u["growth"], level(id)) * pow(1.6, stars)
	return ceilf(c)


func upgrade_title(id: String) -> String:
	var u: Dictionary = UPGRADES[id]
	var t: String = u["title"]
	if u["max"] > 1:
		t += "  %d/%d" % [level(id) + 1, u["max"]]
	return t


func _is_unlocked(id: String) -> bool:
	var u: Dictionary = UPGRADES[id]
	if level(id) >= u["max"]:
		return false
	var req: Dictionary = u["req"]
	for r in req:
		if level(r) < req[r]:
			return false
	return true


# ------------------------------------------------------------------ Kaufen

func buy_upgrade(id: String) -> void:
	levels[id] = level(id) + 1
	match id:
		"capacity":
			hud.show_message("Du kannst jetzt mehr tragen!")
		"field":
			field.set_level(level("field"))
			_build_fence()
			hud.show_message("Das Feld ist gewachsen!")
		"farmer":
			_spawn_helper("farmer")
			hud.show_message("Ein Erntehelfer arbeitet jetzt für dich!")
		"cashier":
			_spawn_helper("cashier")
			hud.show_message("Der Kassierer bedient jetzt die Kunden!")
		"waiter":
			_spawn_helper("waiter")
			hud.show_message("Ein Kellner bringt das Essen zur Theke!")
		"pasta":
			pasta_machine.visible = true
			pasta_machine.process_mode = Node.PROCESS_MODE_INHERIT
			hud.show_message("Nudelmaschine gebaut! Kunden bestellen jetzt auch Nudeln.")
		"oven_speed", "pasta_speed":
			hud.show_message("Die Maschine arbeitet schneller!")
		"customers":
			hud.show_message("Mehr Kunden kommen vorbei!")
		"prices":
			hud.show_message("Bessere Zutaten: Kunden zahlen mehr!")
		"mower":
			hud.show_message("Du erntest jetzt breiter!")
		"new_location":
			_move_to_new_location()
			return
	_refresh_tiles()
	save_game()


func _move_to_new_location() -> void:
	stars += 1
	levels = {}
	tile_paid = {}
	money = 0.0
	save_game()
	get_tree().reload_current_scene()


func _refresh_tiles() -> void:
	for id in UPGRADES:
		var show_tile := _is_unlocked(id)
		if show_tile and not tiles.has(id):
			var t := PayTile.new()
			t.setup(self, id)
			t.paid = float(tile_paid.get(id, 0.0))
			t.position = UPGRADES[id]["pos"]
			add_child(t)
			tiles[id] = t
			if id == "new_location":
				hud.show_message("Alles ausgebaut! Ein neuer Standort wartet auf dich.", 4.0)
		elif not show_tile and tiles.has(id):
			tiles[id].queue_free()
			tiles.erase(id)
		elif show_tile:
			tiles[id].refresh()


func _apply_levels() -> void:
	field.set_level(level("field"))
	_build_fence()
	for i in level("farmer"):
		_spawn_helper("farmer")
	for i in level("waiter"):
		_spawn_helper("waiter")
	for i in level("cashier"):
		_spawn_helper("cashier")
	var has_pasta := level("pasta") > 0
	pasta_machine.visible = has_pasta
	pasta_machine.process_mode = Node.PROCESS_MODE_INHERIT if has_pasta else Node.PROCESS_MODE_DISABLED


func _spawn_helper(role: String) -> void:
	var h := Helper.new()
	h.setup_role(self, role)
	match role:
		"farmer":
			h.position = Vector3(randf_range(-3, 3), 0, 0.5)
		"waiter":
			h.position = Vector3(randf_range(-1.0, 1.0), 0, -5.5)
		"cashier":
			h.position = counter.cash_zone
	add_child(h)
	helpers.append(h)


# ------------------------------------------------------- Abgeben & Abholen

func _in_zone(p: Vector3, center: Vector3, half: Vector2) -> bool:
	return absf(p.x - center.x) <= half.x and absf(p.z - center.z) <= half.y


func _carrier_interact(c: Carrier, delta: float) -> void:
	if c.can_harvest and not c.is_full():
		var local := c.position - FIELD_POS
		if absf(local.x) < 6.0 and local.z > -1.0 and local.z < field.size_z() + 1.0:
			field.harvest_near(c)
	c.transfer_timer -= delta
	if c.transfer_timer > 0.0:
		return
	var is_farmer := c is Helper and (c as Helper).role == "farmer"
	var is_waiter := c is Helper and (c as Helper).role == "waiter"
	for st in stations:
		if not st.visible:
			continue
		if not is_waiter and _in_zone(c.position, st.input_zone, Vector2(0.9, 0.8)) and c.has_item(st.input_kind) and st.wants_input():
			c.take_item(st.input_kind)
			fly_item(st.input_kind, c.position + Vector3(0, 1.0, 0), st.input_pile.global_position + Vector3(0, 0.4, 0))
			st.put_input()
			c.transfer_timer = Carrier.TRANSFER_INTERVAL
			return
		if not is_farmer and _in_zone(c.position, st.output_zone, Vector2(0.9, 0.8)) and not c.is_full() and st.output_stock > 0:
			st.take_output()
			fly_item(st.output_kind, st.output_pile.global_position + Vector3(0, 0.3, 0), c.position + Vector3(0, 1.0, 0))
			c.add_item(st.output_kind)
			c.transfer_timer = Carrier.TRANSFER_INTERVAL
			return
	if _in_zone(c.position, counter.drop_zone, Vector2(0.9, 0.7)):
		for kind in ["pizza", "pasta"]:
			if c.has_item(kind) and counter.has_room(kind):
				c.take_item(kind)
				fly_item(kind, c.position + Vector3(0, 1.0, 0), counter.piles[kind].global_position + Vector3(0, 0.3, 0))
				counter.put(kind)
				c.transfer_timer = Carrier.TRANSFER_INTERVAL
				return


func _player_only(delta: float) -> void:
	if money_pile.amount > 0.0 and _in_zone(player.position, money_pile.position, Vector2(1.1, 1.0)):
		var got := money_pile.collect()
		money += got
		popup_text(player.position, "+$" + Util.money_text(got), Color(0.6, 1.0, 0.5))
	var standing_on: PayTile = null
	for id in tiles:
		var t: PayTile = tiles[id]
		if t.contains(player.position):
			standing_on = t
			break
	if standing_on != null:
		standing_on.pay_step(delta)


func station_needing_input() -> Station:
	var best: Station = null
	for st in stations:
		if not st.visible or not st.wants_input():
			continue
		if best == null or st.input_stock < best.input_stock:
			best = st
	return best


func station_with_output() -> Station:
	var best: Station = null
	for st in stations:
		if not st.visible or st.output_stock == 0:
			continue
		if not counter.has_room(st.output_kind):
			continue
		if best == null or st.output_stock > best.output_stock:
			best = st
	return best


# ------------------------------------------------------------------ Kunden

func _update_customers(delta: float) -> void:
	var max_queue := 2 + level("customers")
	spawn_timer -= delta
	if spawn_timer <= 0.0 and customers.size() < max_queue:
		spawn_timer = 5.0 / (1.0 + 0.35 * level("customers"))
		_spawn_customer()
	for i in customers.size():
		customers[i].target_x = COUNTER_POS.x - i * QUEUE_SPACING
	var staffed := level("cashier") > 0 or _in_zone(player.position, counter.cash_zone, Vector2(0.9, 0.7))
	var front: Customer = customers[0] if customers.size() > 0 else null
	counter.serve(front, staffed, delta)


func _spawn_customer() -> void:
	var order := {}
	var count := randi_range(1, 3 + level("customers") / 2)
	var kinds := ["pizza"]
	if level("pasta") > 0:
		kinds.append("pasta")
	for i in count:
		var k: String = kinds[randi() % kinds.size()]
		order[k] = order.get(k, 0) + 1
	var c := Customer.new()
	c.setup(self, order)
	c.position = Vector3(ROAD_START, 0, ROAD_Z)
	c.target_x = ROAD_START
	add_child(c)
	customers.append(c)


func on_customer_paid(c: Customer) -> void:
	customers.erase(c)
	money_pile.add(c.paid)
	total_sales += 1
	popup_text(money_pile.position, "+$" + Util.money_text(c.paid), Color(0.6, 1.0, 0.5))
	c.leave()


# ------------------------------------------------------- Anleitung & Pfeil

func goal_text() -> String:
	match tutorial_step:
		0:
			return "Lauf durchs Weizenfeld, um zu ernten"
		1:
			return "Bring den Weizen zum Ofen (weißer Rahmen)"
		2:
			return "Hol die fertigen Pizzen ab (grüner Rahmen)"
		3:
			return "Leg die Pizzen auf die Theke"
		4:
			return "Stell dich an die Kasse und bediene die Kunden"
		5:
			return "Sammle dein Geld ein"
		6:
			return "Stell dich auf das Bezahlfeld, um es zu kaufen"
	return ""


func _update_tutorial() -> void:
	var done := false
	match tutorial_step:
		0:
			done = player.has_item("wheat")
		1:
			done = oven.input_stock > 0 or oven.output_stock > 0
		2:
			done = player.has_item("pizza")
		3:
			done = counter.stock["pizza"] > 0
		4:
			done = money_pile.amount > 0.0
		5:
			done = money > 0.0
		6:
			done = level("capacity") > 0
	if done:
		tutorial_step += 1


func _arrow_target() -> Vector3:
	match tutorial_step:
		0:
			return field.nearest_grown(player.position)
		1:
			return oven.input_zone
		2:
			return oven.output_zone
		3:
			return counter.drop_zone
		4:
			return counter.cash_zone
		5:
			return money_pile.position
		6:
			return UPGRADES["capacity"]["pos"]
	# Danach: auf das günstigste bezahlbare Feld zeigen
	if money_pile.amount > 0.0 and money < 1.0:
		return money_pile.position
	var best := Vector3.INF
	var best_cost := INF
	for id in tiles:
		var t: PayTile = tiles[id]
		var left := t.cost - t.paid
		if left <= money and left < best_cost:
			best_cost = left
			best = t.position
	return best


func _update_arrow() -> void:
	var target := _arrow_target()
	arrow.visible = target != Vector3.INF
	if arrow.visible:
		arrow.position = target + Vector3(0, 2.2 + absf(sin(Time.get_ticks_msec() * 0.005)) * 0.5, 0)


# --------------------------------------------------------------- Welt-Aufbau

const GRASS_COLORS := [Color(0.5, 0.7, 0.34), Color(0.66, 0.64, 0.36), Color(0.44, 0.66, 0.55), Color(0.7, 0.56, 0.42)]


func _build_world() -> void:
	var grass: Color = GRASS_COLORS[stars % GRASS_COLORS.size()]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = grass
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 1.0)
	env.ambient_light_energy = 0.38
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	# Wiese
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	ground.mesh = plane
	ground.material_override = Util.mat(grass)
	ground.position.y = -0.03
	add_child(ground)
	# Grasbüschel
	for i in 120:
		var p := Vector3(randf_range(-20, 20), 0, randf_range(-12, 22))
		if absf(p.x) < 9.0 and p.z > -12.0 and p.z < 14.0:
			continue
		var tuft := Util.cylinder(0.0, 0.12, 0.3, grass.darkened(0.15), p + Vector3(0, 0.12, 0), 4)
		add_child(tuft)
	# Straße mit Bordstein und Mittellinie
	add_child(Util.box(Vector3(70, 0.05, 3.4), Color(0.66, 0.67, 0.7), Vector3(0, 0.0, ROAD_Z), 0.1))
	add_child(Util.box(Vector3(70, 0.12, 0.25), Color(0.92, 0.92, 0.92), Vector3(0, 0.03, ROAD_Z + 1.8), 0.4))
	add_child(Util.box(Vector3(70, 0.12, 0.25), Color(0.92, 0.92, 0.92), Vector3(0, 0.03, ROAD_Z - 1.8), 0.4))
	var x := -34.0
	while x < 34.0:
		add_child(Util.box(Vector3(1.2, 0.06, 0.14), Color(1, 1, 1), Vector3(x, 0.01, ROAD_Z), 0.5))
		x += 2.4
	# Holzboden der Küche mit Dielen-Textur und Rand
	var floor_size := Vector2(19.0, 10.6)
	var floor_mesh := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = floor_size
	floor_mesh.mesh = fp
	floor_mesh.material_override = Util.textured_mat(Util.plank_texture(), Vector2(floor_size.x / 4.0, floor_size.y / 4.0), Color(0.82, 0.8, 0.78))
	floor_mesh.position = Vector3(0, 0.03, -6.1)
	add_child(floor_mesh)
	add_child(Util.box(Vector3(floor_size.x + 0.3, 0.06, floor_size.y + 0.3), Color(0.93, 0.86, 0.68), Vector3(0, 0.0, -6.1), 0.2))
	# Geländer an den Seiten der Küche
	for side in [-1.0, 1.0]:
		var gx: float = side * (floor_size.x * 0.5 + 0.05)
		var z := -11.2
		while z <= -1.2:
			add_child(Util.box(Vector3(0.18, 0.7, 0.18), Color(0.95, 0.9, 0.75), Vector3(gx, 0.35, z), 0.3))
			z += 1.0
		add_child(Util.box(Vector3(0.14, 0.12, 10.2), Color(0.95, 0.9, 0.75), Vector3(gx, 0.62, -6.2), 0.4))
	# Bäume und Büsche ringsum
	for i in 26:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * randf_range(10.8, 18.0), 0, randf_range(-11.0, 18.0))
		if randf() < 0.5:
			_add_tree(p)
		else:
			_add_bush(p)
	for i in 10:
		_add_bush(Vector3(randf_range(-16, 16), 0, randf_range(-18.0, -15.5)))

	field = Field.new()
	field.game = self
	field.position = FIELD_POS
	add_child(field)

	oven = _make_station("oven", "pizza", Vector3(-5.0, 0, -5.0), Color(0.9, 0.38, 0.28))
	oven.base_time = 1.6
	pasta_machine = _make_station("pasta", "pasta", Vector3(2.0, 0, -5.0), Color(0.98, 0.78, 0.25))
	pasta_machine.base_time = 2.2

	counter = Counter.new()
	counter.position = COUNTER_POS
	add_child(counter)
	counter.setup(self)

	money_pile = MoneyPile.new()
	money_pile.position = Vector3(4.4, 0, -8.6)
	add_child(money_pile)

	arrow = Node3D.new()
	var arrow_color := Color(0.35, 0.7, 1.0)
	arrow.add_child(Util.box(Vector3(0.42, 0.7, 0.42), arrow_color, Vector3(0, 0.95, 0), 0.4))
	var head := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.1, 0.75, 0.45)
	head.mesh = prism
	head.material_override = Util.mat(arrow_color)
	head.rotation_degrees = Vector3(0, 0, 180)
	head.position = Vector3(0, 0.3, 0)
	arrow.add_child(head)
	add_child(arrow)


func _add_tree(p: Vector3) -> void:
	var s := randf_range(0.8, 1.3)
	var t := Node3D.new()
	t.position = p
	t.scale = Vector3.ONE * s
	t.rotation.y = randf() * TAU
	t.add_child(Util.cylinder(0.14, 0.2, 1.2, Color(0.55, 0.36, 0.24), Vector3(0, 0.6, 0), 7))
	t.add_child(Util.lowpoly_sphere(0.9, Color(0.36, 0.66, 0.34), Vector3(0, 1.7, 0)))
	t.add_child(Util.lowpoly_sphere(0.65, Color(0.42, 0.72, 0.36), Vector3(0.35, 2.2, 0.1)))
	add_child(t)


func _add_bush(p: Vector3) -> void:
	var b := Node3D.new()
	b.position = p
	b.rotation.y = randf() * TAU
	var c := Color(0.4, 0.7, 0.38).lightened(randf_range(-0.08, 0.08))
	b.add_child(Util.lowpoly_sphere(0.8, c, Vector3(0, 0.35, 0)))
	b.add_child(Util.lowpoly_sphere(0.6, c.lightened(0.06), Vector3(0.7, 0.25, 0.2)))
	b.add_child(Util.lowpoly_sphere(0.55, c.darkened(0.05), Vector3(-0.6, 0.22, -0.1)))
	b.scale = Vector3(1, 0.8, 1) * randf_range(0.8, 1.3)
	add_child(b)


# ------------------------------------------------------------ Effekte

var _last_burst := 0


## Kleine Ernte-Partikel, wenn ein Halm geschnitten wird.
func on_harvest(where: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_burst < 70:
		return
	_last_burst = now
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3(0.08, 0.08, 0.08)
	p.mesh = m
	p.material_override = Util.mat(Color(1.0, 0.85, 0.35))
	p.position = where + Vector3(0, 0.6, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Lässt einen Gegenstand im Bogen von a nach b fliegen (nur Optik).
func fly_item(kind: String, from: Vector3, to: Vector3) -> void:
	var it := Util.item(kind)
	it.position = from
	add_child(it)
	var t := it.create_tween()
	t.tween_method(func(k: float) -> void:
		var pos := from.lerp(to, k)
		pos.y += sin(k * PI) * 1.2
		it.position = pos
		it.rotation.y = k * PI, 0.0, 1.0, 0.22)
	t.tween_callback(it.queue_free)


func _make_station(id: String, out_kind: String, pos: Vector3, color: Color) -> Station:
	var st := Station.new()
	st.position = pos
	add_child(st)
	st.setup(self, id, out_kind, color)
	stations.append(st)
	return st


func _build_fence() -> void:
	if fence != null:
		fence.queue_free()
	fence = Node3D.new()
	add_child(fence)
	var c := Color(0.92, 0.85, 0.65)
	var z0 := FIELD_POS.z - 0.6
	var z1 := FIELD_POS.z + field.size_z() + 0.2
	var x := Field.COLUMNS * Field.SPACING * 0.5 + 0.5
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


func popup_text(where: Vector3, text: String, color: Color) -> void:
	var label := Util.billboard_label(text, 72, color)
	label.position = where + Vector3(0, 2.4, 0)
	add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y + 1.5, 1.0)
	t.tween_property(label, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(label.queue_free)


# -------------------------------------------------------------- Spielstand

func save_game() -> void:
	if smoke_test:
		return
	var data := {
		"version": 1,
		"money": money,
		"stars": stars,
		"levels": levels,
		"tile_paid": tile_paid,
		"tutorial": tutorial_step,
		"sales": total_sales,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	money = float(data.get("money", 0.0))
	stars = int(data.get("stars", 0))
	levels = data.get("levels", {})
	tile_paid = data.get("tile_paid", {})
	tutorial_step = int(data.get("tutorial", 0))
	total_sales = int(data.get("sales", 0))


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


# ------------------------------------------------------- Selbsttest (CI)

func _smoke_step(delta: float) -> void:
	smoke_time += delta
	match smoke_phase:
		0:
			# Spieler läuft ins Feld und muss Weizen ernten
			autopilot_input = (Vector2(0, 4.0) - Vector2(player.position.x, player.position.z)).normalized()
			if player.has_item("wheat"):
				autopilot_input = Vector2.ZERO
				print("Selbsttest: Spieler hat geerntet (%d Weizen)" % player.count_item("wheat"))
				smoke_phase = 1
			elif smoke_time > 20.0:
				print("SMOKE_TEST_FAIL Spieler konnte nicht ernten")
				get_tree().quit(1)
		1:
			money = 1000000.0
			for _r in 12:
				for id in UPGRADES:
					if id != "new_location" and _is_unlocked(id):
						buy_upgrade(id)
			print("Selbsttest: Stufen %s" % str(levels))
			print("Selbsttest: Personal=%d Bezahlfelder=%d" % [helpers.size(), tiles.size()])
			player.position = Vector3(-9.5, 0, 9.0)
			smoke_phase = 2
		2:
			if smoke_time > 90.0:
				var ok := total_sales > 0
				print("%s Verkäufe=%d Geldstapel=%d Theke=%s" % ["SMOKE_TEST_OK" if ok else "SMOKE_TEST_FAIL", total_sales, int(money_pile.amount), str(counter.stock)])
				Engine.time_scale = 1.0
				get_tree().quit(0 if ok else 1)


# ------------------------------------------- Bildschirmfotos (für die Entwicklung)

func _screenshot_step(delta: float) -> void:
	shot_time += delta
	if shot_index == 0 and shot_time > 1.0:
		_save_shot("1_start")
		money = 1000000.0
		for _r in 3:
			for id in ["capacity", "field", "farmer", "cashier", "waiter", "pasta", "customers"]:
				if _is_unlocked(id):
					buy_upgrade(id)
		money = 870.0
		shot_index = 1
	elif shot_index == 1 and shot_time > 14.0:
		_save_shot("2_kueche")
		player.position = Vector3(0, 0, 5.0)
		camera.position = player.position + _camera_offset()
		shot_index = 2
	elif shot_index == 2 and shot_time > 15.5:
		_save_shot("3_feld")
		get_tree().quit(0)


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := screenshot_dir.path_join(shot_name + ".png")
	img.save_png(path)
	var small := img.duplicate() as Image
	small.resize(img.get_width() / 2, img.get_height() / 2)
	small.save_jpg(screenshot_dir.path_join(shot_name + "_klein.jpg"), 0.7)
	print("Bildschirmfoto gespeichert: ", path)
