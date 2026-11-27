extends Node
## Testspieler für die Balance (nur in der Entwicklung, Option --balance).
## Spielt das Spiel wie ein Mensch: ernten, abliefern, kassieren, Geld holen, Upgrades kaufen.
## Er protokolliert, wann welches Upgrade gekauft wird und womit er seine Zeit verbringt,
## so sieht man, wo es hakt (z. B. lange Warten, weil eine Ablage voll ist).

const RUN_MINUTES := 30.0

var game: Game
var t := 0.0
var mode := "start"
var mode_time := {}
var stuck_time := 0.0  # steht mit vollem Korb an einer vollen Ablage
var log_timer := 0.0
var earned := 0.0
var last_money_total := 0.0
var pay_target := ""


func _process(delta: float) -> void:
	t += delta
	var goal := _choose()
	mode_time[mode] = mode_time.get(mode, 0.0) + delta
	var to := goal - game.player.position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.2:
		game.autopilot_input = Vector2.ZERO
	else:
		var dir := Vector2(to.x, to.z).normalized()
		game.autopilot_input = dir * clampf(dist / 1.2, 0.25, 1.0)
	log_timer += delta
	if log_timer >= 60.0:
		log_timer = 0.0
		_log_status()
	if t >= RUN_MINUTES * 60.0:
		_summary()
		Engine.time_scale = 1.0
		game.get_tree().quit(0)


func _cheapest_tile() -> PayTile:
	var best: PayTile = null
	for id in game.tiles:
		if id == "new_location":
			continue
		var tile: PayTile = game.tiles[id]
		if best == null or tile.cost - tile.paid < best.cost - best.paid:
			best = tile
	return best


func _pile_money() -> float:
	var m: float = game.money_pile.amount
	if game.level("veg") > 0:
		m += game.veg_shop.money_pile.amount
	return m


func _choose() -> Vector3:
	var p := game.player
	var tile := _cheapest_tile()
	# 1. Upgrade kaufen, wenn genug Geld da ist (oder schon angefangen)
	if tile != null and (game.money >= tile.cost - tile.paid or (pay_target == tile.upgrade_id and game.money > 0.0)):
		if pay_target != tile.upgrade_id:
			pay_target = tile.upgrade_id
			print("BAL %5.0fs  gehe zu %s (%s)" % [t, tile.upgrade_id, Util.money_text(tile.cost)])
		mode = "upgrade"
		return tile.position
	pay_target = ""
	# 2. Geld einsammeln, wenn es für das nächste Upgrade reicht
	if tile != null and game.money + _pile_money() >= tile.cost - tile.paid and _pile_money() > 0.0:
		mode = "geld"
		return _nearest_pile()
	# 3. Fertige Ware abliefern
	for kind in ["pizza", "pasta"]:
		if p.has_item(kind):
			mode = "theke"
			_check_stuck(game.counter.drop_zone, not game.counter.has_room(kind))
			return game.counter.drop_zone
	for kind in ["tomato", "carrot"]:
		if p.has_item(kind):
			mode = "gemueseladen"
			_check_stuck(game.veg_shop.drop_zone, not game.veg_shop.accepts(kind))
			return game.veg_shop.drop_zone
	# 4. Weizen zur Maschine
	if p.has_item("wheat"):
		mode = "maschine"
		var st := game.station_needing_input()
		if st == null:
			st = game.oven
			_check_stuck(st.input_zone, true)
		return st.input_zone
	# 5. Fertiges Essen abholen (solange kein Fließband)
	var out := game.station_with_output()
	if out != null and out.output_stock >= 3:
		mode = "abholen"
		return out.output_zone
	# 6. Kasse besetzen, wenn kein Kassierer da ist und ein Auto wartet
	if game.level("cashier") == 0 and game.customers.size() > 0 and _counter_can_serve():
		mode = "kasse"
		return game.counter.cash_zone_of(0)
	if game.level("veg") > 0 and game.level("veg_cashier") == 0 and game.veg_shop.shoppers.size() > 0 and (game.veg_shop.stock["tomato"] + game.veg_shop.stock["carrot"]) > 0:
		mode = "kasse_gemuese"
		return game.veg_shop.cash_zone
	# 7. Geld holen, wenn viel herumliegt
	if _pile_money() > 50.0:
		mode = "geld"
		return _nearest_pile()
	# 8. Ernten: was am dringendsten gebraucht wird
	if not p.is_full():
		var f := _field_to_harvest()
		if f != null:
			var plant := f.nearest_grown(p.position)
			if plant != Vector3.INF:
				mode = "ernten"
				p.harvest_only = f.kind
				return plant
			mode = "warten_ernte"
			return f.position + Vector3(0, 0, 1.0)
	mode = "leerlauf"
	return game.counter.cash_zone_of(0)


func _counter_can_serve() -> bool:
	var c: Customer = game.customers[0]
	for kind in game.counter.stock:
		if game.counter.stock[kind] > 0 and c.wants(kind):
			return true
	return false


func _field_to_harvest() -> Field:
	var wheat_need: int = 0
	for st in game.stations:
		if st.visible:
			wheat_need = maxi(wheat_need, Station.MAX_INPUT - st.input_stock)
	if game.level("veg") > 0:
		var veg_low: Field = null
		for f in game.veg_fields():
			if game.veg_shop.accepts(f.kind) and (veg_low == null or game.veg_shop.stock[f.kind] < game.veg_shop.stock[veg_low.kind]):
				veg_low = f
		if veg_low != null and (wheat_need < 10 or game.veg_shop.stock[veg_low.kind] < 5):
			return veg_low
	if wheat_need > 0:
		return game.field
	return null


func _nearest_pile() -> Vector3:
	var a: Vector3 = game.money_pile.position
	if game.level("veg") > 0 and game.veg_shop.money_pile.amount > 0.0:
		var b: Vector3 = game.veg_shop.money_pile.position
		if game.money_pile.amount <= 0.0 or game.player.position.distance_to(b) < game.player.position.distance_to(a):
			return b
	return a


func _check_stuck(zone: Vector3, full: bool) -> void:
	if full and game.player.position.distance_to(zone) < 1.2:
		stuck_time += get_process_delta_time()
		mode = "wartet_voll"


func _log_status() -> void:
	var st := game.oven
	var line := "BAL %5.0fs  Geld=%s  Verkäufe=%d  Ofen ein/aus=%d/%d  Theke=%s  Autos=%d" % [t, Util.money_text(game.money), game.total_sales, st.input_stock, st.output_stock, str(game.counter.stock), game.customers.size()]
	if game.level("veg") > 0:
		line += "  Gemüse=%s  Fußgänger=%d" % [str(game.veg_shop.stock), game.veg_shop.shoppers.size()]
	print(line)


func _summary() -> void:
	print("BAL ===== Ergebnis nach %.0f Minuten =====" % (t / 60.0))
	print("BAL Stufen: %s" % str(game.levels))
	var parts: PackedStringArray = []
	var keys := mode_time.keys()
	keys.sort_custom(func(a, b): return mode_time[a] > mode_time[b])
	for k in keys:
		parts.append("%s %d%%" % [k, int(100.0 * mode_time[k] / t)])
	print("BAL Zeit: " + ", ".join(parts))
	print("BAL Wartet an voller Ablage: %.0fs" % stuck_time)
