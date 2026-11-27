class_name PayTile
extends Node3D
## Ein Bezahlfeld auf dem Boden: Draufstellen zahlt nach und nach Geld ein.
## Ist der Preis erreicht, wird das Upgrade freigeschaltet.

const SIZE := Vector2(2.4, 2.4)

var game: Game
var upgrade_id := ""
var cost := 10.0
var paid := 0.0
var fill: MeshInstance3D
var title_label: Label3D
var cost_label: Label3D
var pay_timer := 0.0
var wait := 0.0

## So lange muss man stehen bleiben, bevor Geld fließt (kein Geldverlust beim Drüberlaufen).
const WAIT_TIME := 0.6


func setup(g: Game, id: String) -> void:
	game = g
	upgrade_id = id


func _ready() -> void:
	add_child(Util.rounded_slab(SIZE + Vector2(0.24, 0.24), 0.5, 0.06, Color(1, 1, 1)))
	add_child(Util.rounded_slab(SIZE, 0.4, 0.07, Color(0.33, 0.2, 0.15)))
	fill = Util.box(Vector3(1, 0.02, SIZE.y - 0.3), Color(0.45, 0.78, 0.28), Vector3(0, 0.075, 0), 0.0)
	add_child(fill)
	var bills := Util.item("money")
	bills.position = Vector3(-0.75, 0.08, 0.55)
	bills.rotation_degrees = Vector3(0, 25, 0)
	add_child(bills)
	title_label = Util.floor_label("", 30, Color(1.0, 0.92, 0.7))
	title_label.position = Vector3(0, 0.08, -0.55)
	title_label.width = 220
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title_label)
	cost_label = Util.floor_label("", 60, Color(1, 1, 1))
	cost_label.position = Vector3(0.25, 0.09, 0.55)
	add_child(cost_label)
	refresh()


func refresh() -> void:
	cost = game.upgrade_cost(upgrade_id)
	title_label.text = game.upgrade_title(upgrade_id)
	var left := maxf(0.0, cost - paid)
	cost_label.text = Util.money_text(ceil(left))
	var t := clampf(paid / cost, 0.0, 1.0)
	fill.visible = t > 0.0
	var fw := SIZE.x - 0.3
	fill.scale.x = maxf(0.001, t * fw)
	fill.position.x = -fw * 0.5 + t * fw * 0.5


func contains(p: Vector3) -> bool:
	return absf(p.x - position.x) <= SIZE.x * 0.5 and absf(p.z - position.z) <= SIZE.y * 0.5


## Wird aufgerufen, solange der Spieler auf dem Feld steht.
func reset_wait() -> void:
	if wait > 0.0:
		wait = 0.0
		scale = Vector3.ONE


func pay_step(delta: float) -> void:
	if game.money <= 0.0:
		return
	if wait < WAIT_TIME:
		wait += delta
		# kleines Einsinken zeigt: gleich geht's los
		scale = Vector3.ONE * lerpf(1.0, 0.94, clampf(wait / WAIT_TIME, 0.0, 1.0))
		return
	# In etwa 1,5 Sekunden komplett bezahlen, egal wie teuer.
	var rate := maxf(cost / 1.5, 10.0)
	var amount := minf(minf(rate * delta, game.money), cost - paid)
	if amount <= 0.0:
		return
	game.money -= amount
	paid += amount
	game.tile_paid[upgrade_id] = paid
	if paid >= cost - 0.001:
		paid = 0.0
		game.tile_paid[upgrade_id] = 0.0
		game.buy_upgrade(upgrade_id)
	else:
		refresh()
