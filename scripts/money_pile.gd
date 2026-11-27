class_name MoneyPile
extends Node3D
## Hier landet das Geld der Kunden. Drüberlaufen sammelt es ein.

const BILL_VALUE_VISUAL := 5.0

var amount := 0.0
var pile: Pile
var collect_timer := 0.0


func _ready() -> void:
	add_child(Util.rounded_slab(Vector2(2.3, 2.1), 0.45, 0.05, Color(1, 1, 1)))
	add_child(Util.rounded_slab(Vector2(2.05, 1.85), 0.35, 0.06, Color(0.52, 0.38, 0.27)))
	pile = Pile.new()
	pile.setup("money", 32, 2)
	pile.position = Vector3(-0.35, 0.06, -0.4)
	add_child(pile)


func add(value: float) -> void:
	amount += value
	_refresh()


## Gibt alles Geld heraus und leert den Stapel.
func collect() -> float:
	var v := amount
	amount = 0.0
	_refresh()
	return v


func _refresh() -> void:
	var bills := 0
	if amount > 0.0:
		bills = clampi(int(ceil(amount / BILL_VALUE_VISUAL)), 1, 32)
	pile.show_count(bills)
