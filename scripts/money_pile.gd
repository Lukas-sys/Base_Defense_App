class_name MoneyPile
extends Node3D
## Hier landet das Geld der Kunden. Drüberlaufen sammelt es ein.

const BILL_VALUE_VISUAL := 5.0

var amount := 0.0
var pile: Pile
var collect_timer := 0.0


func _ready() -> void:
	add_child(Util.box(Vector3(2.2, 0.04, 2.0), Color(1, 1, 1), Vector3(0, 0.02, 0)))
	add_child(Util.box(Vector3(2.0, 0.05, 1.8), Color(0.45, 0.32, 0.22), Vector3(0, 0.03, 0)))
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
